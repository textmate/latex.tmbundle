package Latex;

use strict;
use warnings;

use Carp qw( croak );
use Exporter qw(import);

our @EXPORT_OK = qw(guess_tex_engine);

# Guess the TeX engine which should be used to translate a certain TeX-file.
#
# Arguments:
#
#      filepath - The file path to the TeX file either as absolute path or
#                 relative to the location of this file
#
# Returns:
#
#      A string containing the TeX engine for the given file or an empty
#      string if the engine could not be determined
#
# Example:
#
#   We assume `test.tex` contains the line `%!TEX TS-program = pdflatex`
#   $ guess_tex_engine(test.tex)
#   "pdflatex"
#
sub guess_tex_engine {
    my ($filename) = @_;
    open( my $fh, "<", $filename )
      or croak "Can not open $filename: $!";
    my $engine = _get_engine_from_file($fh);
    close($fh);
    return $engine;
}

sub _get_engine_from_file {
    my ($fh) = @_;
    my $engine = "";

    # TS-program is case insensitive e.g. `LaTeX` should be the same as `latex`
    my $engines = "(?i)latex|lualatex|pdflatex|xelatex(?-i)";

    while ( my $line = <$fh> ) {
        if ( $line =~
            m{%!TEX (?:\s+) (?:TS-)program (?:\s*)=(?:\s*) ($engines)}x )
        {
            $engine = lc($1);
            last;
        }
    }
    return $engine

}

1;
