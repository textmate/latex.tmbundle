"""This module contains functions to handle auxiliary files produced by TeX."""

# -- Imports ------------------------------------------------------------------

from __future__ import absolute_import
from __future__ import print_function
from __future__ import unicode_literals

from glob import glob
from os import getenv, remove
from os.path import join
from pipes import quote
from subprocess import check_output


# -- Functions ----------------------------------------------------------------

def remove_auxiliary_files(directory='.',
                           tm_bundle_support=getenv('TM_BUNDLE_SUPPORT')):
    """Remove auxiliary files created by TeX commands.

    Arguments:

        directory

            This string specifies the directory that this function cleans from
            auxiliary files.

        tm_bundle_support

            This string specifies the bundle support path of the LaTeX bundle.

    Returns:

        The function returns a list of strings. Each item in the list
        specifies the location of an auxiliary file removed by this function.

    Examples:

        >>> # Initialize test
        >>> from glob import glob
        >>> from os import getcwd, mkdir
        >>> from os.path import basename, join
        >>> from tempfile import mkdtemp
        >>> tm_bundle_support = join(getcwd(), "Support")
        >>> directory = mkdtemp()

        >>> # Create auxiliary files
        >>> for filename in ["test.aux", "test.toc", "test.synctex.gz"]:
        ...     _ = open(join(directory, filename), 'w')
        >>> mkdir(join(directory, "_minted-test"))
        >>> # Create non auxiliary files
        >>> _ = open(join(directory, '.fslckout'), 'w')

        >>> # Remove auxiliary files
        >>> for path in remove_auxiliary_files(directory,
        ...                                    tm_bundle_support):
        ...     print(path)
        _minted-test
        test.aux
        test.synctex.gz
        test.toc

    """
    clean_command = join(tm_bundle_support, 'bin/clean.rb')
    return check_output('{} {}'.format(quote(clean_command),
                                       quote(directory)),
                        universal_newlines=True, shell=True).split()


def remove_cache_files():
    """This function removes cache files produced by the LaTeX bundle.

    Examples:

        >>> from os import chdir, getcwd, rmdir, mkdir
        >>> directory = getcwd()
        >>> test_directory = "/tmp/LaTeX Bundle Test"
        >>> mkdir(test_directory)
        >>> chdir(test_directory)

        >>> # Create cache files
        >>> _ = open(".test.lb", 'w')
        >>> _ = open(".cache.lb", 'w')

        >>> # Remove cache files
        >>> remove_cache_files()

        >>> rmdir(test_directory)
        >>> chdir(directory)

    """
    for cache_filepath in glob('.*.lb'):
        try:
            remove(cache_filepath)
        except:
            continue
