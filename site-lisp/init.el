;; Copyright (c) 2010-2025, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without modification, are permitted provided that
;; the following conditions are met:
;;
;;  - Redistributions of source code must retain the above copyright notice, this list of conditions and the
;;    following disclaimer.
;;
;;  - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
;;    following - disclaimer in the documentation and/or other materials provided - with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
;; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
;; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;; POSSIBILITY OF SUCH DAMAGE.

(defun go-to-my-project ()
  (let ((curproj (getenv "CURRENT_PROJECT")))
    (let ((project-file
           (expand-file-name (if curproj
                                 (concat "~/.projects/" curproj "/project.el")
                               "~/.projects/.@current/project.el"))))
      (message (concat "Project file: " project-file))
      (if (file-exists-p project-file)
          (load project-file)
        (message (concat "Unknown project file: " project-file))))))

;; Project management
(defun goto-my-project ()
  "Go to the latest project"
  (interactive)
  (go-to-my-project))

(global-set-key "\M-gp" 'goto-my-project)
(go-to-my-project)
