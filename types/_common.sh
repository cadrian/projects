#!/usr/bin/env bash

# Copyright (c) 2010-2025, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
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
PROJECT_DEVDIR="$2"

. $PROJECT_PACK/bash_profile.sh

make_emacs() {
    test -h "$PROJECT"/bin/emacs && rm "$PROJECT"/bin/emacs
    EMACS=$(which emacs-snapshot || which emacs)
    test -e "$PROJECT"/bin/emacs || ln -s $EMACS "$PROJECT"/bin/emacs
    test -e "$PROJECT"/bin/etags || ln -s /usr/bin/ctags-exuberant "$PROJECT"/bin/etags

    cat > "$PROJECT"/project.el <<EOF
(set-frame-name "Emacs: $PROJECT_NAME")
(setq desktop-path '("$PROJECT/"))
(setq desktop-load-locked-desktop 'check-pid)
(desktop-save-mode 1)
(setq desktop-save t)
(setq desktop-restore-frames t)
(add-hook 'kill-emacs-hook
    (lambda () (desktop-save-in-desktop-dir)))
(desktop-read)
EOF
}

make_go() {
    cat > "$PROJECT"/bin/find_path <<EOF
echo $PROJECT/bin
if [ -f $PROJECT/dev/.path ]; then
    cat $PROJECT/dev/.path | awk -vpwd="$(readlink -f $PROJECT/dev)" '/^\// {printf("%s\n", \$0); next} {printf("%s/%s\n", pwd, \$0)}'
else
    find -O3 -L $PROJECT/dev/ -maxdepth 2 -name tmp -prune -o -type d -name bin -print | sort
fi
EOF

    cat > "$PROJECT"/go <<EOF
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
test -x $PROJECT/bin/go_hook && . $PROJECT/bin/go_hook
EOF

    chmod +x "$PROJECT"/go "$PROJECT"/bin/find_path
}
