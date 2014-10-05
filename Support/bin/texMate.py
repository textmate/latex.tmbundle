#!/usr/bin/env python -u
# encoding: utf-8

# This is a rewrite of latexErrWarn.py
#
# Goals:
#
#   1. Modularize the processing of a latex run to better capture and parse
#      errors
#   2. Replace latexmk
#   3. Provide a nice pushbutton interface for manually running
#      latex, bibtex, makeindex, and viewing
#
# Overview:
#
#    Each tex command has its own class that parses the output from that
#    program.  Each of these classes extends the TexParser class which provides
#    default methods:
#
#       parseStream
#       error
#       warning
#       info
#
#   The parseStream method reads each line from the input stream matches
#   against a set of regular expressions defined in the patterns dictionary. If
#   one of these patterns matches then the corresponding method is called. This
#   method is also stored in the dictionary. Pattern matching callback methods
#   must each take the match object as well as the current line as a parameter.
#
#   To enable debug mode without modifying this file:
#
#       defaults write com.macromates.textmate latexDebug 1
#
#   Progress:
#
#       7/17/07  -- Brad Miller
#
#       Implemented  TexParse, BibTexParser, and LaTexParser classes see the
#       TODO's sprinkled in the code below
#
#       7/24/07  -- Brad Miller
#
#       Spiffy new configuration window added
#       pushbutton interface at the end of the latex output is added the
#       confusing mass of code that was Typeset & View has been replaced by
#       this one
#
#   Future:
#
#       Think about replacing latexmk with a simpler python version.  If only
#       rubber worked reliably..

# -- Imports ------------------------------------------------------------------

import sys
import re
import os
import tmprefs

from glob import glob
from os import chdir  # NOQA
from os.path import dirname
from re import match
from subprocess import Popen, PIPE, STDOUT
from sys import stdout
from urllib import quote

from texparser import (BibTexParser, BiberParser, ChkTeXParser, LaTexParser,
                       MakeGlossariesParser, ParseLatexMk, TexParser)


# -- Module Import ------------------------------------------------------------

reload(sys)
sys.setdefaultencoding("utf-8")


# -- Global Variables ---------------------------------------------------------

DEBUG = False
TM_BUNDLE_SUPPORT = os.getenv("TM_BUNDLE_SUPPORT")
TM_SUPPORT_PATH = os.getenv("TM_SUPPORT_PATH")

texMateVersion = ' $Rev$ '
numRuns = 0


# -- Functions ----------------------------------------------------------------

def expand_name(filename, program='pdflatex'):
    """Get the expanded file name for a certain tex file.

    Arguments:

        filename

                The name of the file we want to expand.

        program

                The name of the tex program for which we want to expand the
                name of the file.

    Returns: ``str``

    Examples:

        >>> expand_name('Tests/text.tex')
        './Tests/text.tex'
        >>> expand_name('non_existent_file.tex')
        ''

    """
    stdout.flush()
    run_object = Popen("kpsewhich -progname='{}' '{}'".format(
        program, filename), shell=True, stdout=PIPE)
    return run_object.stdout.read().strip()


def run_bibtex(texfile, verbose=False):
    """Run bibtex for a certain tex file.

    Run bibtex for ``texfile`` and return the following values:

    - The return value of the bibtex runs done by this function: This value
      will be ``0`` after a successful run. Any other value indicates that
      there were some kind of problems.

    - Fatal error: Specifies if there was a fatal error while processing the
      bibliography.

    - Errors: The number of non-fatal errors encountered while processing the
      bibliography

    - Warnings: The number of warnings found while running this function

    Arguments:

        texfile

            Specifies the name of the tex file. This information will be used
            to find the bibliography.

        verbose

            Specifies if the output by this function should be verbose.


    Returns: ``(int, bool, int, int)``

    Examples:

        >>> chdir('Tests')
        >>> run_bibtex('external_bibliography.tex') # doctest:+ELLIPSIS
        <h4>Processing: ...
        ...
        (0, False, 0, 0)
        >>> chdir('..')

    """
    basename = texfile[:texfile.rfind('.')]
    directory = dirname(texfile) if dirname(texfile) else '.'
    regex_auxfiles = (r'.*/({}|bu\d+)\.aux$'.format(basename))
    auxfiles = [f for f in glob("{}/*.aux".format(directory))
                if match(regex_auxfiles, f)]

    stat, fatal, errors, warnings = 0, False, 0, 0
    for bib in auxfiles:
        print('<h4>Processing: {} </h4>'.format(bib))
        run_object = Popen("bibtex '{}'".format(bib), shell=True, stdout=PIPE,
                           stdin=PIPE, stderr=STDOUT, close_fds=True)
        bp = BibTexParser(run_object.stdout, verbose)
        f, e, w = bp.parseStream()
        fatal |= f
        errors += e
        warnings += w
        stat |= run_object.wait()
    return stat, fatal, errors, warnings


def run_biber(texfile, verbose=False):
    """Run biber for a certain tex file.

    The interface for this function is exactly the same as the one for
    ``run_bibtex``. For the list of arguments and return values please take a
    look at the doc-string of ``run_bibtex``.

    Examples:

        >>> chdir('Tests')
        >>> run_biber('external_bibliography_biber.tex') # doctest:+ELLIPSIS
        <...
        ...
        (0, False, 0, 0)
        >>> chdir('..')

    """
    file_no_suffix = getFileNameWithoutExtension(texfile)
    run_object = Popen("biber '{}'".format(file_no_suffix), shell=True,
                       stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    bp = BiberParser(run_object.stdout, verbose)
    fatal, errors, warnings = bp.parseStream()
    stat = run_object.wait()
    return stat, fatal, errors, warnings


def run_latex(ltxcmd, texfile, verbose=False):
    """Run the flavor of latex specified by ltxcmd on texfile.

    This function returns:

        - the return value of ``ltxcmd``,

        - a value specifying if there were any fatal flaws (``True``) or not
          (``False``), and

        - the number of errors and

        - the number of warnings encountered while processing ``texfile``.

    Arguments:

        ltxcmd

            The latex command which should be used translate ``texfile``.

        texfile

            The path of the tex file which should be translated by ``ltxcmd``.

    Returns: ``(int, bool, int, int)``

    Examples:

        >>> chdir('Tests')
        >>> run_latex(ltxcmd='pdflatex',
        ...           texfile='external_bibliography.tex') # doctest:+ELLIPSIS
        <h4>...
        ...
        (0, False, 0, 0)
        >>> chdir('..')

    """
    global numRuns
    if DEBUG:
        print("<pre>run_latex: {} '{}'</pre>".format(ltxcmd, texfile))
    run_object = Popen("{} '{}'".format(ltxcmd, texfile), shell=True,
                       stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    lp = LaTexParser(run_object.stdout, verbose, texfile)
    fatal, errors, warnings = lp.parseStream()
    stat = run_object.wait()
    numRuns += 1
    return stat, fatal, errors, warnings


def run_makeindex(filename):
    """Run the makeindex command.

    Generate the index for the given file returning

        - the return value of ``makeindex``,

        - a value specifying if there were any fatal flaws (``True``) or not
          (``False``), and

        - the number of errors and

        - the number of warnings encountered while processing ``filename``.

    Arguments:

        filename

            The name of the tex file for which we want to generate an index.

    Returns: ``(int, bool, int, int)``

    Examples:

        >>> chdir('Tests')
        >>> run_makeindex('makeindex.tex') # doctest:+ELLIPSIS
        This is makeindex...
        ...
        (0, False, 0, 0)
        >>> chdir('..')

    """
    run_object = Popen("makeindex '{}.idx'".format(
                       getFileNameWithoutExtension(filename)), shell=True,
                       stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    ip = TexParser(run_object.stdout, True)
    fatal, errors, warnings = ip.parseStream()
    stat = run_object.wait()
    return stat, fatal, errors, warnings


def run_makeglossaries():
    """Run makeglossaries"""
    # Call biber without extension.
    fatal, err, warn = 0, 0, 0
    runObj = Popen("makeglossaries '{}'".format(fileNoSuffix), shell=True,
                   stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    bp = MakeGlossariesParser(runObj.stdout, verbose)
    f, e, w = bp.parseStream()
    fatal |= f
    err += e
    warn += w
    stat = runObj.wait()
    return stat, fatal, err, warn


def findViewerPath(viewer, pdfFile, fileName):
    """Use the find_app command to ensure that the viewer is installed in the
    system For apps that support pdfsync search in pdf set up the command to
    go to the part of the page in the document the user was writing."""
    runObj = Popen("'{}/bin/find_app' '{}.app'".format(TM_SUPPORT_PATH,
                   viewer), stdout=PIPE, shell=True)
    vp = runObj.stdout.read()
    syncPath = None
    lineNumber = os.getenv('TM_SELECTION').split(':')[0]
    if viewer == 'Skim' and vp:
        syncPath = ("'{}/Contents/SharedSupport/displayline' ".format(vp) +
                    "{} '{}' '{}'".format(lineNumber, pdfFile,
                                          os.getenv('TM_FILEPATH')))
    if DEBUG:
        print "VP = ", vp
        print "syncPath = ", syncPath
    return vp, syncPath


def refreshViewer(viewer, pdfPath):
    """Use Applescript to tell the viewer to reload"""
    print '<p class="info">Telling %s to Refresh %s...</p>' % (viewer, pdfPath)
    if viewer == 'Skim':
        os.system("/usr/bin/osascript -e 'tell application \"Skim\" to " +
                  "revert (documents whose path is \"{}\")'".format(pdfPath))
    elif viewer == 'TeXShop':
        os.system("/usr/bin/osascript -e 'tell application \"TeXShop\" to " +
                  "tell documents whose path is \"{}\" ".format(pdfPath) +
                  "to refreshpdf'")


# TODO refactor run_viewer and sync_viewer to work together better
def sync_viewer(viewer, fileName, filePath):
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    pdfFile = '{}.pdf'.format(fileNoSuffix)
    cmdPath, syncPath = findViewerPath(viewer, pdfFile, fileName)
    if syncPath:
        stat = os.system(syncPath)
    else:
        print 'pdfsync is not supported for this viewer'
    return stat


def run_viewer(viewer, fileName, filePath, force, usePdfSync=True):
    """If the viewer is TextMate,  then setup the proper urls and/or redirects
    to show the pdf file in the html output window. If the viewer is an
    external viewer then ensure that it is installed and display the pdf"""
    stat = 0
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    pathNoSuffix = filePath + '/' + fileNoSuffix
    if viewer != 'TextMate':
        pdfFile = '{}.pdf'.format(fileNoSuffix)
        pdfPath = '{}.pdf'.format(pathNoSuffix)
        cmdPath, syncPath = findViewerPath(viewer, pdfFile, fileName)
        if cmdPath:
            # if this is not done, the next line will thrown an encoding
            # exception when the pdfFile contains non-ASCII. Is this a Python
            # bug?
            viewer = viewer.encode('utf-8')
            stat = os.system("'{}/bin/check_open' '{}' '{}'".format(
                             TM_BUNDLE_SUPPORT, viewer, pdfPath))
            if stat != 0:
                viewCmd = "/usr/bin/open -a '{}.app' '{}'".format(viewer,
                                                                  pdfPath)
                stat = os.system(viewCmd)
            else:
                refreshViewer(viewer, pdfPath)
        else:
            print('<strong class="error">', viewer, ' does not appear to be ' +
                  'installed on your system.</strong>')
        if syncPath and usePdfSync:
            os.system(syncPath)
        elif not syncPath and usePdfSync:
            print 'pdfsync is not supported for this viewer'
    else:
        pdfPath = filePath+'/'+fileNoSuffix+'.pdf'
        if(numErrs < 1 and numWarns < 1 or
           numErrs < 1 and numWarns > 0 and not force):
            if os.path.isfile(pdfPath):
                print '<script type="text/javascript">'
                print 'window.location="file://'+quote(pdfPath)+'"'
                print '</script>'
            else:
                print 'File does not exist: '+pdfPath
    return stat


def determine_ts_directory(tsDirectives):
    """Determine the proper directory to use for typesetting the current
    document"""
    master = os.getenv('TM_LATEX_MASTER')
    texfile = os.getenv('TM_FILEPATH')
    startDir = os.path.dirname(texfile)

    if 'root' in tsDirectives:
        masterPath = os.path.dirname(os.path.normpath(tsDirectives['root']))
        return masterPath
    if master:
        masterPath = os.path.dirname(master)
        if masterPath == '' or masterPath[0] != '/':
            masterPath = os.path.normpath(os.path.join(startDir, masterPath))
    else:
        masterPath = startDir
    if DEBUG:
        print '<pre>Typesetting Directory = ', masterPath, '</pre>'
    return masterPath


def findTexPackages(fileName):
    """Find all packages included by the master file.
       or any file included from the master.  We should not have to go
       more than one level deep for preamble stuff.
    """
    try:
        realfn = expand_name(fileName)
        texString = open(realfn)
    except:
        print('<p class="error">Error: Could not open ' +
              '%s to check for packages</p>' % fileName)
        print('<p class="error">This is most likely a problem with ' +
              'TM_LATEX_MASTER</p>')
        sys.exit(1)
    inputre = re.compile(r'((^|\n)[^%]*?)(\\input|\\include)\{([\w /\.\-]+)\}')
    usepkgre = re.compile(
        r'((^|\n)[^%]*?)\\usepackage(\[[\w, \-]+\])?\{([\w,\-]+)\}')
    beginre = re.compile(r'((^|\n)[^%]*?)\\begin\{document\}')
    incFiles = []
    myList = []
    for line in texString:
        begin = re.search(beginre, line)
        inc = re.search(inputre, line)
        usepkg = re.search(usepkgre, line)
        if begin:
            break
        elif inc:
            incFiles.append(inc.group(4))
        elif usepkg:
            myList.append(usepkg.group(4))
    beginFound = False
    for ifile in incFiles:
        if ifile.find('.tex') < 0:
            ifile += '.tex'
        try:
            realif = expand_name(ifile)
            incmatches = []
            for line in file(realif):
                incmatches.append(re.search(usepkgre, line))
                if re.search(beginre, line):
                    beginFound = True
            myList += [x.group(4) for x in incmatches if x]
        except:
            print('<p class="warning">Warning: Could not open ' +
                  '%s to check for packages</p>' % ifile)
        if beginFound:
            break
    newList = []
    for pkg in myList:
        if pkg.find(',') >= 0:
            for sp in pkg.split(','):
                newList.append(sp.strip())
        else:
            newList.append(pkg.strip())
    if DEBUG:
        print '<pre>TEX package list = ', newList, '</pre>'
    return newList


def find_TEX_directives():
    """Build a dictionary of %!TEX directives

    The main ones we are concerned with are

       root : which specifies a root file to run tex on for this subsidiary
       TS-program : which tells us which latex program to run
       TS-options : options to pass to TS-program
       encoding  :  file encoding

    """
    texfile = os.getenv('TM_FILEPATH')
    startDir = os.path.dirname(texfile)
    done = False
    tsDirectives = {}
    rootChain = [texfile]
    while not done:
        f = open(texfile)
        foundNewRoot = False
        for i in range(20):
            line = f.readline()
            m = re.match(r'^%!TEX\s+([\w-]+)\s?=\s?(.*)', line)
            if m:
                if m.group(1) == 'root':
                    foundNewRoot = True
                    if m.group(2)[0] == '/':
                        newtf = m.group(2).rstrip()
                    else:  # new root is relative or in same directory
                        newtf = os.path.realpath(
                            os.path.join(startDir, m.group(2).rstrip()))
                    if newtf in rootChain:
                        print("<p class='error'> There is a loop in your " +
                              "'%!TEX root =' directives.</p>")
                        print "<p class='error'> chain = ", rootChain, "</p>"
                        print "<p class='error'> exiting.</p>"
                        sys.exit(-1)
                    else:
                        texfile = newtf
                        rootChain.append(newtf)
                    startDir = os.path.dirname(texfile)
                    tsDirectives['root'] = texfile
                else:
                    tsDirectives[m.group(1)] = m.group(2).rstrip()
        f.close()
        if not foundNewRoot:
            done = True
    if DEBUG:
        print '<pre>%!TEX Directives: ', tsDirectives, '</pre>'
    return tsDirectives


def findFileToTypeset(tsDirectives):
    """Determine which file to typeset. Using the following rules:

       + %!TEX root directive
       + using the TM_LATEX_MASTER environment variable
       + Using TM_FILEPATH

       Once the file is decided return the name of the file and the normalized
       absolute path to the file as a tuple.

    """
    if 'root' in tsDirectives:
        f = tsDirectives['root']
    elif os.getenv('TM_LATEX_MASTER'):
        f = os.getenv('TM_LATEX_MASTER')
    else:
        f = os.getenv('TM_FILEPATH')
    master = os.path.basename(f)
    if DEBUG:
        print '<pre>master file = ', master, '</pre>'
    return master, determine_ts_directory(tsDirectives)


def constructEngineOptions(tsDirectives, tmPrefs):
    """Construct a string of command line options to pass to the typesetting
    engine

    Options can come from:

        +  %!TEX TS-options directive in the file
        + Preferences

    In any case nonstopmode is set as is file-line-error-style.

    """
    opts = "-interaction=nonstopmode -file-line-error-style"
    if synctex:
        opts += " -synctex=1 "
    if 'TS-options' in tsDirectives:
        opts += " " + tsDirectives['TS-options']
    else:
        opts += " " + tmPrefs['latexEngineOptions']
    if DEBUG:
        print '<pre>Engine options = ', opts, '</pre>'
    return opts


def usesOnePackage(testPack, allPackages):
    for p in testPack:
        if p in allPackages:
            return True
    return False


def constructEngineCommand(tsDirectives, tmPrefs, packages):
    """This function decides which engine to run using

       + %!TEX directives from the tex file
       + Preferences
       + or by detecting certain packages

    The default is pdflatex.  But it may be modified to be one of

          latex
          xelatex
          texexec  -- although I'm not sure how compatible context is with any
                      of this

    """
    engine = "pdflatex"
    latexIndicators = ['pstricks', 'xyling', 'pst-asr', 'OTtablx', 'epsfig']
    xelatexIndicators = ['xunicode', 'fontspec']

    if 'TS-program' in tsDirectives:
        engine = tsDirectives['TS-program']
    elif usesOnePackage(latexIndicators, packages):
        engine = 'latex'
    elif usesOnePackage(xelatexIndicators, packages):
        engine = 'xelatex'
    else:
        engine = tmPrefs['latexEngine']
    stat = os.system("type {} > /dev/null".format(engine))
    if stat != 0:
        print('<p class="error">Error: %s is not found, ' % engine +
              'you need to install LaTeX or be sure that your PATH is ' +
              'setup properly.</p>')
        sys.exit(1)
    return engine


def getFileNameWithoutExtension(fileName):
    """Return filename upto the . or full filename if no ."""
    suffStart = fileName.rfind(".")
    if suffStart > 0:
        fileNoSuffix = fileName[:suffStart]
    else:
        fileNoSuffix = fileName
    return fileNoSuffix


def writeLatexmkRc(engine, eOpts):
    """Create a latexmkrc file that uses the proper engine and arguments"""
    rcFile = open("/tmp/latexmkrc", 'w')
    rcFile.write("$latex = 'latex -interaction=nonstopmode " +
                 "-file-line-error-style %s  ';\n" % eOpts)
    rcFile.write("$pdflatex = '%s -interaction=nonstopmode " % engine +
                 "-file-line-error-style %s ';\n""" % eOpts)
    rcFile.close()

###############################################################
#                                                             #
#                 Start of main program...                    #
#                                                             #
###############################################################

if __name__ == '__main__':
    verbose = False
    numRuns = 0
    stat = 0
    texStatus = None
    numErrs = 0
    numWarns = 0
    firstRun = False
    synctex = False

#
# Parse command line parameters...
#
    if len(sys.argv) > 2:
        firstRun = True         # A little hack to make the buttons work nicer.
    if len(sys.argv) > 1:
        texCommand = sys.argv[1]
    else:
        sys.stderr.write("Usage: "+sys.argv[0]+" tex-command firstRun\n")
        sys.exit(255)

#
# Get preferences from TextMate or local directives
#
    tmPrefs = tmprefs.Preferences()

    if int(tmPrefs['latexDebug']) == 1:
        DEBUG = True
        print '<pre>turning on debug</pre>'

    tsDirs = find_TEX_directives()
    os.chdir(determine_ts_directory(tsDirs))

#
# Set up some configuration variables
#
    if tmPrefs['latexVerbose'] == 1:
        verbose = True

    useLatexMk = tmPrefs['latexUselatexmk']
    if texCommand == 'latex' and useLatexMk:
        texCommand = 'latexmk'

    if texCommand == 'latex' and tmPrefs['latexEngine'] == 'builtin':
        texCommand = 'builtin'

    fileName, filePath = findFileToTypeset(tsDirs)
    fileNoSuffix = getFileNameWithoutExtension(fileName)

    ltxPackages = findTexPackages(fileName)

    viewer = tmPrefs['latexViewer']
    engine = constructEngineCommand(tsDirs, tmPrefs, ltxPackages)

    syncTexCheck = os.system("{} --help |grep -q synctex".format(engine))
    if syncTexCheck == 0:
        synctex = True

    if os.getenv('TEXINPUTS'):
        texinputs = os.getenv('TEXINPUTS') + ':'
    else:
        texinputs = ".::"
    texinputs += "%s/tex//" % os.getenv('TM_BUNDLE_SUPPORT')
    os.putenv('TEXINPUTS', texinputs)

    if DEBUG:
        print '<pre>'
        print 'texMateVersion = ', texMateVersion
        print 'engine = ', engine
        print 'texCommand = ', texCommand
        print 'viewer = ', viewer
        print 'texinputs = ', texinputs
        print 'fileName = ', fileName
        print 'useLatexMk = ', useLatexMk
        print 'synctex = ', synctex
        print '</pre>'

    if texCommand == "version":
        runObj = Popen("{} --version".format(engine), stdout=PIPE, shell=True)
        print runObj.stdout.read().split("\n")[0]
        sys.exit(0)

#
# print out header information to begin the run
#
    if not firstRun:
        print '<hr>'
    #print '<h2>Running %s on %s</h2>' % (texCommand,fileName)
    print '<div id="commandOutput"><div id="preText">'

    if fileName == fileNoSuffix:
        print("<h2 class='warning'>Warning:  Latex file has no extension. " +
              "See log for errors/warnings</h2>")

    if synctex and 'pdfsync' in ltxPackages:
        print("<p class='warning'>Warning:  %s supports synctex " % engine +
              "but you have included pdfsync. You can safely remove " +
              "\usepackage{pdfsync}</p>")

#
# Run the command passed on the command line or modified by preferences
#
    if texCommand == 'latexmk':
        writeLatexmkRc(engine, constructEngineOptions(tsDirs, tmPrefs))
        if engine == 'latex':
            texCommand = 'latexmk -pdfps -f -r /tmp/latexmkrc '
        else:
            texCommand = 'latexmk -pdf -f -r /tmp/latexmkrc '
        texCommand = "{} '{}'".format(texCommand, fileName)
        if DEBUG:
            print("latexmk command = {}".format(texCommand))
        runObj = Popen(texCommand, shell=True, stdout=PIPE, stdin=PIPE,
                       stderr=STDOUT, close_fds=True)
        commandParser = ParseLatexMk(runObj.stdout, verbose, fileName)
        isFatal, numErrs, numWarns = commandParser.parseStream()
        texStatus = runObj.wait()
        os.remove("/tmp/latexmkrc")
        if tmPrefs['latexAutoView'] and numErrs < 1:
            stat = run_viewer(viewer, fileName, filePath,
                              tmPrefs['latexKeepLogWin'],
                              'pdfsync' in ltxPackages or synctex)
        numRuns = commandParser.numRuns

    elif texCommand == 'bibtex':
        if os.path.exists(fileNoSuffix+'.bcf'):
            texStatus, isFatal, numErrs, numWarns = run_biber(texfile=fileName)
        else:
            texStatus, isFatal, numErrs, numWarns = run_bibtex(
                texfile=fileName)

    elif texCommand == 'index':
        if os.path.exists(fileNoSuffix+'.glsdefs'):
            texStatus, isFatal, numErrs, numWarns = run_makeglossaries()
        else:
            texStatus, isFatal, numErrs, numWarns = run_makeindex(fileName)

    elif texCommand == 'clean':
        auxiliary_file_extension = ['aux', 'bbl', 'bcf', 'blg', 'fdb_latexmk',
                                    'fls', 'fmt', 'ini', 'log', 'out', 'maf',
                                    'mtc', 'mtc1', 'pdfsync', 'run.xml',
                                    'synctex.gz', 'toc']
        texCommand = 'rm ' + ' '.join(
            ['*.' + extension for extension in auxiliary_file_extension])
        runObj = Popen(texCommand, shell=True, stdout=PIPE, stdin=PIPE,
                       stderr=STDOUT, close_fds=True)
        commandParser = ParseLatexMk(runObj.stdout, True, fileName)

    elif texCommand == 'builtin':
        # the latex, bibtex, index, latex, latex sequence should cover 80% of
        # the cases that latexmk does
        texCommand = engine + " " + constructEngineOptions(tsDirs, tmPrefs)
        texStatus, isFatal, numErrs, numWarns = run_latex(
            texCommand, fileName, verbose)
        if os.path.exists(fileNoSuffix + '.bcf'):
            texStatus, isFatal, numErrs, numWarns = run_biber(texfile=fileName)
        else:
            texStatus, isFatal, numErrs, numWarns = run_bibtex(
                texfile=fileName)
        if os.path.exists(fileNoSuffix + '.idx'):
            texStatus, isFatal, numErrs, numWarns = run_makeindex(fileName)
        texStatus, isFatal, numErrs, numWarns = run_latex(texCommand,
                                                          fileName, verbose)
        texStatus, isFatal, numErrs, numWarns = run_latex(texCommand,
                                                          fileName, verbose)

    elif texCommand == 'latex':
        texCommand = engine + " " + constructEngineOptions(tsDirs, tmPrefs)
        texStatus, isFatal, numErrs, numWarns = run_latex(
            texCommand, fileName, verbose)
        if engine == 'latex':
            psFile = fileNoSuffix+'.ps'
            os.system("dvips {}.dvi -o '{}'".format(fileNoSuffix, psFile))
            os.system("ps2pdf {}".format(psFile))
        if tmPrefs['latexAutoView'] and numErrs < 1:
            stat = run_viewer(viewer, fileName, filePath,
                              tmPrefs['latexKeepLogWin'],
                              'pdfsync' in ltxPackages or synctex)

    elif texCommand == 'view':
        stat = run_viewer(viewer, fileName, filePath,
                          tmPrefs['latexKeepLogWin'],
                          'pdfsync' in ltxPackages or synctex)

    elif texCommand == 'sync':
        if 'pdfsync' in ltxPackages or synctex:
            stat = sync_viewer(viewer, fileName, filePath)
        else:
            print "pdfsync.sty must be included to use this command"
            print "or use a typesetter that supports synctex (such as TexLive)"
            sys.exit(206)

    elif texCommand == 'chktex':
        texCommand = "{} '{}'".format(texCommand, fileName)
        runObj = Popen(texCommand, shell=True, stdout=PIPE, stdin=PIPE,
                       stderr=STDOUT, close_fds=True)
        commandParser = ChkTeXParser(runObj.stdout, verbose, fileName)
        isFatal, numErrs, numWarns = commandParser.parseStream()
        texStatus = runObj.wait()

#
# Check status of running the viewer
#
    if stat != 0:
        print('<p class="error"><strong>error number %d ' % stat +
              ' opening viewer</strong></p>')

#
# Check the status of any runs...
#
    eCode = 0
    if texStatus != 0 or numWarns > 0 or numErrs > 0:
        print("<p class='info'>Found " + str(numErrs) + " errors, and " +
              str(numWarns) + " warnings in " + str(numRuns) + " runs</p>")
        if texStatus:
            if texStatus > 0:
                print("<p class='info'>%s exited with status " % texCommand +
                      "%d</p>" % texStatus)
            else:
                print("<p class='error'>%s exited with error " % texCommand +
                      "code %d</p> " % texStatus)
#
# Decide what to do with the Latex & View log window
#
    if not tmPrefs['latexKeepLogWin']:
        if numErrs == 0 and viewer != 'TextMate':
            eCode = 200
        else:
            eCode = 0
    else:
        eCode = 0

    print '</div></div>'  # closes <pre> and <div id="commandOutput">

#
# Output buttons at the bottom of the window
#
    if firstRun:
        # only need to include the javascript library once
        js = os.getenv('TM_BUNDLE_SUPPORT') + '/bin/texlib.js'
        js = quote(js)
        print('\n<script src="file://%s" type="text/javascript"' % js +
              'charset="utf-8"></script>')
        print('<div id="texActions">')
        print('<input type="button" value="Re-Run %s" ' % engine +
              'onclick="runLatex(); return false" />')
        print('<input type="button" value="Run Bib" onclick="runBibtex(); ' +
              'return false" />')
        if os.path.exists(fileNoSuffix+'.glsdefs'):
            print('<input type="button" value="Make Glossaries" ' +
                  'onclick="runMakeIndex(); return false" />')
        else:
            print('<input type="button" value="Run Makeindex" ' +
                  'onclick="runMakeIndex(); return false" />')
        print('<input type="button" value="Clean up" onclick="runClean(); ' +
              'return false" />')
        if viewer == 'TextMate':
            pdfFile = fileNoSuffix+'.pdf'
            print('<input type="button" value="view in TextMate" ' +
                  'onclick="window.location=\'file://' +
                  quote(filePath + '/' + pdfFile) + '\'"/>')
        else:
            print('<input type="button" value="View in %s" ' % viewer +
                  'onclick="runView(); return false" />')
        print('<input type="button" value="Preferences…" ' +
              'onclick="runConfig(); return false" />')
        print('<p>')
        print('<input type="checkbox" id="hv_warn" name="fmtWarnings" ' +
              'onclick="makeFmtWarnVisible(); return false" />')
        print('<label for="hv_warn">Show hbox,vbox Warnings </label>')
        if useLatexMk:
            print('<input type="checkbox" id="ltxmk_warn" ' +
                  'name="ltxmkWarnings" onclick="makeLatexmkVisible(); ' +
                  'return false" />')
            print('<label for="ltxmk_warn">Show Latexmk Messages </label>')
        print('</p>')
        print('</div>')

    sys.exit(eCode)
