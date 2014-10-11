#!/usr/bin/env sh

# -----------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2014-10-12
# Version:   1
#
# This script setups common variables and aliases for the cram tests inside
# this directory
# -----------------------------------------------------------------------------

# -- Variables ----------------------------------------------------------------

BUNDLE_DIR="$TESTDIR/../.."
TM_BUNDLE_DIR="$HOME/Library/Application Support/TextMate/Managed/Bundles"

export TM_SUPPORT_PATH="$TM_BUNDLE_DIR/Bundle Support.tmbundle/Support/shared"
export TM_BUNDLE_SUPPORT="$BUNDLE_DIR/Support"
export PATH="$BUNDLE_DIR/Support/bin":$PATH
export TM_SELECTION='1:1'

auxiliary_files_regex='(.aux)|(.bbl)|(.bcf)|(.blg)|(.fdb_latexmk)|(.fls)'
auxiliary_files_regex+='|(.fmt)|(.ini)|(.log)|(.out)|(.maf)|(.mtc)|(.mtc1)'
auxiliary_files_regex+='|(.pdfsync)|(.run.xml)|(.synctex.gz)|(.toc)'

# -- Aliases ------------------------------------------------------------------

# Remove leading and trailing whitespace
alias strip="sed -e 's/^ *//' -e 's/ *$//'"
alias countlines="wc -l | strip"
