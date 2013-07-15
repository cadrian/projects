#!/bin/bash

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

var_of() {
    pid=$1
    var=$2
    xargs -0 -n1 < /proc/$pid/environ | grep ^$var= | awk -F= '{print $2}'
}

child_of() {
    pid=$1
    type=$2
    ps -eo "%P:%p:%c" | grep -E "^ *$pid: *[0-9]+:$type\$" | awk -F: '{print $2}'
}

pack=${PROJECT_PACK:-$(dirname $(dirname $(readlink -f $0)))}
test -d "$pack" || exit 1

. $pack/bash_profile.sh

WID=$(xdotool getwindowfocus)
PID=$(xprop -id $WID _NET_WM_PID | sed -r 's/^.* = ([0-9]*)$/\1/')
for CHILD_PID in $(child_of $PID bash); do
    wid=$(var_of $CHILD_PID WINDOWID)
    if [ $wid == $WID ]; then
        emacs_pid=$(child_of $CHILD_PID emacs)
        projects_dir=$(var_of $emacs_pid PROJECTS_DIR)
        dir=$(readlink -f /proc/$CHILD_PID/cwd)
        prj=$(var_of $emacs_pid CURRENT_PROJECT)
        prjdir=$(readlink "$projects_dir/$prj/dev")
        dir0=$(readlink -f $prjdir)
        dirtail="${dir#$dir0/}"

        if [ "$dirtail" != "$dir" ]; then
            dir="$prjdir/$dirtail"
        fi
        dir=$(echo "$dir" | sed "s!$HOME!~!g")
        _project_tabbed $WID "$dir" "$prj" && exit
    fi
done
