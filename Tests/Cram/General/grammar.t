-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ cd ../../..

  $ BUNDLE_DIR="$HOME/Library/Application Support/TextMate/Managed/Bundles"
  $ PYTHON_GRAMMAR_DIR="${BUNDLE_DIR}/Python.tmbundle/Syntaxes"
  $ JS_GRAMMAR_DIR="${BUNDLE_DIR}/JavaScript.tmbundle/Syntaxes"

-- Tests -----------------------------------------------------------------------

  $ gtm < Tests/TeX/text.tex Syntaxes/LaTeX.plist Syntaxes/TeX.plist           \
  > "${PYTHON_GRAMMAR_DIR}"/{Python,"Regular Expressions (Python)"}.tmlanguage \
  > "${BUNDLE_DIR}/SQL.tmbundle/Syntaxes/SQL.plist"                            \
  > "${BUNDLE_DIR}/Java.tmbundle/Syntaxes/Java.plist"                          \
  > "${BUNDLE_DIR}/JavaDoc.tmbundle/Syntaxes/JavaDoc.tmLanguage"               \
  > "${BUNDLE_DIR}/HTML.tmbundle/Syntaxes/HTML.plist"                          \
  > "${BUNDLE_DIR}/CSS.tmbundle/Syntaxes/CSS.plist"                            \
  > "${JS_GRAMMAR_DIR}/JavaScript.plist"                                       \
  > "${JS_GRAMMAR_DIR}/Regular Expressions (JavaScript).tmLanguage"            \
  > "${BUNDLE_DIR}/R.tmbundle/Syntaxes/R.plist" > /dev/null

