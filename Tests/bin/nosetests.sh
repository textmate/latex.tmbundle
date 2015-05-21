#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Author:    Rene Schwaiger (sanssecours@f-m.fm)
#
#           Run nose tests for all Python commands
# ------------------------------------------------------------------------------

nosetests --with-doctest Support/lib/*.py Support/bin/*.py
