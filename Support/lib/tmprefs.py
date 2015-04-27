# -- Imports ------------------------------------------------------------------

from __future__ import print_function
from __future__ import unicode_literals

from Foundation import CFPreferencesAppSynchronize, CFPreferencesCopyAppValue
from os import getenv


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
        tm_identifier = (
            getenv('TM_APP_IDENTIFIER') if getenv('TM_APP_IDENTIFIER') else
            'com.macromates.textmate')
        CFPreferencesAppSynchronize(tm_identifier)

        self.default_values = {
            'latexAutoView': 1,
            'latexEngine': "pdflatex",
            'latexEngineOptions': "",
            'latexVerbose': 0,
            'latexUselatexmk': 1,
            'latexViewer': "TextMate",
            'latexKeepLogWin': 1,
            'latexDebug': 0,
        }
        self.prefs = self.default_values.copy()

        for key in self.prefs:
            preference_value = CFPreferencesCopyAppValue(key, tm_identifier)
            if preference_value is not None:
                self.prefs[key] = preference_value

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
            >>> print(preferences.defaults()) # doctest:+NORMALIZE_WHITESPACE
            { latexAutoView = 1;
              latexDebug = 0;
              latexEngine = pdflatex;
              latexEngineOptions = "";
              latexKeepLogWin = 1;
              latexUselatexmk = 1;
              latexVerbose = 0;
              latexViewer = TextMate; }

        """
        preference_items = [
            '{} = {};'.format(preference,
                              self.default_values[preference] if
                              str(self.default_values[preference]) else '""')
            for preference in sorted(self.default_values)]
        return '{{ {} }}'.format(' '.join(preference_items))


if __name__ == '__main__':
    from doctest import testmod
    testmod()
