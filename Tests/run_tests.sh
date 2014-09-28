#! /bin/bash

# -----------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2014-09-27
# Version:   1
# 
# Run all tests contained in this bundle. The test suite currently requires 
# “nose” (https://nose.readthedocs.org) to be installed. To install nose use:
# 
#       sudo pip install nose
#
# -----------------------------------------------------------------------------

nosetests --with-doctest ../Support/bin/itemize.py
