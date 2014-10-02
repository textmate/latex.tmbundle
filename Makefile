# -----------------------------------------------------------------------------
# Date:    2014-10-02
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 1
#
# Run tests for this bundle. To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the nose test framework (http://nose.readthedocs.org).
#
# -----------------------------------------------------------------------------

.PHONY: run test

# -- Rules --------------------------------------------------------------------

run: test

test:
	nosetests --with-doctest Support/bin/texMate.py
