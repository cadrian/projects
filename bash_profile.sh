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



# To be sourced at the very end of .profile (any environment change after that will be ignored)


# Project public environment variables, set them or use the default
export PROJECT_PACK=${PROJECT_PACK:-/usr/local/share/ProjectManager}
export PROJECTS_DIR=${PROJECTS_DIR:-$HOME/.projects}


# Internal environment variables, don't change them
export PROJECT_CURRENT=$PROJECTS_DIR/.@current
export CURRENT_PROJECT=${CURRENT_PROJECT:-""}


# Save some environment variables to restore them at each project change
export PROJECT_DEFAULT_PATH="$PATH"
export PROJECT_DEFAULT_PS1="$PS1"


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# User functions

# Go to the given project.
# $1 => project name (defaults to current project, if it exists)
function go_to_project {
    if [ x"$1" == x"-fast" ]; then
        FAST=-fast
        shift
    else
        FAST=""
    fi

    if [ -z "$1" ]; then
        # Find the last saved project
        if [ -z "$CURRENT_PROJECT" -a -h $PROJECT_CURRENT ]; then
            CURRENT_PROJECT=$(find $PROJECT_CURRENT -type l -exec readlink {} \;)
            CURRENT_PROJECT=${CURRENT_PROJECT##*/}
        fi
        if [ -z "$CURRENT_PROJECT" ]; then
            echo "Must provide: project name" >&2
            echo "Not enough arguments: aborting." >&2
            return 1
        fi
    else
        CURRENT_PROJECT=$1
    fi

    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT
    test -d $PROJECTS_DIR || mkdir $PROJECTS_DIR

    if [ -e $PROJECT_CURRENT ]; then
        if [ -h $PROJECT_CURRENT ]; then
            rm -f $PROJECT_CURRENT
        else
            echo "$PROJECT_CURRENT is not a symlink: aborting." >&2
            return 1
        fi
    fi

    if [ ! -d $PROJECT ]; then
        echo "Unknown project $CURRENT_PROJECT: aborting." >&2
        return 1
    fi

    echo "Please wait, going to project $CURRENT_PROJECT."

    ln -s $PROJECT $PROJECT_CURRENT


    export PS1="[$CURRENT_PROJECT] $PROJECT_DEFAULT_PS1"
    cd $(find $PROJECT/dev -type l -exec readlink {} \;)

    export PATH="$PROJECT_DEFAULT_PATH"
    test -x $PROJECT/go && . $PROJECT/go $FAST
}


# Temporarily go to the given project. "dependent" because completion will propose deps of the current project.
# $1 => project name (defaults to current project, if it exists)
function go_to_dependent_project {
    if [ -z "$CURRENT_PROJECT" ]; then
        echo "Please go to some project first: aborting." >&2
        return 1
    fi

    if [ -z "$1" -o "$1" == "$CURRENT_PROJECT" ]; then
        dep=dev
        proj=$CURRENT_PROJECT
    else
        dep=dep/$1
        proj=$1
    fi

    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT
    cd $(readlink $PROJECT/$dep)
    test -x $PROJECTS_DIR/$proj/godep && . $PROJECTS_DIR/$proj/godep
}


# Create a new project.
# $1 => project name
# $2 => project type
# $3 => project development directory
function create_new_project {
    PROJECT=$PROJECTS_DIR/$1
    PROJECT_FACTORY=$PROJECT_PACK/types/$2.sh
    PROJECT_DEVDIR=$(cd $3/. && pwd)

    if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "Must provide: project name, project type, and project dev directory" >&2
        echo "Not enough arguments: aborting." >&2
        return 1
    fi

    if [ -d $PROJECT ]; then
        echo "Duplicate project $1: aborting." >&2
        return 1
    fi

    if [ ! -x $PROJECT_FACTORY ]; then
        echo "Unknown project type $2: aborting." >&2
        return 1
    fi

    if [ ! -d "$PROJECT_DEVDIR" ]; then
        echo "Unknown dev directory $3: aborting." >&2
        return 1
    fi

    test -d $PROJECTS_DIR || mkdir $PROJECTS_DIR

    echo "Please wait, creating project $1."

    mkdir $PROJECT
    mkdir $PROJECT/bin
    ln -s $PROJECT_DEVDIR $PROJECT/dev
    echo $2 > $PROJECT/type

    $PROJECT_FACTORY $1 $PROJECT_DEVDIR
}


# Update an existing project with the latest changes in the project manager.
function update_project {
    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT

    if [ -z $CURRENT_PROJECT ]; then
        echo "Must be in a project" >&2
        return 1
    fi

    if [ \( ! -d $PROJECT \) -o \( ! -d $PROJECT/bin \) -o \( ! -h $PROJECT/dev \) ]; then
        echo "Unknown or invalid project $CURRENT_PROJECT: aborting." >&2
        return 1
    fi

    echo "Please wait, updating project $CURRENT_PROJECT."

    type=$(< $PROJECT/type)
    PROJECT_FACTORY=$PROJECT_PACK/types/$type.sh

    if [ -n "$1" ]; then
        PROJECT_DEVDIR=$(cd $1/. && pwd)
        rm $PROJECT/dev
        ln -s $PROJECT_DEVDIR $PROJECT/dev
    else
        PROJECT_DEVDIR=$(readlink $PROJECT/dev)
    fi

    rm -f $PROJECT/.dmenu_profile $PROJECT/.zenity_profile

    $PROJECT_FACTORY $CURRENT_PROJECT $PROJECT_DEVDIR
}


# Create a new project.
# $1 => project name to link to current
function link_dependency {
    DEP_PROJECT=$PROJECTS_DIR/$1
    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT

    if [ -z $CURRENT_PROJECT ]; then
        echo "Must be in a project" >&2
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Must provide: dependent project" >&2
        echo "Not enough arguments: aborting." >&2
        return 1
    fi

    if [ ! -d $DEP_PROJECT ]; then
        echo "Unknown project $1: aborting." >&2
        return 1
    fi

    if [ -h $PROJECT/dep/$1 ]; then
        echo "Dependency already linked; nothing to do." >&2
        return 0
    fi

    echo "Please wait, linking project $1 to $CURRENT_PROJECT."

    test -d $PROJECT/dep || mkdir $PROJECT/dep
    DEP_PROJECT_DEV=$(readlink $DEP_PROJECT/dev)
    ln -s $DEP_PROJECT_DEV $PROJECT/dep/$1
}


# List all known projects.
function list_projects {
    format="%-16s | %-8s | %-80s\n"
    printf "$format" Name Type "Home dev directory"
    printf "$format" "----------------" "--------" "--------------------------------------------------------------------------------"
    for project in $PROJECTS_DIR/*; do
        if [ -d $project ]; then
            printf "$format" ${project##*/} $(< $project/type) $(readlink $project/dev)
        fi
    done
}


# Bash completion
function _list_projects {
    find $PROJECTS_DIR -mindepth 1 -maxdepth 1 -type d | sed 's!^'"$PROJECTS_DIR/"'!!' | sort -u
}

function _list_types {
    find $PROJECT_PACK/types -name \*.sh -executable | sed 's!^'"$PROJECT_PACK/types/"'\(.*\)\.sh$!\1!' | sort -u
}

function _list_deps {
    {
        test -d $PROJECTS_DIR/$CURRENT_PROJECT/dep && find $PROJECTS_DIR/$CURRENT_PROJECT/dep -mindepth 1 -maxdepth 1 -type l | sed 's!^'"$PROJECTS_DIR/$CURRENT_PROJECT/dep/"'!!'
        echo $CURRENT_PROJECT
    } | sort -u
}

function _go_to_project_completion_ {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [ $COMP_CWORD -eq $((1 + $1)) ]; then
        COMPREPLY=($(compgen -W "$(_list_projects)" -- "$cur"))
    fi

    if [ $extglob = 1 ]; then
        shopt -u extglob
    fi
}
function _go_to_project_completion {
    _go_to_project_completion_ 0
}
complete -F _go_to_project_completion go_to_project gp link_dependency lp

function _go_to_dependent_project_completion_ {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [ $COMP_CWORD -eq $((1 + $1)) ]; then
        COMPREPLY=($(compgen -W "$(_list_deps)" -- "$cur"))
    fi

    if [ $extglob = 1 ]; then
        shopt -u extglob
    fi
}
function _go_to_dependent_project_completion {
    _go_to_dependent_project_completion_ 0
}

complete -F _go_to_dependent_project_completion go_to_dependent_project cdp

function _create_new_project_completion_ {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    case $(($COMP_CWORD - $1)) in
        2)
            COMPREPLY=($(compgen -W "$(_list_types)" -- "$cur"))
            ;;
        3)
            COMPREPLY=($(compgen -d -W "." -- "$cur"))
            ;;
    esac

    if [ $extglob = 1 ]; then
        shopt -u extglob
    fi
}
function _create_new_project_completion {
    _create_new_project_completion_ 0
}
complete -F _create_new_project_completion create_new_project np


#internals for opening a new tab. Used by project_tabbed() below and by the new_tab.sh script
function _project_tabbed {
    windowid=$1
    dir=$2
    prj=$3

    if WID=$(xdotool search --class "gnome-terminal" | grep $windowid); then
        :
    else
        echo "Not in a gnome-terminal: aborting." >&2
        return 1
    fi

    xdotool key ctrl+shift+t
    wmctrl -i -a $WID
    sleep 1
    xdotool type --clearmodifiers "go_to_project -fast $prj"
    xdotool key  --clearmodifiers ctrl+j
    sleep 1
    xdotool type --clearmodifiers "cd $dir"
    xdotool key  --clearmodifiers ctrl+j
    sleep 1
    xdotool key  --clearmodifiers ctrl+shift+g
    xdotool key  --clearmodifiers ctrl+l
    xdotool key  --clearmodifiers ctrl+j
}

# Open a new tab in gnome-terminal, for the same project.
function project_tabbed {
    if [ -z "$CURRENT_PROJECT" ]; then
        echo "Please go to some project first: aborting." >&2
        return 1
    fi

    if [ -z "$WINDOWID" ]; then
        echo "Not in a window: aborting." >&2
        return 1
    fi

    xdotool windowfocus $WID #useless?
    _project_tabbed $WINDOWID $(pwd) "$CURRENT_PROJECT"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Finders

function findpwd {
    find "$(pwd)" \( -name CVS -o -name .svn -o -name .git -o -name '@*' -o -name tmp \) -prune -o "$@"
}

function nbprocs {
    echo -P$((2 * $(cat /proc/cpuinfo|grep '^processor'|wc -l)))
}

function fgrep {
    findpwd -type f -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}
# fgrep is often an alias; be sure to remove it
alias fgrep=
unalias fgrep

function fpy {
    findpwd \( -iname \*.py -o -iname \*.config \) -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fc {
    findpwd -iname \*.[ch] -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fcpp {
    findpwd \( -iname \*.[ch]pp -o -iname \*.[ch] \) -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fbas {
    findpwd \( -iname \*.cls -o -iname \*.bas -o -iname \*.frm \)  -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fj {
    findpwd -iname \*.java -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fhtml {
    findpwd -iname \*.html -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fe {
    findpwd -iname \*.e -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function flog {
    findpwd \( -iname \*.log -o -iname \*.dbg -o -iname \*.txt -o -iname \*.[0-9][0-9][0-9] \) -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fconf {
    findpwd \( -iname \*.conf -o -iname \*.ini -o -iname \*make\* \) -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

function fgo {
    findpwd -iname \*.go -print0 | xargs -0 $(nbprocs) -i grep -Hn "$@" {}
}

# Global finders

function gf {
    (cd $(readlink -f $PROJECTS_DIR/$CURRENT_PROJECT/dev); "$@")

    dep_dir=$PROJECTS_DIR/$CURRENT_PROJECT/dep
    if [ -d $dep_dir ]; then
        for dep_link in $(echo $dep_dir/*); do
            dep=$(readlink -f $dep_link)
            (cd $dep; "$@")
        done
    fi
}

function gfgrep {
    gf fg "$@"
}

function gfpy {
    gf fpy "$@"
}

function gfc {
    gf fc "$@"
}

function gfcpp {
    gf fcpp "$@"
}

function gfbas {
    gf fbas "$@"
}

function gfj {
    gf fj "$@"
}

function gfhtml {
    gf fhtml "$@"
}

function gfe {
    gf fe "$@"
}

function gflog {
    gf flog "$@"
}

function gfconf {
    gf fconf "$@"
}

function gfgo {
    gf fgo "$@"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Commands hub

function _p_help {
    cat <<EOF
Usage: p <cmd> <args...>

Projects management hub command.

The available sub-commands are:

go <project>
                Go to the given project, which must exist (see "new")

cd {<project>}
                Changes directory to a dependent project. Mostly useful in
                its simplest form: cd to the root directory of the current
                project.

new <project> <dir> <type>
                Create a new project. The arguments are:
                - the project name
                - the project root directory
                - the project type (use completion to know the currently
                  available types: java, python, and so on)

ln <project>
link <project>
                Link a dependent project (mostly useful for tagging)

ls
list
                List the known projects

up
update
                Update the project meta files using the latest version
                of the project manager

tab
                Open a new console tab (usually Gnome's) and goes to the
                same project as the current console.
                Only works with some consoles.

help
-h
--help
usage
                well... this screen :-)


Copyright (C) 2010-2013 Cyril Adrian <cyril.adrian@gmail.com>

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.

EOF
}

function p {
    fun=$1
    shift
    case "$fun" in
        go)          go_to_project           "$@" ; return $? ;;
        cd)          go_to_dependent_project "$@" ; return $? ;;
        new)         create_new_project      "$@" ; return $? ;;
        ln|link)     link_dependency         "$@" ; return $? ;;
        ls|list)     list_projects           "$@" ; return $? ;;
        up|update)   update_project          "$@" ; return $? ;;
        tab)         project_tabbed          "$@" ; return $? ;;
        help|-h|--help|usage)
            _p_help
            return 0
            ;;
        *)
            {
                echo "Unknown command: $fun"
                echo
                _p_help
            } >&2
            return 1
            ;;
    esac
}

function _p_completion {
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=($(compgen -W "go godep new ln link ls list up update tab" -- "$cur"))
    else
        case ${COMP_WORDS[1]} in
        go)          _go_to_project_completion_           1 ;;
        godep)       _go_to_dependent_project_completion_ 1 ;;
        new)         _create_new_project_completion_      1 ;;
        ln|link)     _go_to_project_completion_           1 ;;
        ls|list)     ;;
        up|update)   ;;
        tab)         ;;
        esac
    fi
}

complete -F _p_completion p


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal functions

function _project_tag_all {
    project=$1
    nb=$($project/bin/find_all.sh | wc -l)
    cols=$(stty size|awk '{print $2}')
    $project/bin/tag_all.sh -V | grep '^OPENING' | awk -vcols=$cols -vsize=30 -vmax=$nb '
       BEGIN {
          len = cols - size - 6;
       }
       max > 0 {
          fill = int(size * NR / max + .5);
          printf("'`tput bold`'%3d%%'`tput sgr0`' '`tput setab 6`'", 100*NR/max + .5);
          for (i=0; i < fill; i++)
             printf(" ");
          printf("'`tput setab 4`'");
          for (i=fill; i < size; i++)
             printf(" ");
          printf("'`tput sgr0`' ");

          if (length($2) < len) {
             a = $2;
          } else {
             a = substr($2, length($2) - len + 4);
             sub("^", "...", a);
          }
          printf("%-s'"$(tput el)"'\r", a);
          fflush();
       }
       END {
          printf("'"$(tput el)"'\n");
       }'
}

ssh_agent_info=${TMPDIR:-/tmp}/ssh_agent_$USER
ssh_agent_flag=${TMPDIR:-/tmp}/ssh_agent_$USER.flag

function _ssh_agent_check {
    if [ $(tty) != "not a tty" -a -r $ssh_agent_info ]; then
        . $ssh_agent_info
        if [ \! -r $ssh_agent_flag ]; then
            ssh-add
            touch $ssh_agent_flag
        fi
    fi
}

function ssh_agent_start {
    if [ \! -r $ssh_agent_info ]; then
        at now 2>/dev/null <<EOF
rm -f $ssh_agent_flag
ssh-agent > $ssh_agent_info
EOF
    fi
}
