#!/usr/bin/python

import sys
import re
from os.path import basename

#in a multifile latex document the current document will come after a left paren
newFilePat = re.compile('.*\((.*\.tex)')
warnPat = re.compile('LaTeX Warning.*?input line (\d+).$')
errPat = re.compile('^([\.\/\w]+\.tex)(:\d+:.*)')

for line in sys.stdin:
    m = newFilePat.match(line)
    if m:
        currentFile = m.group(1)
    w = warnPat.match(line)
    e = errPat.match(line)
    # if we detect a warning message add the current file to the warning plus a tag
    # to make it easy to pick out the line as an error line in TextMate.
    # Do the same thing for error messages.
    if w:
        print "==>"+basename(currentFile)+":"+w.group(1)+":",line
    elif e:
        print "==>"+basename(e.group(1))+e.group(2)
    else:
        sys.stdout.write(line)
    