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

  $ output=`texmate.py latex | grep 'Output written' | countlines`
  $ if [ $output -ge 1 ]; then echo 'OK'; fi
  OK

-- Cleanup --------------------------------------------------------------------

Remove the generated PDF files

  $ rm -f *.pdf

