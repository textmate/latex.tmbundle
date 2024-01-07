-- Setup -----------------------------------------------------------------------

  $ source "$TESTDIR/setup.sh"
  $ cp "$TEX_DIRECTORY/references.tex" \
  >    "$TEX_DIRECTORY/"{more_,}references.bib .
  $ mkdir input
  $ cp "$TEX_DIRECTORY/input/references_input.tex" input
  $ cp "$TEX_DIRECTORY/ünicöde.tex" .

-- Test ------------------------------------------------------------------------

Create some auxiliary files

  $ latexmk -lualatex references.tex 2>&- | trim| tail -n 1
  Latexmk: All targets (.*) are up-to-date (re)
  $ latexmk -xelatex ünicöde.tex 2>&- | trim | tail -n 1
  Latexmk: All targets (\xc3\xbcnic\xc3\xb6de.pdf) are up-to-date (esc)

Delete all auxiliary file created for references.tex

  $ clean.rb references.tex
  references.aux
  references.bbl
  references.bcf
  references.blg
  references.fdb_latexmk
  references.fls
  references.log
  references.run.xml

The directory still contains the auxiliary files for ünicöde.tex

  $ find . -name '*nic*de.*'
  ./\xc3\xbcnic\xc3\xb6de.log (esc)
  ./\xc3\xbcnic\xc3\xb6de.aux (esc)
  ./\xc3\xbcnic\xc3\xb6de.fls (esc)
  ./\xc3\xbcnic\xc3\xb6de.fdb_latexmk (esc)
  ./\xc3\xbcnic\xc3\xb6de.tex (esc)
  ./\xc3\xbcnic\xc3\xb6de.xdv (esc)
  ./\xc3\xbcnic\xc3\xb6de.pdf (esc)

Remove the remaining the auxiliary files

  $ clean.rb > /dev/null

The folder now only contains the DVID, PDF and TeX file

  $ ls
  input
  more_references.bib
  references.bib
  references.pdf
  references.tex
  \xc3\xbcnic\xc3\xb6de.pdf (esc)
  \xc3\xbcnic\xc3\xb6de.tex (esc)
  \xc3\xbcnic\xc3\xb6de.xdv (esc)
