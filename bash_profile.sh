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
    if [ -z "$1" ]; then
        # Find the last saved project
        if [ -h $PROJECT_CURRENT ]; then
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
    test -x . $PROJECT/go && . $PROJECT/go
}


# Temporarily go to the given project. "dependent" because completion will propose deps of the current project.
# $1 => project name (defaults to current project, if it exists)
go_to_dependent_project() {
    if [ -z "$CURRENT_PROJECT" ]; then
        echo "Please go to some project first: aborting." >&2
        return 1
    fi

    if [ -z "$1" -o "$1" == "$CURRENT_PROJECT" ]; then
        dep=dev
    else
        dep=dep/$1
    fi

    PROJECT=$PROJECTS_DIR/$CURRENT_PROJECT
    cd $(readlink $PROJECT/$dep)
    test -x . $PROJECT/$dep/godep && . $PROJECT/$dep/godep
}


# Create a new project.
# $1 => project name
# $2 => project type
# $3 => project development directory
create_new_project() {
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
update_project() {
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
    PROJECT_DEVDIR=$(readlink $PROJECT/dev)

    $PROJECT_FACTORY $CURRENT_PROJECT $PROJECT_DEVDIR
}


# Create a new project.
# $1 => project name to link to current
link_dependency() {
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
list_projects() {
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
_list_projects() {
    find $PROJECTS_DIR -mindepth 1 -maxdepth 1 -type d | sed 's!^'"$PROJECTS_DIR/"'!!' | sort -u
}

_list_types() {
    find $PROJECT_PACK/types -name \*.sh -executable | sed 's!^'"$PROJECT_PACK/types/"'\(.*\)\.sh$!\1!' | sort -u
}

_list_deps() {
    {
        test -d $PROJECTS_DIR/$CURRENT_PROJECT/dep && find $PROJECTS_DIR/$CURRENT_PROJECT/dep -mindepth 1 -maxdepth 1 -type l | sed 's!^'"$PROJECTS_DIR/$CURRENT_PROJECT/dep/"'!!'
        echo $CURRENT_PROJECT
    } | sort -u
}

_go_to_project_completion() {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=($(compgen -W "$(_list_projects)" -- "$cur"))
    fi

    if [ $extglob = 1 ]; then
        shopt -u extglob
    fi
}
complete -F _go_to_project_completion go_to_project gp link_dependency lp

_go_to_dependent_project_completion() {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=($(compgen -W "$(_list_deps)" -- "$cur"))
    fi

    if [ $extglob = 1 ]; then
        shopt -u extglob
    fi
}
complete -F _go_to_dependent_project_completion go_to_dependent_project cdp

_create_new_project_completion() {
    local cur extglob
    shopt extglob|grep -q on
    extglob=$?
    shopt -s extglob
    # the possible completion words
    COMPREPLY=()
    # the current word to be completed, can be empty
    cur="${COMP_WORDS[COMP_CWORD]}"

    case $COMP_CWORD in
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
complete -F _create_new_project_completion create_new_project np


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Useful functions

fc() {
    find $(pwd) \( -name CVS -o -name .svn -o -name .git \) -prune -o \( -name \*.[ch] -o -name \*.[ch]pp \) -exec grep -Hn "$@" {} \;
}

fe() {
    find $(pwd) \( -name CVS -o -name .svn -o -name .git \) -prune -o -name \*.e -exec grep -Hn "$@" {} \;
}

fj() {
    find $(pwd) \( -name CVS -o -name .svn -o -name .git \) -prune -o -name \*.java -exec grep -Hn "$@" {} \;
}

fpy() {
    find $(pwd) \( -name CVS -o -name .svn -o -name .git \) -prune -o -name \*.py -exec grep -Hn "$@" {} \;
}

fly() {
    find $(pwd) \( -name CVS -o -name .svn -o -name .git \) -prune -o \( -name \*.ly -o -name \*.ily \) -exec grep -Hn "$@" {} \;
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Some aliases

alias  gp=go_to_project
alias cdp=go_to_dependent_project
alias  np=create_new_project
alias  lp=link_dependency
alias lsp=list_projects
alias upp=update_project


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Internal functions

_project_tag_all() {
    project=$1
    nb=$($project/bin/find_all.sh | wc -l)
    cols=$(stty size|awk '{print $2}')
    $project/bin/tag_all.sh -V | grep '^OPENING' | awk -vcols=$cols -vsize=30 -vmax=$nb '
       BEGIN {
          len = cols - size - 6;
       }
       {
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
