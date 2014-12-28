# -----------------------------------------------------------------------------
# Date:    2014-12-14
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 10
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

.PHONY: run all clean cramtests nosetests latex_watch

# -- Variables -----------------------------------------------------------------

# We need to set the bundle support location to the support folder of the LaTeX
# bundle. If we do not set this variable explicitly, then `TM_BUNDLE_SUPPORT`
# will be set to the location of the bundle support folder for the `Make`
# bundle. This will lead to errors since `latex_watch` expects that
# `TM_BUNDLE_SUPPORT` is set “correctly”.
export TM_BUNDLE_SUPPORT = $(CURDIR)/Support

# -- Rules --------------------------------------------------------------------

run: all

all: nosetests cramtests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.dvi *.fdb_latexmk *.fls \
		*.glg *.gls *.ilg *.ind *.log *.ps *.pdf

nosetests:
	nosetests --with-doctest 	 \
		Support/bin/itemize.py   \
		Support/bin/texmate.py   \
		Support/bin/texparser.py \
		Support/bin/tmprefs.py

cramtests: clean
	cd Tests/Cram && cram *.t

latex_watch:
	TM_PID=$(shell pgrep TextMate)
	Support/bin/latex_watch.pl -d --textmate-pid=$(TM_PID) \
		"$(CURDIR)/Tests/TeX/makeindex.tex"
