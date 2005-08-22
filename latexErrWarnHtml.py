#!/usr/bin/env python

import sys
import re
from os.path import basename
import os
from struct import *

def percent_escape(str):
	return re.sub('[\x80-\xff /&]', lambda x: '%%%02X' % unpack('B', x.group(0))[0], str)

def make_link(file, line):
	return 'txmt://open?url=file:%2F%2F' + percent_escape(file) + '&line=' + line

#in a multifile latex document the current document will come after a left paren
newFilePat = re.compile('.*\((\.\/.*\.tex)')
warnPat = re.compile('LaTeX Warning.*?input line (\d+).$')
errPat = re.compile('^([\.\/\w\x7f-\xff]+\.tex):(\d+):.*')
incPat = re.compile('.*\<use (.*?)\>');
miscWarnPat = re.compile('LaTeX Warning:.*')

if sys.argv[0] == '-v':
    verbose = True
else:
    verbose = False
numWarns = 0
numErrs = 0
numRuns = 0
inbibidx = False

print '<pre>'
line = sys.stdin.readline()
while line:
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
    if re.match('Running makeindex',line):
        print '<div class="mkindex">'        
        print '<h3>' + line[:-1] + '</h3>'
        sys.stdin.readline()
        inbibidx = True

    if re.match('(! Emergency stop|Error:)',line):
        print '<div class="error">'
        print line
        print 'See the log file for details'
        print '</div>'
        numErrs = numErrs + 1

    ts = re.match('Transcript written on (.*).$',line)
    if ts:
        print '<div class="error">'
        print '<a class="error" href="' + make_link(os.getcwd()+'/'+ts.group(1),'1') +  '">' + ts.group(1) + '</a>'
        print '</div>'
        
    if re.match('Running bibtex',line):
        print '<div class="bibtex">'
        print '<h3>' + line[:-1] + '</h3>'
        sys.stdin.readline()
        inbibidx = True
        
    if re.match('---',line) and inbibidx:
        print '</div>'
        inbibidx = False

    if re.match("Warning--I didn't find a database entry",line):
        print line
        
    if re.match('Run number',line):
        print '<hr />'
        numWarns = 0
        numErrs = 0
        numRuns = numRuns + 1
        print '<hr />'
        
    w = warnPat.match(line)
    e = errPat.match(line)
    me = miscWarnPat.match(line)
    
    # if we detect a warning message add the current file to the warning plus a tag
    # to make it easy to pick out the line as an error line in TextMate.
    # Do the same thing for error messages.
    if w:
        print '<a class="warning" href="' + make_link(os.getcwd()+currentFile[1:], w.group(1)) + '">'+line+"</a>"
        numWarns = numWarns+1
    elif e:
        numErrs = numErrs+1
        nextLine = sys.stdin.readline()
        print '<a class="error" href="' + make_link(os.getcwd()+e.group(1)[1:], e.group(2)) + '">'+line[:-1]+nextLine+"</a>"        
    elif me:
        numWarns = numWarns + 1
        sys.stdout.write('<p class="warning">' + line[:-1] + '</p>')
    else:
        if verbose:
            print line[:-1]
    line = sys.stdin.readline()
eCode = 0
if numWarns > 0 or numErrs > 0:
    print "Found " + str(numErrs) + " errors, and " + str(numWarns) + " warnings in " + str(numRuns) + " runs"
    if numErrs > 0:
        eCode = 2
    else:
        eCode = 1
else:
    print "Success"

print '</pre>'
sys.exit(eCode)
