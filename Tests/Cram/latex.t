-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

  $ TM_FILEPATH="external_bibliography.tex"

Just try to translate the program using `latex`

  $ output=`texMate.py latex | grep 'Output written' | countlines`
  $ if [ $output -ge 1 ]; then echo 'OK'; fi
  OK

We use 3 runs to process a file.

  $ texMate.py builtin | grep 'Output written' | countlines
  3

We try to process the files using `latexmk`.

  $ texMate.py latexmk | grep -e 'All .* up-to-date' | countlines
  1

If we check the tex file with `chktex` we should not get any warning at all.
This means grep will fail and therefore return the status value 1.

  $ texMate.py 'chktex' | grep 'Warning'
  [1]

Check if clean removes all auxiliary files.

  $ texMate.py clean > /dev/null
  $ ls | grep $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Restore the file changes made by previous commands.

  $ git checkout *.aux *.bcf

Remove the generated PDF files

  $ rm -f *.pdf
