-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ cd ../../../

  $ TM_PID=$(pgrep -a TextMate)
  $ CURRENT_DIR=$(pwd)
  $ LOGFILE="/tmp/latex_watch_test.log"
  $ TEX_DIR="Tests/TeX/"
  $ TEXFILE="${CURRENT_DIR}/${TEX_DIR}/makeindex.tex"
  $ PATH=$PATH:Support/bin/

-- Tests ----------------------------------------------------------------------

Run `latex_watch` and check if the log output of the command looks correct.

  $ latex_watch.pl -d --textmate-pid=${TM_PID} "${TEXFILE}" > "${LOGFILE}" &
  $ sleep 10
  $ pkill -n perl
  $ grep "Output written" "${LOGFILE}" > /dev/null
  $ grep -E "Executing\s+check_open" "${LOGFILE}" > /dev/null

-- Cleanup --------------------------------------------------------------------

  $ rm "${LOGFILE}"
  $ rm "${TEX_DIR}"/*.pdf
  $ git checkout "${TEX_DIR}"/*.idx
