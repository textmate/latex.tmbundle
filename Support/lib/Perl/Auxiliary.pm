package Auxiliary;

=head1 Auxiliary

This module contains functions to clean auxiliary files produced by TeX.

=cut

# -- Imports -------------------------------------------------------------------

use strict;
use warnings;

use Carp qw(croak);
use Cwd qw(abs_path);
use Data::Dumper;
use Encode qw(decode);
use Env qw(TM_BUNDLE_SUPPORT);
use Exporter qw(import);
use File::Basename;
use File::Path qw(remove_tree);

use lib dirname( dirname( dirname abs_path $0) ) . '/Support/lib/Perl';
use YAML::Tiny;

# -- Exports -------------------------------------------------------------------

our @EXPORT_OK = qw(get_auxiliary_files remove_auxiliary_files);

# -- Functions -----------------------------------------------------------------

=head2 get_auxiliary_files

This function reads two lists of auxiliary files.

=head3 Arguments:

=over 4

=item tm_bundle_support

This string specifies the bundle support path of the LaTeX bundle.

=back

=head3 Returns:

The function returns two lists:

=over 4

=item * The first list contains a list of extensions. Each extension belongs to
a single auxiliary file produced by one of the various TeX commands.

=item * The second list contains a list of prefixes. Each prefix specifies the
first part of the name of a auxiliary directory produced by a TeX command.

=back

=cut

sub get_auxiliary_files {
    my ($tm_bundle_support) = @_;
    $tm_bundle_support ||= $TM_BUNDLE_SUPPORT;
    my $config_filepath = "$tm_bundle_support/config/auxiliary.yaml";

    my $yaml = YAML::Tiny->read($config_filepath)
      or croak "Can not open $config_filepath: $!";
    my $config = $yaml->[0];

    return $config->{'files'}, $config->{'directories'};
}

=head2 remove_auxiliary_files

Remove auxiliary files created by TeX commands.

=head3 Arguments:

=over 4

=item filename

This string specifies the name of a .tex file without its extension. This
function removes auxiliary files that TeX commands create when they translated
the file specified by this argument.

=item directory

This string specifies the directory that this function cleans from auxiliary
files.

=item tm_bundle_support

This string specifies the bundle support path of the LaTeX bundle.

=back

=cut

sub remove_auxiliary_files {
    my ( $name, $directory, $tm_bundle_support ) = @_;

    $tm_bundle_support ||= $TM_BUNDLE_SUPPORT;

    my ( $file_extensions, $directory_prefixes ) =
      get_auxiliary_files($tm_bundle_support);

    if ( defined($directory) ) {

        unlink( map { decode( "UTF-8", "$directory/$name.$_" ) }
              @$file_extensions );

        # Remove LaTeX bundle cache file
        unlink("$directory/.$name.lb");

        foreach my $dir ( map { "$directory/$_" } @$directory_prefixes ) {
            foreach my $space_substitution ( "-", "_" ) {
                ( my $cache_name = $name ) =~ s/ /$space_substitution/g;
                my $aux_dir = decode( "UTF-8", "$dir$cache_name" );
                remove_tree($aux_dir)
                  if -d $aux_dir && -w $aux_dir;

            }
        }
    }
    return;
}

1;
