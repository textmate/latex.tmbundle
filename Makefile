# ------------------------------------------------------------------------------
# Date:    2015-01-20
# Author:  René Schwaiger (sanssecours@f-m.fm)
# Version: 18
#
#                   Run various tests for this bundle
#
# To execute the tests:
#
#   1. Open the root folder of this bundle inside TextMate
#   2. Run the command “Build” (⌘B) located inside the Make bundle
#
# The tests require the following test frameworks:
# - [tox](https://tox.readthedocs.org)
# - [cram](https://bitheap.org/cram/)
# - [nose](http://nose.readthedocs.org)
# - [rubydoctest](https://github.com/tablatom/rubydoctest)
#
# For all tests to work correctly you also need to install “Skim” inside
# the folder `/Applications`.
# ------------------------------------------------------------------------------

.PHONY: all clean checkstyle latex_watch cramtests nosetests rubydoctests \
		toxtests

# -- Variables -----------------------------------------------------------------

# We need to set the bundle support location to the support folder of the LaTeX
# bundle. If we do not set this variable explicitly, then `TM_BUNDLE_SUPPORT`
# will be set to the location of the bundle support folder for the `Make`
# bundle. This will lead to errors since `latex_watch` expects that
# `TM_BUNDLE_SUPPORT` is set “correctly”.
export TM_BUNDLE_SUPPORT = $(CURDIR)/Support

BINARY_DIRECTORY = Support/bin
LIBRARY_DIRECTORY = Support/lib

# -- Rules ---------------------------------------------------------------------

run: all

all: toxtests cramtests_non_python rubydoctests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.dvi *.fdb_latexmk *.fls \
		*.glg *.gls *.ilg *.ind *.log *.ps *.pdf

# ================
# = Style Checks =
# ================

checkstyle: checkstyle_python

checkstyle_python:
	flake8 $(BINARY_DIRECTORY)/*.py $(LIBRARY_DIRECTORY)/*.py

# ================
# = Manual Tests =
# ================

latex_watch:
	TM_PID=$(shell pgrep TextMate)
	$(BINARY_DIRECTORY)/latex_watch.pl -d --textmate-pid=$(TM_PID) \
		"$(CURDIR)/Tests/TeX/makeindex.tex"

# ===================
# = Automated Tests =
# ===================

cramtests: clean
	cd Tests/Cram && cram *.t

cramtests_non_python:
	cd Tests/Cram && cram check_filenames.t

nosetests: checkstyle_python
	nosetests --with-doctest $(LIBRARY_DIRECTORY)/*.py $(BINARY_DIRECTORY)/*.py

rubydoctests:
	rubydoctest Support/lib/format_table.rb

toxtests: checkstyle_python
	tox
