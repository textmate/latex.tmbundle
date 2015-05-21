-- Setup ----------------------------------------------------------------------

  $ cd "$TESTDIR";
  $ cd ../../..

-- Tests -----------------------------------------------------------------------

Check if the name of any file contains special/problematic characters. We do
this to make sure that the bundle can be cloned using operating systems which
do not support these characters (e.g. Windows).

  $ find -E . -regex '.*[<>:\(\)"\\\|\?\*].*'
