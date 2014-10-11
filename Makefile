# -----------------------------------------------------------------------------
# Date:    2014-10-11
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 6
#
# Run tests for this bundle. To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the nose test framework (http://nose.readthedocs.org) and
# cram (https://bitheap.org/cram/).
# -----------------------------------------------------------------------------

.PHONY: run all clean cramtests nosetests

# -- Rules --------------------------------------------------------------------

run: cramtests

all: nosetests cramtests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.fdb_latexmk *.fls *.glg \
		*.gls *.ilg *.ind *.log *.pdf

nosetests:
	nosetests --with-doctest Support/bin/texMate.py

cramtests: clean
	cd Tests/Cram && cram *.t
