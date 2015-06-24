#!/usr/bin/env bash

# Copyright (c) 2010-2013, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
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
        (src-patterns     ("*.c" "*.cpp" "*.h"))
        (ignore-patterns  ("*.o"))
        (tags-file        "$PROJECT/.mk/TAGS")
        (file-list-cache  "$PROJECT/.mk/files")
        (open-files-cache "$PROJECT/.mk/open-files")
        (vcs              git)
        (compile-cmd      "gcc")
        (startup-hook     $PROJECT_NAME-project-startup)
        (shutdown-hook    nil)))

(defun $PROJECT_NAME-project-startup ()
  t)

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
echo "\$(date -R) - updating $PROJECT for \$PROJECT" >>\$LOG
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.[ch]   -print | parallel --gnu --pipe etags \$@ -f\$TAGS- --language-force=C --fields=+ailmnSz -L- 2>>\$LOG|| echo "Brand new project: no file tagged."
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.[ch]pp -print | parallel --gnu --pipe etags \$@ -a -f\$TAGS --language-force='C++' --fields=+ailmnSz -L- 2>>\$LOG|| echo "Brand new project: no file tagged."
test -e \$TAGS- && { cat \$TAGS- >> \$TAGS; rm \$TAGS-; }

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            echo $PROJECTS_DIR/\${dep#\$PROJECT/dep/}
        fi
    done | parallel --gnu "TAGS=\$PROJECT/.mk/dep_TAGS_{#} PROJECT={} {}/bin/tag_all.sh \$@"
    for tags in \$PROJECT/.mk/dep_TAGS_*; do
        if [ -e \$tags ]; then
            cat \$tags >> \$TAGS
            rm -f \$tags
        fi
    done
fi
EOF

    cat > $PROJECT/bin/find_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-$PROJECT}
export TAGS=\${TAGS:-\$PROJECT/.mk/TAGS}
export PROJECT_DEVDIR=\$(readlink \$PROJECT/dev)
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.[ch] -print 2>/dev/null
find \$PROJECT_DEVDIR -name tmp -prune -o -name \\*.[ch]pp -print 2>/dev/null

if [ -d \$PROJECT/dep ]; then
    for dep in \$(echo \$PROJECT/dep/*); do
        if [ -h \$dep ]; then
            echo $PROJECTS_DIR/\${dep#\$PROJECT/dep/}
        fi
    done | parallel --gnu "PROJECT={} {}/bin/find_all.sh -a \$@"
fi
EOF

    chmod +x $PROJECT/bin/tag_all.sh $PROJECT/bin/find_all.sh
    _project_tag_all $PROJECT
}


make_go() {
    cat > $PROJECT/bin/find_path <<EOF
echo $PROJECT/bin
if [ -f $PROJECT/dev/.path ]; then
    cat $PROJECT/dev/.path | awk -vpwd="$(readlink -f $PROJECT/dev)" '/^\// {printf("%s\n", \$0); next} {printf("%s/%s\n", pwd, \$0)}'
else
    find -L $PROJECT/dev/ -maxdepth 2 -name tmp -prune -o -type d -name bin -print | sort
fi
EOF
    cat > $PROJECT/go <<EOF

export PATH=\$(
    {
        $PROJECT/bin/find_path
        test -d $PROJECT/dep && for dep in $PROJECT/dep/*; do
            if [ -h \$dep ]; then
                project=$PROJECTS_DIR/\${dep#\$PROJECT/dep/}
                PROJECT=\$project \$project/bin/find_path
            fi
        done
        echo \$PROJECT_DEFAULT_PATH
    } | awk '{printf("%s:", \$0)}'
)

test "\$1" == "-fast" || _project_tag_all $PROJECT
EOF

    chmod +x $PROJECT/go $PROJECT/bin/find_path
}


test -d $PROJECT/.mk || mkdir $PROJECT/.mk
make_emacs
make_tags
make_go
