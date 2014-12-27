#!/usr/bin/env python -u
# encoding: utf-8

# -----------------------------------------------------------------------------
# Goals:
#
#   1. Modularize the processing of a latex run to better capture and parse
#      errors
#   2. Provide a nice pushbutton interface for manually running
#      latex, bibtex, makeindex, and viewing
#
# Overview:
#
#    Each tex command has its own class that parses the output from that
#    program.  Each of these classes extends the TexParser class which provides
#    default methods:
#
#       parse_stream
#       error
#       warning
#       info
#
#   The parse_stream method reads each line from the input stream matches
#   against a set of regular expressions defined in the patterns dictionary. If
#   one of these patterns matches then the corresponding method is called. This
#   method is also stored in the dictionary. Pattern matching callback methods
#   must each take the match object as well as the current line as a parameter.
#
#   Original Author: Brad Miller
#   Modified by:     René Schwaiger (sanssecours@f-m.fm)
# -----------------------------------------------------------------------------

# -- Imports ------------------------------------------------------------------

import sys

from argparse import ArgumentParser, ArgumentTypeError
from glob import glob
from os import chdir, getcwd, getenv, putenv, remove, EX_OSFILE  # noqa
from os.path import (basename, dirname, exists, getmtime, isfile, join,
                     normpath, realpath)
from pickle import load, dump
from pipes import quote as shellquote
from re import compile, match, search
from subprocess import call, check_output, Popen, PIPE, STDOUT
from sys import exit, stdout
from textwrap import dedent
from urllib import quote

from texparser import (update_marks, BibTexParser, BiberParser, ChkTexParser,
                       LaTexParser, MakeGlossariesParser, MakeIndexParser,
                       LaTexMkParser)
from tmprefs import Preferences

# -- Module Import ------------------------------------------------------------

reload(sys)
sys.setdefaultencoding("utf-8")


# -- Exit Codes ---------------------------------------------------------------

EXIT_LOOP_IN_TEX_ROOT = -1
EXIT_SUCCESS = 0
EXIT_TEX_ENGINE_NOT_FOUND = 1
EXIT_FILE_ERROR = EX_OSFILE
EXIT_DISCARD = 200
EXIT_SHOW_TOOL_TIP = 206


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

        >>> expand_name('Tests/TeX/text.tex')
        './Tests/TeX/text.tex'
        >>> expand_name('non_existent_file.tex')
        ''

    """
    stdout.flush()
    run_object = Popen("kpsewhich -progname='{}' {}".format(
        program, shellquote(filename)), shell=True, stdout=PIPE)
    return run_object.stdout.read().strip()


def run_bibtex(filename, verbose=False):
    """Run bibtex for a certain file.

    Run bibtex for ``filename`` and return the following values:

    - The return value of the bibtex runs done by this function: This value
      will be ``0`` after a successful run. Any other value indicates that
      there were some kind of problems.

    - Fatal error: Specifies if there was a fatal error while processing the
      bibliography.

    - Errors: The number of non-fatal errors encountered while processing the
      bibliography

    - Warnings: The number of warnings found while running this function

    Arguments:

        filename

            Specifies the name of the tex file without its extension. This
            information will be used to find the bibliography.

        verbose

            Specifies if the output by this function should be verbose.


    Returns: ``(int, bool, int, int)``

    Examples:

        >>> chdir('Tests/TeX')
        >>> run_bibtex('external_bibliography') # doctest:+ELLIPSIS
        <h4>Processing: ...
        ...
        (0, False, 0, 0)
        >>> chdir('../..')

    """
    directory = dirname(filename) if dirname(filename) else '.'
    regex_auxfiles = (r'.*/({}|bu\d+)\.aux$'.format(filename))
    auxfiles = [f for f in glob("{}/*.aux".format(directory))
                if match(regex_auxfiles, f)]

    stat, fatal, errors, warnings = 0, False, 0, 0
    for bib in auxfiles:
        print('<h4>Processing: {} </h4>'.format(bib))
        run_object = Popen("bibtex {}".format(shellquote(bib)), shell=True,
                           stdout=PIPE, stdin=PIPE, stderr=STDOUT,
                           close_fds=True)
        bp = BibTexParser(run_object.stdout, verbose)
        f, e, w = bp.parse_stream()
        fatal |= f
        errors += e
        warnings += w
        stat |= run_object.wait()
    return stat, fatal, errors, warnings


def run_biber(filename, verbose=False):
    """Run biber for a certain file.

    The interface for this function is exactly the same as the one for
    ``run_bibtex``. For the list of arguments and return values please take a
    look at the doc string of ``run_bibtex``.

    Examples:

        >>> chdir('Tests/TeX')
        >>> run_biber('external_bibliography_biber') # doctest:+ELLIPSIS
        <...
        ...
        (0, False, 0, 0)
        >>> chdir('../..')

    """
    run_object = Popen("biber {}".format(shellquote(filename)), shell=True,
                       stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    bp = BiberParser(run_object.stdout, verbose)
    fatal, errors, warnings = bp.parse_stream()
    stat = run_object.wait()
    return stat, fatal, errors, warnings


def run_latex(ltxcmd, texfile, cache_filename, verbose=False):
    """Run the flavor of latex specified by ltxcmd on texfile.

    This function returns:

        - the return value of ``ltxcmd``,

        - a value specifying if there were any fatal flaws (``True``) or not
          (``False``), and

        - the number of errors and

        - the number of warnings encountered while processing ``texfile``.

    Arguments:

        cache_filename

            The path to the cache file for the current tex project. This file
            is used to store information about gutter marks between runs of
            ``texmate``.

        ltxcmd

            The latex command which should be used translate ``texfile``.

        texfile

            The path of the tex file which should be translated by ``ltxcmd``.

    Returns: ``(int, bool, int, int)``

    Examples:

        >>> chdir('Tests/TeX')
        >>> run_latex(ltxcmd='pdflatex',
        ...           cache_filename='.external_bibliography.lb',
        ...           texfile='external_bibliography.tex') # doctest:+ELLIPSIS
        <h4>...
        ...
        (0, False, 0, 0)
        >>> chdir('../..')

    """
    run_object = Popen("{} {}".format(ltxcmd, shellquote(texfile)),
                       shell=True, stdout=PIPE, stdin=PIPE, stderr=STDOUT,
                       close_fds=True)
    lp = LaTexParser(run_object.stdout, verbose, texfile)
    fatal, errors, warnings = lp.parse_stream()
    stat = run_object.wait()
    update_marks(cache_filename, lp.marks)
    return stat, fatal, errors, warnings


def run_makeindex(filename, verbose=False):
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

        >>> chdir('Tests/TeX')
        >>> run_makeindex('makeindex.tex') # doctest:+ELLIPSIS
        <p class="info">Run...Makeindex...
        (0, False, 0, 0)
        >>> chdir('../..')

    """
    run_object = Popen("makeindex {}".format(shellquote("{}.idx".format(
        get_filename_without_extension(filename)))), shell=True,
        stdout=PIPE, stdin=PIPE, stderr=STDOUT, close_fds=True)
    ip = MakeIndexParser(run_object.stdout, verbose)
    fatal, errors, warnings = ip.parse_stream()
    stat = run_object.wait()
    return stat, fatal, errors, warnings


def run_makeglossaries(filename, verbose=False):
    """Run makeglossaries for the given file.

    The interface of this function is exactly the same as the one for
    ``run_makeindex``. For the list of arguments and return values, please
    take a look at ``run_makeindex``.

    Arguments:

        filename

            The name of the tex file for which we want to generate an index.

        verbose

            This value specifies if all output should be printed
            (``verbose=True``) or if only significant messages should be
            printed.

    Examples:

        >>> chdir('Tests/TeX')
        >>> run_makeglossaries('makeglossaries.tex') # doctest:+ELLIPSIS
        <h2>Make Glossaries...
        ...
        (0, False, 0, 0)
        >>> chdir('../..')

    """
    run_object = Popen("makeglossaries {}".format(
                       shellquote(get_filename_without_extension(filename))),
                       shell=True, stdout=PIPE, stdin=PIPE, stderr=STDOUT,
                       close_fds=True)
    bp = MakeGlossariesParser(run_object.stdout, verbose)
    fatal, errors, warnings = bp.parse_stream()
    stat = run_object.wait()
    return stat, fatal, errors, warnings


def get_app_path(application, tm_support_path=getenv("TM_SUPPORT_PATH")):
    """Get the absolute path of the specified application.

    This function returns either the path to ``application`` or ``None`` if
    the specified application was not found.

    Arguments:

        application

            The application for which this function should return the path

        tm_support_path

            The path to the “Bundle Support” bundle

    Returns: ``str``

        # We assume that Skim is installed in the ``/Applications`` folder
        >>> get_app_path('Skim')
        '/Applications/Skim.app'
        >>> get_app_path('NonExistentApp') # Returns ``None``

    """
    try:
        return check_output("'{}/bin/find_app' '{}.app'".format(
                            tm_support_path, application),
                            shell=True, universal_newlines=True).strip()
    except:
        return None


def get_app_path_and_sync_command(viewer, path_pdf, path_tex_file,
                                  line_number):
    """Get the path and pdfsync command for the specified viewer.

    This function returns a tuple containing

        - the full path to the application, and

        - a command which can be used to show the PDF output corresponding to
          ``line_number`` inside tex file.

    If one of these two variables could not be determined, then the
    corresponding value will be set to ``None``.

    Arguments:

        viewer:

            The name of the PDF viewer application.

        path_pdf:

            The path to the generated PDF file.

        path_tex_file

            The path to the tex file for which we want to generate the pdfsync
            command.

        line_number

            The line in the tex file for which we want to get the
            synchronization command.

    Examples:

        # We assume that Skim is installed
        >>> get_app_path_and_sync_command('Skim', 'test.pdf', 'test.tex', 1)
        ...     # doctest:+ELLIPSIS +NORMALIZE_WHITESPACE
        ('.../Skim.app',
         "'.../Skim.app/.../displayline' 1 test.pdf test.tex")

        # Preview has no pdfsync support
        >>> get_app_path_and_sync_command('Preview', 'test.pdf', 'test.tex', 1)
        ('/Applications/Preview.app', None)

    """
    sync_command = None
    path_to_viewer = get_app_path(viewer)
    if path_to_viewer and viewer == 'Skim':
        sync_command = ("'{}/Contents/SharedSupport/displayline' ".format(
                        path_to_viewer) + "{} {} {}".format(line_number,
                        shellquote(path_pdf), shellquote(path_tex_file)))
    return path_to_viewer, sync_command


def refresh_viewer(viewer, pdf_path,
                   tm_bundle_support=getenv('TM_BUNDLE_SUPPORT')):
    """Tell the specified PDF viewer to refresh the PDF output.

    If the viewer does not support refreshing PDFs (e.g. “Preview”) then this
    command will do nothing. This command will return a non-zero value if the
    the viewer could not be found or the PDF viewer does not support a “manual”
    refresh.

    Arguments:

        viewer

            The viewer for which we want to refresh the output of the PDF file
            specified in ``pdf_path``.

        pdf_path

            The path to the PDF file for which we want to refresh the output.

        tm_bundle_support

            The location of the “LaTeX Bundle” support folder

    Returns: ``int``

    Examples:

        >>> refresh_viewer('Skim', 'test.pdf',
        ...                tm_bundle_support=realpath('Support'))
        <p class="info">Tell Skim to refresh 'test.pdf'</p>
        0

    """
    print('<p class="info">Tell {} to refresh \'{}\'</p>').format(viewer,
                                                                  pdf_path)

    if viewer in ['Skim', 'TeXShop']:
        return call("'{}/bin/refresh_viewer.scpt' {} {} ".format(
                    tm_bundle_support, viewer, shellquote(pdf_path)),
                    shell=True)
    return 1


def run_viewer(viewer, texfile_path, pdffile_path,
               suppress_pdf_output_textmate,
               use_pdfsync, line_number,
               tm_bundle_support=getenv('TM_BUNDLE_SUPPORT')):
    """Open the PDF viewer containing the PDF generated from ``file_name``.

    If ``use_pdfsync`` is set to ``True`` and the ``viewer`` supports pdfsync
    then the part of the PDF corresponding to ``line_number`` will be opened.
    The function returns the exit value of the shell command used to display
    the PDF file.

    Arguments:

        viewer

            Specifies which PDF viewer should be used to display the PDF

        tex_file_path

            The location of the tex file.

        suppress_pdf_output_textmate

            This variable is only used when ``viewer`` is set to ``TextMate``.
            If it is set to ``True`` then TextMate will not try to display the
            generated PDF.

        tm_bundle_support

            The location of the “LaTeX Bundle” support folder

    Returns: ``int``

    Examples:

        >>> chdir('Tests/TeX')
        >>> call("pdflatex makeindex.tex > /dev/null", shell=True)
        0
        >>> run_viewer('Skim', './makeindex.tex', './makeindex.pdf',
        ...            suppress_pdf_output_textmate=None, use_pdfsync=True,
        ...            line_number=10,
        ...            tm_bundle_support=realpath('../../Support'))
        0
        >>> chdir('../..')

    """
    status = 0

    if viewer == 'TextMate':
        if not suppress_pdf_output_textmate:
            if isfile(pdffile_path):
                print('''<script type="text/javascript">
                         window.location="file://{}"
                         </script>'''.format(quote(pdffile_path)))
            else:
                print("File does not exist: {}".format(pdffile_path))
    else:
        path_to_viewer, sync_command = get_app_path_and_sync_command(
            viewer, pdffile_path, texfile_path, line_number)
        # PDF viewer is installed
        if path_to_viewer:
            # If this is not done, the next line will thrown an encoding
            # exception when the PDF file contains non-ASCII characters.
            viewer = viewer.encode('utf-8')
            pdf_already_open = not(bool(
                call("'{}/bin/check_open' '{}' {} > /dev/null".format(
                     tm_bundle_support, viewer, shellquote(pdffile_path)),
                     shell=True)))
            if pdf_already_open:
                refresh_viewer(viewer, pdffile_path)
            else:
                status = call("open -a '{}.app' {}".format(viewer,
                              shellquote(pdffile_path)), shell=True)
            # PDF viewer supports pdfsync
            if sync_command and use_pdfsync:
                call(sync_command, shell=True)
            elif not sync_command and use_pdfsync:
                print("{} does not supported pdfsync".format(viewer))

        # PDF viewer could not be found
        else:
            print('<strong class="error"> {} does not appear '.format(viewer) +
                  'to be installed on your system.</strong>')
    return status


def determine_typesetting_directory(ts_directives,
                                    master_document=getenv('TM_LATEX_MASTER'),
                                    tex_file=getenv('TM_FILEPATH')):
    """Determine the proper directory for typesetting the current document.

    The typesetting directory is set according to the first applicable setting
    in the following list:

        1. The typesetting directive specified via the line

                ``%!TEX root = path_to_tex_file``

            somewhere in your tex file

        2. the value of ``TM_LATEX_MASTER``, or
        3. the location of the current tex file.

    Arguments:

        ts_directives

            A dictionary containing typesetting directives. If it contains the
            key ``root`` then the path in the value of ``root`` will be used
            as typesetting directory.

        master_document

            Specifies the location of the master document
            (``TM_LATEX_MASTER``).

        tex_file

            The location of the current tex file

    Returns: ``str``

    Examples:

        >>> ts_directives = {'root' : 'Tests/makeindex.tex'}
        >>> determine_typesetting_directory(ts_directives) # doctest:+ELLIPSIS
        '.../Tests'
        >>> determine_typesetting_directory( # doctest:+ELLIPSIS
        ...     {}, master_document='Tests/external_bibliography')
        '.../Tests'

    """
    tex_file_dir = dirname(tex_file)

    if 'root' in ts_directives:
        master_path = dirname(ts_directives['root'])
    elif master_document:
        master_path = dirname(master_document)
    else:
        master_path = tex_file_dir

    if master_path == '' or not master_path.startswith('/'):
        master_path = normpath(realpath(join(tex_file_dir, master_path)))

    return master_path


def find_file_to_typeset(tyesetting_directives,
                         master_document=getenv('TM_LATEX_MASTER'),
                         tex_file=getenv('TM_FILEPATH')):
    """Determine which tex file to typeset.

    This is determined according to the following options:

       - %!TEX root directive
       - The ``TM_LATEX_MASTER`` environment variable
       - The environment variable ``TM_FILEPATH``

       This function returns a tuple containing the name and the path to the
       file which should be typeset.

    Arguments:

        ts_directives

            A dictionary containing typesetting directives. If it contains the
            key ``root`` then the value of ``root`` will be used for
            determining the file which should be typeset.

        master_document

            Specifies the location of the master document
            (``TM_LATEX_MASTER``).

        tex_file

            The location of the current tex file

    Returns: (``str``, ``str``)

    Examples:

        >>> find_file_to_typeset({'root': 'Tests/makeindex.tex'})
        ...     # doctest:+ELLIPSIS
        ('makeindex.tex', '.../Tests')
        >>> find_file_to_typeset({},
        ...     master_document='../packages.tex',
        ...     tex_file='Tests/input/packages_input1.tex') # doctest:+ELLIPSIS
        ('packages.tex', '.../Tests')
        >>> find_file_to_typeset({'root': '../packages.tex'}, None,
        ...     tex_file='Tests/input/packages_input1.tex') # doctest:+ELLIPSIS
        ('packages.tex', '.../Tests')
        >>> find_file_to_typeset({}, None, 'Tests/packages.tex')
        ...     # doctest:+ELLIPSIS
        ('packages.tex', '.../Tests')

    """
    if 'root' in tyesetting_directives:
        master = tyesetting_directives['root']
    elif master_document:
        master = master_document
    else:
        master = tex_file

    return (basename(master),
            determine_typesetting_directory(tyesetting_directives,
                                            master_document, tex_file))


def find_tex_packages(file_name):
    """Find packages included by the given file.

    This function searches for packages in:

        1. The preamble of ``file_name``, and
        2. files included in the preamble of ``file_name``.

    Arguments:

        file_name

            The path of the file which should be searched for packages.

    Returns: ``{str}``

    Examples:

        >>> chdir('Tests/TeX')
        >>> packages = find_tex_packages('packages.tex')
        >>> isinstance(packages, set)
        True
        >>> sorted(packages) # doctest:+NORMALIZE_WHITESPACE
        ['csquotes', 'framed', 'mathtools', 'polyglossia', 'unicode-math',
         'xcolor']
        >>> chdir('../..')

    """
    try:
        file = open(expand_name(file_name))
    except:
        print('<p class="error">Error: Could not open ' +
              '{} to check for packages</p>'.format(file_name))
        print('<p class="error">This is most likely a problem with ' +
              'TM_LATEX_MASTER</p>')
        exit(EXIT_FILE_ERROR)
    option_regex = r'\[[^\{]+\]'
    argument_regex = r'\{([^\}]+)\}'
    input_regex = compile(r'[^%]*?\\input{}'.format(argument_regex))
    package_regex = compile(r'[^%]*?\\usepackage(?:{})?{}'.format(
                            option_regex, argument_regex))
    begin_regex = compile(r'[^%]*?\\begin\{document\}')

    # Search for packages and included files in the tex document
    included_files = []
    packages = []
    for line in file:
        match_input = match(input_regex, line)
        match_package = match(package_regex, line)
        if match_input:
            included_files.append(match_input.group(1))
        if match_package:
            packages.append(match_package.group(1))
        if match(begin_regex, line):
            break

    # Search for packages in all files till we find the beginning of the
    # document and therefore the end of the preamble
    included_files = [included_file if included_file.endswith('.tex')
                      else '{}.tex'.format(included_file)
                      for included_file in included_files]
    match_begin = False
    while included_files and not match_begin:
        try:
            file = open(expand_name(included_files.pop()))
        except:
            print('<p class="warning">Warning: Could not open ' +
                  '{} to check for packages</p>'.format(included_file))

        for line in file:
            match_package = match(package_regex, line)
            match_begin = match(begin_regex, line)
            if match_package:
                packages.append(match_package.group(1))
            if match_begin:
                break

    # Split package definitions of the form 'package1, package2' into
    # 'package1', 'package2'
    package_list = []
    for package in packages:
        package_list.extend([package.strip()
                             for package in package.split(',')])

    return set(package_list)


def find_tex_directives(texfile):
    """Build a dictionary of %!TEX directives.

    The main ones we are concerned with are:

       root

           Specifies a root file to run tex on for this subsidiary

       TS-program

            Tells us which latex program to run

       TS-options

           Options to pass to TS-program

       encoding

            The text encoding of the tex file

    Arguments:

        texfile

            The initial tex file which should be searched for tex directives.
            If this file contains a “root” directive, then the file specified
            in this directive will be searched next.

    Returns: ``{str: str}``

    Examples:

        >>> chdir('Tests/TeX')
        >>> find_tex_directives('input/packages_input1.tex')
        ...     # doctest:+ELLIPSIS
        {'root': .../Tests/TeX/packages.tex', 'TS-program': 'xelatex'}
        >>> find_tex_directives('makeindex.tex')
        {}
        >>> chdir('../..')

    """
    root_chain = [texfile]
    directive_regex = compile(r'%!TEX\s+([\w-]+)\s?=\s?(.*)')
    directives = {}
    while True:
        lines = [line for (line_number, line) in enumerate(open(texfile))
                 if line_number < 20]
        new_directives = {directive.group(1): directive.group(2).rstrip()
                          for directive
                          in [directive_regex.match(line) for line in lines]
                          if directive}
        directives.update(new_directives)
        if 'root' in new_directives:
            root = directives['root']
            new_tex_file = (root if root.startswith('/') else
                            realpath(join(dirname(texfile), root)))
            directives['root'] = new_tex_file
        else:
            break

        if new_tex_file in root_chain:
            print('''<p class="error"> There is a loop in your "%!TEX root ="
                                       directives.</p>
                     <p class="error"> Chain: {}</p>
                     <p class="error"> Exiting.</p>'''.format(root_chain))
            exit(EXIT_LOOP_IN_TEX_ROOT)
        else:
            texfile = new_tex_file
            root_chain.append(texfile)

    return directives


def construct_engine_options(ts_directives, tm_engine_options, synctex=True):
    """Construct a string of command line options.

    The options come from two different sources:

        - %!TEX TS-options directive in the file
        - Options specified in the preferences of the LaTeX bundle

    In any case ``nonstopmode`` is set as is ``file-line-error-style``.

    Arguments:

        ts_directives

            A dictionary containing typesetting directives. If it contains the
            key ``TS-options`` then this value will be used to construct the
            options.

        tm_engine_options

            A string containing the default typesetting options set inside
            TextMate. This string will be used to extend the options only if
            ts_directives does not contain typesetting options. Otherwise the
            settings specified in this item will be ignored.

        synctex

            Specifies if synctex should be used for typesetting or not.


    Returns: ``str``

    Examples:

        >>> construct_engine_options({}, '', True)
        ...     # doctest:+ELLIPSIS
        '-interaction=nonstopmode -file-line-error-style -synctex=1'
        >>> construct_engine_options({'TS-options': '-draftmode'},
        ...                          '', False)
        '-interaction=nonstopmode -file-line-error-style -draftmode'
        >>> construct_engine_options({'TS-options': '-draftmode'}, '-8bit',
        ...                          False)
        '-interaction=nonstopmode -file-line-error-style -draftmode'
        >>> construct_engine_options({}, '-8bit')
        '-interaction=nonstopmode -file-line-error-style -synctex=1 -8bit'

    """
    options = "-interaction=nonstopmode -file-line-error-style{}".format(
        ' -synctex=1' if synctex else '')

    if 'TS-options' in ts_directives:
        options += ' {}'.format(ts_directives['TS-options'])
    else:
        options += ' {}'.format(tm_engine_options) if tm_engine_options else ''

    return options


def construct_engine_command(ts_directives, tm_engine, packages):
    """Decide which tex engine to use according to the given arguments.

    The value of the engine is calculated according to the first applicable
    setting in the following list:

       1. The value of ``TS-program`` specified inside the tex file.

       2. The list of included packages. If one of the used packages only works
          with a special typesetting engine, then this engine will be returned.

       3. The value of the latex engine specified inside the preferences of
          the LaTeX bundle.

    Arguments:

        ts_directives

            A dictionary containing typesetting directives. If it contains the
            key ``TS-program`` then this value will be used as the typesetting
            engine.

        tm_engine

            A sting containing the default tex engine used in TextMate. The
            default engine will be used if ``TS-program`` is not set and none
            of the specified packages contain engine-specific code.

        packages

            The packages included in the tex file, which should be typeset.

    Returns: ``str``

    Examples:

        >>> construct_engine_command({'TS-program': 'pdflatex'}, 'latex',
        ...                          set())
        'pdflatex'
        >>> construct_engine_command({}, 'latex', {'fontspec'})
        'xelatex'
        >>> construct_engine_command({}, 'latex', set())
        'latex'

    """
    latex_indicators = {'pstricks', 'xyling', 'pst-asr', 'OTtablx', 'epsfig'}
    xelatex_indicators = {'xunicode', 'fontspec'}
    lualatex_indicators = {'luacode'}

    if 'TS-program' in ts_directives:
        engine = ts_directives['TS-program']
    elif packages.intersection(latex_indicators):
        engine = 'latex'
    elif packages.intersection(xelatex_indicators):
        engine = 'xelatex'
    elif packages.intersection(lualatex_indicators):
        engine = 'lualatex'
    else:
        engine = tm_engine

    if call("type {} > /dev/null".format(engine), shell=True) != 0:
        print('''<p class="error">Error: {} was not found,
                 Please make sure that LaTeX is installed and your PATH is
                 setup properly.</p>'''.format(engine))
        exit(EXIT_TEX_ENGINE_NOT_FOUND)

    return engine


def get_filename_without_extension(filename):
    """Get the given file name without its extension.

    If ``filename`` has no extensions then the unchanged file name will be
    returned.

    Arguments:

        file_name

            The path of some file, either with or without extension.

    Returns: ``str``


    Examples:

        >>> get_filename_without_extension('../hello_world.tex')
        '../hello_world'
        >>> get_filename_without_extension('Makefile')
        'Makefile'

    """
    suffix_index = filename.rfind(".")
    return filename[:suffix_index] if suffix_index > 0 else filename


def write_latexmkrc(engine, options, location='/tmp/latexmkrc'):
    """Create a “latexmkrc” file that uses the proper engine and arguments.

    Arguments:

        engine

            A string specifying the engine which should be used by ``latexmk``.

        options

            A string specifying the arguments which should be used by
            ``engine``.

        location

            The path to the location where the ``latexmkrc`` file should be
            saved.

    Examples:

        >>> write_latexmkrc(engine='latex', options='8bit')
        >>> with open('/tmp/latexmkrc') as latexmkrc_file:
        ...     print(latexmkrc_file.read())  # doctest:+ELLIPSIS
        $latex = '...8bit';
        ...

    """
    with open("/tmp/latexmkrc", 'w') as latexmkrc:
        latexmkrc.write(dedent("""\
        $latex = 'latex -interaction=nonstopmode -file-line-error-style {0}';
        $pdflatex = '{1} -interaction=nonstopmode -file-line-error-style {0}';
        """.format(options, engine)))


def get_typesetting_data(filepath, tm_engine,
                         tm_bundle_support=getenv('TM_BUNDLE_SUPPORT')):
    """Return a dictionary containing up-to-date typesetting data.

    This function changes the current directory to the location of
    ``filepath``!

    Arguments:

        filepath

            The filepath of the file we want to typeset.

        tm_engine

            A string representing the current default latex engine.

        tm_bundle_support

            The location of the “LaTeX Bundle” support folder.

    Returns: ``{str: str}``

    Examples:

        >>> current_directory = getcwd()
        >>> data = get_typesetting_data('Tests/TeX/lualatex.tex', 'pdflatex')
        >>> data['engine']
        'lualatex'
        >>> data['synctex']
        True
        >>> chdir(current_directory)

    """
    def get_cached_data():
        """Get current data and update cache."""
        cache_read = False
        typesetting_data = {}

        try:
            with open(cache_filename, 'rb') as storage:
                typesetting_data = load(storage)
                cache_read = True

            cache_data_outdated = (getmtime(file_path) <
                                   getmtime(cache_filename) >
                                   getmtime(filepath))

            # Write new cache data if the current data does not contain
            # the necessary up to date information - This might be the case if
            # only `texparser` has written to the cache file
            if not 'engine' in typesetting_data or cache_data_outdated:
                raise Exception()

        except:
            # Get data and save it in the cache
            packages = find_tex_packages(filename)
            engine = construct_engine_command(typesetting_directives,
                                              tm_engine, packages)
            synctex = not(bool(call("{} --help | grep -q synctex".format(
                                    engine), shell=True)))
            typesetting_data.update({'engine': engine,
                                     'packages': packages,
                                     'synctex': synctex})
            if not cache_read:
                typesetting_data['files_with_guttermarks'] = {filename}

        try:
            with open(cache_filename, 'wb') as storage:
                dump(typesetting_data, storage)
        except:
            print('<p class="warning"> Could not write cache file!</p>')

        return typesetting_data

    filepath = normpath(realpath(filepath))
    typesetting_directives = find_tex_directives(filepath)
    filename, file_path = find_file_to_typeset(typesetting_directives,
                                               tex_file=filepath)
    file_without_suffix = get_filename_without_extension(filename)
    chdir(file_path)
    cache_filename = '.{}.lb'.format(file_without_suffix)
    typesetting_data = get_cached_data()

    # We add the tex files in the bundle directory to the possible input
    # files. If `TEXINPUTS` was not set before then we also add the current
    # directory `.` and the central default repository `::` to the start
    # of `TEXINPUTS`
    texinputs = "{}:{}/tex//".format(
        getenv('TEXINPUTS') if getenv('TEXINPUTS') else '.::',
        tm_bundle_support)
    putenv('TEXINPUTS', texinputs)

    typesetting_data.update({'cache_filename': cache_filename,
                             'filename': filename,
                             'file_path': file_path,
                             'file_without_suffix': file_without_suffix,
                             'typesetting_directives': typesetting_directives})

    return typesetting_data


def get_command_line_arguments():
    """Specify and get command line arguments.

    This function returns a ``Namespace`` containing the arguments specified on
    the command line. The most important arguments in the ``Namespace`` are:

        addoutput

            A boolean that tells us if we should generate HTML output for an
            already existing HTML output window.

        command

            The tex command which should be run by this script.

        filename

            The path to the tex file we want to process.

    Returns: ``Namespace``

    """

    def file_exists(filename):
        if not exists(filename):
            raise ArgumentTypeError(
                "No such file or directory: {0}".format(filename))
        return filename

    parser_file = ArgumentParser(add_help=False)
    parser_file.add_argument(
        'filepath', type=file_exists, nargs='?', default=getenv('TM_FILEPATH'),
        help='Specify the file which should be processed.')
    parser_latex = ArgumentParser(add_help=False)

    parser_latex.add_argument(
        '-latexmk', default=None,
        choices={'yes', 'no', 'pvc'},
        help='''Specify if latexmk should be used to translate the document.
                The value 'pvc' specifies the 'previous continuous' mode.
                If you do not set this option, then value set inside
                TextMate will be used.''')
    parser_latex.add_argument(
        '-engine', default=None,
        choices={'latex', 'lualatex', 'pdflatex', 'xelatex', 'texexec'},
        help='''Set the default engine for tex documents. If you do not set
                this option explicitly, then the value currently set inside the
                TextMate preferences will be used.''')
    parser_latex.add_argument(
        '-options', default=None, dest='engine_options',
        help='''Set the default engine options for tex documents. If you do
                not set this option explicitly, then the engine options set
                inside the TextMate preferences will be used.''')

    parser = ArgumentParser(
        description='Execute common TeX commands.')
    parser.add_argument(
        '-addoutput', action='store_true', default=False,
        help=('Tell %(prog)s to generate HTML output for an existing HTML ' +
              'output window'))
    parser.add_argument(
        '-suppressview', action='store_true', default=False,
        help=('''Tell %(prog)s to not open the PDF viewer application.'''))

    subparsers = parser.add_subparsers(title="Commands", dest='command')
    subparsers.add_parser('bibtex', parents=[parser_file],
                          help='Run bibtex/biber for the specified file.')
    subparsers.add_parser('clean', parents=[parser_file],
                          help='Remove auxiliary files')
    subparsers.add_parser('chktex', parents=[parser_file],
                          help='Check the specified file with chktex.')
    subparsers.add_parser(
        'index', parents=[parser_file],
        help='''Create a index for the specified file using either
                makeglossaries or makeindex.''')
    subparsers.add_parser(
        'latex', parents=[parser_file, parser_latex],
        help='Typeset the specified file using latex.')
    subparsers.add_parser(
        'sync', parents=[parser_file],
        help='''Open the specified PDF file at the position corresponding to
                the currently selected tex code. Instead of providing the
                path to the PDF it is also possible to just use the path of
                the tex file. This command assumes that path to the PDF and
                the tex file only differ in their extension!''')
    subparsers.add_parser(
        'view', parents=[parser_file],
        help='''View the PDF corresponding to the specified tex file using
                either the currently selected viewer or the viewer specified
                as argument.''')
    subparsers.add_parser(
        'version', parents=[parser_file, parser_latex],
        help='Return a version string for the currently selected engine.')

    return parser.parse_args()


# -- Main ---------------------------------------------------------------------

if __name__ == '__main__':
    # Get preferences from TextMate
    tm_preferences = Preferences()
    # Parse command line parameters...
    arguments = get_command_line_arguments()

    command = arguments.command
    viewer_status = 0
    filepath = arguments.filepath
    first_run = not arguments.addoutput
    line_number = getenv('TM_SELECTION').split(':')[0]
    number_errors = 0
    number_runs = 0
    number_warnings = 0
    suppress_viewer = arguments.suppressview
    synctex = False
    tex_status = 0
    tm_autoview = tm_preferences['latexAutoView']
    tm_bundle_support = getenv('TM_BUNDLE_SUPPORT')
    tm_engine = tm_preferences['latexEngine']
    tm_engine_options = tm_preferences['latexEngineOptions'].strip()
    use_latexmk = False
    use_pvc = False # the pvc mode for latexmk
    
    verbose = True if tm_preferences['latexVerbose'] == 1 else False
    viewer = tm_preferences['latexViewer']
        
    if command == 'latex' or command == 'version':
        use_latexmk = ((arguments.latexmk == 'yes') or 
            (not arguments.latexmk and tm_preferences['latexUselatexmk']))
                                          
        use_pvc = ((arguments.latexmk == 'pvc') or 
            (use_latexmk and tm_preferences['latexUselatexmkpvc']))
                
        if (use_latexmk) and (command == 'latex') and (not use_pvc):
            command = 'latexmk'
        if (use_pvc) and (command == 'latex'):
            command = 'latexmkpvc'
        if arguments.engine:
            tm_engine = arguments.engine
        if arguments.engine_options:
            tm_engine_options = arguments.engine_options
        
    typesetting_data = get_typesetting_data(filepath, tm_engine,
                                            tm_bundle_support)

    typesetting_directives = typesetting_data['typesetting_directives']
    cache_filename = typesetting_data['cache_filename']
    filename = typesetting_data['filename']
    file_path = typesetting_data['file_path']
    file_without_suffix = typesetting_data['file_without_suffix']
    packages = typesetting_data['packages']
    engine = typesetting_data['engine']
    synctex = typesetting_data['synctex']

    pdffile_path = "{}/{}.pdf".format(file_path, file_without_suffix)

    if command == "version":
        process = Popen("{} --version".format(engine), stdout=PIPE, shell=True)
        print(process.stdout.readline().rstrip('\n'))
        exit()

    if command != 'sync':
        # Print out header information to begin the run
        if first_run:
            print('<div id="commandOutput"><div id="preText">')
        else:
            print('<hr>')

    if filename == file_without_suffix:
        print("<h2 class='warning'>Warning: LaTeX file has no extension. " +
              "See log for errors/warnings</h2>")

    if synctex and 'pdfsync' in packages and first_run:
        print("<p class='warning'>Warning: {} supports ".format(engine) +
              "synctex but you have included pdfsync. You can safely remove " +
              "\usepackage{pdfsync}</p>")

    problematic_characters = search('[$"]', filename)
    if problematic_characters:
        print('''<p class="error"><strong>
                 The filename {0} contains a problematic character: {1}<br>
                 Please remove all occurrences of {1} in the filename.
                 </strong></p>
              '''.format(filename, problematic_characters.group(0)))
    # Run the command passed on the command line or modified by preferences
    elif command == 'latexmkpvc':
        if first_run: 
            #immediately create buttons at the bottom and 
            #start second run with -addoutput option
            #which will produce output above the buttons
            print('</div></div>')  # Close divs `preText` and `commandOutput`
            pdf_file = '{}.pdf'.format(file_without_suffix)
            # only need to include the javascript library once
            texlib_location = quote('{}/bin/texlib.js'.format(tm_bundle_support))

            print('''<script src="file://{}" type="text/javascript"
                      charset="utf-8"></script>'''.format(texlib_location))
            
            print('''<input id="latexmk_button" type="button" value="Stop latexmk"
                     onclick="stopLatexmkpvc(); return false">''')

            print('''<input type="button" value="Create Index"
                      onclick="runMakeIndex(); return false">
                     <input type="button" value="Clean" onclick="runClean();
                      return false">''')

            if viewer == 'TextMate':
                print('''<input type="button" value="View in TextMate"
                          onclick="window.location='file://{}'"/>'''.format(
                      quote('{}/{}'.format(file_path, pdf_file))))
            else:
                print('''<input type="button" value="View in {}"
                         onclick="runView(); return false">'''.format(viewer))

            print('''<input type="button" value="Preferences"
                      onclick="runConfig(); return false">
                     <p>
                     <input type="checkbox" id="hv_warn" name="fmtWarnings"
                     onclick="makeFmtWarnVisible(); return false">
                     <label for="hv_warn">Show hbox, vbox Warnings </label>
                     ''')


            print('''<input type="checkbox" id="ltxmk_warn"
                      name="ltxmkWarnings" onclick="makeLatexmkVisible();
                      return false">
                     <label for="ltxmk_warn">Show Latexmk Messages </label>''')

            print('</p></div>') #div texActions
            
            print('''<script type="text/javascript">runLatexmkpvc()</script>''') #run the second run with -addoutput

            exit(EXIT_SUCCESS)
        
        else: #not first_run
            engine_options = construct_engine_options(typesetting_directives,
                                                      tm_engine_options, synctex)
            write_latexmkrc(engine, engine_options, '/tmp/latexmkrc')
            latexmkrc_path = "{}/config/latexmkrc".format(tm_bundle_support)
            command = "latexmk -pdf{} {} -f -r /tmp/latexmkrc -r {} {}".format(
                'ps' if engine == 'latex' else '', 
                '-pvc' if use_pvc else '',
                shellquote(latexmkrc_path),
                shellquote(filename))
                        
            process = Popen(command, shell=True, stdout=PIPE, stdin=PIPE,
                            stderr=STDOUT, close_fds=True)        
        
            
            def round_finished(parser, fatal_error, number_errors, number_warnings):
                update_marks(cache_filename, parser.marks)
        
                #don't want sync as it doesn't work with multiple source files
                use_pdfsync = False; #'pdfsync' in packages or synctex
                if tm_autoview and number_errors < 1 and not suppress_viewer:
                    viewer_status = run_viewer(
                        viewer, filepath, pdffile_path,
                        number_errors > 1 or number_warnings > 0
                        and tm_preferences['latexKeepLogWin'],
                        use_pdfsync, line_number)

            command_parser = LaTexMkParser(process.stdout, verbose, 
                                           filename, use_pvc, round_finished)

            status = command_parser.parse_stream()
             
            tex_status = process.wait()
            #wait until user kills latexmk            
        
            if (tex_status == -2):
                #latexmk interrupted, everything is ok
                tex_status=0
            
            fatal_error, number_errors, number_warnings = status
            number_runs = command_parser.number_runs

            remove("/tmp/latexmkrc")            
        
            # Decide what to do with the Latex & View log window
            exit_code = (EXIT_DISCARD if not tm_preferences['latexKeepLogWin'] and
                         number_errors == 0 and viewer != 'TextMate' else EXIT_SUCCESS)
        
            exit(exit_code)

            #end if not first_run
        #end if 'latexmkpvc'

    elif command == 'latexmk':  
        engine_options = construct_engine_options(typesetting_directives,
                                                  tm_engine_options, synctex)
        write_latexmkrc(engine, engine_options, '/tmp/latexmkrc')
        latexmkrc_path = "{}/config/latexmkrc".format(tm_bundle_support)
        command = "latexmk -pdf{} -f -r /tmp/latexmkrc -r {} {}".format(
            'ps' if engine == 'latex' else '', 
            shellquote(latexmkrc_path),
            shellquote(filename))
                    
        process = Popen(command, shell=True, stdout=PIPE, stdin=PIPE,
                        stderr=STDOUT, close_fds=True)                
        
        command_parser = LaTexMkParser(process.stdout, verbose, 
                                       filename, False, None)

        status = command_parser.parse_stream()

        tex_status = process.wait()            
        
        update_marks(cache_filename, command_parser.marks)
        fatal_error, number_errors, number_warnings = status
        number_runs = command_parser.number_runs

        remove("/tmp/latexmkrc")
            
        if tm_autoview and number_errors < 1 and not suppress_viewer:
            viewer_status = run_viewer(
                viewer, filepath, pdffile_path,
                number_errors > 1 or number_warnings > 0
                and tm_preferences['latexKeepLogWin'],
                'pdfsync' in packages or synctex, line_number)

    elif command == 'bibtex':
        use_biber = exists('{}.bcf'.format(file_without_suffix))
        status = (run_biber(file_without_suffix) if use_biber else
                  run_bibtex(file_without_suffix))
        tex_status, fatal_error, number_errors, number_warnings = status

    elif command == 'index':
        use_makeglossaries = exists('{}.glo'.format(file_without_suffix))
        status = (run_makeglossaries(filename, verbose) if use_makeglossaries
                  else run_makeindex(filename, verbose))
        tex_status, fatal_error, number_errors, number_warnings = status

    elif command == 'clean':
        auxiliary_file_regex = (
            '.*\.(acn|acr|alg|aux|bbl|bcf|blg|fdb_latexmk|fls|fmt|glg|glo|gls|'
            'idx|ilg|ind|ini|ist|lb|log|out|maf|mtc|mtc1|pdfsync|run.xml|'
            'synctex.gz|toc)$')
        command = ("find -E . -maxdepth 1 -type f -regex " +
                   "'{}' -delete -print".format(auxiliary_file_regex))
        removed_files = check_output(command, shell=True).strip()
        # Remove leading './' to get nicer looking output
        removed_files = removed_files.replace('./', '')
        if removed_files:
            for removed_file in removed_files.split('\n'):
                print('<p class"info">Removed {}</p>'.format(removed_file))
        else:
            print('<p class"info">Clean: No Auxiliary files found'.format())

    elif command == 'latex':
        engine_options = construct_engine_options(typesetting_directives,
                                                  tm_engine_options, synctex)
        command = "{} {}".format(engine, engine_options)
        status = run_latex(command, filename, cache_filename, verbose)
        tex_status, fatal_error, number_errors, number_warnings = status
        number_runs = 1

        if engine == 'latex':
            call("dvips {0}.dvi -o '{0}.ps'".format(file_without_suffix),
                 shell=True)
            call("ps2pdf '{}.ps'".format(file_without_suffix), shell=True)
        if tm_autoview and number_errors < 1 and not suppress_viewer:
            viewer_status = run_viewer(
                viewer, filepath, pdffile_path,
                number_errors > 1 or number_warnings > 0 and
                tm_preferences['latexKeepLogWin'],
                'pdfsync' in packages or synctex, line_number)

    elif command == 'view' and not suppress_viewer:
        viewer_status = run_viewer(
            viewer, filepath, pdffile_path,
            number_errors > 1 or number_warnings > 0 and
            tm_preferences['latexKeepLogWin'],
            'pdfsync' in packages or synctex, line_number)

    elif command == 'sync':
        if 'pdfsync' in packages or synctex:
            _, sync_command = get_app_path_and_sync_command(
                viewer, pdffile_path, filepath, line_number)
            if sync_command:
                viewer_status = call(sync_command, shell=True)
            else:
                print("The viewer {} does not support pdfsync".format(viewer))
                exit(EXIT_SHOW_TOOL_TIP)

        else:
            print("Either you need to include `pdfsync.sty` in your document" +
                  "or you need to use an engine that supports pdfsync.")
            exit(EXIT_SHOW_TOOL_TIP)

    elif command == 'chktex':
        command = "{} '{}'".format(command, filename)
        process = Popen(command, shell=True, stdout=PIPE, stdin=PIPE,
                        stderr=STDOUT, close_fds=True)
        parser = ChkTexParser(process.stdout, verbose, filename)
        fatal_error, number_errors, number_warnings = parser.parse_stream()
        tex_status = process.wait()

    # Check status of running the viewer
    if viewer_status != 0:
        print('<p class="error"><strong>Error {} '.format(viewer_status) +
              'opening viewer</strong></p>')

    if tex_status > 0:
        print('<p class="warning"> Command {} '.format(command) +
              'exited with status {}'.format(tex_status))
    elif tex_status < 0:
        print('<p class="error"> Command {} exited '.format(command) +
              'with error code {}</p>'.format(tex_status))

    if number_warnings > 0 or number_errors > 0:
        print('<p class="info">Found {} errors, and '.format(number_errors) +
              '{} warnings in {} run{}</p>'.format(number_warnings,
              number_runs, '' if number_runs == 1 else 's'))

    # Decide what to do with the Latex & View log window
    exit_code = (EXIT_DISCARD if not tm_preferences['latexKeepLogWin'] and
                 number_errors == 0 and viewer != 'TextMate' else EXIT_SUCCESS)

    # Output buttons at the bottom of the window
    if first_run:
        print('</div></div>')  # Close divs `preText` and `commandOutput`
        pdf_file = '{}.pdf'.format(file_without_suffix)
        # only need to include the javascript library once
        texlib_location = quote('{}/bin/texlib.js'.format(tm_bundle_support))

        print('''<script src="file://{}" type="text/javascript"
                  charset="utf-8"></script>'''.format(texlib_location))

        print('''<div id="texActions">
                 <input type="button" value="Run {}"
                  onclick="runLatex(); return false">
                 <input type="button" value="Create Bibliography"
                  onclick="runBibtex();
                  return false">'''.format(engine))

        print('''<input type="button" value="Create Index"
                  onclick="runMakeIndex(); return false">
                 <input type="button" value="Clean" onclick="runClean();
                  return false">''')

        if viewer == 'TextMate':
            print('''<input type="button" value="View in TextMate"
                      onclick="window.location='file://{}'"/>'''.format(
                  quote('{}/{}'.format(file_path, pdf_file))))
        else:
            print('''<input type="button" value="View in {}"
                     onclick="runView(); return false">'''.format(viewer))

        print('''<input type="button" value="Preferences"
                  onclick="runConfig(); return false">
                 <p>
                 <input type="checkbox" id="hv_warn" name="fmtWarnings"
                 onclick="makeFmtWarnVisible(); return false">
                 <label for="hv_warn">Show hbox, vbox Warnings </label>
                 ''')

        if use_latexmk:
            print('''<input type="checkbox" id="ltxmk_warn"
                      name="ltxmkWarnings" onclick="makeLatexmkVisible();
                      return false">
                     <label for="ltxmk_warn">Show Latexmk Messages </label>''')

        print('</p></div>') #div texActions

    exit(exit_code)
