# -- Imports ------------------------------------------------------------------

from Foundation import NSDictionary
from os import environ
from newplistlib import writePlistToString
from subprocess import PIPE, STDOUT, Popen


# -- Class --------------------------------------------------------------------

class Preferences(object):
    """Process the current preferences of the LaTeX bundle.

    This class reads the LaTeX preferences and provides a dictionary-like
    interface to process them.

    """

    def __init__(self):
        """Create a new Preferences object from the current settings.

        Examples:

            >>> preferences = Preferences()
            >>> keys = ['latexViewer', 'latexEngine', 'latexUselatexmk',
            ...         'latexVerbose', 'latexDebug', 'latexAutoView',
            ...         'latexKeepLogWin', 'latexEngineOptions']
            >>> all([key in preferences.prefs for key in keys])
            True

        """
        tm_preference_file = ('{}.plist'.format(environ['TM_APP_IDENTIFIER'])
                              if 'TM_APP_IDENTIFIER' in environ
                              else 'com.macromates.textmate.plist')
        self.default_values = {
            'latexAutoView': 1,
            'latexEngine': "pdflatex",
            'latexEngineOptions': "",
            'latexVerbose': 0,
            'latexUselatexmk': 0,
            'latexViewer': "TextMate",
            'latexKeepLogWin': 1,
            'latexDebug': 0,
        }
        self.prefs = self.default_values.copy()
        tm_prefs = NSDictionary.dictionaryWithContentsOfFile_(
            "{}/Library/Preferences/{}".format(environ["HOME"],
                                               tm_preference_file))
        # Only save the values we really need
        for key in self.prefs:
            if key in tm_prefs:
                self.prefs[key] = tm_prefs[key]

    def __getitem__(self, key):
        """Return a value stored inside Preferences.

        If the value is no defined then ``None`` will be returned.

        Arguments:

            key

                The key of the value that should be returned

        Examples:

            >>> preferences = Preferences()
            >>> preferences['latexEngine'].find('tex') >= 0
            True
            >>> isinstance(preferences['latexUselatexmk'], bool)
            True

        """
        return self.prefs.get(key, None)

    def defaults(self):
        """Return a string containing the default preference values.

        Returns: ``str``

        Examples:

            >>> preferences = Preferences()
            >>> preferences.defaults() # doctest:+NORMALIZE_WHITESPACE
            '{ latexAutoView = 1;
               latexDebug = 0;
               latexEngine = pdflatex;
               latexEngineOptions = "";
               latexKeepLogWin = 1;
               latexUselatexmk = 0;
               latexVerbose = 0;
               latexViewer = TextMate;}'

        """
        instr = writePlistToString(self.default_values)
        process = Popen('pl', shell=True, stdout=PIPE, stdin=PIPE,
                        stderr=STDOUT, close_fds=True)
        process.stdin.write(instr)
        process.stdin.close()
        defstr = process.stdout.read()
        return defstr.replace('\n', '')

if __name__ == '__main__':
    from doctest import testmod
    testmod()
