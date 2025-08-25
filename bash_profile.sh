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
go_to_project() {
    if [[ "$1" == "-fast" ]]; then
        FAST=-fast
        shift
    else
        FAST=""
    fi

    if [[ -z "$1" ]]; then
        # Find the last saved project
        if [[ -z $CURRENT_PROJECT && -h $PROJECT_CURRENT ]]; then
            CURRENT_PROJECT=$(find "$PROJECT_CURRENT" -type l -exec readlink {} \;)
            CURRENT_PROJECT=${CURRENT_PROJECT##*/}
        fi
        if [[ -z $CURRENT_PROJECT ]]; then
            echo "Must provide: project name" >&2
            echo "Not enough arguments: aborting." >&2
            return 1
        fi
    else
        CURRENT_PROJECT=$1
    fi

    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT
    test -d "$PROJECTS_DIR" || mkdir "$PROJECTS_DIR"

    if [[ -e $PROJECT_CURRENT ]]; then
        if [[ -h $PROJECT_CURRENT ]]; then
            rm -f "$PROJECT_CURRENT"
        else
            echo "$PROJECT_CURRENT is not a symlink: aborting." >&2
            return 1
        fi
    fi

    if [[ ! -d $PROJECT ]]; then
        echo "Unknown project $CURRENT_PROJECT: aborting." >&2
        return 1
    fi

    echo "Please wait, going to project $CURRENT_PROJECT."

    ln -s "$PROJECT" "$PROJECT_CURRENT"

    export HISTFILE="$PROJECT"/bash.history

    export PS1="[$CURRENT_PROJECT] $PROJECT_DEFAULT_PS1"
    cd "$(find "$PROJECT"/dev -type l -exec readlink {} \;)" || {
        echo "Could not go to the project directory: abotring." >&2
        return 1
    }

    export PATH="$PROJECT_DEFAULT_PATH"
    test -x "$PROJECT"/go && . "$PROJECT"/go $FAST
}


# Temporarily go to the given project or directory. "dependent" because completion will propose deps of the current project.
# $1 => project name (defaults to current project, if it exists)
#       or directory in the current project
go_to_dependent_project() {
    if [[ -z $CURRENT_PROJECT ]]; then
        echo "Please go to some project first: aborting." >&2
        return 1
    fi

    if [[ -z "$1" ]]; then
        dep=dev
        proj=$CURRENT_PROJECT
        dir=.
    elif [[ "$1" == "$CURRENT_PROJECT" ]]; then
        dep=dev
        proj=$CURRENT_PROJECT
        if [[ -z "$2" || ! -d "$PROJECTS_DIR/$CURRENT_PROJECT/dev/$2" ]]; then
            dir=.
        else
            dir="$2"
        fi
    elif [[ -d "$PROJECTS_DIR/$CURRENT_PROJECT/dev/$1" ]]; then
        dep=dev
        proj=$CURRENT_PROJECT
        dir="$1"
    else
        dep=dep/$1
        proj=$1
        if [[ -z "$2" || ! -d "$PROJECTS_DIR/$CURRENT_PROJECT/dep/$1/$2" ]]; then
            dir=.
        else
            dir="$2"
        fi
    fi

    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT
    opwd="$(pwd)"
    cd "$(readlink "$PROJECT/$dep")" || {
        echo "Could not go to project dependencies directory: aborting." >&2
        return 1
    }
    test -x "$PROJECTS_DIR/$proj"/godep && . "$PROJECTS_DIR/$proj"/godep
    cd "$dir" || {
        echo "Could not go to dependent project: aborting." >&2
        return 1
    }
    OLDPWD="$opwd"
}


# Create a new project.
# $1 => project name
# $2 => project type
# $3 => project development directory
create_new_project() {
    PROJECT=$PROJECTS_DIR/$1
    PROJECT_FACTORY=$PROJECT_PACK/types/$2.sh
    PROJECT_DEVDIR=$(cd "$3"/. && pwd)

    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
        echo "Must provide: project name, project type, and project dev directory" >&2
        echo "Not enough arguments: aborting." >&2
        return 1
    fi

    if [[ -d $PROJECT ]]; then
        echo "Duplicate project $1: aborting." >&2
        return 1
    fi

    if [[ ! -x $PROJECT_FACTORY ]]; then
        echo "Unknown project type $2: aborting." >&2
        return 1
    fi

    if [[ ! -d $PROJECT_DEVDIR ]]; then
        echo "Unknown dev directory $3: aborting." >&2
        return 1
    fi

    test -d "$PROJECTS_DIR" || mkdir "$PROJECTS_DIR"

    echo "Please wait, creating project $1."

    mkdir -p "$PROJECT" "$PROJECT/bin"
    ln -s "$PROJECT_DEVDIR" "$PROJECT"/dev
    echo "$2" > "$PROJECT"/type

    "$PROJECT_FACTORY" "$1" "$PROJECT_DEVDIR"
}


# Update an existing project with the latest changes in the project manager.
update_project() {
    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT

    if [[ -z $CURRENT_PROJECT ]]; then
        echo "Must be in a project" >&2
        return 1
    fi

    if [[ ( ! -d $PROJECT ) || ( ! -d $PROJECT/bin ) || ( ! -h $PROJECT/dev ) ]]; then
        echo "Unknown or invalid project $CURRENT_PROJECT: aborting." >&2
        return 1
    fi

    echo "Please wait, updating project $CURRENT_PROJECT."

    local type=$(< "$PROJECT"/type)
    PROJECT_FACTORY=$PROJECT_PACK/types/$type.sh

    if [[ -n "$1" ]]; then
        PROJECT_DEVDIR=$(cd "$1"/. && pwd)
        rm "$PROJECT"/dev
        ln -s "$PROJECT_DEVDIR" "$PROJECT"/dev
    else
        PROJECT_DEVDIR=$(readlink "$PROJECT"/dev)
    fi

    rm -rf "$PROJECT"

    mkdir -p "$PROJECT" "$PROJECT/bin"
    ln -s "$PROJECT_DEVDIR" "$PROJECT"/dev
    echo "$type" > "$PROJECT"/type

    "$PROJECT_FACTORY" "$CURRENT_PROJECT" "$PROJECT_DEVDIR"
}


# Create a new project.
# $1 => project name to link to current
link_dependency() {
    DEP_PROJECT=$PROJECTS_DIR/$1
    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT

    if [[ -z $CURRENT_PROJECT ]]; then
        echo "Must be in a project" >&2
        return 1
    fi

    if [[ -z "$1" ]]; then
        echo "Must provide: dependent project" >&2
        echo "Not enough arguments: aborting." >&2
        return 1
    fi

    if [[ ! -d $DEP_PROJECT ]]; then
        echo "Unknown project $1: aborting." >&2
        return 1
    fi

    if [[ -h $PROJECT/dep/$1 ]]; then
        echo "Dependency already linked; nothing to do." >&2
        return 0
    fi

    echo "Please wait, linking project $1 to $CURRENT_PROJECT."

    test -d "$PROJECT"/dep || mkdir -p "$PROJECT"/dep
    DEP_PROJECT_DEV=$(readlink "$DEP_PROJECT"/dev)
    ln -s "$DEP_PROJECT_DEV" "$PROJECT/dep/$1"
}


# List all known projects.
list_projects() {
    printf "%-16s | %-8s | %-80s\n" Name Type "Home dev directory"
    printf "%-16s | %-8s | %-80s\n" "----------------" "--------" "--------------------------------------------------------------------------------"
    for project in "$PROJECTS_DIR"/*; do
        if [ -d "$project" ]; then
            printf "%-16s | %-8s | %-80s\n" "${project##*/}" "$(< "$project"/type)" "$(readlink "$project"/dev)"
        fi
    done
}


# Bash completion
_list_projects() {
    for f in "$PROJECTS_DIR"/*; do
        [[ -d $f ]] && echo "${f#"$PROJECTS_DIR/"}"
    done
}

_list_types() {
    for f in "$PROJECT_PACK"/types/*.sh; do
        f="${f#"$PROJECT_PACK/types/"}"
        echo "${f%.sh}"
    done
}

_list_deps() {
    for f in "$PROJECTS_DIR/$CURRENT_PROJECT"/dep/*; do
        [[ -h $f ]] && echo "${f#"$PROJECTS_DIR/$CURRENT_PROJECT/dep/"}"
    done
    echo "$CURRENT_PROJECT"
}

_go_to_project_completion_() {
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    local cur="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD == 1 + $1 )); then
        read -r -d '' -a COMPREPLY < <(
            read -r -d '' -a projects < <(_list_projects)
            compgen -S ' ' -W "${projects[*]}" -- "$cur"
        )
    fi
}
_go_to_project_completion() {
    _go_to_project_completion_ 0
}
complete -o nospace -F _go_to_project_completion go_to_project gp link_dependency lp

_go_to_dependent_project_completion_() {
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    local cur="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD > $1 )); then
        read -r -d '' -a COMPREPLY < <(
            compdirs=0
            if (( COMP_CWORD == 1 + $1 )); then
                read -r -d '' -a deps < <(_list_deps)
                compgen -S ' ' -W "${deps[*]}" -- "$cur"
                cd "$(readlink "$PROJECTS_DIR/$CURRENT_PROJECT/dev")" && compdirs=1
            elif (( COMP_CWORD == 2 + $1 )); then
                dep="${COMP_WORDS[$((1 + $1))]}"
                if [ -e "$PROJECTS_DIR/$CURRENT_PROJECT/dep/$dep" ]; then
                    cd "$(readlink "$PROJECTS_DIR/$CURRENT_PROJECT/dep/$dep")"
                else
                    cd "$(readlink "$PROJECTS_DIR/$CURRENT_PROJECT/dev")"
                fi && compdirs=1
            fi
            if (( compdirs == 1 )); then
                read -r -d '' -a dirs < <(
                    curdir="${cur##*/}"
                    if [[ -z "$curdir" || "$curdir" == . ]]; then
                        for f in *; do
                            [[ -d $f ]] && echo "$f"
                        done
                    elif [[ -d $cur ]]; then
                        for f in "$cur"/*; do
                            [[ -d $f ]] && echo "$f"
                        done
                    else
                        for f in "$curdir"/*; do
                            [[ -d $f ]] && echo "$f"
                        done
                    fi 2>/dev/null
                )
                compgen -d -S / -W "${dirs[*]}" -- "$cur"
            fi
        )
    fi
}
_go_to_dependent_project_completion() {
    _go_to_dependent_project_completion_ 0
}

complete -o nospace -F _go_to_dependent_project_completion go_to_dependent_project cd

_create_new_project_completion_() {
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    local cur="${COMP_WORDS[COMP_CWORD]}"

    case $(("$COMP_CWORD" - $1)) in
        2)
            read -r -d '' -a COMPREPLY < <(
                read -r -d '' -a types < <(_list_types)
                compgen -S ' ' -W "${types[*]}" -- "$cur"
            )
            ;;
        3)
            read -r -a COMPREPLY < <(
                compgen -d -S / -W "." -- "$cur"
            )
            ;;
    esac
}
_create_new_project_completion() {
    _create_new_project_completion_ 0
}
complete -o nospace -F _create_new_project_completion create_new_project new


#internals for opening a new tab. Used by project_tabbed() below and by the new_tab.sh script
_project_tabbed() {
    local windowid=$1
    local dir=$2
    local prj=$3

    WID=$(xdotool search --class "gnome-terminal" | grep "$windowid") || {
        echo "Not in a gnome-terminal: aborting." >&2
        return 1
    }

    xdotool key ctrl+shift+t
    wmctrl -i -a "$WID"
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
project_tabbed() {
    if [[ -z $CURRENT_PROJECT ]]; then
        echo "Please go to some project first: aborting." >&2
        return 1
    fi

    if [[ -z $WINDOWID ]]; then
        echo "Not in a window: aborting." >&2
        return 1
    fi

    xdotool windowfocus "$WID" #useless?
    _project_tabbed "$WINDOWID" "$(pwd)" "$CURRENT_PROJECT"
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Commands hub

_p_help() {
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


Copyright (C) 2010-2025 Cyril Adrian <cyril.adrian@gmail.com>

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.

EOF
}

p() {
    local fun=$1
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

_p_completion() {
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD == 1 )); then
        read -r -a COMPREPLY < <(
            IFS=$'\n'
            shopt -s extglob
            compgen -S ' ' -W "go cd new ln link ls list up update tab" -- "$cur"
        )
    else
        case "${COMP_WORDS[1]}" in
        go)          _go_to_project_completion_           1 ;;
        cd)          _go_to_dependent_project_completion_ 1 ;;
        new)         _create_new_project_completion_      1 ;;
        ln|link)     _go_to_project_completion_           1 ;;
        ls|list)     ;;
        up|update)   ;;
        tab)         ;;
        esac
    fi
}

complete -o nospace -F _p_completion p


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal functions

_project_tag_all() {
    local project=$1
    local all nb cols
    read -r -d '' -a all < <(
        "$project"/bin/find_all.sh
    )
    nb=${#all[@]}
    cols=$(stty size|awk '{print $2}')
    rm -f "${TAGS:-"$PROJECT"/.mk/TAGS}"
    "$project"/bin/tag_all.sh -V | grep '^OPENING' | awk -vcols="$cols" -vsize=30 -vmax="$nb" '
       BEGIN {
          len = cols - size - 6;
       }
       max > 0 {
          fill = int(size * NR / max + .5);
          printf("'"$(tput bold)"'%3d%%'"$(tput sgr0)"' '"$(tput setab 6)"'", 100*NR/max + .5);
          for (i=0; i < fill; i++)
             printf(" ");
          printf("'"$(tput setab 4)"'");
          for (i=fill; i < size; i++)
             printf(" ");
          printf("'"$(tput sgr0)"' ");

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

ssh_agent_info=${TMPDIR:-/tmp}/ssh_agent_$USER.info

_ssh_agent_check() {
    if [ -r "$ssh_agent_info" ]; then
        . "$ssh_agent_info"
    fi
    if ssh-add -l | awk '$3 == "'"$HOME"/.ssh/id_rsa'" {exit 0} {exit 1}'; then
        :
    elif [[ -x /usr/lib/openssh/gnome-ssh-askpass ]]; then
        (
            export SSH_ASKPASS=/usr/lib/openssh/gnome-ssh-askpass
            exec ssh-add </dev/null
        )
    elif [[ -t 1 ]]; then
        ssh-add
    else
        xterm -g 80x5 -T ssh-add -e ssh-add
    fi
}

ssh_agent_start() {
    if [[ ! -r "$ssh_agent_info" ]]; then
        (
            exec ssh-agent > "$ssh_agent_info"
        ) & disown
        if which inotifywait >/dev/null 2>&1; then
            while [[ ! -f "$ssh_agent_info" ]]; do
                inotifywait -qqt 1 -e create -e moved_to "$(dirname "$ssh_agent_info")"
            done
        else
            sleep 2
        fi
    fi
}
