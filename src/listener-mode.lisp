(in-package :cl-user)
(defpackage :lem.listener-mode
  (:use :cl :lem :lem.util)
  (:export :listener-mode
           :*listener-mode-keymap*
           :listener-start
           :listener-reset-prompt
           :listener-return
           :listener-prev-input
           :listener-next-input
           :listener-reset-interactive))
(in-package :lem.listener-mode)

(defvar *prompt-attribute* (make-attribute "blue" nil :bold-p t))

(defvar %listener-point-indicator (gensym))
(defmacro %listener-point ()
  `(get-bvar %listener-point-indicator))

(defvar %listener-history-indicator (gensym))
(defmacro %listener-history ()
  `(get-bvar %listener-history-indicator))

(define-minor-mode listener-mode
    (:name "listener"
	   :keymap *listener-mode-keymap*)
  (setf (get-bvar :enable-syntax-highlight) nil)
  (unless (%listener-history)
    (setf (%listener-history)
          (make-history))))

(defun listener-start-point ()
  (copy-point (%listener-point) :temporary))

(defun listener-start (buffer-name mode)
  (let ((buffer (get-buffer-create buffer-name)))
    (setf (current-window) (pop-to-buffer buffer))
    (funcall mode)
    (listener-reset-prompt buffer)))

(defun listener-update-point (&optional (point (current-point)))
  (when (%listener-point)
    (delete-point (%listener-point)))
  (setf (%listener-point)
        (if point
            (copy-point point :right-inserting)
            (copy-point (current-point) :right-inserting))))

(defun listener-reset-prompt (&optional (buffer (current-buffer)))
  (let ((cur-point (buffer-point buffer)))
    (buffer-end cur-point)
    (unless (start-line-p cur-point)
      (insert-character cur-point #\newline 1)
      (buffer-end cur-point))
    (insert-string cur-point
		   (princ-to-string
		    (funcall
		     (get-bvar :listener-get-prompt-function)))
		   :attribute *prompt-attribute*
		   :read-only t
		   :field t)
    (buffer-end cur-point)
    (buffer-undo-boundary buffer)
    (listener-update-point)))

(define-key *listener-mode-keymap* (kbd "C-m") 'listener-return)
(define-command listener-return () ()
  (with-point ((point (buffer-end (current-point)) :left-inserting))
    (if (not (funcall (get-bvar :listener-check-confirm-function) point))
        (insert-character point #\newline)
        (let ((start (listener-start-point)))
          (unless (point< start point)
            (listener-reset-prompt)
            (return-from listener-return t))
          (let ((str (points-to-string start point)))
            (add-history (%listener-history) str)
            (buffer-end point)
            (insert-character point #\newline)
            (listener-update-point)
            (funcall (get-bvar :listener-confirm-function) point str)))))
  t)

(define-key *listener-mode-keymap* (kbd "M-p") 'listener-prev-input)
(define-command listener-prev-input () ()
  (multiple-value-bind (str win)
      (prev-history (%listener-history))
    (let ((start (listener-start-point))
          (end (buffers-end (current-buffer))))
      (save-excursion
        (delete-between-points start end)
        (when win (insert-string start str))
        (move-point (%listener-point) start)))))

(define-key *listener-mode-keymap* (kbd "M-n") 'listener-next-input)
(define-command listener-next-input () ()
  (multiple-value-bind (str win)
      (next-history (%listener-history))
    (let ((start (listener-start-point))
          (end (buffers-end (current-buffer))))
      (save-excursion
        (delete-between-points start end)
        (when win (insert-string start str))
        (move-point (%listener-point) start)))))

(define-key *listener-mode-keymap* (kbd "M-r") 'listener-reset-interactive)
(define-command listener-reset-interactive (arg) ("P")
  (when arg
    (let ((*inhibit-read-only* t))
      (erase-buffer (current-buffer))))
  (listener-reset-prompt)
  t)

(define-key *listener-mode-keymap* (kbd "C-c C-u") 'listener-clear-input)
(define-command listener-clear-input () ()
  (delete-between-points (listener-start-point)
			 (buffers-end (current-buffer))))
