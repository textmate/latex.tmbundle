#!/usr/bin/env python

# This is a rewrite of latexErrWarn.py
# Goals:
#   1.  Modularize the processing of a latex run to better capture and parse errors
#   2.  replace latexmk
#   3.  provide a nice pushbutton interface for manually running latex,bibtex,mkindex, and viewing
#   
# Overview:
#    Each tex command has its own class that parses the output from that program.  Each of these classes
#    extends the TexParser class which provides default methods:
#       parseStream
#       error
#       warning
#       info
#   The parseStream method reads each line from the input stream matches against a set of regular
#   expressions defined in the patterns dictionary.  If one of these patterns matches then the 
#   corresponding method is called.  This method is also stored in the dictionary.  Pattern matching
#   callback methods must each take the match object as well as the current line as a parameter.
#
#   Progress:
#       7/17/07  -- Brad Miller
#       Implemented  TexParse, BibTexParser, and LaTexParser classes
#       see the TODO's sprinkled in the code below
#
#   Future:
# 
#       I think that the typeset and veiw window could have some buttons at the top to enable a user
#       to run latex, bibtex and makeindex
#       With the processing for each command stream nicely separated it would not be possible to
#       think about replacing latexmk.pl with a simpler python version.
#

import sys
import re
from os.path import basename
import os
from struct import *



numRuns = 0

def percent_escape(str):
	return re.sub('[\x80-\xff /&]', lambda x: '%%%02X' % unpack('B', x.group(0))[0], str)

def make_link(file, line):
	return 'txmt://open?url=file:%2F%2F' + percent_escape(file) + '&line=' + line

def shell_quote(string):
	return '"' + re.sub(r'([`$\\"])', r'\\\1', string) + '"'


class TexParser(object):
    """Master Class for Parsing Tex Typsetting Streams"""
    def __init__(self, input_stream, verbose):
        super(TexParser, self).__init__()
        self.input_stream = input_stream
        self.done = False
        self.verbose = verbose
        self.numErrs = 0
        self.numWarns = 0
        self.isFatal = False
        
    def parseStream(self):
        """docstring for parseStream"""
        line = self.input_stream.readline()

        while line and not self.done:
            line = line.rstrip("\n")
            foundMatch = False

            # process matching patterns until we find one
            for pat in self.patterns.keys():
                myMatch = pat.match(line)
                if myMatch:
                    self.patterns[pat](myMatch,line)
                    foundMatch = True
                    break
            
            if self.verbose and not foundMatch:
                print line
            
            line = self.input_stream.readline()

        return self.isFatal, self.numErrs, self.numWarns

    def info(self,m,line):
        print line
    
    def error(self,m,line):
        print '<div class="error">'
        print line
        print '</div>'
        self.numErrs += 1

    def warning(self,m,line):
        print '<div class="warning">'
        print line
        print '</div>'
        self.numWarns += 1

class BibTexParser(TexParser):
    """Parse and format Error Messages from bibtex"""
    def __init__(self, btex, verbose):
        super(BibTexParser, self).__init__(btex,verbose)
        self.patterns = { 
            re.compile("Warning--I didn't find a database entry") : self.warning,
            re.compile(r'I found no \\\w+ command') : self.error,            
            re.compile('---') : self.finishRun
        }
    
    def finishRun(self,m,line):
        self.done = True
        print '</div>'

class LaTexParser(TexParser):
    """Parse Output From Latex"""
    def __init__(self, input_stream, verbose):
        super(LaTexParser, self).__init__(input_stream,verbose)
        self.patterns = {
            re.compile('^This is') : self.info,
            re.compile('^Document Class') : self.info,
            re.compile('^Latexmk') : self.info,
            re.compile('Run number') : self.newRun,
            re.compile('.*\((\.\/.*\.tex)') : self.detectNewFile,
            re.compile('^\s+file:line:error style messages enabled') : self.detectFileLineErr,
            re.compile('.*\<use (.*?)\>') : self.detectInclude,
            re.compile('^Output written') : self.info,
            re.compile('LaTeX Warning.*?input line (\d+).$') : self.handleWarning,
            re.compile('LaTeX Warning:.*') : self.warning,
            re.compile('^([\.\/\w\x7f-\xff ]+\.tex):(\d+):(.*)') : self.handleError,
            re.compile('([^:]*):(\d+): LaTeX Error:(.*)') : self.handleError,
            re.compile('([^:]*):(\d+): (Emergency stop)') : self.handleError,
            re.compile('Transcript written on (.*).$') : self.linkToLog,
            re.compile("Running 'bibtex") : self.startBibtex,
            re.compile('This is BibTeX,') : self.startBibtex,            
            re.compile("Running 'makeindex") : self.startBibtex,    # TODO: implement real MakeIndexParser
            re.compile("This is makeindex") : self.startBibtex,            
            re.compile('^Error: pdflatex') : self.pdfLatexError,
            re.compile('\!.*') : self.handleOldStyleErrors
        }
                

    def newRun(self,m,line):
        global numRuns
        print '<hr />'
        print '<p>', self.numErrs, 'Errors', self.numWarns, 'Warnings', 'in this run.', '</p>'
        self.numWarns = 0
        self.numErrs = 0
        numRuns += 1
        print '<hr />'

    def detectNewFile(self,m,line):
        self.currentFile = m.group(1)
        print "<h3>Typesetting: " + self.currentFile + "</h3>"

    def detectFileLineErr(self,m,line):
        self.fileLineErrors = True

    def detectInclude(self,m,line):
        print "    Including: " + m.group(1)

    def handleWarning(self,m,line):
        print '<a class="warning" href="' + make_link(os.getcwd()+self.currentFile[1:], m.group(1)) + '">'+line+"</a>"
        self.numWarns += 1
    
    def handleError(self,m,line):
        print '<div class="error">'
        latexErrorMsg = 'Latex Error: <a class="error" href="' + make_link(os.getcwd()+'/'+m.group(1),m.group(2)) +  '">' + m.group(1)+":"+m.group(2) + '</a> '+m.group(3)
        line = self.input_stream.readline()
        while len(line) > 1:
            latexErrorMsg = latexErrorMsg+line
            line = self.input_stream.readline()
        print latexErrorMsg+'</div>'
        self.numErrs += 1

    def linkToLog(self,m,line):
        print '<div class="error">'
        print '<a class="error" href="' + make_link(os.getcwd()+'/'+m.group(1),'1') +  '">' + m.group(1) + '</a>'
        print '</div>'

    def startBibtex(self,m,line):
        print '<div class="bibtex">'
        print '<h3>' + line[:-1] + '</h3>'
        bp = BibTexParser(self.input_stream,self.verbose)
        self.input_stream.readline() # swallow the following line of '---'
        f,e,w = bp.parseStream()
        self.numErrs += e
        self.numWarns += w

    def handleOldStyleErrors(self,m,line):
        if re.match('\! LaTeX Error:', line):
            print '<div class="error">'
            print line
            print '</div>'
            self.numErrs += 1
        else:
            print '<div class="warning">'
            print line
            print '</div>'
            self.numWarns += 1

    def pdfLatexError(self,m,line):
        """docstring for pdfLatexError"""
        self.numErrs += 1
        print '<div class="error">'
        print line
        line = self.input_stream.readline()
        if line and re.match('^ ==> Fatal error occurred', line):
            print line.rstrip("\n")
            print '</div>'
            self.isFatal = True
        else:
            print '</div>'


# TODO: detect that we are running latexmk right away and make multiple calls to a latexparsestream
# TODO: Add ParseLatexMk class

#
# Start of main program...
#
if __name__ == '__main__':
    verbose = False

    # Parse command line parameters...
    if len(sys.argv) > 1 and sys.argv[1] == '-v':
        verbose = True
        sys.argv[1:] = sys.argv[2:]
    if len(sys.argv) == 3:
        texCommand = sys.argv[1]
        fileName = sys.argv[2]
    else:
        sys.stderr.write("Usage: "+sys.argv[0]+" [-v] tex-command file.tex\n")
        sys.exit(255)

    # run the command passed to us
    texin,tex = os.popen4(texCommand+" "+shell_quote(fileName))

    print '<pre>'

    lp = LaTexParser(tex,verbose)
    isFatal, numErrs, numWarns = lp.parseStream()

    # cleanup and process error codes
    texStatus = tex.close()
    eCode = 0
    if texStatus != None or numWarns > 0 or numErrs > 0:
        print "Found " + str(numErrs) + " errors, and " + str(numWarns) + " warnings in " + str(numRuns) + " runs"
        if texStatus != None:
            signal = (texStatus & 255)
            returnCode = texStatus >> 8
            if signal != 0:
                print "TeX killed by signal " + str(signal)
            else:
                print "TeX exited with error code " + str(returnCode)

        if isFatal:
            eCode = 3
        elif numErrs > 0 or texStatus != None:
            eCode = 2
        else:
            eCode = 1

    print '</pre>'
    sys.exit(eCode)
