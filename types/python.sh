#!/usr/bin/env bash

PROJECT_NAME=$1
PROJECT=$PROJECTS_DIR/$1
PROJECT_DEVDIR=$2

. $PROJECT_PACK/bash_profile.sh


make_emacs() {
    EMACS=$(which emacs-snapshot || which emacs)
    test -h $PROJECT/bin/emacs && rm $PROJECT/bin/emacs
    test -e $PROJECT/bin/emacs || ln -s $EMACS $PROJECT/bin/emacs

    cat > $PROJECT/project.el <<EOF
(setq load-path (cons "$PROJECT_PACK/site-lisp" (cons "$PROJECT_PACK/site-lisp/mk-project" load-path)))
(setq load-path (cons "~/.emacs.d/site-lisp/python-mode/"  load-path))
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

(defun my-python-filename-to-clipboard ()
  (interactive)
  (let ((text buffer-file-name))
    (deactivate-mark)
    (x-set-selection 'PRIMARY text)
    (message "%s" text)))

(defun my-python-gather-names (indent)
  (message "my-python-gather-names: indent=%d - current=%d" indent (current-indentation))
  (if (py-beginning-of-block)
      (if (>= (current-indentation) indent)
          (my-python-gather-names indent)

          (let ((name (save-excursion
                        (forward-word)
                        (forward-whitespace 1)
                        (word-at-point))))
            (message "concat: %s" name)
            (concat (my-python-gather-names (current-indentation)) "." name)))
    ""))

(defun my-python-def-to-clipboard ()
  (interactive)
  (save-excursion
    (if (py-beginning-of-block)
        (let ((py-module (py-qualified-module-name buffer-file-name)))
          (let ((py-names (my-python-gather-names (+ 1 (current-indentation)))))
            (let ((text (concat py-module py-names)))
              (deactivate-mark)
              (x-set-selection 'PRIMARY text)
              (message "%s" text))))
      (message "not found"))))

(global-set-key (kbd "C-c p C-f") 'my-python-filename-to-clipboard)
(global-set-key (kbd "C-c p C-d") 'my-python-def-to-clipboard)

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

;(pymacs-load "ropemacs" "rope-")
;(setq ropemacs-enable-autoimport t)

(setq whitespace-line-column 140)

(defun $PROJECT_NAME-project-startup ()
  nil)

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
