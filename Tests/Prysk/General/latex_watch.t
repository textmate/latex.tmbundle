-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR"
  $ cd ../../../

  $ TM_PID=$(pgrep -a TextMate)
  $ CURRENT_DIR=$(pwd)
  $ FILENAME='makeindex'
  $ LOGFILE='/tmp/latex_watch_test.log'
  $ TEX_DIR="${CURRENT_DIR}/Tests/TeX"
  $ TEXFILE="${TEX_DIR}/${FILENAME}.tex"
  $ PATH=/Library/TeX/texbin:$PATH:Support/bin/

-- Tests ----------------------------------------------------------------------

Run `latex_watch` and check if the log output of the command looks correct.

  $ if [[ $(uname -r | cut -d "." -f 1) == 15 ]]; then # macOS 10.11
  >   latex_watch.pl -d --textmate-pid=${TM_PID} "${TEXFILE}" > "${LOGFILE}" \
  >     2> /dev/null  &
  > else
  >   latex_watch.pl -d --textmate-pid=${TM_PID} "${TEXFILE}" > "${LOGFILE}" &
  > fi
  $ LATEX_WATCH_PID=$!
  $ sleep 10 # Wait until `latex_watch` translated the document
  $ kill "$LATEX_WATCH_PID" # Close `latex_watch`
  $ sleep 1 # Wait until `latex_watch` terminates
  $ grep 'Output written' "${LOGFILE}" > /dev/null
  $ grep -E 'Executing\s+check_open' "${LOGFILE}" > /dev/null

-- Cleanup --------------------------------------------------------------------

  $ rm "${LOGFILE}"
  $ rm "${TEX_DIR}/${FILENAME}.pdf"
  $ git checkout -q "${TEX_DIR}/${FILENAME}.idx"
