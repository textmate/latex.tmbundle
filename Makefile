# -----------------------------------------------------------------------------
# Date:    2014-10-05
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 2
#
# Run tests for this bundle. To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the nose test framework (http://nose.readthedocs.org).
#
# -----------------------------------------------------------------------------

.PHONY: run test test_texmate

# -- Rules --------------------------------------------------------------------

run: test

test:
	nosetests --with-doctest Support/bin/texMate.py

test_texmate:
	Tests/test_texmate.sh
