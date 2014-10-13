-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

  $ TM_FILEPATH="external_bibliography.tex"

If we check the tex file with `chktex` we should not get any warning at all.
This means grep will fail and therefore return the status value 1.

  $ texmate.py 'chktex' | grep 'Warning'
  [1]
