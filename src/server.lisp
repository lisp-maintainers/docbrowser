(in-package :docbrowser)

(declaim #.*compile-decl*)

(defparameter *files-base-dir*
  (format nil "~asrc/" (namestring (asdf:component-pathname (asdf:find-system :docbrowser)))))

(defclass docbrowser-acceptor (hunchentoot:acceptor)
  ()
  (:documentation "Acceptor for the documentation browser"))

(defvar *url-handlers* (make-hash-table :test 'equal)
  "A hash table keyed on the base URL that maps to the underlying handler function")

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor docbrowser-acceptor) request)
  (let ((handler (gethash (hunchentoot:script-name request) *url-handlers*)))
    (if handler
        (funcall handler)
        (call-next-method))))

(defun %make-define-handler-fn-form (docstring name body)
  `(defun ,name ()
     ,@(when docstring (list docstring))
     ,@body))

(defmacro define-handler-fn (name url &body body)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (setf (gethash ,url *url-handlers*) ',name)
     ,(if (stringp (car body))
          (%make-define-handler-fn-form (car body) name (cdr body))
          (%make-define-handler-fn-form nil name body))))

(defun hunchentoot-stream-as-text (&key (content-type "text/html") (append-charset t))
  "Sends the appropriate headers to ensure that all data is sent back using
the correct encoding and returns a text stream that the result can be
written to."
  (when content-type
    (setf (hunchentoot:content-type*)
          (if append-charset
              (format nil "~a;charset=UTF-8" content-type)
              content-type)))
  (flexi-streams:make-flexi-stream (hunchentoot:send-headers) :external-format :utf8))

(defmacro with-hunchentoot-stream ((out &optional (content-type "text/html") (append-charset t)) &body body)
  `(let ((,out (hunchentoot-stream-as-text :content-type ,content-type :append-charset ,append-charset)))
     ,@body))

(defvar *global-acceptor* nil
  "The acceptor for the currently running server.")

(defun start-docserver (&optional (port 8080))
  (when *global-acceptor*
    (error "Server is already running"))
    (hunchentoot:start (setq *global-acceptor* (make-instance 'docbrowser-acceptor :port port)))
  (setq hunchentoot:*show-lisp-errors-p* t)
  (setq hunchentoot:*log-lisp-warnings-p* t)
  (setq hunchentoot:*log-lisp-backtraces-p* t)
  (setf (hunchentoot:acceptor-access-log-destination *global-acceptor*) (make-broadcast-stream))
  (values))
