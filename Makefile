# -----------------------------------------------------------------------------
# Date:    2014-10-15
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 7
#
# Run tests for this bundle. To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the nose test framework (http://nose.readthedocs.org) and
# cram (https://bitheap.org/cram/). For all tests to work correctly you also
# need to install “Skim” inside `/Applications`
# -----------------------------------------------------------------------------

.PHONY: run all clean cramtests nosetests

# -- Rules --------------------------------------------------------------------

run: cramtests

all: nosetests cramtests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.dvi *.fdb_latexmk *.fls \
		*.glg *.gls *.ilg *.ind *.log *.ps *.pdf

nosetests:
	nosetests --with-doctest Support/bin/texmate.py Support/bin/texparser.py

cramtests: clean
	cd Tests/Cram && cram *.t
