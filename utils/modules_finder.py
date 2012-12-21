#!/usr/bin/env python

# Copyright (c) 2010-2012, Cyril Adrian <cyril.adrian@gmail.com> All rights reserved.
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

import sys

args = sys.argv
res = set()
for arg in sys.argv[1:]:
    path = arg
    add = path not in res
    while add and path:
        array = path.split('/')
        path = '/'.join(array[:-1])
        add = path not in res
    if add:
        array = arg.split('/')
        path = '/'.join(array[:-1])
        res.add(path)

print ":".join(res)
