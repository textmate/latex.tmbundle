-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

Test if using file names containing special characters works

  $ texmate.py -suppressview latex -latexmk yes -engine pdflatex \
  > c\'mplicated\ filename.tex | grep 'Output written' |  countlines
  1

Check if clean removes all auxiliary files.

  $ texmate.py clean c\'mplicated\ filename.tex > /dev/null
  $ ls | grep -E $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Restore the file changes made by previous commands.

  $ git checkout *.aux *.bcf

Remove the generated PDF

  $ rm -f *.pdf
