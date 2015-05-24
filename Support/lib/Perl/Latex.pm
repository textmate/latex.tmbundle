package Latex;

# -- Imports -------------------------------------------------------------------

use strict;
use warnings;

use Carp qw( croak );
use Exporter qw(import);

# -- Exports -------------------------------------------------------------------

our @EXPORT_OK = qw(guess_tex_engine tex_directives);

# -- Functions -----------------------------------------------------------------

# Guess the TeX engine which should be used to translate a certain TeX-file.
#
# Arguments:
#
#      filepath - The file path of the TeX file.
#
# Returns:
#
#      A string containing the TeX engine for the given file or an empty
#      string if the engine could not be determined.
#
sub guess_tex_engine {
    my ($filename) = @_;
    my $engine     = "";
    my %directives = tex_directives($filename);

    $engine = $directives{"program"} if ( exists $directives{"program"} );
    return $engine;
}

# Read `%! TEX` directives from a given file.
#
# Arguments:
#
#      filepath - The file path of the TeX file.
#
# Returns:
#
#      A hash containing the tex directives for the given file.
#
sub tex_directives {
    my ($filename) = @_;
    open( my $fh, "<", $filename )
      or croak "Can not open $filename: $!";
    my %directives = _tex_directives_filehandle($fh);
    close($fh);
    return %directives;
}

# ===========
# = Private =
# ===========

sub _tex_directives_filehandle {
    my ($fh) = @_;
    my %directives = ();

    # TS-program is case insensitive e.g. `LaTeX` should be the same as `latex`
    my $engines = "(?i)latex|lualatex|pdflatex|xelatex(?-i)";
    my $keys    = "encoding|spellcheck|root";

    while ( my $line = <$fh> ) {
        last unless ( 1 .. 20 );
        next unless ( $line =~ m{^ \s*%\s* !TEX}x );

        $line =~ s/^ \s*%\s* !TEX \s* | \s+$//x;

        if ( $line =~ m{(?:TS-)program (?:\s*)=(?:\s*) ($engines)}x ) {
            $directives{"program"} = lc($1);
        }
        elsif ( $line =~ m{($keys) (?:\s*)=(?:\s*) (.+)}x ) {
            $directives{$1} = $2;
        }
    }

    return %directives;
}

1;
