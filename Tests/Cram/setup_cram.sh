#!/usr/bin/env sh

# -----------------------------------------------------------------------------
# Author:    René Schwaiger (sanssecours@f-m.fm)
# Date:      2015-01-02
# Version:   3
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

auxiliary_files_regex='./(aux|acr|alg|bbl|bcf|blg|fdb_latexmk|fls|fmt|glg|gls|'
auxiliary_files_regex+='ini|log|out|maf|mtc|mtc1|pdfsync|run.xml|synctex.gz|'
auxiliary_files_regex+='toc)'

# -- Aliases ------------------------------------------------------------------

# Remove leading and trailing whitespace
alias strip="sed -e 's/^ *//' -e 's/ *$//'"
alias countlines="wc -l | strip"
alias exit_success_or_discard="echo $? | grep -E '^0|200$' > /dev/null"
alias restore_aux_files_git='git checkout *.acn *.aux *.bcf *.glo *.idx *.ist'
