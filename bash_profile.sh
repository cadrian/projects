# To be sourced at the very end of .profile (any environment change after that will be ignored)


# Project public environment variables, set them or use the default
export PROJECT_PACK=${PROJECT_PACK:-/usr/local/share/ProjectManager}
export PROJECTS_DIR=${PROJECTS_DIR:-$HOME/.projects}


# Internal environment variables, don't change them
export PROJECT_CURRENT=$PROJECTS_DIR/.@current
export CURRENT_PROJECT=""


# Save some environment variables to restore them at each project change
export PROJECT_DEFAULT_PATH="$PATH"
export PROJECT_DEFAULT_PS1="$PS1"


# Go to the given project.
# $1 => project name
go_to_project() {
    PROJECT=$PROJECTS_DIR/$1

    if [ -z "$1" ]; then
	echo "Must provide: project name" >&2
	echo "Not enough arguments: aborting." >&2
	return 1
    fi

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
	echo "Unknown project $1: aborting." >&2
	return 1
    fi

    echo "Please wait, going to project $1."

    ln -s $PROJECT $PROJECT_CURRENT
    CURRENT_PROJECT=$1

    export PATH="$PROJECT_DEFAULT_PATH"
    . $PROJECT/go

    export PS1="[$1] $PROJECT_DEFAULT_PS1"
    cd $(ls -l $PROJECT/dev | sed 's/^.*->\s*//')
}


# Create a new project.
# $1 => project name
# $2 => project type
# $3 => project development directory
create_new_project() {
    PROJECT=$PROJECTS_DIR/$1
    PROJECT_FACTORY=$PROJECT_PACK/types/$2.sh
    PROJECT_DEVDIR=$(cd $3 && pwd)

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

    $PROJECT_FACTORY $1
}


# Restore the last saved project
if [ -h $PROJECT_CURRENT ]; then
    current_project=$(ls -l $PROJECT_CURRENT | sed 's/^.*->\s*//')
    go_to_project "${current_project##*/}"
fi


# Some aliases
alias gp=go_to_project
alias np=create_new_project