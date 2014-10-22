-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX

-- Tests ----------------------------------------------------------------------

  $ texmate.py version -engine latex
  pdfTeX .* (re)

  $ texmate.py version packages.tex
  XeTeX .* (re)
