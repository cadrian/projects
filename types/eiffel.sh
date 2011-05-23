#!/usr/bin/env bash

PROJECT_NAME=$1
PROJECT=$PROJECTS_DIR/$1
PROJECT_DEVDIR=$2


make_emacs() {
    cat > $PROJECT/project.el <<EOF
(setq load-path (cons "$PROJECT_PACK/site-lisp" (cons "$PROJECT_PACK/site-lisp/mk-project" load-path)))

(add-to-list 'auto-mode-alist '("\\\\.e\\\\'" . eiffel-mode))
(add-to-list 'auto-mode-alist '("\\\\.se\\\\'" . eiffel-mode))
(autoload 'eiffel-mode "eiffel" "Major mode for Eiffel programs" t)

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
        (src-patterns     ("*.e"))
        (ignore-patterns  ("*.o"))
        (tags-file        "$PROJECT/.mk/TAGS")
        (file-list-cache  "$PROJECT/.mk/files")
        (open-files-cache "$PROJECT/.mk/open-files")
        (vcs              git)
        (compile-cmd      "se compile")
        (startup-hook     $PROJECT_NAME-project-startup)
        (shutdown-hook    nil)))

(defun $PROJECT_NAME-project-startup ()
  t)

(defun tabs-eiffel-mode-hook ()
 (message " Loading tabs-eiffel-mode-hook...")
 (setq eif-set-tab-width-flag nil)
 (setq eif-indent-increment 3))
(add-hook 'eiffel-mode-hook 'tabs-eiffel-mode-hook)

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
export PROJECT_DEVDIR=\$(ls -l $PROJECT/dev | sed 's/^.*-> //')
etags \$@ -f \$TAGS --language-force=Eiffel --extra=+f --fields=+ailmnSz \$(find \$PROJECT_DEVDIR -name \\*.e) 2>/dev/null|| echo "Brand new project: no file tagged."

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            project=$PROJECTS_DIR/\${dep#\$PROJECT/dep/}
            PROJECT=\$project \$project/bin/tag_all.sh -a \$@
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

fe() {
    find \$(pwd) \\( -name CVS -o -name .svn -o -name .git \\) -prune -o -name \\*.e -exec grep -Hn "\$@" {} \;
}

cols=\$(stty size|awk '{print \$2}')
$PROJECT/bin/tag_all.sh -V | grep '^OPENING' | awk -vcols=\$cols '{if (length(\$2) < cols) {a=\$2;} else {a=substr(\$2, length(\$2)-cols-4); sub("^", "...", a);} printf("%-s'"$(tput el)"'\\r", a); fflush();} END {printf("'"$(tput el)"'\\n");}'
EOF
}


mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
