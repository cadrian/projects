#!/bin/bash

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
        _project_tabbed $WID "$dir" "$prj"
    fi
done
