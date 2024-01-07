-- Setup -----------------------------------------------------------------------

  $ source "${TESTDIR}/setup.sh"
  $ cp "${TEX_DIRECTORY}/makeglossaries.tex" .

-- Test ------------------------------------------------------------------------

Create some auxiliary files

  $ latexmk -pdf makeglossaries.tex 2>&- | trim | 
  > tail -n 1
  Latexmk: All targets (.+) are up-to-date (re)

Delete all auxiliary files in the current directory

  $ clean.rb
  makeglossaries.acn
  makeglossaries.aux
  makeglossaries.fdb_latexmk
  makeglossaries.fls
  makeglossaries.glo
  makeglossaries.ist
  makeglossaries.log

The folder now only contains the PDF and the TeX file

  $ ls
  makeglossaries.pdf
  makeglossaries.tex
