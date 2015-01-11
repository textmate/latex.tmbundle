#!/usr/bin/env python2.7

# -- Imports ------------------------------------------------------------------

from subprocess import Popen, PIPE, STDOUT
from tmprefs import Preferences

# -- Main ---------------------------------------------------------------------

if __name__ == '__main__':
    prefs = Preferences()
    command = ('"$DIALOG" -mp "" -d \'{}\' '.format(prefs.defaults()) +
               '"$TM_BUNDLE_SUPPORT"/nibs/tex_prefs.nib')
    Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT)
