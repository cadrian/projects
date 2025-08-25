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

. "$PROJECT_PACK"/bash_profile.sh
. "$PROJECT_PACK"/types/_common.sh "$@"

make_tags() {
    cat > "$PROJECT"/bin/tag_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-"$PROJECT"}
export TAGS=\${TAGS:-\"$PROJECT"/.mk/TAGS}
export LOG=\${LOG:-\"$PROJECT"/.mk/tag_log}
export PROJECT_DEVDIR=\$(readlink \"$PROJECT"/dev)
test x\$1 == x-a || rm -f \$LOG
touch \$LOG
echo "\$(date -R) - updating "$PROJECT"" >>\$LOG
find \"$PROJECT"_DEVDIR -name \\*.php -o -name \\*.html | etags \$@ -f \$TAGS --language-force=PHP -L- 2>\$LOG || echo "Brand new project: no file tagged."

if [ -d \"$PROJECT"/dep ]; then
    for dep in \$(echo \"$PROJECT"/dep/*); do
        if [ -h \$dep ]; then
            project="$PROJECT"S_DIR/\${dep#\"$PROJECT"/dep/}
            PROJECT=\$project \$project/bin/tag_all.sh -a \$@
        fi
    done
fi
EOF

    cat > "$PROJECT"/bin/find_all.sh <<EOF
#!/usr/bin/env bash

export PROJECT=\${PROJECT:-"$PROJECT"}
export TAGS=\${TAGS:-\"$PROJECT"/.mk/TAGS}
export PROJECT_DEVDIR=\$(readlink \"$PROJECT"/dev)
find \"$PROJECT"_DEVDIR -name \\*.php -o -name \\*.html 2>/dev/null

if [ -d \"$PROJECT"/dep ]; then
    for dep in \$(echo \"$PROJECT"/dep/*); do
        if [ -h \$dep ]; then
            project="$PROJECT"S_DIR/\${dep#\"$PROJECT"/dep/}
            PROJECT=\$project \$project/bin/find_all.sh -a \$@
        fi
    done
fi
EOF

    chmod +x "$PROJECT"/bin/tag_all.sh "$PROJECT"/bin/find_all.sh
    _project_tag_all "$PROJECT"
}

test -d "$PROJECT"/.mk || mkdir -p "$PROJECT"/.mk
make_emacs
make_tags
make_go
