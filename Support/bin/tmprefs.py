import os
import newplistlib as plistlib

from Foundation import NSDictionary
from subprocess import PIPE, STDOUT, Popen

# The preference file for textmate to retrieve the prefs from
if os.environ.has_key('TM_APP_IDENTIFIER'):
    TM_PREFERENCE_FILE = os.environ['TM_APP_IDENTIFIER'] + '.plist'
else:
    TM_PREFERENCE_FILE = 'com.macromates.textmate.plist'

class Preferences(object):
    """docstring for Preferences"""
    def __init__(self):
        super(Preferences, self).__init__()
        self.defaults = {
            'latexAutoView' : 1,
            'latexEngine' : "pdflatex",
            'latexEngineOptions' : "",
            'latexVerbose' : 0,
            'latexUselatexmk' : 0,
            'latexViewer' : "TextMate",
            'latexKeepLogWin' : 1,
            'latexDebug' : 0,
        }
        self.prefs = self.defaults.copy()
        self.prefs.update(self.readTMPrefs())

    def __getitem__(self,key):
        """docstring for __getitem__"""
        return self.prefs.get(key,None)

    def readTMPrefs(self):
        """readTMPrefs reads the textmate preferences file and constructs a python dictionary.
        The keys that are important for latex are as follows:
        latexAutoView = 0
        latexEngine = pdflatex
        latexEngineOptions = "-interaction=nonstopmode -file-line-error-style"
        latexUselatexmk = 0
        latexViewer = Skim
        """
        return NSDictionary.dictionaryWithContentsOfFile_(os.environ["HOME"]+"/Library/Preferences/" + TM_PREFERENCE_FILE)

    def toDefString(self):
        """docstring for toDefString"""
        instr = plistlib.writePlistToString(self.defaults)
        runObj = Popen('pl',shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        runObj.stdin.write(instr)
        runObj.stdin.close()
        defstr = runObj.stdout.read()
        return defstr.replace("\n","")

if __name__ == '__main__':
    test = Preferences()
    print test.toDefString()
    print test['latexUselatexmk']
    print test['Foo']
    useLatexMk = test['latexUselatexmk']
    print useLatexMk


