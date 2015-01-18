#!/usr/bin/env python

# -- Imports ------------------------------------------------------------------

from subprocess import Popen, PIPE, STDOUT

if __name__ == '__main__' and __package__ is None:
    from os import sys, path
    sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))

from lib.tmprefs import Preferences

# -- Main ---------------------------------------------------------------------

if __name__ == '__main__':
    prefs = Preferences()
    command = ('"$DIALOG" -mp "" -d \'{}\' '.format(prefs.defaults()) +
               '"$TM_BUNDLE_SUPPORT"/nibs/tex_prefs.nib')
    Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT)
