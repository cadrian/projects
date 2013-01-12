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
    go build -o $PROJECT/bin/golang_flymake $PROJECT_PACK/types/rc/golang_flymake.go

    test -h $PROJECT/bin/emacs && rm $PROJECT/bin/emacs
    EMACS=$(which emacs-snapshot || which emacs)
    test -e $PROJECT/bin/emacs || ln -s $EMACS $PROJECT/bin/emacs
    test -e $PROJECT/bin/etags || ln -s /usr/bin/ctags-exuberant $PROJECT/bin/etags

    cat > $PROJECT/project.el <<EOF
(setq load-path (cons "$PROJECT_PACK/site-lisp" (cons "$PROJECT_PACK/site-lisp/mk-project" load-path)))
(setq project-basedir "$PROJECT_DEVDIR")

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
        (src-patterns     ("*.go"))
        (ignore-patterns  ("*.[568oa]"))
        (tags-file        "$PROJECT/.mk/TAGS")
        (file-list-cache  "$PROJECT/.mk/files")
        (open-files-cache "$PROJECT/.mk/open-files")
        (vcs              git)
        (compile-cmd      "go build")
        (startup-hook     $PROJECT_NAME-project-startup)
        (shutdown-hook    nil)))

(defun $PROJECT_NAME-project-startup ()
  t)

(require 'flymake)

(defun $PROJECT_NAME-flymake-go-init ()
  (let* ((temp-file (flymake-init-create-temp-buffer-copy
                     'flymake-create-temp-inplace))
         (local-file (file-relative-name
                      temp-file
                      (file-name-directory buffer-file-name))))
    (list "$PROJECT/bin/golang_flymake" (list temp-file))))

(push '(".+\\\\.go$" $PROJECT_NAME-flymake-go-init) flymake-allowed-file-name-masks)

(add-hook 'go-mode-hook 'flymake-mode)

(set-frame-name "Emacs: $PROJECT_NAME")
(project-load "$PROJECT_NAME-project")
(project-dired)
EOF

    TMPDIR=${TMPDIR:-/tmp}
    if [ "$(df $TMPDIR)" != "$(df $PROJECT_DEVDIR)" ]; then
        TMPDIR="$PROJECT_DEVDIR"/.tmp
    fi

    cat > $PROJECT/bin/gobuild.sh <<EOF
#!/bin/sh
export GOPATH="$PROJECT_DEVDIR"

if [ x\$1 = x-v ]; then
    verbose=true
    shift
else
    verbose=false
fi

if [ x\$1 = x ]; then
    echo "Usage: \$0 [-v] <go file>" >&2
    exit 1
fi

emacsfile="\$1"
gofile=\$(basename \$emacsfile)
gosrc=\$(dirname \$emacsfile)
gopkg=\${gosrc#\$GOPATH/src/}

export TMPDIR=$TMPDIR/gobuild-\$USER/\$\$

rm -rf \$TMPDIR
mkdir -p \$TMPDIR

if \$verbose; then
    export LOG=\$TMPDIR.log
    echo "log to \$LOG"
    shift
fi

if grep -q '^package main$' \$emacsfile; then
    # a main source
    actualfile=\$TMPDIR/\$gofile
    cp -lf \$emacsfile \$actualfile
else
    # some go package
    cp -lf \$gosrc/*.go \$TMPDIR
    rm -f \$TMPDIR/*_flymake.go
    if [ \${gofile%_flymake.go} = \$gofile ]; then
        actualfile=\$TMPDIR/\$gofile
    else
        actualfile=\$TMPDIR/\${gofile%_flymake.go}.go
    fi
    rm -f \$actualfile
    cp -lf \$emacsfile \$actualfile
fi

actualfile_pattern="^.*/\$(basename \$actualfile)"

if \$verbose; then
    {
        echo file: \$gofile
        echo pkg:  \$gopkg
        echo src:  \$gosrc
        ls \$gosrc
        echo
        echo \$TMPDIR
        ls \$TMPDIR
        echo
    } > \$LOG

    go build \$TMPDIR/*.go 2>&1 | tee -a \$LOG
else
    go build \$TMPDIR/*.go 2>&1
fi | grep -E "\$actualfile_pattern:" | sed "s&\$actualfile_pattern&\$emacsfile&"
EOF
    chmod +x $PROJECT/bin/gobuild.sh
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
echo "\$(date -R) - updating $PROJECT for \$PROJECT" >>\$LOG
find \$PROJECT_DEVDIR/src -name \\*.go -print | etags \$@ -f \$TAGS --language-force=Go -L- 2>>\$LOG|| echo "Brand new project: no file tagged."

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
find \$PROJECT_DEVDIR/src -name \\*.go -print 2>/dev/null

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

export GOPATH="$PROJECT_DEVDIR"

test "\$1" == "-fast" || _project_tag_all $PROJECT
EOF

    chmod +x $PROJECT/go
}


test -d $PROJECT/.mk || mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
