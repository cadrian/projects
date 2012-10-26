#!/usr/bin/env bash

PROJECT_NAME=$1
PROJECT=$PROJECTS_DIR/$1
PROJECT_DEVDIR=$2

. $PROJECT_PACK/bash_profile.sh


make_emacs() {
    EMACS=$(which emacs-snapshot || which emacs)
    test -h $PROJECT/bin/emacs && rm $PROJECT/bin/emacs
    test -e $PROJECT/bin/emacs || ln -s $EMACS $PROJECT/bin/emacs

    MALABAR=$HOME/.emacs.d/malabar-1.4.0
    PMD=$HOME/.emacs.d/pmd-4.2.5
    JAVA=$(which java)

    cat > $PROJECT/project.el <<EOF
(add-to-list 'load-path "$PROJECT_PACK/site-lisp")
(add-to-list 'load-path "$PROJECT_PACK/site-lisp/mk-project")
(add-to-list 'load-path "$MALABAR/lisp")
(setq project-basedir "$PROJECT_DEVDIR")

(require 'pmd)
(setq pmd-java-home "$JAVA")
(setq pmd-home "$PMD")
(setq pmd-ruleset-list (list "basic" "braces" "clone" "codesize" "coupling" "design" "finalizers" "imports" "junit" "naming" "optimizations" "strings" "unusedcode"))
(global-set-key (kbd "M-g x") 'pmd-current-buffer)

(setq semantic-default-submodes '(global-semantic-idle-scheduler-mode
                                  global-semanticdb-minor-mode
                                  global-semantic-idle-summary-mode
                                  global-semantic-mru-bookmark-mode))

(require 'malabar-mode)
(setq malabar-groovy-lib-dir "$MALABAR/lib")
(add-hook 'malabar-mode-hook
  (lambda ()
    (add-hook 'after-save-hook
              (lambda ()
                (malabar-compile-file-silently)
                (pmd-current-buffer))
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
      '((basedir          "$PROJECT_DEVDIR")
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
    (setq tab-width 4)
    (semantic-mode t)))

(add-hook 'kill-emacs-hook
  (lambda ()
    (if (malabar-groovy-live-p)
        (malabar-groovy-stop))))

(load "fix-java.el")

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
find \$PROJECT_DEVDIR -name .svn -prune -o -name CVS -prune -o -name tmp -prune -o -name \\*.java -print | etags \$@ -f \$TAGS --language-force=Java --Java-kinds=-f -L- 2>>\$LOG || echo "Brand new project: no file tagged."

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
find \$PROJECT_DEVDIR -name .svn -prune -o -name CVS -prune -o -name tmp -prune -o -name \\*.java -print 2>/dev/null

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

test "\$1" == "-fast" || _project_tag_all $PROJECT
EOF

    chmod +x $PROJECT/go
}


test -d $PROJECT/.mk || mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
