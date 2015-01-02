# ------------------------------------------------------------------------------
# Date:    2015-01-02
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 11
#
#                   Run various tests for this bundle
#
# To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the following test frameworks:
#
# - [nose](http://nose.readthedocs.org)
# - [cram](https://bitheap.org/cram/)
# - [rubydoctest](https://github.com/tablatom/rubydoctest)
#
# For all tests to work correctly you also need to install “Skim” inside
# the folder `/Applications`.
# ------------------------------------------------------------------------------

.PHONY: all clean latex_watch cramtests nosetests rubydoctests

# -- Variables -----------------------------------------------------------------

# We need to set the bundle support location to the support folder of the LaTeX
# bundle. If we do not set this variable explicitly, then `TM_BUNDLE_SUPPORT`
# will be set to the location of the bundle support folder for the `Make`
# bundle. This will lead to errors since `latex_watch` expects that
# `TM_BUNDLE_SUPPORT` is set “correctly”.
export TM_BUNDLE_SUPPORT = $(CURDIR)/Support

# -- Rules ---------------------------------------------------------------------

run: all

all: nosetests rubydoctests cramtests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.dvi *.fdb_latexmk *.fls \
		*.glg *.gls *.ilg *.ind *.log *.ps *.pdf

# ================
# = Manual Tests =
# ================

latex_watch:
	TM_PID=$(shell pgrep TextMate)
	Support/bin/latex_watch.pl -d --textmate-pid=$(TM_PID) \
		"$(CURDIR)/Tests/TeX/makeindex.tex"

# ===================
# = Automated Tests =
# ===================

cramtests: clean
	cd Tests/Cram && cram *.t

nosetests:
	nosetests --with-doctest 	 \
		Support/bin/itemize.py   \
		Support/bin/texmate.py   \
		Support/bin/texparser.py \
		Support/bin/tmprefs.py

rubydoctests:
	rubydoctest Support/bin/format_table.rb
