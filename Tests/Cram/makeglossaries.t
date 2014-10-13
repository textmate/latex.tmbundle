-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

  $ TM_FILEPATH="makeglossaries.tex"

Translate the file to create the files needed by `makeglossaries`

  $ output=`texMate.py latex | grep "Output written" | countlines`
  $ if [ $output -ge 1 ]; then echo 'OK'; fi
  OK

Generate the index for the file

  $ texMate.py index | grep "Output written in .*.gls" | countlines
  1

Check if clean removes all auxiliary files.

  $ texMate.py clean > /dev/null
  $ ls | grep $auxiliary_files_regex
  [1]

-- Cleanup --------------------------------------------------------------------

Restore the file changes made by previous commands.

  $ git checkout *.aux *.bcf *.ist

Remove the generated PDF files

  $ rm -f *.pdf

