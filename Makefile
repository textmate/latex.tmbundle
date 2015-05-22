# ------------------------------------------------------------------------------
# Author: René Schwaiger (sanssecours@f-m.fm)
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
# For all tests to work correctly you also need to install:
# 1. “Skim” inside the folder `/Applications` and
# 2. [gtm](http://lists.macromates.com/textmate/2010-May/030881.html) in a
# 	 location accessible via `PATH`.
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
RUBY_FILES = Support/lib/command.rb Support/lib/format_table.rb \
			 Support/lib/latex.rb

# -- Rules ---------------------------------------------------------------------

run: all

all: toxtests cramtests_general perltests rubydoctests

clean:
	cd Tests/TeX && rm -vf *.acr *.alg *.bbl *.blg *.dvi *.fdb_latexmk *.fls \
		*.glg *.gls *.ilg *.ind *.log *.ps *.pdf

# ================
# = Style Checks =
# ================

checkstyle: checkstyle_python checkstyle_ruby

checkstyle_python:
	flake8 $(BINARY_DIRECTORY)/*.py $(LIBRARY_DIRECTORY)/*.py

checkstyle_ruby:
	rubocop $(RUBY_FILES)

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

cramtests_python: clean
	cd Tests/Cram/Python && cram *.t

cramtests_general:
	cd Tests/Cram/General && cram *.t

nosetests: checkstyle_python
	nosetests --with-doctest $(LIBRARY_DIRECTORY)/*.py $(BINARY_DIRECTORY)/*.py

perltests:
	perl Tests/Perl/*.t

rubydoctests: checkstyle_ruby
	rubydoctest $(RUBY_FILES)

toxtests: checkstyle_python
	tox
