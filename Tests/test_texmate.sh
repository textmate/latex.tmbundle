#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2014-10-05
# Version:   1
#
# This script can be used to test the functionality of `texMate`.
# -----------------------------------------------------------------------------

# -- Variables ----------------------------------------------------------------

BUNDLE_DIR="$HOME/Library/Application Support/Avian/Bundles/LaTeX.tmbundle"
TM_BUNDLE_DIR="$HOME/Library/Application Support/TextMate/Managed/Bundles"

export TM_SUPPORT_PATH="$TM_BUNDLE_DIR/Bundle Support.tmbundle/Support/shared"
export TM_BUNDLE_SUPPORT="$BUNDLE_DIR/Support"
export TM_FILEPATH="$BUNDLE_DIR/Tests/external_bibliography.tex"
export PATH="$BUNDLE_DIR/Support/bin":$PATH
export TM_SELECTION='1:1'

# -- Main ---------------------------------------------------------------------

texMate.py builtin
texMate.py clean
texMate.py latexmk
