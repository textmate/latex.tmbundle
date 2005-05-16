#!/usr/bin/env python

import sys
import re
from os.path import basename
import os

#in a multifile latex document the current document will come after a left paren
newFilePat = re.compile('.*\((\.\/.*\.tex)')
warnPat = re.compile('LaTeX Warning.*?input line (\d+).$')
errPat = re.compile('^([\.\/\w]+\.tex):(\d+):.*')
incPat = re.compile('.*\<use (.*?)\>');

if sys.argv[0] == '-v':
    verbose = True
else:
    verbose = False
numWarns = 0
numErrs = 0
print '<pre>'
for line in sys.stdin:
    # print out first line
    if re.match('^This is',line):
        print line[:-1]
    if re.match('^Document Class',line):
        print line[:-1]
    m = newFilePat.match(line)
    if m:
        currentFile = m.group(1)
        print "<h3>Typesetting: " + currentFile + "</h3>"
    inf = incPat.match(line)
    if inf:
        print "    Including: " + inf.group(1)
    if re.match('^Output written',line):
        print line[:-1]
    w = warnPat.match(line)
    e = errPat.match(line)
    # if we detect a warning message add the current file to the warning plus a tag
    # to make it easy to pick out the line as an error line in TextMate.
    # Do the same thing for error messages.
    if w:
        print '<a href="txmt://open?url=file://'+os.getcwd()+currentFile[1:]+"&line="+w.group(1)+'">'+line+"</a>"
        numWarns = numWarns+1
    elif e:
        numErrs = numErrs+1
        print '<a href="txmt://open?url=file://'+os.getcwd()+e.group(1)[1:]+"&line="+e.group(2)+'">'+line+"</a>"        
    else:
        if verbose:
            print line[:-1]
eCode = 0
if numWarns > 0 or numErrs > 0:
    print "Found " + str(numErrs) + " errors, and " + str(numWarns) + " warnings."
    if numErrs > 0:
        eCode = 2
    else:
        eCode = 1
else:
    print "Success"

print '</pre>'
sys.exit(eCode)
