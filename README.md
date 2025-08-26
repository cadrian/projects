**A collection of tools for multiple projects management.**

# Usage

Just source __bash_profile.sh__

The command is **p**

## Create a new project

**p new <name> <type> <directory>**

Create a new project of the given type. Give it a name and a root directory location.

Supported project types: C, python, java, eiffel, go, PHP, and more.

## Go to a project

### Basic command line support

**p go <name>**

In the shell, go to the given project root directory

### GUI support

Bind a shortcut to either __zenity_project__ or __dmenu_project__.

Those show a list to select a project; then open a shell in the
project's root directory, and an emacs editor using its "desktop mode"
(session management features) to remember which files were open in a
given project.

**Note:** the __demnu_project__ script is not well maintained. I don't
use it anymore since __dmenu__ does not work properly with Wayland.

# Prerequisites

At least:
- [GNU **bash**](https://www.gnu.org/software/bash/)
- [GNU **emacs**](https://www.gnu.org/software/emacs/)
- [GNU **coreutils**](https://www.gnu.org/software/coreutils/)
- **at** (any flavour: systemd, etc.)
- [**exuberant ctags**](https://ctags.sourceforge.net/) or [**universal ctags**](https://github.com/universal-ctags/ctags)

Optional:
- Either **zenity**, **yad**, or **dmenu** for GUI support.

# License

2-clause BSD where applicable (http://opensource.org/licenses/BSD-2-Clause)

Imported files from other people keep their original license.
