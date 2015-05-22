use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename;
use Test::Simple tests => 3;

use lib dirname( dirname( dirname abs_path $0) ) . '/Support/lib';
use Latex 'guess_tex_engine';

my $tex_dir = dirname( dirname abs_path $0) . '/TeX';

ok( guess_tex_engine( $tex_dir . '/xelatex.tex' ) eq 'xelatex',
    'Guess tex engine for xelatex.tex' );
ok( guess_tex_engine( $tex_dir . '/ünicöde.tex' ) eq 'xelatex',
    'Guess tex engine for ünicöde.tex' );
ok( guess_tex_engine( $tex_dir . '/text.tex' ) eq '',
    'Guess tex engine for text.tex' );
