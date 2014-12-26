#!/usr/bin/env python
# encoding: utf-8

# -- Imports ------------------------------------------------------------------

from argparse import ArgumentParser, FileType
from re import compile, match, search
from os import getcwd
from os.path import basename, dirname, join, normpath, realpath
from pickle import load, dump
from pipes import quote as shellquote
from subprocess import call
from sys import stdout
from urllib import quote


# -- Functions ----------------------------------------------------------------

def make_link(file, line=1):
    """Create a TextMate link for ``file`` pointing to ``line``.

    Arguments:

        file

            The path to the file that should be opened if we click the link
            generated by this function.

        line

            The line which should be displayed when TextMate opens ``file``.

    Returns: ``str``

    Examples:

        >>> make_link('Tests/TeX/makeindex.tex', 1)
        'txmt://open/?url=file://Tests/TeX/makeindex.tex&line=1'
        >>> make_link('Wide Open Spaces.txt', 20)
        'txmt://open/?url=file://Wide%20Open%20Spaces.txt&line=20'

    """
    return "txmt://open/?url=file://{}&line={}".format(quote(file), line)


def update_marks(cache_filename, marks_to_set=[]):
    """Set or remove gutter marks.

    This function starts by removing marks from the files specified inside the
    dictionary item ``files_with_guttermarks`` stored inside the ``pickle``
    file ``cache_filename``. After that it sets all marks specified in
    ``marks_to_set``.

    cache_filename

        The path to the cache file for the current tex project. This file
        stores a dictionary containing the item ``files_with_guttermarks``.
        ``files_with_guttermarks`` stores a list of files, from which we need
        to remove gutter marks.

    marks_to_set

        A list of tuples of the form ``(file_path, line_number, marker_type,
        message)``, where file_path and line_number specify the location where
        a marker of type ``marker_type`` together with an optional message
        should be placed.

    Examples:

        >>> marks_to_set = [('Tests/TeX/lualatex.tex', 1, 'note',
        ...                  'Lua was created in 1993.'),
        ...                 ('Tests/TeX/lualatex.tex', 4, 'warning',
        ...                  'Lua means "Moon" in Portuguese.'),
        ...                 ('Tests/TeX/lualatex.tex', 6, 'error', None)]
        >>> data = {'files_with_guttermarks': {'Tests/TeX/lualatex.tex'}}
        >>> cache_filename = '.test.lb'
        >>> with open(cache_filename, 'wb') as storage:
        ...     dump(data, storage)

        Set marks
        >>> update_marks(cache_filename, marks_to_set)

        Remove marks
        >>> update_marks(cache_filename)
        >>> from os import remove
        >>> remove(cache_filename)

        Working with a non existent file should just set the marks in
        ``marks_to_set``
        >>> update_marks('non_existent_file')
        >>> remove('non_existent_file')

    """
    try:
        # Try to read from cache
        with open(cache_filename, 'rb') as storage:
            typesetting_data = load(storage)
            files_with_guttermarks = typesetting_data['files_with_guttermarks']
            marks_to_remove = []
            for filename in files_with_guttermarks:
                marks_to_remove.extend([(filename, 'error'),
                                        (filename, 'warning')])
    except:
        typesetting_data = {}
        marks_to_remove = []

    try:
        # Try to write cache data for next run
        newfiles = {filename for (filename, _, _, _) in marks_to_set}
        if 'files_with_guttermarks'in typesetting_data:
            typesetting_data['files_with_guttermarks'].update(newfiles)
        else:
            typesetting_data['files_with_guttermarks'] = newfiles
        with open(cache_filename, 'wb') as storage:
            dump(typesetting_data, storage)
    except:
        print('<p class="warning"> Could not write cache file {}!</p>'.format(
              cache_filename))

    marks_remove = {}
    for filepath, mark in marks_to_remove:
        path = normpath(realpath(filepath))
        marks = marks_remove.get(path)
        if marks:
            marks.append(mark)
        else:
            marks_remove[path] = [mark]

    marks_add = {}
    for filepath, line, mark, message in marks_to_set:
        path = normpath(realpath(filepath))
        message = shellquote(message) if message else None
        marks = marks_add.get(path)
        if marks:
            marks.append((line, mark, message))
        else:
            marks_add[path] = [(line, mark, message)]

    commands = {filepath: 'mate {}'.format(' '.join(['-c {}'.format(mark) for
                                                     mark in marks]))
                for filepath, marks in marks_remove.iteritems()}

    for filepath, markers in marks_add.iteritems():
        command = ' '.join(['-l {} -s {}{}'.format(line, mark,
                                                   ":{}".format(message) if
                                                   message else '')
                            for line, mark, message in markers])
        commands[filepath] = '{} {}'.format(commands.get(filepath, 'mate'),
                                            command)

    for filepath, command in commands.iteritems():
        call("{} {}".format(command, shellquote(filepath)), shell=True)


# -- Classes ------------------------------------------------------------------

class TexParser(object):
    """Parse TeX typesetting streams.

    This class reads output from a tex program and tries to convert this
    information into HTML.

    """

    def __init__(self, input_stream, verbose):
        """Initialize a new TexParser.

        Arguments:

            input_stream

                A stream like object containing data produced by a tex program.

            verbose

                Specifies if the output produced by this class should cover
                all messages provided by input stream (verbose=True) or if
                only messages about important events should produce output by
                this class.

        Examples:

            >>> with open('Tests/Log/external_bibliography.log') as log:
            ...     parser = TexParser(log, True)

        """
        self.input_stream = input_stream
        self.patterns = []
        self.done = False
        self.verbose = verbose
        self.number_errors = 0
        self.number_warnings = 0
        self.fatal_error = False

    def get_rewrapped_line(self):
        """Try to get exactly one line of coherent tex output.

        Sometimes TeX breaks up lines with hard line breaks. This is
        annoying. Even more annoying is that it sometime does not break line,
        for two distinct warnings. This function attempts to return a single
        statement.

        Returns: ``str``

        Examples:

            >>> with open('Tests/Log/latexmk.log') as log: # doctest:+ELLIPSIS
            ...     parser = TexParser(log, True)
            ...     line = parser.get_rewrapped_line()
            ...     while line:
            ...         print(line)
            ...         line = parser.get_rewrapped_line()
            Latexmk: ...
            ...
            \EU1/AvenirNext(0)/m/n/... on all fair paths ...
            ...

        """
        statement = ""
        while True:
            line = self.input_stream.readline()
            if not line:
                return statement
            statement += line.rstrip('\n')
            if not (len(line) == 80 and not line[78] in {'!', '.'}):
                break
        return statement + '\n'

    def parse_stream(self):
        """Process the input stream one line at a time.

        We match against each pattern in the patterns dictionary. If a pattern
        matches we call the corresponding method in the dictionary. The
        dictionary is organized with patterns as the keys and methods as the
        values.

        This method returns a tuple containing the following values:

            - A boolean value specifying if there was a fatal error
              encountered by the tex program.

            - The number of errors found in the stream

            - The number of warnings found in the stream

        Returns: ``(bool, int, int)``

        Examples:

            >>> status = None
            >>> # Since the pattern dictionary of ``TexParser`` is empty the
            >>> # following will print nothing
            >>> with open('Tests/Log/external_bibliography.log') as log:
            ...     parser = TexParser(log, False)
            ...     status = parser.parse_stream()
            >>> status
            (False, 0, 0)

        """
        line = self.get_rewrapped_line()
        while line and not self.done:
            line = line.rstrip("\n")
            found_match = False

            # Process matching patterns until we find one
            for patttern, function in self.patterns:
                matching = patttern.match(line)
                if matching:
                    function(matching, line)
                    stdout.flush()
                    found_match = True
                    break
            if self.verbose and not found_match:
                print(line)

            line = self.get_rewrapped_line()
        if not self.done:
            self.bad_run()
        return self.fatal_error, self.number_errors, self.number_warnings

    def info(self, matching, line):
        """Print a message containing ``line``.

        The functions of the form ``function(self, matching, line)`` in this
        class and all subclasses use the same interface. We will therefore
        describe their behaviour only here once.

        Arguments:

            matching

                A regex match containing the match for the given line. What
                ``matching`` contains is dependent on the regex, which lead to
                the call of this function.

            line

                A string containing the regex pattern which lead to the call
                of this function

        Returns: ``str``

        """
        print('<p class="info">{}</p>'.format(line))

    def error(self, matching, line):
        print('<p class="error">{}</p>'.format(line))
        self.number_errors += 1

    def warning(self, matching, line):
        print('<p class="warning">{}</p>'.format(line))
        self.number_warnings += 1

    def warning_format(self, matching, line):
        print('<p class="fmtWarning">{}</p>'.format(line))

    def fatal(self, matching, line):
        print('<p class="error">{}</p>'.format(line))
        self.fatal_error = True

    def bad_run(self):
        pass


class BibTexParser(TexParser):
    """Parse and format messages from bibtex"""

    def __init__(self, input_stream, verbose):
        """Initialize the regex patterns for the BibTexParser"""
        super(BibTexParser, self).__init__(input_stream, verbose)
        self.patterns.extend([
            (compile("Warning--"), self.warning),
            (compile(r'I found no \\\w+ command'), self.error),
            (compile("I couldn't open style file"), self.error),
            (compile(r"You're missing a field name---line (\d+)"), self.error),
            (compile(r'Too many commas in name \d+ of'), self.error),
            (compile('I was expecting a'), self.error),
            (compile('This is BibTeX'), self.info),
            (compile('The style'), self.info),
            (compile('Database'), self.info),
            (compile(r'(---)|(\(There were .*\))'), self.finish_run)
        ])

    def parse_stream(self):
        r"""Parse log messages from bibtex.

        Examples:

            >>> status = None
            >>> with open('Tests/Log/bibtex.log') as log:  # doctest:+ELLIPSIS
            ...     parser = BibTexParser(log, False)
            ...     status = parser.parse_stream()
            <p class="info">This is BibTeX...</p>
            <p class="info">The style file: alpha.bst</p>
            <p class="info">Database file #1: References.bib</p>
            <p class="warning">Warning--entry...isn't style-file defined</p>
            <p class="warning">Warning--empty journal in Rea...</p>
            <p class="warning">Warning--I didn't find ... "Haggarty:01"</p>
            <p class="warning">Warning--to sort,... in IEEE_1003_26</p>
            <p class="warning">... "Realtime_Linux_Academic_Vs_Reality"...</p>
            <p class="error">I was expecting ... biblio.bib</p>
            <p class="error">Too many commas...for entry Arridge89</p>
            <p class="error">You're missing...---line 5 of file biblio.bib</p>
            <p class="error">I found no \bibdata command---while ...2a.aux</p>
            <p class="error">I couldn't open style file natbib.bst</p>
            >>> status
            (False, 5, 5)
            >>> parser.done
            True

        """
        return super(BibTexParser, self).parse_stream()

    def finish_run(self, matching, line):
        self.done = True


class BiberParser(TexParser):
    """Parse and format messages from biber"""

    def __init__(self, input_stream, verbose):
        """Initialize the regex patterns for the BiberParser"""
        super(BiberParser, self).__init__(input_stream, verbose)
        self.patterns.extend([
            (compile('INFO - This is Biber'), self.info),
            (compile('WARN'), self.warning),
            (compile('ERROR'), self.error),
            (compile('FATAL'), self.fatal),
            (compile('^.*Output to (.*)$'), self.finish_run),
        ])

    def parse_stream(self):
        """Parse log messages from biber.

        Examples:

            >>> status = None
            >>> with open('Tests/Log/biber.log') as log:  # doctest:+ELLIPSIS
            ...     parser = BiberParser(log, False)
            ...     status = parser.parse_stream()
            <p class="info">INFO - This is Biber...</p>
            <p class="warning">WARN - Warning: Found ... expected... 2.5</p>
            <p class="error">FATAL - Cannot find ... to BibLaTeX?</p>
            <p class="error">ERROR - Cannot find file '.../References1'!</p>
            <p>Complete transcript is in ...</a></p>
            >>> status
            (True, 1, 1)
            >>> parser.done
            True

        """
        return super(BiberParser, self).parse_stream()

    def finish_run(self, matching, line):
        log = matching.group(1)
        print('<p>Complete transcript is in <a href="{}">{}</a></p>'.format(
              make_link(join(getcwd(), log)), log))
        self.done = True


class MakeIndexParser(TexParser):
    """Parse and format messages from makeindex."""

    def __init__(self, input_stream, verbose):
        """Initialize the regex patterns for the MakeIndexParser"""
        super(MakeIndexParser, self).__init__(input_stream, verbose)
        self.patterns.extend([
            (compile(r'This is makeindex, version (\d+\.\d+)'),
             self.run_makeindex),
            (compile(r'(\w+ \w+ file) (?:\./)?' +
                     r'(.*\.(?:(?:idx)|(?:ind))).*\((.*)\)'),
             self.work_with_file),
            (compile(r'Sorting entries.*\((.*)\)'), self.sorting),
            (compile(r'(Transcript written in) (.*)\.$'),
             self.transcript_written),
            (compile(r'(\w+ written in) (.*)\.$'), self.written)
        ])

    def parse_stream(self):
        """Parse log messages from makeindex.

        Examples:

        >>> filepath = 'Tests/Log/makeindex.log'
        >>> with open(filepath) as log:  # doctest:+ELLIPSIS
        ...                              # doctest:+NORMALIZE_WHITESPACE
        ...     parser = MakeIndexParser(log, False)
        ...     status = parser.parse_stream()
        <p class="info">Run...Makeindex...<p>
        <p class="info">Scanning...2 entries accepted, 0 rejected...
        <p class="info">Sorting entries: <strong>2 comparisons</strong><p>
        <p class="info">Generating...makeindex.ind:...9 lines written, 0...
        <p class="info">Output written in <a
            href="txmt://...makeindex.ind&line=1">makeindex.ind</a></p>
        <p class="info">Transcript written in <a
            href="txmt:...makeindex.ilg&line=1">makeindex.ilg</a></p>
        >>> status
        (False, 0, 0)
        >>> parser.done
        True

        """
        return super(MakeIndexParser, self).parse_stream()

    def run_makeindex(self, matching, line):
        version = matching.group(1)
        print('<p class="info">Run <strong>Makeindex</strong>, ' +
              'version {}<p>'.format(version))

    def sorting(self, matching, line):
        status = matching.group(1)
        print('<p class="info">Sorting entries: <strong>' +
              '{}</strong><p>'.format(status))

    def work_with_file(self, matching, line):
        description = matching.group(1)
        filename = matching.group(2)
        status = matching.group(3)
        print('<p class="info">{} {}: <strong>{}</strong>'.format(description,
              filename, status))

    def written(self, matching, line):
        description = matching.group(1)
        filename = matching.group(2)
        filepath = make_link(join(getcwd(), filename))
        print('<p class="info">{} <a href="{}">{}</a></p>'.format(
              description, filepath, filename))

    def transcript_written(self, matching, line):
        self.written(matching, line)
        self.done = True


class MakeGlossariesParser(MakeIndexParser):
    """Parse and format messages from makeglossaries."""

    def __init__(self, input_stream, verbose):
        """Initialize the regex patterns for the MakeGlossariesParser"""
        super(MakeGlossariesParser, self).__init__(input_stream, verbose)
        self.patterns.extend([
            (compile('^.*makeglossaries version (.*)$'), self.begin_run),
            (compile('^.*added glossary type \'(.*)\' \((.*)\).*$'),
             self.add_type),
            (compile(r'(\w+ \w+ file) (?:\./)?' +
                     r'(.*\.(?:(?:acr)|(?:ist)|(?:glo)|(?:gls))).*\((.*)\)'),
             self.work_with_file),
            (compile(r'(\w+ written in) (.*)\.$'), self.written),
            (compile('^.*Markup written into file "(.*)".$'),
             self.finish_markup),
            (compile('^.*xindy.*-L (.*) -I.*-t ".*\.(.*)" -o.*$'),
             self.run_xindy),
            (compile('Cannot locate xindy module'), self.warning),
            (compile('ERROR'), self.error),
            (compile('Warning'), self.warning),
            (compile('^\*\*\*'), self.info),
        ])
        self.types = {}

    def parse_stream(self):
        """Parse log messages from makeglossaries.

        Examples:

            >>> status = None
            >>> filepath = 'Tests/Log/makeglossaries.log'
            >>> with open(filepath) as log:  # doctest:+ELLIPSIS
            ...     parser = MakeGlossariesParser(log, False)
            ...     status = parser.parse_stream()
            <h2>Make Glossaries</h2><p class="info" >Version: <i>...</i></p>
            <p class="info">Add...main... (Files: glg,gls,glo)</i></p>
            ...
            <p class="info">Run <strong>Makeindex</strong>, version ...<p>
            <p class="info">Scanning...makeglossaries.ist:...29 a...0 i...
            ...
            <p class="info">Sorting entries: <strong>0 comparisons</strong><p>
            ...Generating...makeglossaries.gls:...6 lines written, 0...
            ...Out... <a href="txmt://open/?url=file://.../...gls&line=1">...
            ...
            <h3>Run xindy for glossary type main...Language: english...
            ...Finished ...main...Out...in <a ...makeglossaries.gls...</p>
            >>> status
            (False, 0, 0)

        """
        return super(MakeGlossariesParser, self).parse_stream()

    def begin_run(self, matching, line):
        version = matching.group(1)
        print('<h2>Make Glossaries</h2>' +
              '<p class="info" >Version: <i>{}</i></p>'''.format(version))

    def add_type(self, matching, line):
        glossary_type = matching.group(1)
        files = matching.group(2)
        for file in files.split(','):
            self.types[file] = glossary_type
        print('<p class="info">Add Glossary Type <strong>' +
              '{}</strong><i> (Files: {})</i></p>'.format(glossary_type,
                                                          files))

    def run_xindy(self, matching, line):
        language = matching.group(1)
        file = matching.group(2)
        glossary_type = self.types[file]
        print('<h3>Run xindy for glossary type {}</h3>'.format(glossary_type) +
              '<p class="info">Language: {}</p>'.format(language))

    def transcript_written(self, matching, line):
        self.written(matching, line)

    def finish_markup(self, m, line):
        mkfile = m.group(1)
        glossary_type = self.types[mkfile[-3:]]
        print('<p class="info">Finished glossary for type <strong>' +
              '{}</strong>. Output is in <a href="{}">{}</a></p>'.format(
              glossary_type, make_link(join(getcwd(), mkfile), 1), mkfile))


class LaTexParser(TexParser):
    """Parse log messages from latex."""

    def __init__(self, input_stream, verbose, filename):
        """Initialize the regex patterns for the LaTexParser."""
        super(LaTexParser, self).__init__(input_stream, verbose)
        self.suffix = filename[:filename.rfind('.')]
        self.filename = self.current_file = filename
        # Save gutter marks for errors and warnings
        self.marks = []
        self.patterns.extend([
            (compile('^Document Class'), self.info),
            (compile('.*?\(\.\/([^\)]*?\.(tex|{})( |$))'.format(self.suffix)),
             self.detect_new_file),
            (compile('.*\<use (.*?)\>'), self.detect_include),
            (compile('^Output written'), self.info),
            (compile('LaTeX Warning:.*?input line (\d+)(\.|$)'),
             self.handle_warning),
            (compile('LaTeX Warning:.*'), self.warning),
            (compile('.*pdfTeX warning.*'), self.warning),
            (compile('LaTeX Font Warning:.*'), self.warning),
            (compile('Overfull.*wide'), self.warning_format),
            (compile('Underfull.*badness'), self.warning_format),
            (compile('^([\.\/\w\x7f-\xff\-]+' +
                     '(?:\.sty|\.tex|\.{}))'.format(self.suffix) +
                     ':(\d+):\s+(.*)'),
             self.handle_error),
            (compile('([^:]*):(\d+): LaTeX Error:(.*)'), self.handle_error),
            (compile('([^:]*):(\d+): (Emergency stop)'), self.handle_error),
            (compile('Runaway argument'), self.pdf_latex_error),
            # We need the (.*) at the beginning of the regular expression
            # since in some edge cases cases the output about the transcript
            # might actually not start at the beginning of the line.
            (compile('(.*)Transcript written on (.*)\.$'), self.finish_run),
            (compile('\!.*'), self.handle_old_style_errors),
            (compile('^\s+==>'), self.fatal)
        ])

    def parse_stream(self):
        """Parse log messages from makeglossaries.

        Examples:

            >>> status = None
            >>> filepath = 'Tests/Log/latex.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = LaTexParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <h4>Processing: Embedded Operating Systems.tex</h4>
            <p class="info">Document Class: article...LaTeX document class</p>
            <ul><li>Including: Figures/Operating_System_Layer.pdf</li></ul>
            <p class="warning"><a
                href="txmt://open/?url=file:/...%20Systems.tex&line=159">LaTeX
                Warning: Reference `figure:Operating_System_Layer' on page 3
                undefined on input line 159.</a></p>
            <p class="fmtWarning">Underfull \hbox ... lines 159--160</p>
            <p class="warning"><a
                href=".../Embedded%20Operating%20Systems.tex&line=161">LaTeX
                Warning: Citation `Software_Entwicklung' on page 3 undefined
                on input line 161.</a></p>
            <p class="warning"><a
                href="txmt://open/?url=file:/...Systems.tex&line=194">LaTeX
                Warning: Citation `Embedded_OS_Market_Share_2005' on page 5
                undefined on input line 194.</a></p>
            <p class="warning">LaTeX Font Warning: Font shape `OT1/cmss/m/n'
                in size <4> not available</p>
            <p class="warning">pdfTeX warning: pdflatex
                (file ./figure/figure_1.pdf): PDF inclusion: found PDF version
                <1.6>, but at most version <1.5> allowed</p>
            <p class="error">Latex Error: <a
                href="....tex&line=22">./makeglossaries.tex:22</a> Undefined
                control sequence.</p>
            <p class="warning">LaTeX Warning:
                There were undefined references.</p>
            <p class="warning">LaTeX Warning: Label(s) may have changed.
                Rerun to get cross-references right.</p>
            <p class="info">Output written on "Embedded Operating Systems.pdf"
                (28 pages, 474379 bytes).</p>
            <p>Complete transcript is in
                <a href="...%20Operating%20Systems.log&line=1">Embedded
                Operating Systems.log</a></p>
            >>> status
            (False, 1, 7)
            >>> parser.done
            True
            >>> status = None
            >>> filepath = 'Tests/Log/latex_error.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = LaTexParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <h4>Processing: makeglossaries.tex</h4>
            <p class="error">! LaTeX Error: File `Word.sty' not found.</p>
            <p class="error">
            <pre>{ \par bla \par \printglossaries \par \end {document}</pre>
            </p>
            <p class="warning">! File ended while scanning use of
                \@xdblarg.</p>
            <p class="error">! LaTeX Error: There's no line here to end</p>
            <p class="error">Latex Error: <a
                href=...makeglossaries.tex&line=6">./makeglossaries.tex:6</a>
                Emergency stop.</p>
            <p class="error">Latex Error: <a href="...line=6">...</a>
                ==> Fatal error occurred, no output PDF file produced!</p>
            <p>Complete transcript is in <...line=1">makeglossaries.log</a></p>
            >>> status
            (True, 5, 1)
            >>> parser.done
            True

        """
        return super(LaTexParser, self).parse_stream()

    def detect_new_file(self, matching, line):
        self.current_file = matching.group(1).rstrip()
        print("<h4>Processing: {}</h4>".format(self.current_file))

    def detect_include(self, matching, line):
        filepath = matching.group(1)
        print("<ul><li>Including: {}</li></ul>".format(filepath))

    def handle_warning(self, matching, line):
        filepath = join(getcwd(), self.current_file)
        linenumber = matching.group(1)
        print('<p class="warning"><a href="{}">{}</a></p>'.format(
              make_link(filepath, linenumber), line))
        self.marks.append((filepath, linenumber, 'warning', line))
        self.number_warnings += 1

    def handle_error(self, matching, line):
        filename = matching.group(1)
        linenumber = matching.group(2)
        description = matching.group(3)
        filepath = join(getcwd(), filename)
        print('<p class="error">Latex Error: <a href="' +
              '{}">{}:{}</a> {}</p>'.format(make_link(filepath, linenumber),
                                            filename, linenumber, description))
        self.marks.append((filepath, linenumber, 'error', description))
        self.number_errors += 1
        if search('Fatal error', description):
            self.fatal_error = True

    def handle_old_style_errors(self, matching, line):
        if search('[Ee]rror', line):
            print('<p class="error">{}</p>'.format(line))
            self.number_errors += 1
        else:
            print('<p class="warning">{}</p>'.format(line))
            self.number_warnings += 1

    def pdf_latex_error(self, matching, line):
        self.number_errors += 1
        print ('<p class="error">'.format(line))
        line = self.input_stream.readline()
        if line and match('^ ==> Fatal error occurred', line):
            print('{}'.format(line.rstrip('\n')))
            self.fatal_error = True
        elif line:
            print('<pre>{}</pre>'.format(line.rstrip('\n')))
        print('</p>')
        stdout.flush()

    def warning(self, matching, line):
        # We might have gotten here by matching $1 of the following regex:
        #   (LaTeX Warning:.*) ?input line (\d+)(\.|$)
        # Lets read the next line and check if we find the remaining regex
        # pattern
        next_line = self.input_stream.readline().strip('\n')
        match_next_line = match('.*?input line (\d+)(\.|$)', next_line)
        if match_next_line:
            return (self.handle_warning(match_next_line,
                                        '{} {}'.format(line, next_line)))
        else:
            # We discard `next_line` here in the hope that it did not contain
            # any essential information.
            return super(LaTexParser, self).warning(matching, line)

    def finish_run(self, matching, line):
        filename = matching.group(2).strip('"')
        filepath = make_link(join(getcwd(), filename))
        print('<p>Complete transcript is in <a href="{}">{}</a></p>'.format(
              filepath, filename))
        print('</div>') #Latex div
        
        self.done = True 

    def bad_run(self):
        logfile = basename(self.filename)
        logfile = logfile.replace(self.suffix, 'log')
        logpath = join(getcwd(), logfile)
        print('<p class="error">A fatal error occurred, log file is in ' +
              '<a href="{}">{}</a></p>'.format(make_link(logpath, logfile),
                                               logfile))


class LaTexMkParser(TexParser):
    """Parse log messages from latexmk."""

    def __init__(self, input_stream, verbose, filename, use_pvc, round_finished):
        """Initialize the regex patterns for the LaTexMkParser.
           The parameter use_pvc is a boolean indicating whether 
           the -pvc option should be passed to latexmk.
           round_finished is a callback function executed after each round of latexmk
        """
        super(LaTexMkParser, self).__init__(input_stream, verbose)
        self.filename = filename
        self.use_pvc = use_pvc
        self.round_finished = round_finished
        self.marks = []
        self.patterns.extend([
            (compile('This is (pdfTeX|latex2e|latex|LuaTeX|XeTeX)'),
             self.start_latex),
            (compile('This is BibTeX'), self.start_bibtex),
            (compile('.*This is Biber'), self.start_biber),
            #(compile('^Latexmk: All targets \(.*?\) are up-to-date'),
            #  self.finish_run),
            (compile('^Latexmk: Log file says output to'), self.finish_run),
            (compile('This is makeindex'), self.start_bibtex),
            (compile('^Latexmk'), self.latexmk),
            (compile('Run number'), self.new_run)
        ])
        self.number_runs = 0

    def parse_stream(self):
        """Parse log messages from latexmk.

        Examples:

            >>> status = None
            >>> filepath = 'Tests/Log/latexmk_makeindex.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = LaTexMkParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <p class="ltxmk">Latexmk: This is Latexmk,...</p>
            ...This is pdfTeX...
            ...This is makeindex...
            ...This is pdfTeX...
            ...
            ...All targets (makeindex.pdf) are up-to-date...
            >>> status
            (False, 0, 0)
            >>> parser.done
            True

            >>> filepath = 'Tests/Log/latexmk_external_bibliography_biber.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = LaTexMkParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <p class="ltxmk">Latexmk: This is Latexmk...
            ...This is pdfTeX...
            ...This is Biber...
            ...This is pdfTeX...
            ...This is pdfTeX...
            ...All targets...are up-to-date...
            >>> status
            (False, 0, 0)
            >>> parser.number_runs
            4
            >>> parser.done
            True

            >>> filepath = 'Tests/Log/latexmk_external_bibliography.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = LaTexMkParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <p class="ltxmk">Latexmk: This is Latexmk...
            ...This is pdfTeX...
            ...This is BibTeX...
            ...This is pdfTeX...
            ...This is pdfTeX...
            ...All targets...are up-to-date...
            >>> status
            (False, 0, 0)
            >>> parser.done
            True

        """
        return super(LaTexMkParser, self).parse_stream()

    def start_bibtex(self, matching, line):
        print('<div class="bibtex"><h3>{}</h3>'.format(line[:-1]))
        parser = BibTexParser(self.input_stream, self.verbose)
        fatal_error, number_errors, number_warnings = parser.parse_stream()
        self.number_errors += number_errors
        self.number_warnings += number_warnings

    def start_biber(self, matching, line):
        print('<div class="biber"><h3>{}</h3>'.format(line))
        parser = BiberParser(self.input_stream, self.verbose)
        fatal_error, number_errors, number_warnings = parser.parse_stream()
        self.number_errors += number_errors
        self.number_warnings += number_warnings

    def start_latex(self, matching, line):
        print('<div class="latex"><hr><h3>{}</h3>'.format(line[:-1]))
        parser = LaTexParser(self.input_stream, self.verbose, self.filename)
        fatal_error, number_errors, number_warnings = parser.parse_stream()
        self.number_errors += number_errors
        self.number_warnings += number_warnings
        self.marks = parser.marks

    def new_run(self, matching, line):
        if self.number_runs > 0:
            print('<hr><p> {} Errors {} Warnings in this run.</p>'.format(
                self.number_errors, self.number_warnings))
        self.number_warnings = 0
        self.number_errors = 0
        self.number_runs += 1

    def finish_run(self, matching, line):
        self.latexmk(matching, line)

        if self.use_pvc: #never finish running
            self.round_finished(self, self.fatal_error, self.number_errors, self.number_warnings)
            
        else:
            self.done = True


    def latexmk(self, matching, line):
        print('<p class="ltxmk">{}</p>'.format(line))


class ChkTexParser(TexParser):
    """Parse the output from chktex."""

    def __init__(self, input_stream, verbose, filename):
        """Initialize the regex patterns for the ChkTexParser."""
        super(ChkTexParser, self).__init__(input_stream, verbose)
        self.fileName = filename
        self.patterns.extend([
            (compile('^ChkTeX'), self.info),
            (compile('Warning \d+ in (.*.tex) line (\d+):(.*)'),
             self.handle_warning),
            (compile('Error \d+ in (.*.tex) line (\d+):(.*)'),
             self.handle_error),
            (compile('(\d+) errors printed; (\d+) warnings printed;'),
             self.finish_run)
        ])
        self.number_runs = 0

    def parse_stream(self):
        r"""Parse log messages from chktex.

        Examples:

            >>> status = None
            >>> filepath = 'Tests/Log/chktex.log'
            >>> with open(filepath) as log: # doctest:+ELLIPSIS
            ...                             # doctest:+NORMALIZE_WHITESPACE
            ...     parser = ChkTexParser(log, False, filepath)
            ...     status = parser.parse_stream()
            <p class="info">ChkTeX ...</p>
            <p class="warning">Warning:
                <a href="...makeglossaries.tex&line=4">makeglossaries.tex:
                Command terminated with space.</a></p>
            <pre>        \makeglossaries
                                       ^</pre>
            ...
            <p class="error">Error:
                <a href="...dodo.tex&line=4">dodo.tex: Could not find argument
                for command.</a></p>
            <pre>         \verb*!something!
                     ^^^^^</pre>
            >>> status
            (False, 1, 2)
            >>> parser.done
            True

        """
        return super(ChkTexParser, self).parse_stream()

    def handle(self, matching, line, error_class='warning'):
        filename = matching.group(1)
        linenumber = matching.group(2)
        description = matching.group(3)
        print('<p class="{}">{}: <a href="{}">{}:{}</a></p>'.format(
              error_class, 'Error' if error_class == 'error' else 'Warning',
              make_link(join(getcwd(), filename), linenumber), filename,
              description))
        details = self.input_stream.readline()
        if len(details) > 2:
            print('<pre>{}\n{}</pre>'.format(details[:-1],
                  self.input_stream.readline()[:-1])),
        if error_class == 'error':
            self.number_errors += 1
        else:
            self.number_warnings += 1

    def handle_warning(self, matching, line):
        self.handle(matching, line)

    def handle_error(self, matching, line):
        self.handle(matching, line, 'error')

    def finish_run(self, matching, line):
        self.done = True

if __name__ == '__main__':

    parser = ArgumentParser(
        description='Parse output from latexmk.')
    parser.add_argument(
        'logfile', type=FileType('r'),
        help="""The location of the log file that should be parsed. Use -
                to read from STDIN.""")
    parser.add_argument(
        'file',
        help="""The location of the (master) tex file without its extension.
                This has to be the file from which the output in `logfile` was
                generated.""")
    arguments = parser.parse_args()
    logfile = arguments.logfile
    texfile = '{}.tex'.format(arguments.file)
    cachefile = '{}/.{}.lb'.format(dirname(arguments.file),
                                   basename(arguments.file))

    texparser = LaTexMkParser(logfile, verbose=False, filename=texfile)
    texparser.parse_stream()
    update_marks(cachefile, texparser.marks)
