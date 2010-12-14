#!/usr/bin/env bash

PROJECT_NAME=$1
PROJECT=$PROJECTS_DIR/$1


make_emacs() {
    MALABAR=$HOME/.emacs.d/malabar-1.4.0

    cat > $PROJECT/project.el <<EOF
(add-to-list 'load-path "$PROJECT_PACK/site-lisp")
(add-to-list 'load-path "$PROJECT_PACK/site-lisp/mk-project")
(add-to-list 'load-path "$MALABAR/lisp")

(setq semantic-default-submodes '(global-semantic-idle-scheduler-mode
                                  global-semanticdb-minor-mode
                                  global-semantic-idle-summary-mode
                                  global-semantic-mru-bookmark-mode))
(semantic-mode 1)
(require 'malabar-mode)
(setq malabar-groovy-lib-dir "$MALABAR/lib")
(add-hook 'malabar-mode-hook
  (lambda ()
    (add-hook 'after-save-hook 'malabar-compile-file-silently
               nil t)))
(add-to-list 'auto-mode-alist '("\\\\.java\\\\'" . malabar-mode))

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

(project-def "$PROJECT_NAME-project"
      '((basedir          "$PROJECT/dev/")
        (src-patterns     ("*.java" "*.c" "*.cpp" "*.h"))
        (ignore-patterns  ("*.o"))
        (tags-file        "$PROJECT/.mk/TAGS")
        (file-list-cache  "$PROJECT/.mk/files")
        (open-files-cache "$PROJECT/.mk/open-files")
        (vcs              git)
        (compile-cmd      "mvn")
        (startup-hook     $PROJECT_NAME-project-startup)
        (shutdown-hook    nil)))

(defun $PROJECT_NAME-project-startup ()
  (autoload 'camelCase-mode "camelCase-mode" nil t))

(load-library "hideshow")
(defadvice goto-line (after expand-after-goto-line
                            activate compile)

    "hideshow-expand affected block when using goto-line in a collapsed buffer"
    (save-excursion
       (hs-show-block)))

(add-hook 'c-mode-hook
  (lambda ()
    (hs-minor-mode)
    (c-subword-mode t)
    (setq tab-width 4)))

(add-hook 'java-mode-hook
  (lambda ()
    (hs-minor-mode)
    (c-subword-mode t)
    (setq tab-width 4)))

(add-hook 'kill-emacs-hook
  (lambda ()
    (if (malabar-groovy-live-p)
        (malabar-groovy-stop))))

(load "fix-java.el")

(set-frame-name "$PROJECT_NAME")
(project-load "$PROJECT_NAME-project")
(project-dired)
EOF
}


make_tags() {
    cat > $PROJECT/bin/tag_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-$PROJECT}
export TAGS=\${TAGS:-\$PROJECT/.mk/TAGS}
etags \$@ -f \$TAGS --language-force=Java --Java-kinds=-f \$(find \$PROJECT/dev/. -name .svn -prune -o -name CVS -prune -o -name \*.java -print)

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            project=$PROJECTS_DIR/\${dep#\$PROJECT/dep/}
            PROJECT=\$project \$project/bin/tag_all.sh -a
        fi
    done
fi
EOF
    chmod +x $PROJECT/bin/tag_all.sh
    $PROJECT/bin/tag_all.sh
}


make_go() {
    cat > $PROJECT/go <<EOF

export PATH=\$({
        echo $PROJECT/bin
        find -L $PROJECT/dev/ -type d -name bin | sort
        test -d $PROJECT/dep && find -L $PROJECT/dep -type d -name bin | sort
    } | awk '{printf("%s:", \$0)}'
    echo \$PROJECT_DEFAULT_PATH
)

$PROJECT/bin/tag_all.sh

set_build
EOF
}


mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
