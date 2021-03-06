(in-package :lem)

(export '(completion-attribute
          non-focus-completion-attribute
          completion
          completion-test
          completion-hypheen
          completion-file
          completion-strings
          completion-buffer-name))

(defun fuzzy-match-p (str elt)
  (loop :with start := 0
        :for c :across str
        :do (let ((pos (position c elt :start start)))
              (if pos
                  (setf start pos)
                  (return nil)))
        :finally (return t)))

(defun completion-test (x y)
  (and (<= (length x) (length y))
       (string= x y :end2 (length x))))

(defun %comp-split (string separator)
  (let ((list nil) (words 0) (end (length string)))
    (when (zerop end) (return-from %comp-split nil))
    (flet ((separatorp (char) (find char separator))
           (done () (return-from %comp-split (cons (subseq string 0 end) list))))
      (loop :for start = (position-if #'separatorp string :end end :from-end t)
            :do (when (null start) (done))
                (push (subseq string (1+ start) end) list)
                (push (string (aref string start)) list)
                (incf words)
                (setf end start)))))

(defun completion (name list &key (test #'search) separator key)
  (let ((strings
          (remove-if-not (if separator
                             (let* ((parts1 (%comp-split name separator))
                                    (parts1-length (length parts1)))
                               (lambda (elt)
                                 (when key
                                   (setf elt (funcall key elt)))
                                 (let* ((parts2 (%comp-split elt separator))
                                        (parts2-length (length parts2)))
                                   (and (<= parts1-length parts2-length)
                                        (loop
                                          :for p1 :in parts1
                                          :for p2 :in parts2
                                          :unless (funcall test p1 p2)
                                          :do (return nil)
                                          :finally (return t))))))
                             (lambda (elt)
                               (funcall test name elt)))
                         list)))
    strings))

(defun completion-hypheen (name list &key key)
  (completion name list :test #'completion-test :separator "-" :key key))

(defun completion-file (str directory)
  (setf str (expand-file-name str directory))
  (let* ((dirname (directory-namestring str))
         (files (mapcar #'namestring (append (uiop:directory-files dirname)
                                             (uiop:subdirectories dirname)))))
    (let ((strings
            (loop
              :for pathname :in (or (directory str) (list str))
              :for str := (namestring pathname)
              :append
                 (completion (enough-namestring str dirname)
                             files
                             :test #'completion-test
                             :separator "-."
                             :key #'(lambda (path)
                                      (enough-namestring path dirname))))))
      strings)))

(defun completion-strings (str strings)
  (completion str strings :test #'fuzzy-match-p))

(defun completion-buffer-name (str)
  (completion-strings str (mapcar #'buffer-name (buffer-list))))
