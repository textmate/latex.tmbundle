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

  $ texmate.py view > /dev/null

Check if clean removes all auxiliary files.

  $ texmate.py clean > /dev/null
  $ ls | grep -E $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Restore the file changes made by previous commands.

  $ restore_aux_files_git

Remove the generated files

  $ rm -f *.ilg *.ind *.pdf


