-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

  $ TM_FILEPATH="external_bibliography.tex"

Generate the PDF

  $ makeindex "$TM_FILEPATH" >/dev/null 2>&1
  $ pdflatex "$TM_FILEPATH" >/dev/null 2>&1

-- Tests ----------------------------------------------------------------------

Check if opening the PDF works with the current viewer

  $ texMate.py view > /dev/null

Check if clean removes all auxiliary files.

  $ texMate.py clean > /dev/null
  $ ls | grep $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Restore the file changes made by previous commands.

  $ git checkout *.aux *.bcf *.ist

Remove the generated PDF files

  $ rm -f *.pdf


