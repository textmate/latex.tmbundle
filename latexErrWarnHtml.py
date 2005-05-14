#!/usr/bin/env python

import sys
import re
from os.path import basename
import os

#in a multifile latex document the current document will come after a left paren
newFilePat = re.compile('.*\((\.\/.*\.tex)')
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
        print '<a href="txmt://open?url=file://'+os.environ.get('TM_DIRECTORY')+currentFile[1:]+"&line="+w.group(1)+'">'+line+"</a>"
    elif e:
        print '<a href="txmt://open?url=file://'+os.environ.get('TM_DIRECTORY')+e.group(1)[1:]+"&line="+e.group(2)+'">'+line+"</a>"        
    else:
        sys.stdout.write(line)

print '<a href="http://localhost/~'+os.environ.get('USER')+'/web_kit_workaround.pdf">Click Here to preview Typeset file</a>'

