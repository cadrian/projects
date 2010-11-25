#!/usr/bin/env python

import os
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
