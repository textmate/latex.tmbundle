#!/usr/bin/perl

# -- Imports -------------------------------------------------------------------

use strict;
use warnings;

use Carp qw(croak);
use Cwd qw(abs_path);
use File::Basename;
use Test::More tests => 3;

use lib dirname( dirname( dirname abs_path $0) ) . '/Support/lib/Perl';
use Auxiliary qw(get_auxiliary_files remove_auxiliary_files);

# -- Tests ---------------------------------------------------------------------

# =======================
# = get_auxiliary_files =
# =======================

my ( $extensions, $directories, @extensions_reference, @directories_reference );

@extensions_reference = qw(acn acr alg aux bbl bcf blg fdb_latexmk fls fmt glo
  glg gls idx ilg ind ini ist latexmk.log lof log lol lot maf mtc mtc1 nav nlo
  nls pytxcode out pdfsync run.xml snm synctex.gz toc);

@directories_reference = qw(pythontex-files- _minted-);

( $extensions, $directories ) = get_auxiliary_files( abs_path 'Support' );

is_deeply( \@extensions_reference, $extensions,
    'Check the list of auxiliary file extensions' );

is_deeply( \@directories_reference, $directories,
    'Check the list of auxiliary directory prefixes' );

# ==========================
# = remove_auxiliary_files =
# ==========================

my ( $directory, $filename, $filehandle ) =
  ( '/tmp/LaTeX Bundle Test', 'test' );

mkdir $directory;

# Create auxiliary files
open $filehandle, '>', "$directory/$filename.acn" or croak "$!";
close $filehandle;
open $filehandle, '>', "$directory/$filename.lol" or croak "$!";
close $filehandle;
mkdir "$directory/pythontex-files-$filename";

remove_auxiliary_files( $filename, $directory, abs_path 'Support' );

# Create auxiliary files
$filename = "blärgh blubb";
open $filehandle, '>', "$directory/$filename.acn" or croak "$!";
close $filehandle;
mkdir(
    "$directory/_minted-" . do { $filename =~ s/ /_/gr; }
);
mkdir(
    "$directory/pythontex-files-" . do { $filename =~ s/ /-/gr; }
);

remove_auxiliary_files( $filename, $directory, abs_path 'Support' );

# The test directory must be empty after the function removed all auxiliary
# files
ok( rmdir($directory), 'Check if removing auxiliary files worked correctly' );
