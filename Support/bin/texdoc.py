#!/usr/bin/env python
# -*- coding: utf-8 -*-

# -----------------------------------------------------------------------------
# Date:    2015-01-20
# Authors: Brad Miller
#          René Schwaiger (sanssecours@f-m.fm)
# Version: 2
# -----------------------------------------------------------------------------

"""Display documentation for tex packages.

This script is a hacked together set of heuristics to try and bring some
order out of the various bits and pieces of documentation that are strewn
around any given LaTeX distro.

``texdoctk`` provides a nice list of packages, along with paths to the
documents that are relative to one or more roots. The root for these documents
varies. the catalogue/entries directory contains a set of html files for
packages from CPAN. Sometimes the links to the real documentation are inside
these html files and are correct and sometimes they are not. So this script
attempts to use find the right path to as many bits of documentation that
really exist on your system and make it easy for you to get to them.

The packages are displayed in two groups:

- The first group is the set of packages that you use in your document.
- The second group is the set of packages as organized in the texdoctk.dat
  file (if you have one)

Finally, if you call the command when your cursor is on a word in TextMate
this script will attempt to find the best match for that word as a package and
open the documentation for that package immediately.

Because good dvi viewers are quite rare on OS X, I also provide a simple
``viewDoc.sh script``. ``viewDoc.sh`` converts a dvi file (using ``dvipdfm``)
and opens it in Previewer.

"""


# -- Imports ------------------------------------------------------------------

from __future__ import absolute_import
from __future__ import print_function
from __future__ import unicode_literals

from os import sys, path
sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))

import os
import pickle
import time

from glob import glob
from os import getenv
from os.path import basename, exists, splitext
from pipes import quote as shellquote
from subprocess import check_output
try:
    from urllib.parse import quote  # Python 3
except ImportError:
    from urllib import quote  # Python 2

from lib.tex import (find_tex_packages, find_tex_directives,
                     find_file_to_typeset)


# -- Functions ----------------------------------------------------------------

def find_best_documentation(directory):
    """Find the “best” tex documentation in a given directory.

    Given a directory that should contain documentation find the “best” format
    of the documentation available.

    Arguments:

        directory

            The directory where the documentation is located

    Returns: ``str``

    Examples:

        >>> texmf_directory = check_output(
        ...     "kpsewhich --expand-path '$TEXMFMAIN'",
        ...     shell=True, universal_newlines=True).strip()
        >>> print(find_best_documentation("{}/doc/latex/lastpage/".format(
        ...                               texmf_directory)))
        /usr/local/texlive/2014/texmf-dist/doc/latex/lastpage/lastpage.pdf

    """
    filename_endings = ['.pdf', '.dvi', '.txt', '.tex', '.sty', 'README']
    for ending in filename_endings:
        doc_files = glob('{}*{}'.format(directory, ending))
        if doc_files:
            return doc_files[-1]
    return ''


def get_documentation_files():
    """Get a dictionary containing tex documentation files.

    This function searches all directories under the ``texmf`` root for dvi or
    pdf files that might be documentation. It returns a dictionary containing
    file-paths. The dictionary uses the filenames without their extensions as
    keys.

    Returns: ``{str: str}``

    Examples:

        >>> documentation_files = get_documentation_files()
        >>> print(documentation_files['lastpage']) # doctest:+ELLIPSIS
        /.../lastpage.pdf

    """
    texmf_directory = check_output("kpsewhich --expand-path '$TEXMFMAIN'",
                                   shell=True, universal_newlines=True).strip()
    doc_files = check_output("find -E {} -regex '.*\.(pdf|dvi)' -type f".
                             format(shellquote(texmf_directory)),
                             shell=True, universal_newlines=True).splitlines()
    return {basename(splitext(line)[0]): line.strip() for line in doc_files}


# -- Main ---------------------------------------------------------------------

if __name__ == '__main__':

    pathDict = {}
    descDict = {}
    headings = {}

    # Part 1
    # Find all the packages included in this file or its inputs
    tsDirs = find_tex_directives(os.environ["TM_FILEPATH"])
    fileName, filePath = find_file_to_typeset(tsDirs)
    mList = find_tex_packages(fileName)

    home = os.environ["HOME"]
    docdbpath = home + "/Library/Caches/TextMate"
    docdbfile = docdbpath + "/latexdocindex"
    ninty_days_ago = time.time() - (90 * 86400)
    cachedIndex = False

    if (exists(docdbfile) and os.path.getmtime(docdbfile) > ninty_days_ago):
        infile = open(docdbfile, 'rb')
        path_desc_list = pickle.load(infile)
        pathDict = path_desc_list[0]
        descDict = path_desc_list[1]
        headings = path_desc_list[2]
        cachedIndex = True
    else:
        # Part 2
        # Parse the texdoctk database of packages
        texMFbase = os.environ["TM_LATEX_DOCBASE"]
        docIndex = os.environ["TEXDOCTKDB"]

        docBase = texMFbase + "/"  # + "doc/"
        if docBase[-5:].rfind('doc') < 0:
            docBase = docBase + "doc/"

        catalogDir = os.environ["TM_LATEX_HELP_CATALOG"]

        texdocs = os.environ["TMTEXDOCDIRS"].split(':')
        myDict = {}
        for p in texdocs:
            key = p[p.rfind('/')+1:]
            myDict[key] = p

        docDict = get_documentation_files()

        try:
            docIndexFile = open(docIndex, 'r')
        except:
            docIndexFile = []
        for line in docIndexFile:
            if line[0] == "#":
                continue
            elif line[0] == "@":
                currentHeading = line[1:].strip()
                headings[currentHeading] = []
            else:
                try:
                    lineFields = line.split(';')
                    key = lineFields[0]
                    desc = lineFields[1]
                    path = lineFields[2]
                except:
                    print("Error parsing line: {}".format(line))

                headings[currentHeading].append(key)
                if path.rfind('.sty') >= 0:
                    path = docBase + "tex/" + path
                else:
                    path = docBase + path
                    if not os.path.exists(path):
                        # sometimes texdoctk.dat is misleading...
                        altkey = path[path.rfind("/")+1:path.rfind(".")]
                        if key in docDict:
                            path = docDict[key]
                        elif altkey in docDict:
                            path = docDict[altkey]
                        else:
                            if key in myDict:
                                path = find_best_documentation(myDict[key])

                pathDict[key] = path.strip()
                descDict[key] = desc.strip()

        # Part 3
        # supplement texdoctk index with the regular texdoc catalog
        try:
            catList = os.listdir(catalogDir)
        except:
            catList = []
        for fname in catList:
            key = fname[:fname.rfind('.html')]
            if key not in pathDict:
                pathDict[key] = catalogDir + '/' + fname
                descDict[key] = key
                if key in docDict:
                    pathDict[key] = docDict[key]

        # Continue to supplement with searched for files
        for p in docDict.keys()+myDict.keys():
            if p not in pathDict:
                if p in docDict:
                    pathDict[p] = docDict[p].strip()
                    descDict[p] = p
                else:
                    if p in myDict:
                        path = find_best_documentation(myDict[p])
                        pathDict[p] = path.strip()
                        descDict[p] = p

        try:
            if not os.path.exists(docdbpath):
                os.mkdir(docdbpath)
            outfile = open(docdbfile, 'wb')
            pickle.dump([pathDict, descDict, headings], outfile)
        except:
            print("<p>Error: Could not cache documentation index</p>")

    # Part 4
    # if a word was selected then view the documentation for that word
    # using the best available version of the doc as determined above
    cwPackage = os.environ.get("TM_CURRENT_WORD", None)
    if cwPackage in pathDict:
        os.system("viewDoc.sh " + pathDict[cwPackage])
        sys.exit()

    # Part 5
    # Print out the results in html/javascript
    # The java script gives us the nifty expand collapse outline look
    tm_bundle_support = getenv('TM_BUNDLE_SUPPORT')
    css_location = quote('{}/css/texdoc.css'.format(tm_bundle_support))
    js_location = quote('{}/lib/texdoc.js'.format(tm_bundle_support))
    print("""<link rel="stylesheet" href="file://{}">
             <script type="text/javascript" src="file://{}"
                 charset="utf-8">
             </script>""".format(css_location, js_location))
    print("<h1>Your Packages</h1>")
    print("<ul>")
    for p in mList:
        print('<div id="mypkg">')
        if p in pathDict:
            print("""<li><a href= "javascript:
                     TextMate.system('\\'%s/bin/viewDoc.sh\\' %s', null);">
                     %s</a></li>
                  """ % (os.environ["TM_BUNDLE_SUPPORT"], pathDict[p],
                         descDict[p]))
        else:
            print("""<li>%s</li>""" % (p))
        print('</div>')
    print("</ul>")

    print("<hr />")
    print("<h1>Packages Browser</h1>")
    print("<ul>")
    for h in headings:
        print('<li><a href="javascript:dsp(this)" class="dsphead" ' +
              'onclick="dsp(this)">{}</a></li>'.format(h))
        print('<div class="dspcont">')
        print("<ul>")
        for p in headings[h]:
            if os.path.exists(pathDict[p]):
                print("""<li><a href="javascript:TextMate.system(""" +
                      """'\\'{}/bin/viewDoc.sh\\' """.format(
                          os.environ["TM_BUNDLE_SUPPORT"]) +
                      """{}', null);"> {}</a></li>""".format(
                          pathDict[p], descDict[p]))
            else:
                print("""<li>%s</li>""" % (p))
        print("</ul>")
        print('</div>')
    print("</ul>")
    if cachedIndex:
        print("""<p>You are using a saved version of the LaTeX documentation
                 index. This index is automatically updated every 90 days. If
                 you want to force an update simply remove the file %s </p>
              """ % docdbfile)
