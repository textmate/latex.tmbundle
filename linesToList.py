#!/usr/bin/python

# TODO:  make this script detect indented lines so it can generate nested list environments

import sys
import re

descPat = re.compile('(^[\w\s]{1,20}?):(.*$)')
lines = sys.stdin.readlines()

for i in lines:
    if len(i) > 1:
        m = descPat.match(i)
        if m:
            print "    \\\\item",'[',m.group(1),']',m.group(2)
        else:
            print "    \\\\item ", i
