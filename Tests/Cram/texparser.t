-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ source setup_cram.sh
  $ cd ../TeX/

-- Tests ----------------------------------------------------------------------

  $ texparser.py ../Log/ünicöde.log ünicöde.tex | \
  >  grep '15.*Undefined control sequence.' > /dev/null
