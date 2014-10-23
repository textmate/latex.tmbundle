-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

Just try to translate the program using `latex`

  $ texmate.py -suppressview latex -latexmk no -engine lualatex lualatex.tex \
  > | grep 'Output written' |  countlines
  1

Check if clean removes all auxiliary files.

  $ texmate.py clean lualatex.tex > /dev/null
  $ ls | grep -E $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Remove the generated PDF files

  $ rm -f *.pdf
