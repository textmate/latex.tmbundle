-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

  $ TM_FILEPATH="makeindex.tex"

Generate the index for the file

  $ texmate.py index | grep 'Output written' | countlines
  1

Translate the LaTeX file

  $ texmate.py -s latex -e pdflatex -l no | grep 'Output written' | countlines
  1

-- Cleanup --------------------------------------------------------------------

Remove the generated PDF files

  $ rm -f *.pdf

