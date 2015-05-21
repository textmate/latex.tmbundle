-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../../TeX/

-- Tests ----------------------------------------------------------------------

  $ TM_FILEPATH="external_bibliography.tex"

  $ texmate.py version -engine latex
  pdfTeX .* (re)

  $ texmate.py version packages.tex
  XeTeX .* (re)
