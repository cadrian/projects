#!/usr/bin/env bash

# Copyright (c) 2010-2012, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that
# the following conditions are met:
#
#  - Redistributions of source code must retain the above copyright notice, this list of conditions and the
#    following disclaimer.
#
#  - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#    following - disclaimer in the documentation and/or other materials provided - with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

PROJECT_NAME=$1
PROJECT=$PROJECTS_DIR/$1
PROJECT_DEVDIR=$2

. $PROJECT_PACK/bash_profile.sh


make_emacs() {
    test -h $PROJECT/bin/emacs && rm $PROJECT/bin/emacs
    EMACS=$(which emacs-snapshot || which emacs)
    test -e $PROJECT/bin/emacs || ln -s $EMACS $PROJECT/bin/emacs
    test -e $PROJECT/bin/etags || ln -s /usr/bin/ctags-exuberant $PROJECT/bin/etags

    cat > $PROJECT/project.el <<EOF
(setq load-path (cons "$PROJECT_PACK/site-lisp" (cons "$PROJECT_PACK/site-lisp/mk-project" load-path)))
(setq load-path (cons "~/.emacs.d/site-lisp/python-mode/"  load-path))
(setq project-basedir "$PROJECT_DEVDIR")
(setenv "PYMACS_PYTHON" "python2.6")

(add-to-list 'auto-mode-alist '("\\\\.pycfg\\\\'" . python-mode))

(require 'mk-project)
(global-set-key (kbd "C-c p c") 'project-compile)
(global-set-key (kbd "C-c p l") 'project-load)
(global-set-key (kbd "C-c p a") 'project-ack)
(global-set-key (kbd "C-c p g") 'project-grep)
(global-set-key (kbd "C-c p o") 'project-multi-occur)
(global-set-key (kbd "C-c p u") 'project-unload)
(global-set-key (kbd "C-c p f") 'project-find-file) ; or project-find-file-ido
(global-set-key (kbd "C-c p i") 'project-index)
(global-set-key (kbd "C-c p s") 'project-status)
(global-set-key (kbd "C-c p h") 'project-home)
(global-set-key (kbd "C-c p d") 'project-dired)
(global-set-key (kbd "C-c p t") 'project-tags)

(defun my-python-gather-names (indent)
  (if (py-beginning-of-def-or-class)
      (if (>= (current-indentation) indent)
          (progn
            (my-python-gather-names indent))

          (let ((name (save-excursion
                        (forward-word)
                        (forward-whitespace 1)
                        (word-at-point))))
            (let ((parent-name (my-python-gather-names (current-indentation))))
              (if parent-name
                  (concat parent-name "." name)
                name))))
    nil))

(defun my-python-def ()
  (save-excursion
    (if (py-beginning-of-def-or-class)
        (progn
          (forward-word)
          (let ((py-module (py-qualified-module-name buffer-file-name)))
            (let ((py-names (my-python-gather-names (1+ (current-indentation)))))
              (concat py-module "." py-names)))))))

(defun my-python-unittest-def ()
  (save-excursion
    (if (py-beginning-of-def-or-class)
        (progn
          (forward-word)
            (let ((py-names (my-python-gather-names (1+ (current-indentation)))))
              (concat buffer-file-name " " py-names))))))

(defun my-copy-to-clipboard (text)
  (interactive)
    (deactivate-mark)
    (x-set-selection 'PRIMARY text)
    (x-set-selection 'CLIPBOARD text)
    (message "%s" text))

(defun my-python-filename-to-clipboard ()
  (interactive)
  (my-copy-to-clipboard buffer-file-name))

(defun my-python-def-to-clipboard ()
  (interactive)
  (let ((text (my-python-def)))
    (if text
        (my-copy-to-clipboard text)
      (message "no def or class found"))))

(defun my-python-unittest-def-to-clipboard ()
  (interactive)
  (let ((text (my-python-unittest-def)))
    (if text
        (my-copy-to-clipboard text)
      (message "no def or class found"))))

(global-set-key (kbd "C-c p y f") 'my-python-filename-to-clipboard)
(global-set-key (kbd "C-c p y x") 'my-python-def-to-clipboard)
(global-set-key (kbd "C-c p y d") 'my-python-unittest-def-to-clipboard)

(project-def "$PROJECT_NAME-project"
      '((basedir          "$PROJECT_DEVDIR")
        (src-patterns     ("*.py" "*.pycfg"))
        (ignore-patterns  ("*.pyc"))
        (tags-file        "$PROJECT/.mk/TAGS")
        (file-list-cache  "$PROJECT/.mk/files")
        (open-files-cache "$PROJECT/.mk/open-files")
        (vcs              git)
        (compile-cmd      nil)
        (startup-hook     $PROJECT_NAME-project-startup)
        (shutdown-hook    nil)))

(setq ropemacs-enable-shortcuts nil)
(setq ropemacs-local-prefix "C-c C-p")

(require 'python-mode)
(autoload 'pymacs-apply "pymacs")
(autoload 'pymacs-call "pymacs")
(autoload 'pymacs-eval "pymacs" nil t)
(autoload 'pymacs-exec "pymacs" nil t)
(autoload 'pymacs-load "pymacs" nil t)

(setq whitespace-line-column 140)

(defun $PROJECT_NAME-project-startup ()
  nil)

(require 'flymake)

;(load-library "flymake-cursor")
(defun $PROJECT_NAME-flymake-pycodecheck-init ()
  (let* ((temp-file (flymake-init-create-temp-buffer-copy
                     'flymake-create-temp-inplace))
         (local-file (file-relative-name
                      temp-file
                      (file-name-directory buffer-file-name))))
    (list "$PROJECT_PACK/types/rc/pylint_etc_wrapper.py" (list local-file))))
(add-to-list 'flymake-allowed-file-name-masks
             '("\\\\.py\\\\'" $PROJECT_NAME-flymake-pycodecheck-init))

(add-hook 'find-file-hook 'flymake-find-file-hook)

(set-frame-name "Emacs: $PROJECT_NAME")
(project-load "$PROJECT_NAME-project")
(project-dired)
EOF
}


make_tags() {
    cat > $PROJECT/bin/tag_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-$PROJECT}
export TAGS=\${TAGS:-\$PROJECT/.mk/TAGS}
export LOG=\${LOG:-\$PROJECT/.mk/tag_log}
export PROJECT_DEVDIR=\$(readlink \$PROJECT/dev)
test x\$1 == x-a || rm -f \$LOG
touch \$LOG
echo "\$(date -R) - updating $PROJECT" >>\$LOG
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.py -print | etags \$@ -f \$TAGS --language-force=python --python-kinds=cfm -L- 2>>\$LOG || echo "Brand new project: no file tagged."

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            project=$PROJECTS_DIR/\${dep#\$PROJECT/dep/}
            PROJECT=\$project \$project/bin/tag_all.sh -a \$@
        fi
    done
fi
EOF

    cat > $PROJECT/bin/find_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-$PROJECT}
export TAGS=\${TAGS:-\$PROJECT/.mk/TAGS}
export PROJECT_DEVDIR=\$(readlink \$PROJECT/dev)
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.py -print 2>/dev/null

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            project=$PROJECTS_DIR/\${dep#\$PROJECT/dep/}
            PROJECT=\$project \$project/bin/find_all.sh -a \$@
        fi
    done
fi
EOF

    chmod +x $PROJECT/bin/tag_all.sh $PROJECT/bin/find_all.sh
    _project_tag_all $PROJECT
}


make_go() {
    cat > $PROJECT/go <<EOF

export PATH=\$({
        echo $PROJECT/bin
        find -L $PROJECT/dev/ -name tmp -prune -o -type d -name bin -print | sort
        test -d $PROJECT/dep && find -L $PROJECT/dep -name tmp -prune -o -type d -name bin -print | sort
    } | awk '{printf("%s:", \$0)}'
    echo \$PROJECT_DEFAULT_PATH
)

#export PYTHONPATH=\$({
#        $PROJECT_PACK/utils/modules_finder.py \$(find -L $PROJECT/dev/ -name __init__.py -exec dirname {} \; | sort)
#        test -d $PROJECT/dep && $PROJECT_PACK/utils/modules_finder.py \$(find -L $PROJECT/dep -name __init__.py -exec dirname {} \; | sort) | sort
#    } | awk '{printf("%s:", \$0)}'
#    echo
#)

test "\$1" == "-fast" || _project_tag_all $PROJECT
EOF

    chmod +x $PROJECT/go
}


test -d $PROJECT/.mk || mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
