#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2015-01-18
# Version:   1
#
#           Run nose tests for all Python commands
#
# ------------------------------------------------------------------------------

nosetests --with-doctest     \
    Support/lib/*.py         \
    Support/bin/configure.py \
    Support/bin/texmate.py   \
    Support/bin/texparser.py
