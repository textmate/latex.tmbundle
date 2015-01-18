#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2015-01-18
# Version:   1
#
#           Run cram tests for all Python commands
#
# This script will be called by `tox` to test the bundle commands written in
# Python using different versions of `python`.
#
# ------------------------------------------------------------------------------

find Tests/Cram -name '*.t' -type f -not -name 'check_filenames.t' \
    -exec cram '{}' +
