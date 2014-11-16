#!/usr/bin/env python

from os import popen4
from tmprefs import Preferences

prefs = Preferences()
command = ('"$DIALOG" -mp "" -d \'{}\' '.format(prefs.defaults) +
           '"$TM_BUNDLE_SUPPORT"/nibs/tex_prefs.nib')
popen4(command)
