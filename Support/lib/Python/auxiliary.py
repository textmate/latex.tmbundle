"""This module contains functions to handle auxiliary files produced by TeX."""

# -- Imports ------------------------------------------------------------------

from __future__ import absolute_import
from __future__ import print_function
from __future__ import unicode_literals

from glob import glob
from io import open
from os import getenv, listdir, remove
from os.path import isfile, isdir, join
from re import match
from shutil import rmtree


# -- Functions ----------------------------------------------------------------

def read_list(file_object, list_name):
    """This function reads a list of items from an open file.

    The list must be in the standard YAML format. Here is an example:

        list_name:
          - item1
          - item2

    There must be no spaces before or after the list name, or this function
    will fail.

    Arguments:

        file_object

            This argument specifies the file object this function reads to get
            the items of the list.

        list_name

            This string specifies the name of the list this function tries to
            read.

    Returns:

        The function returns a list of strings. Each string specifies one of
        the items read by this function.


    Examples:

        >>> config_file = "Support/config/auxiliary.yaml"
        >>> with open(config_file, 'r', encoding='utf-8') as auxiliary_file:
        ...     for extension in read_list(auxiliary_file, 'files'):
        ...         print(extension) # doctest:+ELLIPSIS
        acn
        acr
        ...
        toc

    """
    # Read till list name
    while file_object.readline() != '{}:\n'.format(list_name):
        continue

    # Read list items
    items = []
    while True:
        line = file_object.readline().strip()
        if line.startswith('- '):
            items.append(line[2:].lstrip())
        else:
            break
    return items


def get_auxiliary_files(tm_bundle_support=getenv('TM_BUNDLE_SUPPORT')):
    """This function reads two lists of auxiliary files.

    Arguments:

        tm_bundle_support

            This string specifies the bundle support path of the LaTeX bundle.

    Returns:

        The function returns two lists:

        - The first list contains a list of extensions. Each extension belongs
          to a single auxiliary file produced by one of the various TeX
          commands.

        - The second list contains a list of prefixes. Each prefix specifies
          the first part of the name of a auxiliary directory produced by some
          TeX command.

    Examples:

        >>> from os import getcwd
        >>> tm_bundle_support = join(getcwd(), "Support")
        >>> prefix_directories = get_auxiliary_files(tm_bundle_support)[1]
        >>> for prefix in prefix_directories:
        ...     print(prefix)
        pythontex-files-
        _minted-

    """
    config_filepath = join(tm_bundle_support, "config/auxiliary.yaml")
    with open(config_filepath, 'r', encoding='utf_8') as auxiliary_file:
        return (read_list(auxiliary_file, 'files'),
                read_list(auxiliary_file, 'directories'))


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
        >>> from os import chdir, getcwd, rmdir, mkdir
        >>> directory = getcwd()
        >>> tm_bundle_support = join(directory, "Support")
        >>> test_directory = "/tmp/LaTeX Bundle Test"
        >>> mkdir(test_directory)
        >>> chdir(test_directory)

        >>> # Create auxiliary files
        >>> _ = open("test.aux", 'w')
        >>> _ = open("test.toc", 'w')
        >>> _ = open("test.synctex.gz", 'w')
        >>> mkdir("_minted-test")

        >>> # Remove auxiliary files
        >>> for path in remove_auxiliary_files(tm_bundle_support =
        ...                                    tm_bundle_support):
        ...     print(path)
        _minted-test
        test.aux
        test.synctex.gz
        test.toc

        >>> rmdir(test_directory)
        >>> chdir(directory)

    """
    file_extensions, dir_prefixes = get_auxiliary_files(tm_bundle_support)
    removed_files = []

    for filepath in listdir(directory):
        if isfile(filepath) and any(filepath.endswith(extension) for
                                    extension in file_extensions):
            try:
                remove(filepath)
                removed_files.append(filepath)
            except:
                pass

        elif (isdir(filepath) and
              match('^(?:{})'.format('|'.join(dir_prefixes)), filepath)):
            try:
                rmtree(filepath)
                removed_files.append(filepath)
            except:
                pass

    return removed_files


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

# -- Main ---------------------------------------------------------------------

if __name__ == '__main__':
    # Run tests for this module
    from doctest import testmod
    testmod()
