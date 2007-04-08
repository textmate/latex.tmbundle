eval '(exit $?0)' && eval 'exec perl -x -S "$0" ${1+"$@"}' && 
eval 'exec perl -x -S  "$0" $argv:q'
if 0;
#!/usr/bin/perl -w
#!/opt/local/bin/perl -w
#!/usr/local/bin/perl -w
# The above code allows this script to be run under UNIX/LINUX without
# the need to adjust the path to the perl program in a "shebang" line.
# (The location of perl changes between different installations, and
# may even be different when several computers running different
# flavors of UNIX/LINUX share a copy of latex or other scripts.)  The
# script is started under the default command interpreter sh, and the
# evals in the first two lines restart the script under perl, and work
# under various flavors of sh.  The -x switch tells perl to start the
# script at the first #! line containing "perl".  The "if 0;" on the
# 3rd line converts the first two lines into a valid perl statement
# that does nothing.
#
# Source of the above: manpage for perlrun


# ATTEMPT TO ALLOW FILENAMES WITH SPACES:
#    (as of 1 Apr 2006)

# Problems:
# A.  Quoting filenames will not always work.  
#        a.  Under UNIX, quotes are legal in filenames, so when PERL
#            directly runs a binary, a quoted filename will be treated as
#            as a filename containing a quote character.  But when it calls
#            a shell, the quotes are handled by the shell as quotes.
#        b.  Under MSWin32, quotes are illegal filename characters, and tend
#            to be handled correctly.
#        c.  But under cygwin, results are not so clear (there are many 
#            combinations: native v. cygwin perl, native v cygwin programs
#            NT v. unix scripts, which shell is called.
# B.  TeX doesn't handle filenames with spaces gracefully.
#        a.  Current UNIX (gluon2 Mar 31, Apr 1, 2006) doesn't handle them 
#            at all.  (Somewhere there's raw TeX that treats space as separater.)
#        b.  Current fptex does.  But in \input the filename must be in quotes.
#            This is incompatible with UNIX, where quotes are legal filename 
#            characters, and so quotes are interpreted as belonging to the 
#            filename.
#     =====> Thus there is no OS- and TeX-version independent way of using 
#     filenames with spaces with \input. ===========================
# C.  =====> Using the shell for command lines is not safe, since special 
#     characters can cause lots of mayhem.
#     It will therefore be a good idea to sanitize filenames.  
#
# I've sanitized all calls out:
#     a. system and exec use a single argument, which forces
#        use of shell, under all circumstances
#        Thus I can safely use quotes on filenames:  They will be handled by 
#        the shell under UNIX, and simply passed on to the program under MSWin32.
#     b. I reorganized Run, Run_Detached to use single command line
#     c. All calls to Run and Run_Detached have quoted filenames.
#     d. So if a space-free filename with wildcards is given on latexmk's
#        command line, and it globs to space-containing filename(s), that
#        works (fptex on home computer, native NT tex)
#     e. ====> But globbing fails: the glob function takes space as filename 
#        separator.   ====================

#================= TO DO ================
#
# 1.  See ??  ESPECIALLY $MSWin_fudge_break
# 2.  Check fudged conditions in looping and make_files 
# 3.  Should not completely abort after a run that ends in failure from latex
#     Missing input files (including via custom dependency) should be checked for
#     a change in status
#         If sources for missing files from custom dependency 
#             are available, then do a rerun
#         If sources of any kind become available rerun (esp. for pvc)
#             rerun
#         Must parse log_file after unsuccessful run of latex: it may give
#             information about missing files. 
# 4.  Check file of bug reports and requests
# 5.  Rationalize bibtex warnings and errors.  Two almost identical routines.
#         Should 1. Use single routine
#                2. Convert errors to failure only in calling routine
#                3. Save first warning/error.


# To do: 
#   Rationalize again handling of include files.
#     Perhaps use kpsewhich to do searches.
#        (How do I avoid getting slowed down too much?)
#     Better parsing of log file for includes.
#   Do I handle the recursive dependence of bbl and aux files sensibly.
#     Perhaps some appropriate touching of the .aux and .bbl files would help?
#   Document the assumptions at each stage of processing algorithm.
#   Option to restart previewer automatically, if it dies under -pvc
#   Test for already running previewer gets wrong answer if another
#     process has the viewed file in its command line

$version_num = '3.08n';
$version_details = 'latexmk, John Collins, 26 February 2007';

use Config;
use File::Copy;
use File::Basename;
use FileHandle;
use File::Find;
use Cwd;            # To be able to change cwd
use Cwd "chdir";    # Ensure $ENV{PWD}  tracks cwd

#use strict;

# Translation of signal names to numbers and vv:
%signo = ();
@signame = ();
if ( defined $Config{sig_name} ) {
   $i = 0;
   foreach $name (split(' ', $Config{sig_name})) {
      $signo{$name} = $i;
      $signame[$i] = $name;
      $i++;
   }
}
else {
   warn "Something wrong with the perl configuration: No signals?\n";
}

## Copyright John Collins 1998-2005
##           (username collins at node phys.psu.edu)
##      (and thanks to David Coppit (username david at node coppit.org) 
##           for suggestions) 
## Copyright Evan McLean
##         (modifications up to version 2)
## Copyright 1992 by David J. Musliner and The University of Michigan.
##         (original version)
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307


##
##
##   For Win95 et al.:  Remaining items on list.
##     1.  See specific flags
##     6.  Need to check out all calls to system
##     8.  Now check that I do the bibtex and index stuff correctly.
##     9.  Convert routines to have arguments.
##    12.  Need to have default filetypes for graphics includes.
##         To make that rational, the find_file routine, etc must be modified,
##         otherwise there will be much duplication of code.
##
##
##   NEW FEATURES, since v. 2.0:
##     1.  Correct algorithm for deciding how many times to run latex:
##         based on whether the aux file changes between runs
##     2.  Continuous preview works, and can be of ps file or dvi file
##     3.  pdf creation by pdflatex possible
##     4.  Defaults for commands are OS dependent.
##     5.  Parsing of log file instead of source file is used to
##         obtain dependencies, by default.
##     6.  Meta-commands in source file
##
##           %#{}raw
##           %#{}begin.raw
##              Start section of raw LaTeX: treat as %#{latex}begin.ignore.
##
##           %#{}end.raw     
##              End section of raw LaTeX: treat as %#{latex}end.ignore.
##
##           %#{latexmk}ignore
##           %#{latexmk}begin.ignore
##              Start section that is to be ignored in scanning dependencies. 
##           %#{latexmk}end.ignore
##              End section that is to be ignored in scanning dependencies. 
##
##           %#{latexmk}include.file FILE
##           %#{latexmk}input.file FILE
##              Add FILE to list of include files.  (FILE is separated from 
##              the keyword "include.file" or "input.file" by white space, 
##              and is terminated by end-of-line or whitespace.)
##
##
##
##   Modified 
##
##
##      26 Feb 2007, John Collins  Finish the correction on updating viewer
##                      by signal.  There were two problems:  First is that
##                      originally latexmk -pvc when it started a viewer found
##                      the process number of the program it started, which
##                      may be a script that spawns the actual viewer, not the
##                      actual viewer.  I fixed that. The second problem is 
##                      that there are multiple processes with the 
##                      characteristics looked for by find_process_id.  The 
##                      routine gave the first found.  I switched it to find
##                      the one with the highest ID number, most likely the
##                      last to be run and therefore the viewer.
##                   Change unix et al default ps previewer back to 
##                      unadorned gv, with watch-file method assumed
##                      for update (configured by user).  This overcomes
##                      the problem that different gv programs (regular
##                      and GNU) have incompatible command line options
##                      -watch v. --watch, etc.
##      25 Feb 2007, John Collins  Try to correct incorrect update by signal
##      16 Feb 2007, John Collins  Deal with problem that in preview 
##                      continuous mode, latexmk does not start a new
##                      viewer if a previous one is detected viewing
##                      the same file, but that the viewer could be
##                      be viewing a file of the same NAME but in a
##                      DIFFERENT directory.
##                      Solution 1: option for unconditional view in -pvc
##       3 Nov 2006, John Collins  Correction
##      30 Oct 2006, John Collins  Update method by running command
##                     (from patch by Tom Goodale)
##       8 Jun 2006, John Collins  Small correction in diagnostics
##       3 Jun 2006, John Collins  Correct diagnostics on rc file
##                     There's a problem on gluon2, but I think it is a bug
##                     in the perl installation.  It gives errors in opening 
##                     and closing files, without apparent bad
##                     effects.  I work around it in my .latexmkrc
##                     file. 
##      24 May 2006, John Collins  Improve diagnostics on rc file
##      16 Apr 2006, John Collins  Remove diagnostic
##      12 Apr 2006, John Collins  Correct error message in rc file
##       3 Apr 2006, John Collins  Small changes in comments.
##       1 Apr 2006, John Collins
##         Nix that.  For consistency, always pass single command to system
##             and to exec.  This forces perl to send the command line
##             to a shell, so that quoting the file name is always sensible. 
##         Otherwise quoting a filename will be wrong under UNIX whenever
##             a direct call to a binary is made: \" is a legal character
##             in a UNIX filename
##         Still need to fix to get command-line and initialization-file 
##             specified filenames and patterns that contain spaces to 
##             work under MSWin.  (Some care with quoting needed.)  Results
##             of globbing seems to be fine as is the use of quotes in calls
##             to system and exec.
##      31 Mar 2006, John Collins
##         Not correct: need to fix Run to use array of arguments
##      30 Mar 2006, John Collins
##         Attempt to use quoted filenames, to handle filenames with spaces. 
##         Started: look at all calls to Run*.
##                  a. latex started.
##       8 Mar 2006, John Collins
##         Add -cd and -cd- switches to switch/not to directory 
##            containing source file
##      14 Jan 2006, John Collins
##         Add 'out' to generated extensions.  (Hyperref generated file)
##         Restored 'ind' to this list, as per documentation
##         IS THIS CORRECT?
##      13 Jan 2006, John Collins
##         List of excluded primary files (@default_excluded_files).
##             Useful when doing automatic "latexmk"
##             Must allow explicit run on excluded file, so only
##               apply it when using default file list
##         When testing for out-of-date dest, explicitly include
##             primary source file.  It may not get into @includes
##             under certain error conditions, e.g., files renamed
##             to different base.
##      14 Dec 2005, John Collins
##         Fix up loop for incorrectly found missing file, associated
##            with bad line-breaks in .log file.
##       9 Aug 2005, John Collins
##         Correct spelling error.
##       8 Aug 2005, John Collins
##         Globbing, etc of commandline files preserves order of files
##            and eliminates directories.
##      18 Jul 2005, John Collins
##         Preserve order of files in @default_files
##      22 May 2005, John Collins
##         Fix copy_file_and_time
##      14 Feb 2005, John Collins
##         Variables for the signal to update previewer.
##            Defaults: SIGUSR1 for dvi viewer (correct for xdvi)
##                      SIGHUP for ps and pdf viewer (correct for gv)
##      28 Jan 2005, John Collins
##         Try 'use strict'.  Turned it off.  Too many warnings for now.
##      15 Jan 2005, John Collins
##         Quote $0 on first two lines, so that paths to latexmk work
##            when they contain spaces
##      28 Sep 2004, John Collins
##         Correct parsing of log file:
##             '(file{' is not treated, as produced by
##                     pdfeTeXk, Version 3.141592-1.11a-2.1
##      14 Sep 2004, John Collins
##      13 Sep 2004, John Collins
##         Correct diagnostics in make_pdf2 when psF file does not exist
##         Correct making of psF file: when psF but not ps file is old
##         Similarly on dviF
##       2 Sep 2004, John Collins
##         Correct bug in sub view_file_via_temporary
##      31 Aug 2004, John Collins
##         Change name of $ignore_break_pvc to $MSWin_fudge_break
##      30 Aug 2004, John Collins
##         Correct non-continuation when references or citations are undefined
##         Correct some issues related to the $failure variables.
##         Finish MAC OSX initialization: pscmd.
##         Etc
##         Fix incorrect reruns: Exclude all generated files from missing
##             file list, and from @includes.  Stop using the change of set
##             of input files criterion.
##      29 Aug 2004, John Collins
##         Remove the evals in the main makes: they cause funny behavior
##             with ctrl/C and ctrl/break, since they don't insulate the 
##             outside perl from the break.
##         Fix some stuff in find_dirs and find_files
##         $ignore_break_pvc
##         Make the commands defined as NONE more self-documenting
##         Use the GNU TMPDIR env variable for $tmpdir when available
##         Start MAC OSX configuration section
##         Correct non-reading of subsidiary aux files by parse_aux
##         Correct treatment of view_via_temporary
##      14 Jul 2004, John Collins
##         Rcfiles: give error message when appropriate
##           (Use subroutine process_rc_file to unify this)
##           Previously a syntax error in an rcfile did not result in a message
##         Remove currently superfluous $count variable in sub make_postscript
##         Deal with "No file name." line in log file
##         Version number 3.08a
##      14 Jun 2004, John Collins
##         Correct misprint in comment on $texfile_search to refer to 
##               current name of @default_files variable.
##       8 Jun 2004, John Collins
##         Set up: make view files (but dvi not possible) to temporary, and
##               then move to final location.
##       7 Jun 2004, John Collins
##         Makeindex is called with full filename
##       2 Jun 2004, John Collins
##         Correct bug in parsing of log files from pdflatex
##      24 May 2004, John Collins
##         Version number to 3.08a (later 3.08) (Aim at 3.10 for next release)
##         In &build_latex_dvi_pdf, change rerun condition to do rerun 
##              after error when files changed
##      17 May 2004, John Collins
##      16 May 2004, John Collins
##         Correct bug in using $print_type eq 'pdf'
##         Command line switches for print_type
##      15 May 2004, John Collins
##          Change version to 3.11 for after next release
##      14 May 2004, John Collins
##      12 May 2004, John Collins
##      11 May 2004, John Collins
##         Correct parse_log bug 
##       9 May 2004, John Collins
##         Check source times in determining rerun condition on latex
##         Pvc: test on changed sources.  
##              improve ordering of ops.
##         Move all make_bbl and make_ind inside make_files
##       3 May 2004, John Collins
##         Correct bug
##       2 May 2004, John Collins
##         Redo handling of errors in -pvc mode: $force_mode off.
##         Deal with dying in caller of &make_files (etc)
##       1 May 2004, John Collins
##         Go mode applies to custom dependencies
##         Rerun custom dependency and latex when previously non-found
##           files are found.
##      30 Apr 2004, John Collins
##         Fix bug in make_dependents
##         Add messages about up-to-date files when doing nothing
##         Silence more informational messages in silent mode.
##         In list of dependent files generated from .log file
##            excluded those whose extenstions are in @generated_exts.
##            This removes generated files from the dependency list.
##      29 Apr 2004, John Collins
##      28 Apr 2004, John Collins
##         Rationalize default file-list to be in @default_files, etc
##         Change behavior about lack of command line files:
##             Files specified on command-line but none found: error
##             No files specified on command-line: 
##                Try @default_files (with wildcards)
##                If still none: error
##         Also apply sort and uniq to globbed list, to eliminate duplicates
##      27 Apr 2004, John Collins
##         Correct parsing of filenames in log file and in aux file
##      26 Apr 2004, John Collins
##         Correct calls to open, to be OK under perl 5.005 (on SUN)
##      25 Apr 2004, John Collins
##         Cleanup of comments, some error messages, etc
##         Change terminology 'include' to 'input' where appropriate
##         Switches to turn off modes: -F-, -g-, -i-, -I-, -pv-, -pvc-
##         -pv and -pvc override each other.  (Easier than making them
##            incompatible, and particularly necessary when one is
##            specified in a startup file.)
##         Die if incorrect option specified on command line.
##         Turn off bibtex mode if no .bib files specified in .aux
##            file. That would be the situation if a .bbl file was
##            input by an input command, so that the user is not 
##            expecting to use bibtex. 
##         Add a condition for rerun to include a change in the list
##            of input files. 
##         In force_mode, don't die when files are not found; they may
##            be in a search path where I don't look.  (But I have only
##            done this for the case that I parse the log file.)
##         When files for viewing, converting (dvi to ps, etc), etc are 
##            not found, give a warning rather than trying to continue.
##         Revise parsing in .log file to allow filenames with spaces.
##         Use arrays for all lists of filenames.
##       5 Apr 2004, John Collins
##         If latexmk exits because of an error with latex, bibtex 
##            or makeindex, then give a non-zero exit code.
##       4 Apr 2004, John Collins
##         All options can be introduced by -- or -
##         Attempt to treat cygwin correctly
##         Complete the list of commands printed with -commands
##         Correct commands for postscript mode written to .dep file
##       3 Apr 2004, John Collins
##         V. 3.07 started
##       2 Mar 2004, John Collins
##         Obfuscate e-mail addresses so that they aren't picked up by
##            worms and spammers
##      17 Jun 2003, John Collins
##         For pdf viewing set $viewer_update_method to $pdf_update_method
##            Previously it was set wrongly to $ps_update_method
##      10 Dec 2002, John Collins
##         Recursive search of BIBINPUTS and TEXINPUTS
##         Thanks to Nevin Kapur
##       5 Nov 2002, John Collins
##         Reorganize handling of filename specification, so that 
##         filenames can be specified in an rc file. E.g.,
##              @file_list = ("paper");
##      26 Oct 2002, John Collins
##         In -pvc mode keep going (i.e., -f switch), but have and -f- 
##            option to turn it off.
##      25 Oct 2002, John Collins
##         Correct bug in splitting of command line
##      24 Oct 2002, John Collins
##         pdfdvi option
##         For -pvc take PID of viewer from fork.
##      22 Oct 2002, John Collins
##         Change pscmd on linux
##      12--15 Oct 2002, John Collins
##         Improve error messages.  
##         Add "_switch" to names of configuration variables giving switches
##           (to avoid confusion with variables specifying commands).
##           E.g., latex_silent_switch
##         -P pdf switch on dvips, to ensure correct type 1 font generation
##           (otherwise pdf files have type 3 fonts, and look bad on screen).
##         Correct running of ps filter.  
##             It now only runs when ps file is updated.
##         Some clean-ups of code.
##         Allow preview of multiple files
##         Option to generate pdf file by ps2pdf (switch -pdfps)
##         Prevent detached previewer from responding to ctrl/C given to
##             parent latemk process.
##         Under MS Windows, wildcards allowed in file names.
##      14 Apr 2002, John Collins
##         Ver. 3.05
##      24 Nov 2001, John Collins
##         Ver. 3.04.  Released on CTAN
##      11 Jun 2001, John Collins
##         Ver. 3.00.  Misc cleanup.
##
##   1998-2001, John Collins.  Many improvements and fixes.
##
##   Modified by Evan McLean (no longer available for support)
##   Original script (RCS version 2.3) called "go" written by David J. Musliner
##
## 2.0 - Final release, no enhancements.  LatexMk is no longer supported
##       by the author.
## 1.9 - Fixed bug that was introduced in 1.8 with path name fix.
##     - Fixed buglet in man page.
## 1.8 - Add not about announcement mailling list above.
##     - Added texput.dvi and texput.aux to files deleted with -c and/or
##       the -C options.
##     - Added landscape mode (-l option and a bunch of RC variables).
##     - Added sensing of "\epsfig{file=...}" forms in dependency generation.
##     - Fixed path names when specified tex file is not in the current
##       directory.
##     - Fixed combined use of -pvc and -s options.
##     - Fixed a bunch of speling errors in the source. :-)
##     - Fixed bugs in xdvi patches in contrib directory.
## 1.7 - Fixed -pvc continuous viewing to reattach to pre-existing
##       process correctly.
##     - Added $pscmd to allow changing process grepping for different
##       systems.
## 1.6 - Fixed buglet in help message
##     - Fixed bugs in detection of input and include files.
## 1.5 - Removed test message I accidentally left in version 1.4
##     - Made dvips use -o option instead of stdout redirection as some
##       people had problems with dvips not going to stdout by default.
##     - Fixed bug in input and include file detection
##     - Fixed dependency resolution process so it detects new .toc file
##       and makeindex files properly.
##     - Added dvi and postscript filtering options -dF and -pF.
##     - Added -v version commmand.
## 1.4 - Fixed bug in -pvc option.
##     - Made "-F" option include non-existant file in the dependency list.
##       (RC variable: $force_include_mode)
##     - Added .lot and .lof files to clean up list of extensions.
##     - Added file "texput.log" to list of files to clean for -c.
##     - LatexMk now handles file names in a similar fashion to latex.
##       The ".tex" extension is no longer enforced.
##     - Added $texfile_search RC variable to look for default files.
##     - Fixed \input and \include so they add ".tex" extension if necessary.
##     - Allow intermixing of file names and options.
##     - Added "-d" and banner options (-bm, -bs, and -bi).
##       (RC variables: $banner, $banner_message, $banner_scale,
##       $banner_intensity, $tmpdir)
##     - Fixed "-r" option to detect an command line syntax errors better.
## 1.3 - Added "-F" option, patch supplied by Patrick van der Smagt.
## 1.2 - Added "-C" option.
##     - Added $clean_ext and $clean_full_ext variables for RC files.
##     - Added custom dependency generation capabilities.
##     - Added command line and variable to specify custom RC file.
##     - Added reading of rc file in current directly.
## 1.1 - Fixed bug where Dependency file generation header is printed
##       rependatively.
##     - Fixed bug where TEXINPUTS path is searched for file that was
##       specified with absolute an pathname.
## 1.0 - Ripped from script by David J. Musliner (RCS version 2.3) called "go"
##     - Fixed a couple of file naming bugs
##        e.g. when calling latex, left the ".tex" extension off the end
##             of the file name which could do some interesting things
##             with some file names.
##     - Redirected output of dvips.  My version of dvips was a filter.
##     - Cleaned up the rc file mumbo jumbo and created a dependency file
##       instead.  Include dependencies are always searched for if a
##       dependency file doesn't exist.  The -i option regenerates the
##       dependency file.
##       Getting rid of the rc file stuff also gave the advantage of
##       not being restricted to one tex file per directory.
##     - Can specify multiple files on the command line or no files
##       on the command line.
##     - Removed lpr options stuff.  I would guess that generally,
##       you always use the same options in which case they can
##       be set up from an rc file with the $lpr variable.
##     - Removed the dviselect stuff.  If I ever get time (or money :-) )
##       I might put it back in if I find myself needing it or people
##       express interest in it.
##     - Made it possible to view dvi or postscript file automatically
##       depending on if -ps option selected.
##     - Made specification of dvi file viewer seperate for -pv and -pvc
##       options.
##-----------------------------------------------------------------------


## Explicit exit codes: 
##             10 = bad command line arguments
##             11 = file specified on command line not found
##                  or other file not found
##             12 = failure in some part of making files
##             13 = error in initialization file
##             20 = probable bug
##             or retcode from called program.


#Line length in log file that indicates wrapping.  
# This number EXCLUDES line-end characters, and is one-based
$log_wrap = 79;

#########################################################################
## Default document processing programs, and related settings,
## These are mostly the same on all systems.
## Most of these variables represents the external command needed to 
## perform a certain action.  Some represent switches.

## Commands to invoke latex, pdflatex
$latex  = 'latex';
$pdflatex = 'pdflatex';
## Switch(es) to make them silent:
$latex_silent_switch  = '-interaction=batchmode';
$pdflatex_silent_switch  = '-interaction=batchmode';

## Command to invoke bibtex
$bibtex  = 'bibtex';
# Switch(es) to make bibtex silent:
$bibtex_silent_switch  = '-terse';

## Command to invoke makeindex
$makeindex  = 'makeindex';
# Switch(es) to make makeinex silent:
$makeindex_silent_switch  = '-q';

## Command to convert dvi file to pdf file directly:
$dvipdf  = 'dvipdf';

## Command to convert dvi file to ps file:
$dvips  = 'dvips';
## Command to convert dvi file to ps file in landscape format:
$dvips_landscape = 'dvips -tlandscape';
# Switch(es) to get dvips to make ps file suitable for conversion to good pdf:
#    (If this is not used, ps file and hence pdf file contains bitmap fonts
#       (type 3), which look horrible under acroread.  An appropriate switch
#       ensures type 1 fonts are generated.  You can put this switch in the 
#       dvips command if you prefer.)
$dvips_pdf_switch = '-P pdf';
# Switch(es) to make dvips silent:
$dvips_silent_switch  = '-q';

## Command to convert ps file to pdf file:
$ps2pdf = 'ps2pdf';

##Printing:
$print_type = 'ps';     # When printing, print the postscript file.
                        # Possible values: 'dvi', 'ps', 'pdf', 'none'

## Which treatment of default extensions and filenames with
##   multiple extensions is used, for given filename on
##   tex/latex's command line?  See sub find_basename for the
##   possibilities. 
## Current tex's treat extensions like UNIX teTeX:
$extension_treatment = 'unix';

$dvi_update_signal = undef;
$ps_update_signal = undef;
$pdf_update_signal = undef;

$dvi_update_command = undef;
$ps_update_command = undef;
$pdf_update_command = undef;

$new_viewer_always = 0;     # If 1, always open a new viewer in pvc mode.
                            # If 0, only open a new viewer if no previous
                            #     viewer for the same file is detected.

#########################################################################

################################################################
##  Special variables for system-dependent fudges, etc.
$MSWin_fudge_break = 1; # Give special treatment to ctrl/C and ctrl/break
                        #    in -pvc mode under MSWin
                        # Under MSWin32 (at least with perl 5.8 and WinXP)
                        #   when latemk is running another program, and the 
                        #   user gives ctrl/C or ctrl/break, to stop the 
                        #   daughter program, not only does it reach
                        #   the daughter, but also latexmk/perl, so
                        #   latexmk is stopped also.  In -pvc mode,
                        #   this is not normally desired.  So when the
                        #   $MSWin_fudge_break variable is set,
                        #   latexmk arranges to ignore ctrl/C and
                        #   ctrl/break during processing of files;
                        #   only the daughter programs receive them.
                        # This fudge is not applied in other
                        #   situations, since then having latexmk also
                        #   stopping because of the ctrl/C or
                        #   ctrl/break signal is desirable.
                        # The fudge is not needed under UNIX (at least
                        #   with Perl 5.005 on Solaris 8).  Only the
                        #   daughter programs receive the signal.  In
                        #   fact the inverse would be useful: In
                        #   normal processing, as opposed to -pvc, if
                        #   force mode (-f) is set, a ctrl/C is
                        #   received by a daughter program does not
                        #   also stop latexmk.  Under tcsh, we get
                        #   back to a command prompt, while latexmk
                        #   keeps running in the background!


################################################################


# System-dependent overrides:
if ( $^O eq "MSWin32" ) {
# Pure MSWindows configuration
    ## Configuration parameters:

    ## Use first existing case for $tmpdir:
    $tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || '.';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    @rc_system_files = ( 'C:/latexmk/LatexMk' );

    $search_path_separator = ';';  # Separator of elements in search_path

    # For both fptex and miktex, the following makes error messages explicit:
    $latex_silent_switch  = '-interaction=batchmode -c-style-errors';
    $pdflatex_silent_switch  = '-interaction=batchmode -c-style-errors';

    # For a pdf-file, "start x.pdf" starts the pdf viewer associated with
    #   pdf files, so no program name is needed:
    $pdf_previewer = 'start';
    $ps_previewer  = 'start';
    $ps_previewer_landscape  = "$ps_previewer";
    $dvi_previewer  = 'start';
    $dvi_previewer_landscape = "$dvi_previewer";
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    $dvi_update_method = 1;
    $ps_update_method = 1;
    $pdf_update_method = 3; # acroread locks the pdf file
    # Use NONE as flag that I am not implementing some commands:
    $lpr =
        'NONE $lpr variable is not configured to allow printing of ps files';
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Its use is not essential.
    $pscmd = 
        'NONE $pscmd variable is not configured to detect running processes';
    $pid_position = -1;     # offset of PID in output of pscmd.  
                            # Negative means I cannot use ps
}
elsif ( $^O eq "cygwin" ) {
    # The problem is a mixed MSWin32 and UNIX environment. 
    # Perl decides the OS is cygwin in two situations:
    # 1. When latexmk is run from a cygwin shell under a cygwin
    #    environment.  Perl behaves in a UNIX way.  This is OK, since
    #    the user is presumably expecting UNIXy behavior.  
    # 2. When CYGWIN exectuables are in the path, but latexmk is run
    #    from a native NT shell.  Presumably the user is expecting NT
    #    behavior. But perl behaves more UNIXy.  This causes some
    #    clashes. 
    # The issues to handle are:
    # 1.  Perl sees both MSWin32 and cygwin filenames.  This is 
    #     normally only an advantage.
    # 2.  Perl uses a UNIX shell in the system command
    #     This is a nasty problem: under native NT, there is a
    #     start command that knows about NT file associations, so that
    #     we can do, e.g., (under native NT) system("start file.pdf");
    #     But this won't work when perl has decided the OS is cygwin,
    #     even if it is invoked from a native NT command line.  An
    #     NT command processor must be used to deal with this.
    # 3.  External executables can be native NT (which only know
    #     NT-style file names) or cygwin executables (which normally
    #     know both cygwin UNIX-style file names and NT file names,
    #     but not always; some do not know about drive names, for
    #     example).
    #     Cygwin executables for tex and latex may only know cygwin
    #     filenames. 
    # 4.  The BIBINPUTS and TEXINPUTS environment variables may be
    #     UNIX-style or MSWin-style depending on whether native NT or
    #     cygwin executables are used.  They are therefore parsed
    #     differently.  Here is the clash:
    #        a. If a user is running under an NT shell, is using a
    #           native NT installation of tex (e.g., fptex or miktex),
    #           but has the cygwin executables in the path, then perl
    #           detects the OS as cygwin, but the user needs NT
    #           behavior from latexmk.
    #        b. If a user is running under an UNIX shell in a cygwin
    #           environment, and is using the cygwin installation of
    #           tex, then perl detects the OS as cygwin, and the user
    #           needs UNIX behavior from latexmk.
    #     Latexmk has no way of detecting the difference.  The two
    #     situations may even arise for the same user on the same
    #     computer simply by changing the order of directories in the
    #     path environment variable


    ## Configuration parameters: We'll assume native NT executables.
    ## The user should override if they are not.

    # This may fail: perl converts MSWin temp directory name to cygwin
    # format. Names containing this string cannot be handled by native
    # NT executables.
    $tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || '.';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    ## We can stay with MSWin files here, since perl understands them,
    @rc_system_files = ( 'C:/latexmk/LatexMk' );

    $search_path_separator = ';';  # Separator of elements in search_path
    # This is tricky.  The search_path_separator depends on the kind
    # of executable: native NT v. cygwin.  
    # So the user will have to override this.

    # For both fptex and miktex, the following makes error messages explicit:
    $latex_silent_switch  = '-interaction=batchmode -c-style-errors';
    $pdflatex_silent_switch  = '-interaction=batchmode -c-style-errors';

    # We will assume that files can be viewed by native NT programs.
    #  Then we must fix the start command/directive, so that the
    #  NT-native start command of a cmd.exe is used.
    # For a pdf-file, "start x.pdf" starts the pdf viewer associated with
    #   pdf files, so no program name is needed:
    $start_NT = "cmd /c start";
    $pdf_previewer = "$start_NT";
    $ps_previewer  = "$start_NT";
    $ps_previewer_landscape  = "$ps_previewer";
    $dvi_previewer  = "$start_NT";
    $dvi_previewer_landscape = "$dvi_previewer";
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    $dvi_update_method = 1;
    $ps_update_method = 1;
    $pdf_update_method = 3; # acroread locks the pdf file
    # Use NONE as flag that I am not implementing some commands:
    $lpr =
        'NONE $lpr variable is not configured to allow printing of ps files';
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Its use is not essential.
    # When the OS is detected as cygwin, there are two possibilities:
    #    a.  Latexmk was run from an NT prompt, but cygwin is in the
    #        path. Then the cygwin ps command will not see commands
    #        started from latexmk.  So we cannot use it.
    #    b.  Latexmk was started within a cygwin environment.  Then
    #        the ps command works as we need.
    # Only the user, not latemk knows which, so we default to not
    # using the ps command.  The user can override this in a
    # configuration file. 
    $pscmd = 
        'NONE $pscmd variable is not configured to detect running processes';
    $pid_position = -1;     # offset of PID in output of pscmd.  
                            # Negative means I cannot use ps
}
else {
    # Assume anything else is UNIX or clone

    ## Configuration parameters:


    ## Use first existing case for $tmpdir:
    $tmpdir = $ENV{TMPDIR} || '/tmp';

    ## List of possibilities for the system-wide initialization file.  
    ## The first one found (if any) is used.
    ## Normally on a UNIX it will be in a subdirectory of /opt/local/share or
    ## /usr/local/share, depending on the local conventions.
    ## /usr/local/lib/latexmk/LatexMk is put in the list for
    ## compatibility with older versions of latexmk.
    @rc_system_files = 
     ( '/opt/local/share/latexmk/LatexMk', 
       '/usr/local/share/latexmk/LatexMk',
       '/usr/local/lib/latexmk/LatexMk' );

    $search_path_separator = ':';  # Separator of elements in search_path

    $dvi_update_signal = $signo{USR1} 
         if ( defined $signo{USR1} ); # Suitable for xdvi
    $ps_update_signal = $signo{HUP} 
         if ( defined $signo{HUP} );  # Suitable for gv
    $pdf_update_signal = $signo{HUP} 
         if ( defined $signo{HUP} );  # Suitable for gv
    ## default document processing programs.
    # Viewer update methods: 
    #    0 => auto update: viewer watches file (e.g., gv)
    #    1 => manual update: user must do something: e.g., click on window.
    #         (e.g., ghostview, MSWIN previewers, acroread under UNIX)
    #    2 => send signal.  Number of signal in $dvi_update_signal,
    #                         $ps_update_signal, $pdf_update_signal
    #    3 => viewer can't update, because it locks the file and the file 
    #         cannot be updated.  (acroread under MSWIN)
    #    4 => Run command to update.  Command in $dvi_update_command, 
    #    $ps_update_command, $pdf_update_command.
    $dvi_previewer  = 'start xdvi';
    $dvi_previewer_landscape = 'start xdvi -paper usr';
    if ( defined $dvi_update_signal ) { 
        $dvi_update_method = 2;  # xdvi responds to signal to update
    } else {
        $dvi_update_method = 1;  
    }
#    if ( defined $ps_update_signal ) { 
#        $ps_update_method = 2;  # gv responds to signal to update
#        $ps_previewer  = 'start gv -nowatch';
#        $ps_previewer_landscape  = 'start gv -swap -nowatch';
#    } else {
#        $ps_update_method = 0;  # gv -watch watches the ps file
#        $ps_previewer  = 'start gv -watch';
#        $ps_previewer_landscape  = 'start gv -swap -watch';
#    }
    # Turn off the fancy options for gv.  Regular gv likes -watch etc
    #   GNU gv likes --watch etc.  User must configure
    $ps_update_method = 0;  # gv -watch watches the ps file
    $ps_previewer  = 'start gv';
    $ps_previewer_landscape  = 'start gv -swap';
    $pdf_previewer = 'start acroread';
    $pdf_update_method = 1;  # acroread under unix needs manual update
    $lpr = 'lpr';         # Assume lpr command prints postscript files correctly
    $lpr_dvi =
        'NONE $lpr_dvi variable is not configured to allow printing of dvi files';
    $lpr_pdf =
        'NONE $lpr_pdf variable is not configured to allow printing of pdf files';
    # The $pscmd below holds a command to list running processes.  It
    # is used to find the process ID of the viewer looking at the
    # current output file.  The output of the command must include the
    # process number and the command line of the processes, since the
    # relevant process is identified by the name of file to be viewed.
    # Uses:
    #   1.  In preview_continuous mode, to save running a previewer
    #       when one is already running on the relevant file.
    #   2.  With xdvi in preview_continuous mode, xdvi must be
    #       signalled to make it read a new dvi file.
    #
    # The following works on Solaris, LINUX, HP-UX, IRIX
    # Use -f to get full listing, including command line arguments.
    # Use -u $ENV{CMD} to get all processes started by current user (not just
    #   those associated with current terminal), but none of other users' 
    #   processes. 
    $pscmd = "ps -f -u $ENV{USER}"; 
    $pid_position = 1; # offset of PID in output of pscmd; first item is 0.  
    if ( $^O eq "linux" ) {
        # Ps on Redhat (at least v. 7.2) appears to truncate its output
        #    at 80 cols, so that a long command string is truncated.
        # Fix this with the --width option.  This option works under 
        #    other versions of linux even if not necessary (at least 
        #    for SUSE 7.2). 
        # However the option is not available under other UNIX-type 
        #    systems, e.g., Solaris 8.
        $pscmd = "ps --width 200 -f -u $ENV{USER}"; 
    }
    elsif ( $^O eq "darwin" ) {
        # OS-X on Macintosh
        $lpr_pdf  = 'lpr';  
        $pscmd = "ps -ww -u $ENV{USER}"; 
    }
}

## default parameters
$max_repeat = 5;        # Maximum times I repeat latex.  Normally
                        # 3 would be sufficient: 1st run generates aux file,
                        # 2nd run picks up aux file, and maybe toc, lof which 
                        # contain out-of-date information, e.g., wrong page
                        # references in toc, lof and index, and unresolved
                        # references in the middle of lines.  But the 
                        # formatting is more-or-less correct.  On the 3rd
                        # run, the page refs etc in toc, lof, etc are about
                        # correct, but some slight formatting changes may
                        # occur, which mess up page numbers in the toc and lof,
                        # Hence a 4th run is conceivably necessary. 
                        # At least one document class (JHEP.cls) works
			# in such a way that a 4th run is needed.  
                        # We allow an extra run for safety for a
			# maximum of 5. Needing further runs is
			# usually an indication of a problem; further
			# runs may not resolve the problem, and
			# instead could cause an infinite loop.
$max_abs_repeat = 50;   # Sometimes latex will be rerun because of 
                        # source files that change during a run.
                        # To save really infinite loops, we'll set an 
                        # upper limit.
$clean_ext = "";        # space separated extensions of files that are
                        # to be deleted when doing cleanup, beyond
                        # standard set
$clean_full_ext = "";   # space separated extensions of files that are
                        # to be deleted when doing cleanup_full, beyond
                        # standard set and those in $clean_ext
@cus_dep_list = ();     # Custom dependency list
@default_files = ( '*.tex' );   # Array of LaTeX files to process when 
                        # no files are specified on the command line.
                        # Wildcards allowed
                        # Best used for project specific files.
@default_excluded_files = ( );   
                        # Array of LaTeX files to exclude when using
                        # @default_files, i.e., when no files are specified
                        # on the command line.
                        # Wildcards allowed
                        # Best used for project specific files.
$texfile_search = "";   # Specification for extra files to search for
                        # when no files are specified on the command line
                        # and the @default_files variable is empty.
                        # Space separated, and wildcards allowed.
                        # These files are IN ADDITION to *.tex in current 
                        # directory. 
                        # This variable is obsolete, and only in here for
                        # backward compatibility.


## default flag settings.
$silent = 0;            # silence latex's messages?
$bibtex_mode = 0;	# is there a bibliography needing bibtexing?
$index_mode = 0;	# is there an index needing makeindex run?
$landscape_mode = 0;	# default to portrait mode
# The following contains a list of extensions for files that may be read in 
# during a LaTeX run but that are generated in the previous run.  They should be 
# excluded from the dependents, since NORMALLY they are not true source files. 
# This list can be overridden in a configuration file if it causes problems.
# The extensions "aux" and "bbl" are always excluded from the dependents,
# because they get special treatment.
@generated_exts = ( 'ind', 'lof', 'lot', 'out', 'toc' );
     # 'out' is generated by hyperref package
# But it's worth making a list anyway
@generated_exts1 = ( 'aux', 'bbl', 'ind' );
# Which kinds of file do I have requests to make?
# If no requests at all are made, then I will make dvi file
# If particular requests are made then other files may also have to be
# made.  E.g., ps file requires a dvi file
$dvi_mode = 0;          # No dvi file requested
$postscript_mode = 0;           # No postscript file requested
$pdf_mode = 0;          # No pdf file requested to be made by pdflatex
                        # Possible values: 
                        #     0 don't create pdf file
                        #     1 to create pdf file by pdflatex
                        #     2 to create pdf file by ps2pdf
                        #     3 to create pdf file by dvipdf
$view = 'default';      # Default preview is of highest of dvi, ps, pdf
$sleep_time = 2;	# time to sleep b/w checks for file changes in -pvc mode
$banner = 0;            # Non-zero if we have a banner to insert
$banner_scale = 220;    # Original default scale
$banner_intensity = 0.95;  # Darkness of the banner message
$banner_message = 'DRAFT'; # Original default message
$do_cd = 0;     # Do not do cd to directory of source file.
                #   Thus behave like latex.
@dir_stack = (); # Stack of pushed directories.
$cleanup_mode = 0;      # No cleanup of nonessential files.
                        # $cleanup_mode = 0: no cleanup
                        # $cleanup_mode = 1: full cleanup 
                        # $cleanup_mode = 2: cleanup except for dvi and ps
                        # $cleanup_mode = 3: cleanup except for dep and aux
$diagnostics = 0;
$dvi_filter = '';	# DVI filter command
$ps_filter = '';	# Postscript filter command

$includes_from_log = 1;  # =1 to work on log file to find dependencies
$force_mode = 0;        # =1 to force processing past errors
$force_include_mode = 0;# =1 to ignore non-existent files when making
                        # dependency files.
$go_mode = 0;           # =1 to force processing regardless of time-stamps
                        # =2 full clean-up first
$preview_mode = 0;
$preview_continuous_mode  = 0;
$printout_mode = 0;     # Don't print the file

# Do we make view file in temporary then move to final destination?
#  (To avoid premature updating by viewer).
$always_view_file_via_temporary = 0;      # Set to 1 if  viewed file is always
                                   #    made through a temporary.
$pvc_view_file_via_temporary = 1;  # Set to 1 if only in -pvc mode is viewed 
                                   #    file made through a temporary.

# State variables initialized here:

$updated = 0;           # Flags when something has been remade
                        # Used to allow convenient user message in -pvc mode


# Used for some results of parsing log file:
$reference_changed = 0;
$bad_reference = 0;
$bad_citation = 0;


# Set search paths for includes.
# Set them early so that they can be overridden
$TEXINPUTS = $ENV{'TEXINPUTS'};
if (!$TEXINPUTS) { $TEXINPUTS = '.'; }
$BIBINPUTS = $ENV{'BIBINPUTS'};
if (!$BIBINPUTS) { $BIBINPUTS = '.'; }

@psfigsearchpath = ('.');

# Convert search paths to arrays:
# If any of the paths end in '//' then recursively search the
# directory.  After these operations, @BIBINPUTS and @TEXINPUTS should
# have all the directories that need to be searched

@TEXINPUTS = find_dirs1 ($TEXINPUTS);
@BIBINPUTS = find_dirs1 ($BIBINPUTS);

## Read rc files:

# Read first system rc file that is found:
SYSTEM_RC_FILE:
foreach $rc_file ( @rc_system_files )
{
   # print "===Testing for system rc file \"$rc_file\" ...\n";
   if ( -e $rc_file )
   {
      # print "===Reading system rc file \"$rc_file\" ...\n";
      # Read the system rc file
      process_rc_file( $rc_file );
      last SYSTEM_RC_FILE;
   }
}

# Read user rc file.
$rc_file = "$ENV{'HOME'}/.latexmkrc";
if ( -e $rc_file )
{
  process_rc_file( $rc_file );
}

# Read rc file in current directory.
$rc_file = "latexmkrc";
if ( -e $rc_file )
{
  &process_rc_file( $rc_file );
}

#show_array ("TEXINPUTS", @TEXINPUTS); show_array ("BIBINPUTS", @BIBINPUTS); die;

## Process command line args.
@command_line_file_list = ();
$bad_options = 0;

#print "Command line arguments:\n"; for ($i = 0; $i <= $#ARGV; $i++ ) {  print "$i: '$ARGV[$i]'\n"; }

while ($_ = $ARGV[0])
{
  # Make -- and - equivalent at beginning of option:
  s/^--/-/;
  shift;
  if (/^-c$/)        { $cleanup_mode = 2; }
  elsif (/^-commands$/) { &print_commands; exit; }
  elsif (/^-C$/)     { $cleanup_mode = 1; }
  elsif (/^-cd$/)    { $do_cd = 1; }
  elsif (/^-cd-$/)   { $do_cd = 0; }
  elsif (/^-d$/)     { $banner = 1; }
  elsif (/^-dvi$/)   { $dvi_mode = 1; }
  elsif (/^-dvi-$/)  { $dvi_mode = 0; }
  elsif (/^-f$/)     { $force_mode = 1; }
  elsif (/^-f-$/)    { $force_mode = 0; }
  elsif (/^-F$/)     { $force_include_mode = 1; }
  elsif (/^-F-$/)    { $force_include_mode = 0; }
  elsif (/^-g$/)     { $go_mode = 1; }
  elsif (/^-g-$/)    { $go_mode = 0; }
  elsif (/^-gg$/)    { $go_mode = 2; }
  elsif ( /^-h$/ || /^-help$/ )   { &print_help; exit;}
  elsif (/^-il$/)    { $includes_from_log = 1; }
  elsif (/^-it$/)    { $includes_from_log = 0; }
  elsif (/^-i$/)     { $generate_and_save_includes = 1; }
  elsif (/^-i-$/)    { $generate_and_save_includes = 0; }
  elsif (/^-I$/)     { $force_generate_and_save_includes = 1; }
  elsif (/^-I-$/)    { $force_generate_and_save_includes = 0; }
  elsif (/^-diagnostics/) { $diagnostics = 1; }
  elsif (/^-l$/)     { $landscape_mode = 1; }
  elsif (/^-new-viewer$/) {
                       $new_viewer_always = 1; 
  }
  elsif (/^-new-viewer-$/) {
                       $new_viewer_always = 0; 
  }
  elsif (/^-l-$/)    { $landscape_mode = 0; }
  elsif (/^-p$/)     { $printout_mode = 1; 
                       $preview_continuous_mode = 0; # to avoid conflicts
                       $preview_mode = 0;  
                     }
  elsif (/^-p-$/)    { $printout_mode = 0; }
  elsif (/^-pdfdvi$/){ $pdf_mode = 3; }
  elsif (/^-pdfps$/) { $pdf_mode = 2; }
  elsif (/^-pdf$/)   { $pdf_mode = 1; }
  elsif (/^-pdf-$/)  { $pdf_mode = 0; }
  elsif (/^-print=(.*)$/) {
      $value = $1;
      if ( $value =~ /^dvi$|^ps$|^pdf$/ ) {
          $print_type = $value;
          $printout_mode = 1;
      }
      else {
          &exit_help("Latexmk: unknown print type '$value' in option '$_'");
      }
  }
  elsif (/^-ps$/)    { $postscript_mode = 1; }
  elsif (/^-ps-$/)   { $postscript_mode = 0; }
  elsif (/^-pv$/)    { $preview_mode = 1; 
                       $preview_continuous_mode = 0; # to avoid conflicts
                       $printout_mode = 0; 
                     }
  elsif (/^-pv-$/)   { $preview_mode = 0; }
  elsif (/^-pvc$/)   { $preview_continuous_mode = 1;
                       $force_mode = 0;    # So that errors do not cause loops
                       $preview_mode = 0;  # to avoid conflicts
                       $printout_mode = 0; 
                     }
  elsif (/^-pvc-$/)  { $preview_continuous_mode = 0; }
  elsif (/^-silent$/ || /^-quiet$/ ){ $silent = 1; }
  elsif (/^-v$/ || /^-version$/)   { 
      print "\n$version_details. Version $version_num\n"; 
      exit; 
  }
  elsif (/^-verbose$/)  { $silent = 0; }
  elsif (/^-view=default$/) { $view = "default";}
  elsif (/^-view=dvi$/)     { $view = "dvi";}
  elsif (/^-view=none$/)    { $view = "none";}
  elsif (/^-view=ps$/)      { $view = "ps";}
  elsif (/^-view=pdf$/)     { $view = "pdf"; }
  elsif (/^-r$/) {  
     if ( $ARGV[0] eq '' ) {
        &exit_help( "No RC file specified after -r switch"); 
     }
     if ( -e $ARGV[0] ) {
	process_rc_file( $ARGV[0] );
     } 
     else {
	$! = 11;
	die "Latexmk: RC file [$ARGV[0]] does not exist\n"; 
     }
     shift; 
  }
  elsif (/^-bm$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No message specified after -bm switch");
     }
     $banner = 1; $banner_message = $ARGV[0];
     shift; 
  }
  elsif (/^-bi$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No intensity specified after -bi switch");
     }
     $banner_intensity = $ARGV[0];
     shift; 
  }
  elsif (/^-bs$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No scale specified after -bs switch");
     }
     $banner_scale = $ARGV[0];
     shift; 
  }
  elsif (/^-dF$/) {
     if ( $ARGV[0] eq '' ) {
	&exit_help( "No dvi filter specified after -dF switch");
     }
     $dvi_filter = $ARGV[0];
     shift; 
  }
  elsif (/^-pF$/) {
     if ( $ARGV[0] eq '' ) {
        &exit_help( "No ps filter specified after -pF switch");
     }
     $ps_filter = $ARGV[0];
     shift; 
  }
  elsif (/^-/) {
     warn "Latexmk: $_ bad option\n"; 
     $bad_options++;
  }
  else {
     push @command_line_file_list, $_ ; 
  }
}

if ( $bad_options > 0 ) {
    &exit_help( "Bad options specified" );
}

warn "Latexmk: This is $version_details, version: $version_num.\n",
     "**** Report bugs etc to John Collins <collins at phys.psu.edu>. ****\n"
   unless $silent;

# For backward compatibility, convert $texfile_search to @default_files
# Since $texfile_search is initialized to "", a nonzero value indicates
# that an initialization file has set it.
if ( $texfile_search ne "" ) {
    @default_files = split / /, "*.tex $texfile_search";
}

#printA "A: Command line file list:\n";
#for ($i = 0; $i <= $#command_line_file_list; $i++ ) {  print "$i: '$command_line_file_list[$i]'\n"; }

#Glob the filenames command line if the script was not invoked under a 
#   UNIX-like environment.
#   Cases: (1) MS/MSwin native    Glob
#                      (OS detected as MSWin32)
#          (2) MS/MSwin cygwin    Glob [because we do not know whether
#                  the cmd interpreter is UNIXy (and does glob) or is
#                  native MS-Win (and does not glob).]
#                      (OS detected as cygwin)
#          (3) UNIX               Don't glob (cmd interpreter does it)
#                      (Currently, I assume this is everything else)
if ( ($^O eq "MSWin32") || ($^O eq "cygwin") ) {
    # Preserve ordering of files
    @file_list = glob_list1(@command_line_file_list);
#print "A1:File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }
}
else {
    @file_list = @command_line_file_list;
#print "A2:File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }
}
@file_list = uniq1( @file_list );


# Check we haven't selected mutually exclusive modes.
# Note that -c overides all other options, but doesn't cause
# an error if they are selected.
if (($printout_mode && ( $preview_mode || $preview_continuous_mode ))
    || ( $preview_mode && $preview_continuous_mode ))
{
  # Each of the options -p, -pv, -pvc turns the other off.
  # So the only reason to arrive here is an incorrect inititalization
  #   file, or a bug.
  &exit_help( "Conflicting options (print, preview, preview_continuous) selected");
}

if ( @command_line_file_list ) {   
    # At least one file specified on command line (before possible globbing).
    if ( !@file_list ) {
        &exit_help( "Wildcards in file names didn't match any files");
    }
}
else {
    # No files specified on command line, try and find some
    # Evaluate in order specified.  The user may have some special
    #   for wanting processing in a particular order, especially
    #   if there are no wild cards.
    # Preserve ordering of files
    my @file_list1 = uniq1( glob_list1(@default_files) );
    my @excluded_file_list = uniq1( glob_list1(@default_excluded_files) );
    # Make hash of excluded files, for easy checking:
    my %excl = ();
    foreach my $file (@excluded_file_list) {
	$excl{$file} = '';
    }
    foreach my $file (@file_list1) {
	push( @file_list, $file)  unless ( exists $excl{$file} );
    }    
    if ( !@file_list ) {
	&exit_help( "No file name specified, and I couldn't find any");
    }
}

$num_files = $#file_list + 1;
$num_specified = $#command_line_file_list + 1;

#print "Command line file list:\n";
#for ($i = 0; $i <= $#command_line_file_list; $i++ ) {  print "$i: '$command_line_file_list[$i]'\n"; }
#print "File list:\n";
#for ($i = 0; $i <= $#file_list; $i++ ) {  print "$i: '$file_list[$i]'\n"; }


# If selected a preview-continuous mode, make sure exactly one filename was specified
if ($preview_continuous_mode && ($num_files != 1) ) {
    if ($num_specified > 1) {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode\n".
          "    but $num_specified were specified"
        );
    }
    elsif ($num_specified == 1) {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode\n".
          "    but wildcarding produced $num_files files"
        );
    }
    else {
        &exit_help( 
          "Need to specify exactly one filename for ".
              "preview-continuous mode.\n".
          "    Since none were specified on the command line, I looked for \n".
          "    files in '@default_files'.\n".
          "    But I found $num_files files, not 1."
        );
    }
}


# If landscape mode, change dvips processor, and the previewers:
if ( $landscape_mode )
{
  $dvips = $dvips_landscape;
  $dvi_previewer = $dvi_previewer_landscape;
  $ps_previewer = $ps_previewer_landscape;
}

if ( $silent ) { 
    $latex .= " $latex_silent_switch"; 
    $pdflatex .= " $pdflatex_silent_switch"; 
    $bibtex .= " $bibtex_silent_switch"; 
    $makeindex .= " $makeindex_silent_switch"; 
    $dvips .= " $dvips_silent_switch"; 
}

# Which files do we need to make?
$need_dvi = $need_ps = $need_pdf = 0;
# Which kind of file do we preview?
if ( $view eq "default" ) {
    # If default viewer requested, use "highest" of dvi, ps and pdf
    #    that was requested by user.  
    # No explicit request means view dvi.
    $view = "dvi";
    if ( $postscript_mode ) { $view = "ps"; }
    if ( $pdf_mode ) { $view = "pdf"; }
}

# Now check all the requirements that force us to make files.
$need_dvi = $dvi_mode;
$need_ps  = $postscript_mode;
$need_pdf = $pdf_mode;
if ( $preview_continuous_mode || $preview_mode ) {
    if ( $view eq "dvi" ) {$need_dvi = 1; }
    if ( $view eq "ps" )  {$need_ps = 1; }
    if ( $view eq "pdf" ) {
        # Which of the two ways to make pdf files do we use?
        if ( $need_pdf ) {
            # We already have been told how to make pdf files
        }
        else {
            # Use pdflatex route:
            $need_pdf = 1; 
        }
    }
}

# What implicit requests are made?
if ( length($dvi_filter) != 0 ) {$need_dvi = 1; }
if ( length($ps_filter) != 0 )  {$need_ps = 1; }
if ( $banner ) { $need_ps = 1; }
# printout => need ps
if ( $printout_mode ) { 
    ## May be wrong if print from other kinds of file
    if ( $print_type eq 'dvi' ) {
        $need_dvi = 1; 
    }
    elsif ( $print_type eq 'none' ) {
        # Nothing
    }
    elsif ( $print_type eq 'pdf' ) {
        # Will need a pdf file, but there are several methods to make it
        # Respect a previous request, otherwise get pdf by pdflatex
        if ( $need_pdf == 0 ) {
            $need_pdf = 1; 
        }
    }
    elsif ( $print_type eq 'ps' ) {
        $need_ps = 1; 
    }
    else {
     die "Latexmk: incorrect value \"$print_type\" for type of file to print\n".
         "Allowed values are \"dvi\", \"pdf\", \"ps\", \"none\"\n"
    }
}

# pdf file by ps2pdf => ps file needed. 
if ( $need_pdf == 3 ) { $need_dvi = 1; }
if ( $need_pdf == 2 ) { $need_ps = 1; }
# postscript file => dvi file needed. 
if ( $need_ps ) { $need_dvi = 1; }

# If no files requested, default to dvi:
if ( ! ($need_dvi || $need_ps || $need_pdf) ) { $need_dvi = 1; }

if ( $need_pdf == 2 ) {
    # We generate pdf from ps.  Make sure we have the correct kind of ps.
    $dvips .= " $dvips_pdf_switch";
}

# Which conversions do we need to make?
$tex_to_dvi = $dvi_to_ps = $ps_to_pdf = $dvi_to_pdf = $tex_to_pdf = 0;
if ($need_dvi) { $tex_to_dvi = 1; }
if ($need_ps) { $dvi_to_ps = 1; }
if ($need_pdf == 1) { $tex_to_pdf = 1; }
if ($need_pdf == 2) { $ps_to_pdf = 1; }
if ($need_pdf == 3) { $dvi_to_pdf = 1; }

# Make convenient forms for lookup.
# Extensions always have period.

# Convert @generated_exts to a hash for ease of look up, with exts preceeded 
# by a '.'
%generated_exts = ();
foreach (@generated_exts) {
    $generated_exts{".$_"} = 1;
}
%generated_exts_all = %generated_exts;
foreach (@generated_exts1) {
    $generated_exts_all{".$_"} = 1;
}

$quell_uptodate_msgs = $silent; 
   # Whether to quell informational messages when files are uptodate
   # Will turn off in -pvc mode

# Process for each file.
# The value of $bibtex_mode set in an initialization file may get
# overridden, during file processing, so save it:
$save_bibtex_mode = $bibtex_mode;

$failure_count = 0;
$last_failed = 0;    # Flag whether failed on making last file
                     # This is used for showing suitable error diagnostics
FILE:
foreach $filename ( @file_list )
{
    $failure = 0;        # Set nonzero to indicate failure at some point of 
                         # a make.  Use value as exit code if I exit.
    $failure_msg = '';   # Indicate reason for failure
    $bibtex_mode = $save_bibtex_mode;

    if ( $do_cd ) {
       ($filename, $path) = fileparse( $filename );
       warn "Latexmk: Changing directory to '$path'\n";
       pushd( $path );
    }
    else {
	$path = '';
    }


    ## remove extension from filename if was given.
    if ( &find_basename($filename, $root_filename, $texfile_name) )
    {
	if ( $force_mode ) {
	   warn "Latexmk: Could not find file [$texfile_name]\n";
	}
	else {
            &ifcd_popd;
	    &exit_msg1( "Could not find file [$texfile_name]",
			11);
	}
    }

    if ($cleanup_mode > 0)
    {
        ## Do clean if necessary
        &cleanup_basic;
        if ( $cleanup_mode != 2 ) { &cleanup_dvi_ps_pdf; }
        if ( $cleanup_mode != 3 ) { &cleanup_aux_dep; }
        next FILE;
    }
    if ($go_mode == 2) {
        warn "Latexmk: Removing all generated files\n" unless $silent;
        &cleanup_basic;
        &cleanup_dvi_ps_pdf;
        &cleanup_aux_dep;
    }
    #Initialize aux_file list:
    @aux_files = ("$root_filename.aux");
    ## Make file. ##
    ## Find source files:
    %source_times = ();
         # This will hold a hash mapping filenames to times
         #    filename => time stamp
         # Each file will be a source, direct or indirect.
         # Time_stamp is zero for non-existent file.
         # It is to be used to determine whether a remake through latex 
         #     is needed, particularly in -pvc mode
         # The time will be the file's timestamp when:
         #     (a) it is used as source, just before run
         #  or (b) created as dependent, just after run
         #  or (c) when first encountered (e.e., initially)
         #  in order of preference.
         # The update_... subroutines provide the best method of handling 
         #  this:
         # Overall rules:
         #    1.  %source_times reflects the times of files immediately a run
         #        in which they are sources or destinations
         #    2.  Source files have times corresponding to the files used 
         #        by their user program.
         #    3.  After each program is run, it should check for changes in its 
         #        sources, and rerun if needed.
         #    4.  Thus after running a program, we know that its output is 
         #        up-to-date with respect to its sources, and 
         #        %source_times contains the times of the sources used.
         #    5.  If it updates the times of the destination files, that is OK,
         #        since we are not yet using the destination files as sources
         #        for another program; these destination files will automatically
         #        cause an out-of-date condition for the other program.
         #    6.  The last condition is important, because the finding
         #        of dependencies may result in new files being found.
         # HENCE:
         # After running each program (latex, makeindex, bibtex or 
         #    custom_dependency), update the part of %source_times 
         #    corresponding to its input files.
         #    But leave other times unaltered.
         # In addition cus_dependency may find new source files for latex
         #    and we must add these to the relevant list
         # (Hence need list of relevant source filenames.)
         # In addition, we must allow for source files changing
         #    during a run.  This is most important for latex, since
         #    it may run a long time.  
         # So we must check for changed source files immediately after a run.
         #    and trigger a rerun.
         # In addition, unused files may accumulate in %source_times,
         #    if they were used earlier and then not used later.
         # So after a full parse_log, we must ensure that %source_times
         #    is updated to reflect the current set of source files.
         #    But with the times  being taken from the previously known 
         #    values, if any.
         # Using the previously known values ensures that we can detect
         #    the case that a source filetime changed since its user
         #    program was run. 
    # We split the source files according to their status
    # bibtex and makeindex are special, because they are in 
    #    a circular dependence loop
    @bib_files = ();      # Sources for bibtex
    @cus_dep_files = ();  # Sources for custom dependency
    @ind_files = ();      # Sources for makeindex
    @includes = ();       # Sources files read by latex, excluding
                          # those involved circularly
    %includes_missing = (); # Possible source files for latex, 
        # whose status is problematic.  In form
        # filename => [wherefrom, fullname]
        # wherefrom  0: exact name known. 
        #            1: name for non-existent file, from logfile, possibly 
        #                   bad parse, possibly it's been deleted.
        #            2: not necessarily fullname, from logfile, probably OK
        #                   (graphics file, typically).  
        #                   File not found by latexmk.
        #            3: possibly incomplete (pathless, possibly extension-less)
        #                   name from error message in .log file
        #            4: non-found file from .tex file: either non-existent file
        #                   or I didn't find it.
    $read_depend = 0;  # True to read depend file, false to generate it.
    $dep_file = "$root_filename.dep";

    ## Figure out if we read the dependency file or generate a new one.
    if ( ! $force_generate_and_save_includes )
    {
      if ( $generate_and_save_includes )
      {
	if ( -e $dep_file )
	{
	  # Compare timestamp of dependency file and root tex file.
	  $dep_mtime = &get_mtime("$dep_file");
	  $tex_mtime = &get_mtime("$texfile_name");
	  if ( $tex_mtime < $dep_mtime )
	  {
	    $read_depend = 1;
	  }
	}
      }
      elsif ( -e $dep_file )  # If dependency file already exists.
      {
	$read_depend = 1;
      }
    }

    if ( $includes_from_log )
    {
       &parse_log;
       if ( $force_generate_and_save_includes 
            || ($generate_and_save_includes && $read_depend == 0 )
          )
       {
          &update_depend_file;
       }
    }
    elsif ( $read_depend )
    {
      # Read the dependency file     
      # $read_depend should only be set if the dep_file actually exists
      # So a failure to open it indicates a problem, e.g., user deleted the file,
      #    which calls for a die rather than simply setting $failure
      my $return = process_dep_file( $dep_file );
      if ($return > 0) {
          # Error message was already printed.
	  if (!$force_mode ) {
             warn "Latexmk: I will not continue processing this file.\n";
             warn "Latexmk: Use the -f option to force processing.\n";
             if ($return ==2) {
                # There were syntax errors
                warn "Latexmk: Try deleting or removing the dependency file '$dep_file'\n",
                     "   to remove errors\n";
	     }
             next FILE;
	  }
      }
    }
    else
    {
      # Generate dependency file.
      &scan_for_includes("$texfile_name"); 
      &update_depend_file;
    }

#    warn "====@includes===\n";

    #************************************************************

    if ( $preview_continuous_mode ) { 
        &make_preview_continuous; 
        # Will probably exit by ctrl/C and never arrive here.
        next FILE;
    }


## Handling of failures:
##    Variable $failure is set to indicate a failure, with information
##       put in $failure_msg.  
##    These variables should be set to 0 and '' at any point at which it
##       should be assumed that no failures have occurred.
##    When after a routine is called it is found that $failure is set, then
##       processing should normally be aborted, e.g., by return.
##    Then there is a cascade of returns back to the outermost level whose 
##       responsibility is to handle the error.
##    Exception: An outer level routine may reset $failure and $failure_msg
##       after initial processing, when the error condition may get 
##       ameliorated later.
    #Initialize failure flags now.
    $failure = 0;
    $failure_msg = '';
    &make_files($go_mode);
    if ($failure > 0) { next FILE;}
    &make_preview  if  $preview_mode ;
    if ($failure > 0) { next FILE;}
    &make_printout if $printout_mode ;
    if ($failure > 0) { next FILE;}
} # end FILE
continue {
    # Handle any errors
    if ( $failure > 0 ) {
        if ( $failure_msg ) {
            #Remove trailing space
            $failure_msg =~ s/\s*$//;
            warn "Latexmk: Did not finish processing file: $failure_msg\n";
            $failure = 1;
        }
        $failure_count ++;
        $last_failed = 1;
    }
    else {
        $last_failed = 0;
    }
    &ifcd_popd;
}
# If we get here without going through the continue section:
if ( $do_cd && ($#dir_stack > -1) ) {
   # Just in case we did an abnormal exit from the loop
   warn "Latexmk: Potential bug: dir_stack not yet unwound, undoing all directory changes now\n";
   &finish_dir_stack;
}

if ($failure_count > 0) {
    if ( $last_failed <= 0 ) {
        # Error occured, but not on last file, so
        #     user may not have seen error messages
        warn "\n------------\n";
        warn "Latexmk: Some operations failed.\n";
    }
    if ( !$force_mode ) {
      warn "Latexmk: Use the -f option to force complete processing.\n";
    }
    exit 12;
}



# end MAIN PROGRAM
#############################################################

#************************************************************
#### Subroutines
#************************************************************

#************************************************************
#### Highest level


sub make_files
{
    my $do_build = $_[0];
    my $new_files = &find_new_files;
    my $new_deps = &make_dependents($do_build);
    if ( ($new_files > 0) || ($new_deps > 0) ) {
	$do_build = 1;
    }

    # Ensure bbl file up-to-date.  
    # Also remake the bbl file if there is a bad citation, or if we
    #     use go_mode (which says to remake everything)
    # The call to &make_bbl will also remake the bbl file if it is
    #    out-of-date with respect to the bib files
    # But ignore the return code from make_bbl, since the bbl file depends 
    # on the aux file, which may in fact be out of date if the tex file has
    # changed, and we are about to re-latex it.

    &make_bbl($bad_citation || $do_build) if $bibtex_mode ; 

    # Similarly for ind file.  This is simpler because it only depends
    # on the idx file.
    &make_ind($do_build) if $index_mode ;

    # In the remaining makes, the postscript and pdf makes will be
    #   triggered by a successful make of dvi or pdf, so they do not
    #   need a $do_build argument
    # Reset the failure information, since the initial set up routines 
    #   may have reacted to out-of-date information.
    $failure = 0;
    $failure_msg = '';
    &make_latex_dvi_pdf($do_build, 'dvi') if ($need_dvi) ;
    if ($failure > 0) { return;}
    &make_postscript                      if ($need_ps) ;
    if ($failure > 0) { return;}
    &make_latex_dvi_pdf($do_build, 'pdf') if ($need_pdf == 1) ;
    if ($failure > 0) { return;}
    &make_pdf2                            if ($need_pdf == 2) ;
    if ($failure > 0) { return;}
    &make_pdf3                            if ($need_pdf == 3) ;
    if ($failure > 0) { return;}
}

#************************************************************

sub make_latex_dvi_pdf
# Usage make_latex_dvi_pdf( do_build, type_of_build )
# Arrive here:  log_file parsed
#               dependents up-to-date
#               bbl up-to-date
#               ind up-to-date
{
  my $do_build = $_[0];
  my $dest_type = $_[1];
  my $dest;
  my $processor;
  if ( $dest_type eq 'dvi' ) { 
      $dest = "$root_filename.dvi"; 
      $processor = $latex;
  } elsif ( $dest_type eq 'pdf' ) { 
      $dest = "$root_filename.pdf"; 
      $processor = $pdflatex; 
  } else {
      warn "Latexmk::make_latex_dvi_pdf: BUG: ",
           "undefined destination type '$dest_type'";
      exit 20;
  }

  ## get initial last modified times.
  #    Include explicit name of primary tex source, just in case
  #      it's not obtained from parsing the log file 
  #      (under error or exotic conditions, e.g., files renamed)
  my $tex_mtime = &get_latest_mtime(@includes, $texfile_name);
  my $dest_mtime= &get_mtime("$dest");
  my $aux_mtime = &get_mtime("$root_filename.aux");
  my $bib_mtime = &get_latest_mtime(@bib_files);
  my $bbl_mtime = &get_mtime("$root_filename.bbl");
  my $ilg_mtime = &get_mtime("$root_filename.ilg");
  my $ind_mtime = &get_mtime("$root_filename.ind");

  ## - if no destination file (dvi or pdf), 
  ##      or .aux older than tex file or bib file or anything they input, 
  ##   then run latex.

  #print "'$root_filename': aux = $aux_mtime;  tex = $tex_mtime\n";
  #show_array( "Include names: ", @includes );
  #&list_conditions (
  #   $do_build, 
  #   !(-e "$root_filename.aux"),
  #   ($aux_mtime < $tex_mtime),
  #   !(-e "$dest"),
  #   ( (-e "$root_filename.bbl") && ($aux_mtime < $bbl_mtime) ),
  #   ($dest_mtime < $tex_mtime),
  #   ( (-e "$root_filename.ilg") && ($aux_mtime < $ilg_mtime) ),
  #   ( (-e "$root_filename.ind") && ($aux_mtime < $ind_mtime) ),
  #   ( $includes_from_log && ! -e "$root_filename.log" )
  #);
  my $dest_bad =  (!-e "$dest") || ($dest_mtime < $tex_mtime) ;
  my $outofdate =
	$do_build
	|| !(-e "$root_filename.aux")
	|| ($aux_mtime < $tex_mtime)
	|| $dest_bad
	|| ( (-e "$root_filename.bbl") && ($aux_mtime < $bbl_mtime) )
	|| ( (-e "$root_filename.ilg") && ($aux_mtime < $ilg_mtime) )
	|| ( (-e "$root_filename.ind") && ($aux_mtime < $ind_mtime) )
	|| ( $includes_from_log && ! -e "$root_filename.log" );
  if ( $outofdate ){ 
      &build_latex_dvi_pdf($processor);
      if ($failure > 0) { return;}
  }
  else { 
      warn "Latexmk: File '$dest' is up to date\n" 
         if !$quell_uptodate_msgs;
  }
  &make_dvi_filtered if ( $dest_type eq 'dvi');
  if ($failure > 0) { return;}
}

sub list_conditions {
    my $on = 0;
    foreach (@_) {
	if ($_) {$on = 1;}
    }
    if (!$on) {return;}
    print "On conditions: ";
    for ($i = 1; $i <= $#_+1; $i++) {
	if ($_[$i-1]) {print "$i ";}
    }
    print "===\n";
}

#************************************************************

sub build_latex_dvi_pdf { 
    # Argument: 0 = processor (e.g., 'latex' or 'pdflatex')
    #
    # I don't need to know whether I run latex or pdflatex!
    #
    # Repeat running latex as many times as needed to resolve cross
    # references, also running bibtex and makeindex as necessary.  The
    # algorithm for determining whether latex needs to be run again is
    # whether certain generated files have changed since the previous
    # run.  A limit (contained in $max_repeat) is applied on the
    # number of runs, to avoid infinite loops in pathological cases or
    # in the case of a bug.  $max_repeat should be at least 4, to
    # allow for the maximum number of repeats under normal
    # circumstances, which is 3, plus one for unusual cases of page
    # breaks moving around.  
    #
    # The criterion for needing a rerun is that one or both of the
    # .aux file and the .idx file has changed.  To prove this: observe
    # that reruns are necessary because information that needs to be
    # read in from a file does not correspond to the current
    # conditions.  The relevant files are: the .aux file, and possibly
    # one or more of: the index files, the table of contents file
    # (.toc), the list of figures file (.lof), the list of tables file
    # (.lot).  The information read in is: cross reference
    # definitions, page references, tables of contents, figures and
    # tables.  Note that the list of figures (for example) may itself
    # contain undefined references or incorrect page references.  If
    # there is any incorrectness, changed information will be written
    # to the corresponding file on the current run, and therefore one
    # or more of the auxiliary files will have changed.  
    #
    # In fact the lines in the .toc, .lof and .lot files correspond to
    # entries in the .aux file, so it is not necessary to check the
    # .toc, .lof and .lot files (if any).  However WHETHER these files 
    # are input by latex is not determined by the aux file, but does
    # affect the output.  It is possible for the tex file to change
    # the state of one of the .toc, .lof, or .lot files between begin
    # required and not required.  The same could happen for other
    # input files.  
    #
    # For example, initially suppose no TOC is required, and that all
    # generated files are up-to-date.  The .toc file is either not
    # present or is out-of-date.  Then change the source file so
    # that a TOC is requested.  Run latex; it uses wrong TOC
    # information, but the .aux file might not change.  
    #
    # Two possibilities: (a) check .toc, .lof, .lot (possibly etc!)
    # files for changes; (b) check for a change in the list of input
    # files.  We'll choose the second: since it requires less file
    # checking and is more general.  It applies in all situations
    # where the extra auxiliary input files (e.g., .toc) correspond in
    # contents to the state of the .aux file, but only if these files
    # are used. 
    #
    # Therefore a correct algorithm is to require a rerun if either of
    # the following is true:
    #
    #    1.  The .aux file has changed from the previous run.
    #    2.  The .idx file has changed from the previous run.
    #    3.  ?? The set of input files has changed from the previous run.
    #       This causes too many problems.
    #       If the generated files are in the input list, their
    #           time stamps get tested, which is VERY wrong
    #       Change of set of input files is entirely irrelevant under all 
    #           other situations, and to test for it is WRONG.
    #       Best is a thorough-going configurable analysis of generated files
    #           that get into circular dependences.
    #
    # Of course, if a previous version of one of these files did not
    # exist (as on a first run), then that implies a rerun is
    # necessary. And if a .aux file or a .idx file is not generated,
    # there is no point in testing it against a previous version.
    #
    # Assume on entry that the .ind and .bbl files are up-to-date with 
    # respect to the already existing .idx and .aux files.  This will
    # be the case if latexmk was used to make them.

    my $aux_file;
    my $processor = $_[0];

    # Count runs of latex, so we can bail out if we need too many runs,
    #    but we'll reset the count if the source files change.
    # But for sane error messages, we'll count the previous runs
    my $count_latex = 0;  
    my $uncounted_latex = 0;
    my $repeat = 0;
  
    do {
        # Arrival here means that a new run of latex/pdflatex is requested
        # Assume:
        # (a) .ind file (if any) 
        #          corresponds to the .idx file from the previous run
        #      AND is up-to-date wrt any sources (.ist) ?? to check
        # (b) .bbl file (if any) 
        #          corresponds to the .aux file from the previous run.
        #      AND is up-to-date wrt sources (.bib, .bst) ?? to check
        # (c) files generated by custom dependency are up-do-date
        # (d) %source_times set

        $repeat = 0;     # Assume no repeat necessary.
	$count_latex++;  # Count the number of passes through latex
        my $count_string = "$count_latex";
        if ($uncounted_latex > 0) { $count_string .= "+$uncounted_latex"; }
        warn_running( "Run number $count_string of '$processor $texfile_name'" );
        foreach $aux_file (@aux_files) 
        {
            if ( -e $aux_file ) {
	        warn "Latexmk: Saving old .aux file \"$aux_file\"\n"
                    unless $silent;
                copy_file_and_time ( "$aux_file", "$aux_file.bak");
            }
        }
        if ( (! -e "$root_filename.aux") && (! -e "$root_filename.aux.bak") ) {
            # Arrive here if neither of the .aux and the .aux.bak files exists
            # for the base file.
            # I make minimal .aux.bak file, containing a single line "\relax "
            # This is the same as the aux file generated for a latex file
            # which does not need any cross references, etc.  Generating this
            # .aux.bak file will save a pass through latex on simple files.
            local $aux_bak_file = ">$root_filename.aux.bak";
            open(aux_bak_file) or die "Cannot write file $aux_bak_file\n";
            print aux_bak_file "\\relax \n";
            close(aux_bak_file);
        }
        if ( (! -e "$root_filename.aux") && ( -e "$root_filename.aux.bak") ) {
            # Arrive here if .aux does NOT exist 
            # BUT the .aux.bak file DOES exist
            # ?? What to do?
        }
        if ( (-e "$root_filename.aux") && $bibtex_mode) { 
           # We have assumed that the bbl file is up-to-date 
           #    with respect to the previous aux file.  However
           #    it may be out-of-date with respect to the bib file(s).
           # So run bibtex in this case
           my $bibtex_return_code = &make_bbl(0);
           if ( ($bibtex_return_code == 2) & !$force_mode )
           {
	       $failure = 1;
               $failure_msg = 'Bibtex reported an error';
               return;
               #### Bypass to end of calling eval-block
               ###die "Bibtex reported an error\n";
           }
        }

        if ( -e "$root_filename.idx" ) {
	    warn "Latexmk: Saving old .idx file '$root_filename.idx'\n" 
               unless $silent;
            copy_file_and_time ( "$root_filename.idx", "$root_filename.idx.bak");
        }

        ########## Run latex (or c.):
        my @includes_previous = @includes;
        &update_source_times(@includes);
        my ($pid, $return_latex) = &Run("$processor \"$texfile_name\""); 
        # Did the source files change while we were running?
        my $source_changed = &update_source_times(@includes);


        ######### Analyze results of run:
        # List reasons for rerun. 
        my @reason = ();
        # Variables to analyze need to rerun:
        my $aux_changed = 0;
        my $idx_changed = 0;
        my @aux_files_previous = @aux_files;

        ####### Capture any changes in source file status before we
        #         check for errors in the latex run
        my $return_log = &parse_log;
        if ( $return_log == 0 ) {
           &aux_restore;
           $failure = 1;
           $failure_msg = "Latex failed to generate a log file";
           return;
           #### Bypass to end of calling eval-block
           ###die "Latex failed to generate a log file\n";
	}

        ####### Check for new files, direct or indirect
        my $new_files = &find_new_files;
        my $new_deps = &make_dependents(0);
#	warn "==== $new_files $new_deps";
        if ($new_files > 0) {
            push @reason, "New source files found";
	}
        if ($new_deps > 0) {
            push @reason, "Custom-dependency files changed";
            $uncounted_latex += $count_latex;
            $count_latex = 0;
	}


        if ($return_latex) {
           # ?? Must 
           #  a) parse_log file (so -pvc has latest dependency information)
           #  b) check for newfiles, and do dependency check;
           #     don't abort if new files become available.  Rather repeat
           #  c) Perhaps best to explicitly look for the missing files.
           #  d) Also in -pvc must check for new files.
           if (!$force_mode) {
               if ( ($new_files > 0) || $source_changed ) {
                  warn "Latexmk: Latex encountered an error,\n",
                       "         I am not in force_mode,\n",
                       "         but new source files are found,\n",
                       "   So I will try running Latex again\n";
	       }
               else {
                   &aux_restore;
                   $failure = 1;
                   $failure_msg = "Latex encountered an error";
                   return;
                   #### Bypass to end of calling eval-block
                   ###die "Latex encountered an error\n";
	       }
           }
           elsif ($silent) {
               # User may not have seen error
               warn "====Latex encountered an error: see .log file====\n";
           }
        }

        $updated = 1;    # Flag that some dependent file has been remade

        if ( $includes_from_log )
        {
           if ( @aux_files ne @aux_files_previous ){
	       $aux_changed = 1;
               push @reason, "List of .aux files has changed";
	   }
        }

        if ( !$aux_changed )
        {
           # Look for changes in the individual aux files.
	   foreach $aux_file (@aux_files)
           {
              if ( -e "$aux_file" ) {
                  if ( &diff ("$aux_file", "$aux_file.bak") ) {
                      push @reason, ".aux file '$aux_file' changed";
                      $aux_changed = 1;
                      last;
                  }
                  else {
                      warn "Latexmk: File \"$aux_file\" has not changed, ",
                           "so it is valid\n" unless $silent;
	          }
	      }
	   }
        }
        if ( (!-e "$root_filename.aux") && (-e "$root_filename.aux.bak") ) {
           warn "Latexmk: No aux file was generated, ",
                         "so I don't need .aux.bak file\n"
              unless $silent;
           unlink ("$root_filename.aux.bak");
        }

        if ( (-e "$root_filename.aux") && $aux_changed && $bibtex_mode) { 
            # Note running bibtex only makes sense if the aux file exists.
            # If any aux file has changed, then the citations may
            # have changed and we must run bibtex. 
            # The argument to &make_bbl forces this.
            # &make_bbl also checks whether the bbl file is
            #   out-of-date with respect to the bib files.
            my $bibtex_return_code = &make_bbl($aux_changed);
            if ( ($bibtex_return_code == 2) && !$force_mode ) 
            {
   	       $failure = 1;
               $failure_msg = 'Bibtex reported an error';
               return;
               #### Bypass to end of calling eval-block
               ###die "Bibtex reported an error\n";

            }
        }

        if ( -e "$root_filename.idx" ) {
           if ( &diff ("$root_filename.idx", "$root_filename.idx.bak") ) {
               # idx file exists and has changed 
               #    implies idx file written 
               #    implies indexing being used
               push @reason, "The .idx file changed";
               $index_mode = 1;
	       $idx_changed = 1;
           } else {
               warn "Latexmk: The .idx file has not changed, so it is valid\n"
                  unless $silent;
           }
           if ($index_mode) {
              my $makeindex_return_code = &make_ind($idx_changed);
              if ( ($makeindex_return_code == 2) & !$force_mode ) {
	         $failure = 1;
                 $failure_msg = 'Makeindex reported an error';
                 return;
                 #### Bypass to end of calling eval-block
                 ###die "Makeindex reported an error\n";
              }
           }
        }
        else {
           if ($index_mode) {
              warn "Latexmk: No .idx file was generated, but index_mode is set; ",
                   "I will unset it"
                 unless $silent;
              $index_mode = 0;
           }
           if ( -e "$root_filename.idx.bak") {
              warn "Latexmk: No idx file was generated. ",
                   "So I delete unneeded .idx.bak file\n"
                 unless $silent;
              unlink ("$root_filename.idx.bak");
           }
       }

#        if ( @includes ne @includes_previous ) { 
#            push @reason, "The set of input files changed.  ";
#        }

        $source_changed2 = &update_all_source_times;

        if ($source_changed ) {
            push @reason, "File '$source_changed' changed during run";
            $uncounted_latex += $count_latex;
            $count_latex = 0;
	}
        if ($source_changed2) {
            push @reason, "File '$source_changed2' changed during run";
            $uncounted_latex += $count_latex;
            $count_latex = 0;
	}
        if ( $#reason >= 0
#             $aux_changed 
#             || $idx_changed 
#             ||( @includes ne @includes_previous ) 
#             || ( $new_files > 0 )
#             || ( $new_deps > 0 )
#             || $source_changed
#             || $source_changed2
           ) {
            $repeat = 1;
            if ( $diagnostics ) {
                show_array( "Latexmk: I must rerun latex, because:", @reason);
            }
            elsif (!$silent) {
		warn "Latexmk: $reason[0].  I must rerun latex\n";
#		if !$silent && ($#reason >=0) ;
            }
        }

        if ( $count_latex ge $max_repeat ) { 
           # Avoid infinite loop by having a maximum repeat count
           # Getting here represents some kind of weird error.
           if ($repeat ) {
              warn "Latexmk: Maximum runs of latex reached ",
                   "without correctly resolving cross references\n";
           }
           $repeat = 0;
        }
        if ( $count_latex + $uncounted_latex ge $max_abs_repeat ) { 
           if ($repeat ) {
              warn "Latexmk: Absolute maximum runs of latex reached ",
                   "without finding stable source files\n";
           }
           $repeat = 0;
        }
    } until ($repeat == 0);

# Summarize issues that may have escaped notice:
    my @warnings = ();
    if ($bad_reference) {
        push @warnings, "Latex could not resolve all references";
    }
    if ($bad_citation) {
        push @warnings, "Latex could not resolve all citations";
    }
    if ($bibtex_mode) {
        my $retcode = &check_bibtex_log;
        if ($retcode == 3) {
            push @warnings, "Could not open bibtex log file for error check";
        }
        elsif ($retcode == 2) {
          push @warnings, "Bibtex errors";
        }
        elsif ($retcode == 1) {
          push @warnings, "Bibtex warnings";
        }

    }
    if ($#warnings > 0) {
	show_array( "Latexmk: Summary of warnings:", @warnings );
    }
}

#************************************************************

# Finds the basename of the root file
# Arguments:
#  1 - Filename to breakdown
#  2 - Where to place base file
#  3 - Where to place tex file
#  Returns non-zero if tex file does not exist
#
# The rules for determining this depend on the implementation of TeX.
# The variable $extension_treatment determines which rules are used.

sub find_basename
#?? Need to use kpsewhich, if possible
{
  local($given_name, $base_name, $ext, $path, $tex_name);
  $given_name = $_[0];
  if ( "$extension_treatment" eq "miktex_old" ) {
       # Miktex v. 1.20d: 
       #   1. If the filename has an extension, then use it.
       #   2. Else append ".tex".
       #   3. The basename is obtained from the filename by
       #      removing the path component, and the extension, if it
       #      exists.  If a filename has a multiple extension, then
       #      all parts of the extension are removed. 
       #   4. The names of generated files (log, aux) are obtained by
       #      appending .log, .aux, etc to the basename.  Note that
       #      these are all in the CURRENT directory, and the drive/path
       #      part of the originally given filename is ignored.
       #
       #   Thus when the given filename is "\tmp\a.b.c", the tex
       #   filename is the same, and the basename is "a".

       ($base_name, $path, $ext) = fileparse ($given_name, '\..*');
       if ( "$ext" eq "") { $tex_name = "$given_name.tex"; }
       else { $tex_name = $given_name; }
       $_[1] = $base_name;
       $_[2] = $tex_name;
  }
  elsif ( "$extension_treatment" eq "unix" ) {
       # unix (at least web2c 7.3.1) => 
       #   1. If filename.tex exists, use it, 
       #   2. else if filename exists, use it.
       #   3. The base filename is obtained by deleting the path
       #      component and, if an extension exists, the last
       #      component of the extension, even if the extension is
       #      null.  (A name ending in "." has a null extension.)
       #   4. The names of generated files (log, aux) are obtained by
       #      appending .log, .aux, etc to the basename.  Note that
       #      these are all in the CURRENT directory, and the drive/path
       #      part of the originally given filename is ignored.
       #
       #   Thus when the given filename is "/tmp/a.b.c", there are two
       #   cases: 
       #      a.  /tmp/a.b.c.tex exists.  Then this is the tex file,
       #          and the basename is "a.b.c".
       #      b.  /tmp/a.b.c.tex does not exist.  Then the tex file is
       #          "/tmp/a.b.c", and the basename is "a.b".

      if ( -e "$given_name.tex" ) {
         $tex_name = "$given_name.tex";
      }
      else {
         $tex_name = "$given_name";
      }
      ($base_name, $path, $ext) = fileparse ($tex_name, '\.[^\.]*');
      $_[1] = $base_name;
      $_[2] = $tex_name;
  }
  else {
     die "Latexmk: Incorrect configuration gives \$extension_treatment=",
         "'$extension_treatment'\n";
  }
   if ($diagnostics) {
      print "Given='$given_name', tex='$tex_name', base='$base_name'\n";
  }
  return ! -e $tex_name;
}

#************************************************************

sub make_bbl {
# If necessary, make bbl file.  Assume bibtex mode on.
# Force run if first argument is non-zero.
# Update times for bibfiles (external sources for bibtex)
# ?? Should parse blg file to find .bst files
# Return 0 if nothing made, 
#        1 if bbl file made, 
#        2 if bibtex reported an error
#        3 if .blg file couldn't be opened
#        4 if there was another error
   my $bib_mtime = &get_latest_mtime(@bib_files);
   my $bbl_mtime = &get_mtime("$root_filename.bbl");
   ## if no .bbl or .bib changed since last bibtex run, run bibtex.
   if ( !-e "$root_filename.aux" ) 
   {
      # bibtex reads aux file, so if there is no aux file, there is
      # nothing to do
       return 0;
   }   

   if (($_[0] != 0)
       || !(-e "$root_filename.bbl")
       || ($bbl_mtime < $bib_mtime)
       )
   {
       my ($pid, $return) = &Run_msg("$bibtex \"$root_filename\""); 
       $updated = 1;
       &update_source_times( @bib_files );
       $bbl_mtime = &get_mtime("$root_filename.bbl");
       if ( $return != 0 ) 
          {  return 2; }
       $return = &check_for_bibtex_errors;
       if ( $return == 0 ) 
          { return 1;}
       elsif ( $return == 1 ) 
          { return 2;}
       elsif ( $return == 2 ) 
          { return 3;}
       else 
          { return 4; }
   }
   else 
   { return 0; }
}

#************************************************************

sub make_ind {
# If necessary, make ind file.  Assume makeindex mode on.
# Force run if first argument is non-zero.
# Update times for ind_files
# ?? Should parse .ilg file to find .ist files
# Return 0 if nothing made, 
#        1 if ind file made, 
#        2 if makeindex reported an error
   if ( !-e "$root_filename.idx" ) 
   {
      # makeindex reads idx file, so if there is no idx file, there is
      # nothing to do
      return 0;
   }   
   if ( ($_[0] != 0) || !(-e "$root_filename.ind") )
   {
      my ($pid, $return) = &Run_msg("$makeindex \"$root_filename.idx\"");
      &update_source_times( @ind_files );
      $updated = 1;
      if ($return) { return 2; }
      else { return 1; }
   }
   else {
      return 0; 
   }
}

#************************************************************

sub find_new_files
{
    my @new_includes = ();
MISSING_FILE:
    foreach my $missing (uniq( sort keys %includes_missing ) ) {
       my ($base, $path, $ext) = fileparse ($missing, '\.[^\.]*');
       if ( -e "$missing.tex" ) { 
	   push @new_includes, "$missing.tex";
# It's probably best to try all possibilities, since
# we don't know which one applies.  So go on to next case.
#           next MISSING_FILE;
       }
       if ( -e $missing ) { 
	   push @new_includes, $missing;
#           next MISSING_FILE;
       }
       if ( $ext ne "" ) {
           foreach my $dep (@cus_dep_list){
              my ($fromext,$toext) = split(' ',$dep);
              if ( ( "$ext" eq ".$toext" )
                   && ( -e "$path$base.$fromext" )
		  )  {
                  # Source file for the missing file exists
                  # So we have a real include file, and it will be made
                  # next time by &make_dependents
                  push @new_includes, $missing ;
#                  next MISSING_FILE;
              }
              # no point testing the $toext if the file doesn't exist.
	   }
       }
       else {
           # $_ doesn't exist, $_.tex doesn't exist,
           # and $_ doesn't have an extension
           foreach my $dep (@cus_dep_list){
              my ($fromext,$toext) = split(' ',$dep);
              if ( -e "$path$base.$fromext" ) {
                  # Source file for the missing file exists
                  # So we have a real include file, and it will be made
                  # next time by &make_dependents
                  push @new_includes, "$path$base.$toext" ;
#                  next MISSING_FILE;
              }
              if ( -e "$path$base.$toext" ) {
                  # We've found the extensionfor the missing file,
                  # and the file exists
                  push @new_includes, "$path$base.$toext" ;
#                  next MISSING_FILE;
              }
	   }
       }
    } # end MISSING_FILES

    @new_includes = uniq( sort(@new_includes) );

    # Sometimes bad line-breaks in log file (etc) create the
    # impression of a missing file e.g., ./file, but with an incorrect
    # extension.  The above tests find the file with an extension,
    # e.g., ./file.tex, but it is already in the list.  So now I will
    # remove files in the new_include list that are already in the
    # include list.  Also handle aliasing of file.tex and ./file.tex.
    # For example, I once found:
# (./qcdbook.aux (./to-do.aux) (./ideas.aux) (./intro.aux) (./why.aux) (./basics
#.aux) (./classics.aux)

    my @really_new = ();
    # Create a hash indexed by filenames so we can look up filenames.
    my %includes_tmp = ();
    foreach my $file (@includes) {
        my $stripped = $file;
        $stripped =~ s{^\./}{};
        $includes_tmp{$stripped} = 1;
    }
    foreach my $file (@new_includes) {
        my $stripped = $file;
        $stripped =~ s{^\./}{};
        if ( !exists $includes_tmp{$stripped} ) {
           push @really_new, $file;
        }
    }
    @new_includes = @really_new;

    @includes = uniq( sort(@includes, @new_includes) );
    &add_source_times(@new_includes);
    
    my $found = $#new_includes + 1;
    if ( $diagnostics && ( $found > 0 ) ) {
	warn "Latexmk: Detected previously missing files:\n";
        foreach (@new_includes) {
            warn "   '$_'\n";
	}
    }
    return $found;
}

#************************************************************

sub make_dependents
{
# Usage: make_dependents(build)
# First argument = 1 => rebuild unconditionally
#                  0 => rebuild only if dest is out-of-date
# Return 0 if nothing made, 1 if something made
  my $build = shift;
  my $makes = 0;     # Count of makes done
FILE:
  foreach my $file (@includes)
  {
     my ($base_name, $path, $toext) = fileparse ($file, '\.[^\.]*');
     $base_name = $path.$base_name;
     if ( $toext eq "" ) {next FILE;}
     $toext =~ s/^\.//;
DEP:
     foreach my $dep ( @cus_dep_list )
     {
        my ($fromext,$proptoext,$must,$func_name) = split(' ',$dep);
        if ( $toext eq $proptoext )
	{
	   # Found match of rule
	   if ( -e "$base_name.$fromext" )
	   {
	      &add_source_times( "$base_name.$fromext", "$base_name.$toext" );
              # From file exists, now check if it is newer
  	      if (( ! (-e "$base_name.$toext" ))
                  || $build
		  || ( &get_mtime("$base_name.$toext")
                        < &get_mtime("$base_name.$fromext") 
                     )
                 )
              {
                 warn_running( "Running '&$func_name( $base_name )'" );
	         my $return = &$func_name($base_name);
                 $updated = 1;
                 &update_source_times( "$base_name.$fromext", "$base_name.$toext" );
	         if ( !$force_mode && $return )
	         {
                    $failure = $return;
                    $failure_msg = "$func_name encountered an error";
                    last FILE;
                    #### Bypass to end of calling eval-block
                    ###die "$func_name encountered an error\n";
	         }
                 else {
                    $makes++;
		 }
	     }
	  }
	  else
	  {  # Source file does not exist
             # Perhaps the rule is not to be applied.
	     if ( !$force_mode && ( $must != 0 ))
	     {
                $failure = 1;
                $failure_msg = "File '$base_name.$fromext' does not exist ".
                               "to build '$base_name.$toext'";
                last FILE;
                #### Bypass to end of calling eval-block
                ###die "File '$base_name.$fromext' does not exist ".
                ###    "to build '$base_name.$toext'\n";
	     }
	  } # 
       } # End of Rule found
     } # End DEP
  } # End FILE
  return ($makes>0 ? 1 : 0);
} # End sub make_dependents

#************************************************************

sub make_dvi_filtered
{
  my $dvi_file = "$root_filename.dvi";
  my $dviF_file = "$root_filename.dviF";
  return if ( length($dvi_filter) == 0 );
  if ( ! -e $dvi_file ) {
       warn "Latexmk: Dvi file \"$dvi_file\" has not been made, ",
            "so I cannot filter it\n";
       return;
  }
  my $dviF_mtime = &get_mtime("$dviF_file");
  my $dvi_mtime = &get_mtime("$dvi_file");
  if ( (! -e "$dviF_file") 
       || ( $dviF_mtime < $dvi_mtime )
     ) {
     if ( &view_file_via_temporary ) {
        my $tmpfile1 = tempfile1( "${root_filename}_tmp", ".dviF" );
        &Run_msg( "$dvi_filter < \"$dvi_file\" > \"$tmpfile1\"" );
        move( $tmpfile1, $dviF_file );
     }
     else {
        &Run_msg( "$dvi_filter < \"$dvi_file\" > \"$dviF_file\"" );
     }
     $updated = 1;
  }
  else { 
      warn "Latexmk: File '$dviF_file' is up to date\n"
           if !$quell_uptodate_msgs;
  }
}

#************************************************************

sub make_pdf2
{
    my $ps_file;
    my $pdf_file;

    if ( length($ps_filter) == 0 )
        {$ps_file = "$root_filename.ps";}
    else 
        {$ps_file = "$root_filename.psF";}
    $pdf_file = "$root_filename.pdf";

    my $ps_mtime = &get_mtime("$ps_file");
    my $pdf_mtime = &get_mtime("$pdf_file");
    if ( ! -e $ps_file ) {
	warn "Latexmk: Postscript file \"$ps_file\" has not been made,\n",
             "         so I cannot convert it to pdf\n";
        return;
    }
    if ((! -e "$pdf_file") 
        ||( $pdf_mtime < $ps_mtime )
       )
    {
        if ( &view_file_via_temporary ) {
           my $tmpfile = tempfile1( "${root_filename}_tmp", ".pdf" );
           &Run_msg( "$ps2pdf  \"$ps_file\" \"$tmpfile\"" );
           move( $tmpfile, $pdf_file );
        }
        else {
           &Run_msg( "$ps2pdf  \"$ps_file\" \"$pdf_file\"" );
        }
        $updated = 1;
    }
    else
    { 
        warn "Latexmk: File '$pdf_file' is up to date\n" if !$quell_uptodate_msgs;
    }
}

#************************************************************

sub make_pdf3
{
    my $dvi_file;
    my $pdf_file;

    if ( length($dvi_filter) == 0 )
        {$dvi_file = "$root_filename.dvi";}
    else 
        {$dvi_file = "$root_filename.dviF";}
    $pdf_file = "$root_filename.pdf";

    my $dvi_mtime = &get_mtime("$dvi_file");
    my $pdf_mtime = &get_mtime("$pdf_file");
    if ( ! -e $dvi_file ) {
	warn "Latexmk: Dvi file \"$dvi_file\" has not been made,\n",
             "         so I cannot convert it to pdf\n";
        return;
    }
    if ((! -e "$pdf_file") 
        ||( $pdf_mtime < $dvi_mtime )
       )
    {
        if ( &view_file_via_temporary ) {
           my $tmpfile = tempfile1( "${root_filename}_tmp", ".pdf" );
           &Run_msg( "$dvipdf  \"$dvi_file\" \"$tmpfile\"" );
           move( $tmpfile, $pdf_file );
        }
        else {
           &Run_msg( "$dvipdf  \"$dvi_file\" \"$pdf_file\"" );
        }
        $updated = 1;
    }
    else
    { 
        warn "Latexmk: File '$pdf_file' is up to date\n" if !$quell_uptodate_msgs;
    }
}

#************************************************************

sub make_printout
{
  my $ext = '';      # extension of file to print
  my $command = '';  # command to print it
  if ( $print_type eq 'dvi' ) {
      if ( length($dvi_filter) == 0 )
      {
	$ext = '.dvi';
      }
      else
      {
	$ext = '.dviF';
      }
      $command = $lpr_dvi;
  }
  elsif ( $print_type eq 'pdf' ) {
      $ext = '.pdf';
      $command = $lpr_pdf;
  }
  elsif ( $print_type eq 'ps' ) {
      if ( length($ps_filter) == 0 )
      {
	$ext = '.ps';
      }
      else
      {
	$ext = '.psF';
      }
      $command = $lpr;
  }
  elsif ( $print_type eq 'none' ) {
      warn "------------\nPrinting is configured off\n------------\n";
      return;
  }
  else
  {
     die "Latexmk: incorrect value \"$print_type\" for type of file to print\n".
         "Allowed values are \"dvi\", \"pdf\", \"ps\", \"none\"\n"
  }
  my $file = $root_filename.$ext;
  if ( ! -e $file ) {
      warn "Latexmk: File \"$file\" has not been made, so I cannot print it\n";
      return;
  }
  warn_running( "Printing using '$command $file'" );
  &Run("$command \"$file\"");
}

#************************************************************

sub make_postscript
{
  my $tmpfile;
  my $tmpfile1;
  my $header;
  my $dvi_file;
  my $ps_file = "$root_filename.ps";
  my $psF_file = "$root_filename.psF";

  # Figure out the dvi file name
  if ( length($dvi_filter) == 0 )
  {
    $dvi_file = "$root_filename.dvi";
  }
  else
  {
    $dvi_file = "$root_filename.dviF";
  }

  if ( ! -e $dvi_file ) {
      warn "Latexmk: Dvi file '$dvi_file' has not been made, ",
                "so I cannot convert it to postscript\n";
      return;
  }

  # Do banner stuff
  if ( $banner )
  {
    ## Make temp banner file
#    local(*INFILE,*OUTFILE);
    local(*OUTFILE);

    $tmpfile = tempfile1("latexmk_header", ".ps");
    if ( ! open(OUTFILE, ">$tmpfile") ) {
      die "Latexmk: Could not open temporary file [$tmpfile]\n"; }
    print OUTFILE "userdict begin /bop-hook{gsave 200 30 translate\n";
    print OUTFILE "65 rotate /Times-Roman findfont $banner_scale scalefont setfont\n";
    print OUTFILE "0 0 moveto $banner_intensity setgray ($banner_message) show grestore}def end\n";
    close(OUTFILE);
    $header = "-h $tmpfile";
  }
  else
  {
    $header = '';
  }

  my $ps_mtime = &get_mtime("$ps_file");
  my $dvi_mtime = &get_mtime("$dvi_file");
  if ( (! -e "$ps_file") 
       || ( $ps_mtime < $dvi_mtime )
     )
  {
      if ( &view_file_via_temporary ) {
	  $tmpfile1 = tempfile1( "${root_filename}_tmp", ".ps" );
          &Run_msg( "$dvips $header \"$dvi_file\" -o \"$tmpfile1\"" );
          move( $tmpfile1, $ps_file );
      }
      else {
          &Run_msg( "$dvips $header \"$dvi_file\" -o \"$ps_file\"" );
      }
      $updated = 1;
  }
  else
  { 
      warn "Latexmk: File '$ps_file' is up to date\n" if !$quell_uptodate_msgs;
  }
  # End make of ps file

  if ( length($ps_filter) != 0 ) {
     my $psF_mtime = &get_mtime("$psF_file");
     # Get ps_mtime again, since the ps_file may have changed:
     my $ps_mtime = &get_mtime("$ps_file");
     if ( (! -e "$psF_file") 
          || ( $psF_mtime < $ps_mtime )
     ) {
         if ( &view_file_via_temporary ) {
	    $tmpfile1 = tempfile1( "${root_filename}_tmp", ".ps" );
            &Run_msg("$ps_filter < \"$ps_file\" > \"$tmpfile1\"");
            move( $tmpfile1, $psF_file );
         }
         else {
            &Run_msg("$ps_filter < \"$ps_file\" > \"$psF_file\"");
         }
         $updated = 1;
      }
      else  { 
          warn "Latexmk: File '$psF_file' is up to date\n" 
             if !$quell_uptodate_msgs;
      }
  }
  # End make of psF file

  if ( $banner )
  {
    unlink("$tmpfile");
  }

}

#************************************************************
# run appropriate previewer.

sub make_preview
{
  my $ext;
  my $viewer;
  if ( $view eq 'dvi' )
  {
     $viewer = $dvi_previewer;
     $ext = '.dvi';
     if ( length($dvi_filter) != 0 )
     {
       $ext = '.dviF';
     }
  } 
  elsif ( $view eq 'none' )
  {
      warn "Not using a previewer\n" if !$silent;
      return;
  }
  elsif ( $view eq 'ps' )
  {
    $viewer = $ps_previewer;
    $ext = '.ps';
    if ( length($ps_filter) != 0 )
    {
      $ext = '.psF';
    }
  }
  elsif ( $view eq 'pdf' )
  {
    $viewer = $pdf_previewer;
    $ext = '.pdf';
  }
  else
  {
      warn "Latexmk::make_preview BUG: Invalid preview method '$view'\n";
      exit 20;
  }

  my $view_file = "$root_filename$ext";  

  if ( ! -e $view_file ) {
      warn "Latexmk: File \"$view_file\" has not been made, so I cannot view it\n";
      return;
  }
  warn_running( "Starting previewer: '$viewer $view_file'" );
  my ($pid, $return) = &Run ("$viewer \"$view_file\"");
  if ($return){
    warn "Latexmk: Could not start previewer [$viewer $view_file]";
  }
}

#************************************************************

sub make_preview_continuous
{

  # How do we persuade viewer to update.  Default is to do nothing.
  my $viewer_update_method = 0;
  my $viewer_update_signal = undef;
  my $viewer_update_command = undef;
  # Extension of file:
  my $ext;
  # Command to run viewer.  '' for none
  my $viewer;
  $quell_uptodate_msgs = 1;
  if ( $view eq 'dvi' )
  {
     $viewer = $dvi_previewer;
     $viewer_update_method = $dvi_update_method;
     $viewer_update_signal = $dvi_update_signal;
     if (defined $dvi_update_command)
     {
         $viewer_update_command = $dvi_update_command;
     }
     $ext = '.dvi';
     if ( length($dvi_filter) != 0 )
     {
       $ext = '.dviF';
     }
  } 
  elsif ( $view eq 'none' )
  {
      warn "Not using a previewer\n";
      $viewer = '';
      $ext = '';
  }
  elsif ( $view eq 'ps' )
  {
     $viewer = $ps_previewer;
     $viewer_update_method = $ps_update_method;
     $viewer_update_signal = $ps_update_signal;
     if (defined $ps_update_command)
     {
         $viewer_update_command = $ps_update_command;
     }
     $ext = '.ps';
     if ( length($ps_filter) != 0 )
     {
        $ext = '.psF';
     }
  }
  elsif ( $view eq 'pdf' )
  {
     $viewer = $pdf_previewer;
     $viewer_update_method = $pdf_update_method;
     $viewer_update_signal = $pdf_update_signal;
     if (defined $pdf_update_command)
     {
         $viewer_update_command = $pdf_update_command;
     }
     $ext = '.pdf';
  }
  else
  {
      warn "Latexmk::make_preview_continuous BUG: ",
           "Invalid preview method '$view'\n";
      exit 20;
  }


  # Viewer information:
  my $viewer_running = 0;    # No viewer running yet
  my $view_file = "$root_filename$ext";  
  my $viewer_process = 0;    # default: no viewer process number known
  my $need_to_get_viewer_process = 0;
       # This will be used when we start a viewer that will be updated
       # by use of a signal.  The process number returned by the startup
       # of the viewer may not be that of the viewer, but may, for example,
       # be that of a script that starts the viewer.  But the startup time
       # may be signficant, so we will wait until the next needed update before
       # determining the process number of the viewer.

  if ( -e $view_file && ($viewer ne '') && !$new_viewer_always ) {
      # Is a viewer already running?
      #    (We'll save starting up another viewer.)
      $viewer_process = &find_process_id( $view_file );
      if ( $viewer_process ) {
          warn "Latexmk: Previewer is already running\n" 
              if !$silent;
          $viewer_running = 1;
          $need_to_get_viewer_process = 0;
      }
  }
  # Loop forever, rebuilding .dvi and .ps as necessary.
  # Set $first_time to flag first run (to save unnecessary diagnostics)
CHANGE:
  for (my $first_time = 1; 1; $first_time = 0 ) {
     $updated = 0;
     $failure = 0;
     $failure_msg = '';
     if ( $MSWin_fudge_break && ($^O eq "MSWin32") ) {
        # Fudge under MSWin32 ONLY, to stop perl/latexmk from
        #   catching ctrl/C and ctrl/break, and let it only reach
        #   downstream programs. See comments at first definition of
        #   $MSWin_fudge_break.
        $SIG{BREAK} = $SIG{INT} = 'IGNORE';
     }

     make_files($go_mode && $first_time);

##     warn "=========Viewer PID = $viewer_process; updated=$updated\n";

     if ( $MSWin_fudge_break && ($^O eq "MSWin32") ) {
        $SIG{BREAK} = $SIG{INT} = 'DEFAULT';
     }
     if ( $failure > 0 ) {
        if ( !$failure_msg ) {
	    $failure_msg = 'Failure to make the files correctly';
	}
        #Remove trailing space
        $failure_msg =~ s/\s*$//;
        warn "Latexmk: $failure_msg\n";
     }
     elsif ( $updated && ($viewer_process != 0) )
     {
         # Get viewer to update screen if we have to do it:
	 if ($viewer_update_method == 2) {
	    if ($need_to_get_viewer_process ) {
               $viewer_process = &find_process_id(  $view_file );
               $need_to_get_viewer_process = 0;
	    }
            if (defined $viewer_update_signal) {
               print "Latexmk: signalling viewer, process ID $viewer_process\n"
                  if $diagnostics ;
	       kill $viewer_update_signal, $viewer_process;
	    }
            else {
               warn "Latexmk: viewer is supposed to be sent a signal\n",
                    "  but no signal is defined.  Misconfiguration or bug?\n";
            }
	 }
         elsif ($viewer_update_method == 4) {
            if (defined $viewer_update_command) {
		warn "RUN $viewer_update_command";
 	       my ($update_pid, $update_retcode) 
                  = &Run_msg( $viewer_update_command );
               if ($update_retcode != 0) {
		   warn "Latexmk: I could not run command to update viewer\n";
	       }
	    }
            else {
               warn "Latexmk: viewer is supposed to be updated by running a command,\n",
                    "  but no command is defined.  Misconfiguration or bug?\n";
            }
	}
      }
      if ( (!$viewer_running) && (-e $view_file) && ($viewer ne '') ) {
	if ( !$silent ) {
            if ($new_viewer_always) {
              warn "Latexmk: starting previewer: $viewer $view_file\n",
                   "------------\n";
	    }
            else {
              warn "Latexmk: I have not found a previewer that ",
                           "is already running. \n",
                   "   So I will start it: $viewer $view_file\n",
                   "------------\n";
	  }
	}
        my $retcode;
        ($viewer_process, $retcode) 
              = &Run ("start $viewer \"$root_filename$ext\"");
        if ( $retcode != 0 ) {
           if ($force_mode) {
              warn "Latexmk: I could not run previewer\n";
           }
           else {
              &exit_msg1( "I could not run previewer", $retcode);
           }
        }
        else {
           $viewer_running = 1;
           if ($viewer_update_method == 2) {
               # If viewer will be update by sending it a signal,
               #   then tell myself to get the viewer's true process
               #   number later.  
               # Just at this moment the process started above, that has 
               #   process number $viewer_process, may just be a startup
               #   script and not the viewer itself.
               $need_to_get_viewer_process = 1;
	   }
	} # end analyze result of trying to run viewer
     } # end start viewer
     if ( $first_time || $updated || $failure ) {
        print "\n=== Watching for updated files. Use ctrl/C to stop ...\n";
     }
     WAIT: while (1) {
        sleep($sleep_time);
#        print "DDD ";
#	show_source_times();
#	print "INCLUDES: @includes\n"; 
        my $changed_file = &update_all_source_times;
        if ($changed_file) {
#?? Need a test above for change in non-found files
#?? Need to check for new_files
	    warn "Latexmk: Changed file '$changed_file' ....  Remake files.\n";
            last WAIT; 
        }
        my $new_files = &find_new_files;
        if ($new_files > 0) {
	    warn "Latexmk: New file found.\n";
            last WAIT; 
        }
     } # end WAIT:
  } #end infinite_loop CHANGE:
} #end sub make_preview_continuous

#************************************************************

sub process_rc_file {
    # Usage process_rc_file( filename )
    # Run rc_file whose name is given in first argument
    #    Exit with code 11 if file could not be read.  
    #      (In general this is not QUITE the right error)
    #    Exit with code 13 if there is a syntax error or other problem.
    # ???Should I leave the exiting to the caller (perhaps as an option)?
    #     But I can always catch it with an eval if necessary.
    #     That confuses ctrl/C and ctrl/break handling.
    my $rc_file = $_[0];
    do( $rc_file );
    # The return value from the do is not useful, since it is the value of 
    #    the last expression evaluated, which could be anything.
    # The correct test of errors is on the values of $! and $@.

# This is not entirely correct.  On gluon2:
#      rc_file does open of file, and $! has error, apparently innocuous
#      See ~/proposal/06/latexmkrc-effect

    my $OK = 1;
    if ( $! ) {
        # Get both numeric error and its string, by forcing numeric and 
        #   string contexts:
        my $err_no = $!+0;
        my $err_string = "$!";
        warn "Latexmk: Initialization file '$rc_file' could not be read,\n",
             "   or it gave some other problem. Error code \$! = $err_no.\n",
             "   Error string = '$err_string'\n";
	$! = 256;
        $OK = 0;
    }
    if ( $@ ) {
	$! = 256;
        # Indent the error message to make it easier to locate
        my $indented = prefix( $@, "    " );
        $@ = "";
        warn "Latexmk: Initialization file '$rc_file' gave an error:\n",
            "$indented";
        $OK = 0;
    }
    if ( ! $OK ) { die "Latexmkrc: Stopping because of problem with rc file\n"; }
} #end process_rc_file

#************************************************************

sub process_dep_file {
    # Usage process_dep_file( filename )
    # Run dep_file whose name is given in first argument
    #    Return 0 on success
    #    Return 1 if file could not be read.
    #      (In general this is not QUITE the right error)
    #    Retrun 2 if there is a syntax error or other problem.
    my $rc_file = $_[0];
    do( $rc_file );
    # The return value from the do is not useful, since it is the value of 
    #    the last expression evaluated, which could be anything.
    # The correct test of errors is on the values of $! and $@.
    if ( $! ) {
        warn "Latexmk: Dependency file '$rc_file' could not be read\n";
        return 1;
    }
    if ( $@ ) {
        my $indented = prefix( $@, "    " );
        $@ = "";
        warn "Latexmk: Probable bug; dependency file '$rc_file' gave an error:\n",
            "$indented";
        return 2
    }
    return 0;
} #end process_dep_file

#************************************************************

# cleanup_basic
# - erases basic set of generated files, exits w/ no other processing.
#   (all but aux, dep, dvi, pdf, and ps), 
#   and also texput.log, and files with extensions in $clean_ext

sub cleanup_basic
{
# Basic set:
  unlink("$root_filename.aux.bak");
  unlink("$root_filename.bbl");
  unlink("$root_filename.blg");
  unlink("$root_filename.log");
  unlink("$root_filename.ind");
  unlink("$root_filename.idx");
  unlink("$root_filename.idx.bak");
  unlink("$root_filename.ilg");
  unlink("texput.log");

  # Do any other file extensions specified
  foreach $ext (split(' ',$clean_ext), @generated_exts )
  {
    unlink("$root_filename.$ext");
  }
}


#************************************************************
# cleanup_dvi_ps_pdf
# - erases generated dvi, ps, and pdf files (and others specified in 
#   $cleanup_full_ext),
#   and also texput.dvi, and files with extensions in $clean_full_ext

sub cleanup_dvi_ps_pdf
{
  unlink("$root_filename.dvi");
  unlink("$root_filename.pdf");
  unlink("$root_filename.ps");
  unlink("$root_filename.dviF");
  unlink("$root_filename.psF");
  unlink("texput.dvi");
  # Do any other file extensions specified
  foreach $ext (split(' ',$clean_full_ext))
  {
    unlink("$root_filename.$ext");
  }
}


#************************************************************
# cleanup_aux_dep
# - erases generated aux and dep files, and also texput.aux

sub cleanup_aux_dep
{
  unlink("$root_filename.aux");
  unlink("$root_filename.dep");
  unlink("texput.aux");
  # .aux files are also made for \include'd files
  foreach my $include (@includes) { 
     $include =~ s/\.[^\.]*$/.aux/;
     unlink($include);
  }
}


#************************************************************

sub aux_restore {
   warn "Latexmk: restoring last $root_filename.aux file\n";
   # But don't copy the time from the aux.bak file
   # So the aux file will look up-to-date
   copy_file_keep_time( "$root_filename.aux.bak", "$root_filename.aux" );
}

#************************************************************

sub exit_msg1
{
  # exit_msg1( error_message, retcode [, action])
  #    1. display error message
  #    2. if action set, then restore aux file
  #    3. exit with retcode
  warn "\n------------\n";
  warn "Latexmk: $_[0].\n";
  warn "-- Use the -f option to force complete processing.\n";
  if ($_[2])
  {
      &aux_restore;
  }
  my $retcode = $_[1];
  if ($retcode >= 256) {
     # Retcode is the kind returned by system from an external command
     # which is 256 * command's_retcode
     $retcode /= 256;
  }
  exit $retcode;
}

#************************************************************

sub warn_running {
   # Message about running program:
    if ( $silent ) {
        warn "Latexmk: @_\n";
    }
    else {
        warn "------------\n@_\n------------\n";
    }
}

#************************************************************

sub exit_help
# Exit giving diagnostic from arguments and how to get help.
{
    warn "\nLatexmk: @_\n",
         "Use\n",
         "   latexmk -help\nto get usage information\n";
    exit 10;
}


#************************************************************

sub print_help
{
  print
  "Latexmk $version_num: Automatic LaTeX document generation routine\n\n",
  "Usage: latexmk [latexmk_options] [filename ...]\n\n",
  "  Latexmk_options:\n",
  "   -bm <message> - Print message across the page when converting to postscript\n",
  "   -bi <intensity> - Set contrast or intensity of banner\n",
  "   -bs <scale> - Set scale for banner\n",
  "   -commands  - list commands used by latexmk for processing files\n",
  "   -c     - clean up (remove) all nonessential files, except\n",
  "            dvi, ps and pdf files.\n",
  "            This and the other clean-ups are instead of a regular make.\n",
  "   -C     - clean up (remove) all nonessential files\n",
  "            including aux, dep, dvi, postscript and pdf files\n",
  "   -c1    - clean up (remove) all nonessential files,\n",
  "            including dvi, pdf and ps files, but excluding aux and dep files \n",
  "   -cd    - Change to directory of source file when processing it\n",
  "   -cd-   - Do NOT change to directory of source file when processing it\n",
  "   -dF <filter> - Filter to apply to dvi file\n",
  "   -dvi   - generate dvi\n",
  "   -dvi-  - turn off required dvi\n",
  "   -f     - force continued processing past errors\n",
  "   -f-    - turn off forced continuing processing past errors\n",
  "   -F     - Ignore non-existent files when making dependencies\n",
  "   -F-    - Turn off -F\n",
  "   -gg    - Super go mode: clean out generated files (-C), and then\n",
  "            process files regardless of file timestamps\n",
  "   -g     - process regardless of file timestamps\n",
  "   -g-    - Turn off -g\n",
  "   -h     - print help\n",
  "   -help - print help\n",
  "   -i     - rescan for input if dependency file older than tex file\n",
  "   -i-    - Turn off -i\n",
  "   -il    - make list of input files by parsing log file\n",
  "   -it    - make list of input files by parsing tex file\n",
  "   -I     - force rescan for input files\n",
  "   -I-    - Turn off -I\n",
  "   -l     - force landscape mode\n",
  "   -l-    - turn off -l\n",
  "   -new-viewer   - in -pvc mode, always start a new viewer\n",
  "   -new-viewer-  - in -pvc mode, start a new viewer only if needed\n",
  "   -pdf   - generate pdf by pdflatex\n",
  "   -pdfdvi - generate pdf by dvipdf\n",
  "   -pdfps - generate pdf by ps2pdf\n",
  "   -pdf-  - turn off pdf\n",
  "   -ps    - generate postscript\n",
  "   -ps-   - turn off postscript\n",
  "   -pF <filter> - Filter to apply to postscript file\n",
  "   -p     - print document after generating postscript.\n",
  "            (Can also .dvi or .pdf files -- see documentation)\n",
  "   -print=dvi     - when file is to be printed, print the dvi file\n",
  "   -print=ps      - when file is to be printed, print the ps file (default)\n",
  "   -print=pdf     - when file is to be printed, print the pdf file\n",
  "   -pv    - preview document.  (Side effect turn off continuous preview)\n",
  "   -pv-   - turn off preview mode\n",
  "   -pvc   - preview document and continuously update.  (This also turns\n",
  "                on force mode, so errors do not cause latexmk to stop.)\n",
  "            (Side effect: turn off ordinary preview mode.)\n",
  "   -pvc-  - turn off -pvc\n",
  "   -r <file> - Read custom RC file\n",
  "   -silent  - silence progress messages from called programs\n",
  "   -v     - display program version\n",
  "   -verbose - display usual progress messages from called programs\n",
  "   -version      - display program version\n",
  "   -view=default - viewer is default (dvi, ps, pdf)\n",
  "   -view=dvi     - viewer is for dvi\n",
  "   -view=none    - no viewer is used\n",
  "   -view=ps      - viewer is for ps\n",
  "   -view=pdf     - viewer is for pdf\n",
  "   filename = the root filename of LaTeX document\n",
  "\n",
  "-p, -pv and -pvc are mutually exclusive\n",
  "-h, -c and -C overides all other options.\n",
  "-pv and -pvc require one and only one filename specified\n",
  "All options can be introduced by '-' or '--'.  (E.g., --help or -help.)\n",
  "Contents of RC file specified by -r overrides options specified\n",
  "  before the -r option on the command line\n";

}

#************************************************************
sub print_commands
{
  warn "Commands used by latexmk:\n",
       "   To run latex, I use \"$latex\"\n",
       "   To run pdflatex, I use \"$pdflatex\"\n",
       "   To run bibtex, I use \"$bibtex\"\n",
       "   To run makeindex, I use \"$makeindex\"\n",
       "   To make a ps file from a dvi file, I use \"$dvips\"\n",
       "   To make a ps file from a dvi file with landscape format, ",
           "I use \"$dvips_landscape\"\n",
       "   To make a pdf file from a dvi file, I use \"$dvipdf\"\n",
       "   To make a pdf file from a ps file, I use \"$ps2pdf\"\n",
       "   To view a pdf file, I use \"$pdf_previewer\"\n",
       "   To view a ps file, I use \"$ps_previewer\"\n",
       "   To view a ps file in landscape format, ",
            "I use \"$ps_previewer_landscape\"\n",
       "   To view a dvi file, I use \"$dvi_previewer\"\n",
       "   To view a dvi file in landscape format, ",
            "I use \"$dvi_previewer_landscape\"\n",
       "   To print a ps file, I use \"$lpr\"\n",
       "   To print a dvi file, I use \"$lpr_dvi\"\n",
       "   To print a pdf file, I use \"$lpr_pdf\"\n",
       "   To find running processes, I use \"$pscmd\", \n",
       "      and the process number is at position $pid_position\n";
   warn "Notes:\n",
        "  Command starting with \"start\" is run detached\n",
        "  Command that is just \"start\" without any other command, is\n",
        "     used under MS-Windows to run the command the operating system\n",
        "     has associated with the relevant file.\n",
        "  Command starting with \"NONE\" is not used at all\n";
}

#************************************************************

sub view_file_via_temporary {
    return $always_view_file_via_temporary 
           || ($pvc_view_file_via_temporary && $preview_continuous_mode);
}

#************************************************************
#### Tex-related utilities


# check for citation which bibtex didnt find.

sub check_for_bibtex_errors
# return 0: OK, 1: bibtex error, 2: could not open .blg file.
{
  my $log_name = "$root_filename.blg";
  my $log_file = new FileHandle;
  my $retcode = open( $log_file, "<$log_name" );
  if ( $retcode == 0) {
     if ( !$force_mode ) {
        $failure = 1;
        $failure_msg = "Could not open bibtex log file for error check";
        #### Bypass to end of calling eval-block
        ###die "Could not open bibtex log file for error check\n";
     }
     else {
        warn "Latexmk: Could not open bibtex log file for error check\n";
     }
     return 2;
  }
  $retcode = 0;
  while (<$log_file>)
  {
#    if (/Warning--/) { return 1; }
    if (/error message/) 
    { 
       $retcode = 1; 
       last;
    }
  }
  close $log_file;
  return $retcode;
}

#************************************************************
# check for bibtex warnings

sub check_bibtex_log
# return 0: OK, 1: bibtex warnings, 2: bibtex errors, 
#        3: could not open .blg file.
{
  my $log_name = "$root_filename.blg";
  my $log_file = new FileHandle;
  my $retcode = open( $log_file, "<$log_name" );
  if ( $retcode == 0 ) {    
      return 3;
  }
  my $have_warning = 0;
  my $have_error = 0;
  while (<$log_file>)
  {
    if (/Warning--/) { 
        #print "Bibtex warning: $_"; 
        $have_warning = 1;
    }
    if (/error message/) { 
        #print "Bibtex error: $_"; 
        $have_error = 1;
    }
  }
  close $log_file;
  if ($have_error) {return 2;}
  if ($have_warning) {return 1;}
  return 0;
}

#************************************************************
# - looks recursively for included & inputted and psfig'd files and puts
#   them into @includes.
# - note only primitive comment removal: cannot deal with escaped %s, but then,
#	when would they occur in any line important to latexmk??

sub scan_for_includes
{
  my $texfile_name = $_[0];
  warn "-----Scanning [$texfile_name] for input files etc ... -----\n";
  &scan_for_includes_($texfile_name);
  ## put root tex file into list of includes.
  push @includes, $texfile_name;
  &save_source_times;
}

sub scan_for_includes_
{
  local(*FILE,$orig_filename);
##JCC
  local($ignoremode,$line);
  $ignoremode = 0;
  $line = 0;
  if (!open(FILE,$_[0])) 
  {
    warn "Latexmk: could not open input file [$_[0]]\n";
    return;
  }
LINE:
  while(<FILE>)
  {
    $line = $line + 1;
    
    if ( /^\s*(%#.*)\s*$/ )
    {
       $_ = $1;
       ##warn "======Metacommand \"$_\"\n";
       if ( /%#{}end.raw/ || /%#{latexmk}end.ignore/ )
       {
	   $ignoremode = 0;
           warn "  Ignore mode off, at line $line in file $_[0].\n";
       }
       elsif ( $ignoremode == 1 )
       {
           # In ignore mode only end.raw, etc metacommands are recognized.
	   next LINE;
       }
       elsif ( /%#{}raw/ || /%#{}begin.raw/ || 
            /%#{latexmk}ignore/ || /%#{latexmk}begin.ignore/ )
       {
	   $ignoremode = 1;
           warn "  Ignore mode on, at line $line in file $_[0].\n";
       }
       elsif ( /%#{latexmk}include.file[\040\011]+([^\040\011\n]*)/ 
               || /%#{latexmk}input.file[\040\011]+([^\040\011\n]*)/ )
       {
          push @includes, $1;
          warn "  Adding input file \"$1\" at line $line in file $_[0].\n";
       }
       else
       { 
         # Unrecognized metacommands are, by specification, to be ignored.
	   warn "Unrec. \"$_\"\n";
       }
       next LINE;
    }
    if ( $ignoremode == 1 )
    {
	##warn "Skipping a line:\n  $_";
        next LINE;
    }

    ($_) = split('%',$_);		# primitive comment removal

    if (/\\def/ || /\\newcommand/ || /\\renewcommand/ || /\\providecommand/)
    {
        ##JCC Ignore definitions:
        warn "Ignoring definition:\n  $_";
    }
    elsif (/\\include[{\s]+([^\001\040\011}]*)[\s}]/)
    {
      $full_filename = $1;
      $orig_filename = $full_filename;
      $full_filename = &find_file_ext($full_filename, 'tex', \@TEXINPUTS);
      if ($full_filename)
      {
      	push @includes,  $full_filename;
	if ( -e $full_filename )
	{
	  warn "	Found input file [$full_filename]\n";
	  &scan_for_includes_($full_filename);
	}
        else
        {
          if ( $orig_filename =~ /^\// )
          {
            warn "Latexmk: In \\include, ",
                 "could not find file [$orig_filename]\n";
          }
          else
          {
            warn "Latexmk: In \\include, ",
                 "could not find file [$orig_filename] in path [@TEXINPUTS]\n";
            warn "         assuming in current directory ($full_filename)\n";
          }
        }
      }
      else
      {
        if ( ! $force_include_mode )
        {
          if ( $orig_filename =~ /^\// )
          {
            warn "Latexmk: In \\include, ",
                "could not find file [$orig_filename]\n";
          }
          else
          {
            warn "Latexmk: In \\include, ",
                "could not find file [$orig_filename] in path [@TEXINPUTS]\n";
          }
        }
      }
    }
    elsif (/\\input[{\s]+([^\001\040\011}]*)[\s}]/)
    {
      $full_filename = $1;
      $orig_filename = $full_filename;
      $full_filename = &find_file_ext($full_filename, 'tex', \@TEXINPUTS);
      if ($full_filename)
      {
	push @includes, $full_filename;
#	warn "added '$full_filename'\n";
	if ( -e $full_filename )
	{
	  warn "	Found input for file [$full_filename]\n";
	  &scan_for_includes_($full_filename);
	}
	else
	{
	  if ( $orig_filename =~ /^\// )
	  {
	    warn "Latexmk: In \\input, could not find file [$orig_filename]\n";
	  }
	  else
	  {
	    warn "Latexmk: In \\input, ",
                 "could not find file [$orig_filename] in path [@TEXINPUTS]\n";
	    warn "         assuming in current directory ($full_filename)\n";
	  }
	}
      }
      else
      {
	if ( ! $force_include_mode )
	{
	  if ( $orig_filename =~ /^\// )
	  {
	    warn "Latexmk: In \\input, could not find file [$orig_filename]\n";
	  }
	  else
	  {
	    warn "Latexmk: In \\input, ",
                "could not find file [$orig_filename] in path [@TEXINPUTS]\n";
	  }
	}
      }
    }
    elsif (/\\blackandwhite{([^\001\040\011}]*)}/ || /\\colorslides{([^\001}]*)}/)
    {
############      $slide_mode = 1;
      $full_filename = &find_file_ext($1, 'tex', \@TEXINPUTS);
      if ($full_filename)
      {
      	push @includes, $full_filename;
	if ( -e $full_filename )
	{
	  warn "	Found slide input for file [$full_filename]\n";
	  &scan_for_includes_($full_filename);
	}
      }
    }
    elsif (/\\psfig{file=([^,}]+)/ || /\\psfig{figure=([^,}]+)/)
    {
      $orig_filename = $1;
      $full_filename = &find_file($1, \@psfigsearchpath);
      if ($full_filename)
      {
      	push @includes, $full_filename;
	if ( -e $full_filename )
	{
	  warn "	Found psfig for file [$full_filename]\n";
	}
      }
    }
    elsif ( /\\epsfbox{([^}]+)}/ || /\\epsfbox\[[^\]]*\]{([^}]+)}/ ||
	    /\\epsffile{([^}]+)}/ || /\\epsffile\[[^\]]*\]{([^}]+)}/ ||
	    /\\epsfig{file=([^,}]+)/ || /\\epsfig{figure=([^,}]+)/ )
    {
      $orig_filename = $1;
      $full_filename = &find_file($1, \@psfigsearchpath);
      if ($full_filename)
      {
      	push @includes, $full_filename;
	if ( -e $full_filename )
	{
	  warn "	Found epsf for file [$full_filename]\n";
	}
      }
    }
    elsif ( 
        /\\includegraphics{([^}]+)}/ || /\\includegraphics\[[^\]]*\]{([^}]+)}/ 
       )
    {
      $orig_filename = $1;
      $full_filename = &find_file_ext($1,'eps', \@psfigsearchpath);
      if ($full_filename)
      {
      	push @includes, $full_filename;
	if ( -e $full_filename )
	{
	  warn "	Found epsf for file [$full_filename]\n";
	}
      }
      else
      {
        warn "Latexmk: For \\includegraphics, ",
             "could not find file [$orig_filename]\n",
             "          in path [@psfigsearchpath]\n";
	if ( ! $force_include_mode ) {warn "\n";}        
      }
    }
    elsif (/\\documentstyle[^\000]+landscape/)
    {
      warn "	Detected landscape mode\n";
      $landscape_mode = 1;
    }
    elsif (/\\bibliography{([^}]+)}/)
    {
      @bib_files = split /,/, $1;
      &find_file_list1( \@bib_files, \@bib_files, '.bib', \@BIBINPUTS );
      warn "	Found bibliography files [@bib_files]\n" unless $silent;
      &update_source_times( @bib_files );
      $bibtex_mode = 1;
    }
    elsif (/\\psfigsearchpath{([^}]+)}/)
    {
      @psfigsearchpath = &split_search_path(':', '', $1);
    }
    elsif (/\\graphicspath{([^}]+)}/)
    {
      @psfigsearchpath = &split_search_path(':', '', $1);
    }
    elsif (/\\makeindex/)
    {
      $index_mode = 1;
      warn "        Detected index mode\n";
    }
  }
}

#**************************************************
sub parse_log
{
# Scan log file for: include files, bibtex mode, 
#    reference_changed, bad_reference, bad_citation
# In bibtex mode, scan aux file for bib files
# Return value: 1 if success, 0 if no log file.
# Set global variables:
#   @includes to list of included files that exist or that appear to be 
#       genuine files (as opposed to incorrectly parsed names).
#   %includes_missing to list of files that latex appeared to search for 
#        and didn't find, i.e., from error messages 
#   @aux_files to list of .aux files.
#   Leave these unchanged if there is no log file.
#   $reference_changed, $bad_reference, $bad_citation
#   Apply &save_source_times


    my @default_includes = ($texfile_name);  #Use under error conditions
    @includes = ();   
    my $log_name = "$root_filename.log";
    my $log_file = new FileHandle;
    if ( ! open( $log_file, "<$log_name" ) )
    {
        @includes = @default_includes;
        return 0;
    }
    my $line_number = 0;
    my $graphic_line = 0;
    @aux_files = ();
    my @bbl_files = ();
    my @ignored_input_files = ();
    my @existent = ();
    my @include_list = ();
    my @include_graphics_list = ();
    my %includes_from_errors = ();
    %includes_missing = ();
    

    $reference_changed = 0;
    $bad_reference = 0;
    $bad_citation = 0;

##  ?? New.  We'll determine these modes from parsing the file
    $bibtex_mode = 0;
    $index_mode = 0;

LINE:
   while(<$log_file>) { 
      $line_number++;
      chomp;
      if ( $line_number == 1 ){
	  if ( /^This is / ) {
	      # First line OK\n";
              next LINE;
          } else {
             warn "Latexmk: Error on first line of \"$log_name\".  ".
                 "This is apparently not a TeX log file.\n";
             close $log_file;
             $failure = 1;
             $failure_msg = 'Log file appeared to be in wrong format.';
             @includes = @default_includes;
             return 0;
	  }
      }
      # Handle wrapped lines:
      # They are lines brutally broken at exactly $log_wrap chars 
      #    excluding line-end.
      my $len = length($_);
      while ($len == $log_wrap)
      {
        my $extra = <$log_file>;
        chomp $extra;
        $line_number++;
        $len = length($extra);
        $_ .= $extra;
      }
      # Check for changed references, bad references and bad citations:
      if (/Rerun to get/) { 
          warn "Latexmk: References changed.\n";
          $reference_changed = 1;
      } 
      if (/LaTeX Warning: (Reference[^\001]*undefined)./) { 
	 warn "Latexmk: $1 \n";
         $bad_reference = 1;
      } 
      if (/LaTeX Warning: (Citation[^\001]*undefined)./) {
	 warn "Latexmk: $1 \n";
         $bad_citation = 1;
      }
      if ( /^Document Class: / ) {
          # Latex message
	  next LINE;
      }
      if ( /^Output written on / ) {
          # Latex message
	  next LINE;
      }
      if ( /^Underfull / ) {
          # Latex error/warning
	  next LINE;
      }
      if ( /^Overfull / ) {
          # Latex error/warning
	  next LINE;
      }
      if ( /^\(Font\)/ ) {
	  # Font info line
          next LINE;
      }
      if ( /^Package: / ) {
          # Package sign-on line
	  next LINE;
      }
      if ( /^Document Class: / ) {
          # Class sign-on line
	  next LINE;
      }
      if ( /^Writing index file / ) {
          $index_mode =1;
          warn "Latexmk: Index file written, so turn on index_mode\n" 
             unless $silent;
	  next LINE;
      }
      if ( /^No file .*?\.bbl./ ) {
          warn "Latexmk: Non-existent bbl file, so turn on bibtex_mode\n $_\n"
             unless $bibtex_mode == 1;
          $bibtex_mode = 1;
	  next LINE;
      }
      if ( /^No file\s*(.*)\.$/ ) {
          # This message is given by standard LaTeX macros, like \IfFileExists
          warn "Latexmk: Missing input file: '$1' from 'No file ...' line\n"
	      unless $silent;
	  $includes_missing{$1} = [3];
	  next LINE;
      }
      if ( /^File: ([^\s\[]*) Graphic file \(type / ) {
          # First line of message from includegraphics/x
          push @include_graphics_list, $1;
	  next LINE;
      }
      if ( /^File: / ) {
         # Package sign-on line. Includegraphics/x also produces a line 
         # with this signature, but I've already handled it.
         next LINE;
      }
      if (/^\! LaTeX Error: File \`([^\']*)\' not found\./ ) {
	  $includes_missing{$1} = [3];
          next LINE;
      }
      if (/.*?:\d*: LaTeX Error: File \`([^\']*)\' not found\./ ) {
          # Alternate file-line-error style of errors
	  $includes_missing{$1} = [3];
          next LINE;
      }
      if (/^LaTeX Warning: File \`([^\']*)\' not found/ ) {
	  $includes_missing{$1} = [3];
          next LINE;
      }
      if (/^\! LaTeX Error: / ) {
          next LINE;
      }
      if (/^No pages of output\./) {
          warn "Latexmk: Log file says no output from latex\n"
             unless $silent;
	  next LINE;
      }
   INCLUDE_CANDIDATE:
       while ( /\((.*$)/ ) {
       # Filename found by
       # '(', then filename, then terminator.
       # Terminators: obvious candidates: ')':  end of reading file
       #                                  '(':  beginning of next file
       #                                  ' ':  space is an obvious separator
       #                                  ' [': start of page: latex
       #                                        and pdflatex put a
       #                                        space before the '['
       #                                  '[':  start of config file
       #                                        in pdflatex, after
       #                                        basefilename.
       #                                  '{':  some kind of grouping
       # Problem: 
       #   All or almost all special characters are allowed in
       #   filenames under some OS, notably UNIX.  Luckily most cases
       #   are rare, if only because the special characters need
       #   escaping.  BUT 2 important cases are characters that are
       #   natural punctuation
       #   Under MSWin, spaces are common (e.g., "C:\Program Files")
       #   Under VAX/VMS, '[' delimits directory names.  This is
       #   tricky to handle.  But I think few users use this OS
       #   anymore.
       #
       # Solution: use ' [', but not '[' as first try at delimiter.
       # Then if candidate filename is of form 'name1[name2]', then
       #   try splitting it.  If 'name1' and/or 'name2' exists, put
       #   it/them in list, else just put 'name1[name2]' in list.
       # So form of filename is now:
       #  '(', 
       # then any number of characters that are NOT ')', '(', or '{'
       #   (these form the filename);
       # then ' [', or ' (', or ')', or end-of-string.
       # That fails for pdflatex
       # In log file:
       #   '(' => start of reading of file, followed by filename
       #   ')' => end of reading of file
       #   '[' => start of page (normally preceeded by space)
       # Remember: 
       #    filename (on VAX/VMS) may include '[' and ']' (directory
       #             separators) 
       #    filenames (on MS-Win) commonly include space.

       # First step: replace $_ by whole of line after the '('
       #             Thus $_ is putative filename followed by other stuff.
          $_ = $1; 
##          warn "==='$_'===\n";
          if ( /^([^\(^\)^\{]*?)\s\[/ ) {
              # Terminator: space then '['
              # Use *? in condition: to pick up first ' [' as terminator
              # 'file [' should give good filename.
          }
          elsif ( /^([^\(^\)^\{]*)\s(?=\()/ ) {
              # Terminator is ' (', but '(' isn't in matched string,
              # so we keep the '(' ready for the next match
          }
          elsif  ( /^([^\(^\)^\{]*)(\))/ ) {
              # Terminator is ')'
          }
          elsif ( /^([^\(^\)^\{]*?)\s*\{/ ) {
              # Terminator: arbitrary space then '{'
              # Use *? in condition: to pick up first ' [' as terminator
              # 'file [' should give good filename.
          }
	  else {
              #Terminator is end-of-string
	  }
##          warn "   ---'$1'---'$''---\n";
          $_ = $';       # Put $_ equal to the unmatched tail of string '
          my $include_candidate = $1;
          $include_candidate =~ s/\s*$//;   # Remove trailing space.
          if ( "$include_candidate" eq "[]" ) {
              # Part of overfull hbox message
              next INCLUDE_CANDIDATE;
          }
          # Make list of new include files; sometimes more than one.
          my @new_includes = ($include_candidate);
          if ( $include_candidate =~ /^(.+)\[([^\]]+)\]$/ ) {
             # Construct of form 'file1[file2]', as produced by pdflatex
             if ( -e $1 ) {
                 # If the first component exists, we probably have the
                 #   pdflatex form
                 @new_includes = ($1, $2);
	     }
             else {
                # We have something else.
                # So leave the original candidate in the list
	     }
	  }
	INCLUDE_NAME:
          foreach my $include_name (@new_includes) {
	      my ($base, $path, $ext) = fileparse ($include_name, '\.[^\.]*');
	      if ( $ext eq '.bbl' ) {
		  warn "Latexmk: Input bbl file \"$include_name\", ",
                                 "so turn on bibtex_mode\n"
		     unless ($bibtex_mode == 1) || $silent;
		  $bibtex_mode = 1;
		  push @bbl_files, $include_name;
	      } elsif ( $ext eq ".aux" ) {
		  push @aux_files, $include_name;
		  push @ignored_input_files, $include_name;
	      } elsif ( $generated_exts_all{$ext} ) {
		  #warn "Ignoring '$include_name'\n" if $diagnostics;
		  push @ignored_input_files, $include_name;
	      } else {
		  push @include_list, $include_name;
	      }
	  } # INCLUDE_NAME
      } # INCLUDE_CANDIDATE
  }  # LINE
  close($log_file);
  @aux_files = &uniq( sort(@aux_files) );
  @ignored_input_files = &uniq( sort(@ignored_input_files) );

  if ( $bibtex_mode ) 
  {  
      &parse_aux; 
      # Has side effect of setting @bib_files.
  }
  @include_list = &uniq(sort @include_list);
  @include_graphics_list = &uniq(sort @include_graphics_list);
  foreach (@include_list) {
      if ( -e $_ ) {
         push @existent, $_;
      } else {
         $includes_missing{$_} = [1];
      }
  }
  foreach (@include_graphics_list) {
      if ( -e $_ ) {
         push @existent, $_;
      } else {
         # I have to work harder finding the file
         $includes_missing{$_} = [2];
      }
  }

  my $non_exist = 0;
  my $not_found = 0;
  my $missing = 0;
  my @missing_names = keys %includes_missing;
  foreach (@missing_names) {
      my ($base, $path, $ext) = fileparse( $_, '\.[^\.]*' );
      if ( $generated_exts_all{$ext} ) {
	  #warn "Ignoring possibly missing file '$_'\n" if $diagnostics;
	  delete $includes_missing{$_};
          next;
      }
      $missing++;
      my $code = ${$includes_missing{$_}}[0];
      if ($code == 1) {$non_exist ++;}
      if ($code == 2) {$not_found ++;}
  }

#?? Have I done a full parse here?
#?? Must also update cus_dep_file_list? 
  @includes = @existent;
  &save_source_times;

  if ( $diagnostics ) 
  {
     my $inc = $#include_list + 1;
     my $exist = $#existent + 1;
     my $non_exist = $#includes_missing + 1;
     my $bbl = $#bbl_files + 1;
     print "$inc included files detected, of which ";
     print "$exist exist, and $non_exist do not exist.\n";
     print "Input files that exist:\n";
     foreach (@existent) { print "   $_\n";}

     if ( $#bbl_files >= 0 ) {
        print "Input bbl files:\n";
        foreach (@bbl_files) { print "   $_\n";  }
     }
     if ( $#ignored_input_files >= 0 ) {
        print "Other input files that are generated via LaTeX run:\n";
        foreach (@ignored_input_files) { print "   $_\n";  }
     }
     if ( $missing > 0 ) {
        print "Apparent input files that appear NOT to exist:\n";
        print "  Some correspond to misunderstood lines in the .log file\n";
        print "  Some are files that latexmk failed to find\n";
        print "  Some really don't exist\n";
        foreach (uniq( sort keys %includes_missing) ) { print "   $_\n";  }
     }
  }
  # Ensure @includes has something in it:
  if ($#includes < 0) { @includes = @default_includes;}
  return 1;
}

#************************************************************

sub parse_aux
# Parse aux_file for bib files.  
# Return 0 and leave @bib_files unchanged if cannot open any aux files.
# Else set @bib_files from information in the aux files
# And:
# Return 1 if no problems
# Return 2 with @bib_files empty if there are no \bibdata
#   lines. In that case turn off bibtex mode, as side effect.
# Return 3 if I couldn't locate all the bib_files
{
   # List of detected bib files:
   local @new_bib_files = ();
   # List of detected aux files.  Perhaps wrong approach
   local @new_aux_files = ();
   foreach my $aux_file (@aux_files) {
       parse_aux1( $aux_file );
   }
   if ($#new_aux_files < 0) {
       return 0;
   }

   @bib_files = uniq( sort( @new_bib_files ) );

   if ( $#bib_files == -1 ) {
       warn "Latexmk: No .bib files listed in .aux file, ",
            "so turn off bibtex_mode\n";
       $bibtex_mode = 0;
       return 2;
   }
   my $bibret = &find_file_list1( \@bib_files, \@bib_files, '.bib', \@BIBINPUTS );
   &update_source_times( @bib_files );
   if ($bibret == 0) {
      warn "Latexmk: Found bibliography files [@bib_files]\n" unless $silent;
   }
   else {
       warn "Latexmk: Failed to find one or more bibliography files in [@bib_files]\n";
       if ($force_mode) {
          warn "==== Force_mode is on, so I will continue.  But there may be problems ===\n";
       }
       else {
           #$failure = -1;
           #$failure_msg = 'Failed to find one or more bib files';
           warn "Latexmk: Failed to find one or more bib files\n";
       }
       return 3;
   }
   return 1;
}

#************************************************************

sub parse_aux1
# Parse single aux file for bib files.  
# Usage: &parse_aux1( aux_file_name )
#   Append newly found bib_filenames in @new_bib_files, already 
#        initialized/in use.
#   Append aux_file_name to @new_aux_files if aux file opened
#   Recursively check \@input aux files
#   Return 1 if success in opening $aux_file_name and parsing it
#   Return 0 if fail to open it
{
   my $aux_file = $_[0];
   my $aux_fh = new FileHandle;
   if (! open($aux_fh, $aux_file) ) { 
       warn "Latexmk: Couldn't find aux file '$aux_file'\n";
       return 0; 
   }
   push @new_aux_files, $aux_file;
AUX_LINE:
   while (<$aux_fh>) {
      if ( /^\\bibdata\{(.*)\}/ ) { 
          # \\bibdata{comma_separated_list_of_bib_file_names}
          # (Without the '.bib' extension)
          push( @new_bib_files, split /,/, $1 ); 
      }
#      elsif ( /^\\\@input\{(.*)\}/ ) { 
#          # \\@input{next_aux_file_name}
#	  &parse_aux1( $1 );
#      }
   }
   close($aux_fh);
   return 1;
}

#************************************************************

sub update_depend_file
{
  warn "Latexmk: Writing dependency file [$root_filename.dep]\n";
  $rc_file = ">$root_filename.dep";
  open(rc_file) 
    or die "Latexmk: Unable to open dependency file [$rc_file] for updating\n";
  print rc_file "\@includes = (\n";
  my $first = 1;
  foreach my $name (@includes) {
      if (!$first) {print rc_file ",\n";}
      print rc_file "\'$name\'";
      $first = 0;
  }
  print rc_file "\n)\n";
  print rc_file "\@bib_files = (\n";
  $first = 1;
  foreach $name (@bib_files) {
      if (!$first) {print rc_file ",\n";}
      print rc_file "\'$name\'";
      $first = 0;
  }
  print rc_file "\n)\n";
  if ($bibtex_mode)
  {
    print rc_file "\$bibtex_mode = 1;\n";
  }
  if ($index_mode)
  {
    print rc_file "\$index_mode = 1;\n";
  }
  print rc_file "\$view = \"$view\";\n";
  print rc_file "\$need_dvi = $need_dvi;\n";
  print rc_file "\$need_ps = $need_ps;\n";
  print rc_file "\$need_pdf = $need_pdf;\n";
  print rc_file "\$pdf_mode = $pdf_mode;\n";
  close rc_file;
}

#************************************************************
#************************************************************
#************************************************************
#
#      SOURCE TIME ROUTINES:
#

#************************************************************


sub save_source_times {
    # But preserve old times, when known
#    print "SST ";
    my %old_times = %source_times;
    &set_times( \%source_times, @includes, @bib_files, @ind_files, @cus_dep_files );
    foreach my $file (keys %source_times) {
        if ( defined $old_times{$file} ) {
#            print "Defined $old_times{$file}\n";
            $source_times{$file} = $old_times{$file};
        }
    }
#    show_source_times();
}

#************************************************************

sub add_source_times {
    # Add time stamps of specified files to %source_time hash,
    # preserving old times when they exist.
    &add_times( \%source_times, @_ );
}

#************************************************************

sub update_all_source_times {
    # Update selected source times
    return &update_times( \%source_times, keys %source_times );
}

#************************************************************

sub update_source_times {
    # Update selected source times
    return &update_times( \%source_times, @_ );
}

#************************************************************

sub changed_source_times {
    return &changed_times( \%source_times );
}

#************************************************************

sub show_source_times {
    print "Source times:\n";
    foreach my $file (sort keys %source_times) {
        if ( defined $source_times{$file}  )
           {print " '$file' => $source_times{$file}\n";}
        else { print "  Trouble with '$file'\n";}
    }
}

#************************************************************

sub set_times {
    # In hash pointed to by $_[0], 
    # set (file->time) for each file in rest of arguments
    my $ref = shift;
    %$ref = ();
    &add_times( $ref, @_ );
}

#************************************************************

sub add_times {
    # Usage: add_times( ref_to_list_of_times, files ....)
    # In hash pointed to by first argument, save times of files
    # Keep old times when they exist.
    # The hash maps filenames to times
    # Filenames for non-existent files map to zero
    my $ref = shift;
FILE:
    foreach my $file (@_) {
        if (defined $$ref{$file}) {
            # We've already seen this file.  Use orginal time only
            next FILE;
	}
        $$ref{$file} = get_mtime0($file);
    } #end FILE
}

#************************************************************

sub update_times {
    # Usage: update_times( ref_to_list_of_times, files ....)
    # In hash pointed to by first argument, save times of files
    # The hash maps filenames to times
    # Filenames for non-existent files map to zero
    # Return first changed file
    my $ref = shift;
    my $changed_file = '';
FILE:
    foreach my $file (@_) {
        my $old_time = $$ref{$file};
        if ( !$old_time ) {$old_time = 0;}
        my $new_time = get_mtime0($file);
        $$ref{$file} = $new_time;
        if ( ($new_time != $old_time) && ($changed_file eq '') ) {
	    $changed_file = $file;
            print "$file' changed time from $old_time to $new_time\n"
		if $diagnostics;
	}
    } #end FILE
    return $changed_file;
}

#************************************************************

sub changed_times {
    # Usage: changed_times( ref_to_list_of_times )
    # The argument is a ref to a hash that maps filenames to times
    # Non-existent files have time zero
    # Return name of first changed file, if at least one file changed
    #        else "" if no files changed
    # (Change => change of time or change of existence.)
    
    my $ref = shift;
FILE:
    foreach my $file (keys %$ref) {
        my $old_time = $$ref{$file};
        my $new_time = get_mtime0($file);
        if ( $old_time != $new_time ) {
            print "$file' changed time from '$old_time to $new_time\n"
		if $diagnostics;
            return $file;
	}
    } #end FILE
    return '';
}

#************************************************************

#************************************************************
#************************************************************
#************************************************************
#
#      UTILITIES:
#

#************************************************************
# Miscellaneous

sub show_array {
# For use in diagnostics and debugging. 
#  On stderr, print line with $_[0] = label.  
#  Then print rest of @_, one item per line preceeded by some space
    warn "$_[0]\n";
    shift;
    foreach (@_){ warn "  $_\n";}
}

#************************************************************

sub glob_list {
    # Glob a collection of filenames.  Sort and eliminate duplicates
    # Usage: e.g., @globbed = glob_list(string, ...);
    my @globbed = ();
    foreach (@_) {
        push @globbed, glob;
    }
    return uniq( sort( @globbed ) );
}

#==================================================

sub glob_list1 {
    # Glob a collection of filenames.  
    # But no sorting or elimination of duplicates
    # Usage: e.g., @globbed = glob_list1(string, ...);

    my @globbed = ();
    foreach my $file_spec (@_) {
        # Problem, when the PATTERN contains spaces, the space(s) are
        # treated as pattern separaters (in MSWin at least).
        # MSWin: I can quote the pattern (is that MSWin native, or also 
        #        cygwin?)
        # Linux: Quotes in a pattern are treated as part of the filename!
        #        So quoting a pattern is definitively wrong.
        push @globbed, glob( "$file_spec" );
    }
    return @globbed;
}

#************************************************************
# Miscellaneous

sub prefix {
   #Usage: prefix( string, prefix );
   #Return string with prefix inserted at the front of each line
   my @line = split( /\n/, $_[0] );
   my $prefix = $_[1];
   for (my $i = 0; $i <= $#line; $i++ ) {
       $line[$i] = $prefix.$line[$i]."\n";
   }
   return join( "", @line );
}


#************************************************************
#      File handling routines:


#************************************************************

sub get_latest_mtime
# - arguments: each is a filename.
# - returns most recent modify time.
{
  my $return_mtime = 0;
  foreach my $include (@_)
  {
    my $include_mtime = &get_mtime($include);
    # The file $include may not exist.  If so ignore it, otherwise
    # we'll get an undefined variable warning.
    if ( ($include_mtime) && ($include_mtime >  $return_mtime) )
    {
      $return_mtime = $include_mtime;
    }
  }
  return $return_mtime;
}

#************************************************************

sub get_mtime_raw
{ 
  my $mtime = (stat($_[0]))[9];
  return $mtime;
}

#************************************************************

sub get_mtime { 
    return get_mtime0($_[0]);
}

#************************************************************

sub get_mtime0 {
   # Return time of file named in argument
   # If file does not exist, return 0;
   if ( -e $_[0] ) {
       return get_mtime_raw($_[0]);
   }
   else {
       return 0;
   }
}

#************************************************************



# Find file with default extension
# Usage: find_file_ext( name, default_ext, ref_to_array_search_path)
sub find_file_ext
#?? Need to use kpsewhich, if possible.  Leave to find_file?
{
    my $full_filename = shift;
    my $ext = shift;
    my $ref_search_path = shift;
    my $full_filename1 = &find_file($full_filename, $ref_search_path, '1');
#print "Finding \"$full_filename\" with ext \"$ext\" ... ";
    if (( $full_filename1 eq '' ) || ( ! -e $full_filename1 ))
    {
      my $full_filename2 = 
          &find_file("$full_filename.$ext",$ref_search_path,'1');
      if (( $full_filename2 ne '' ) && ( -e $full_filename2 ))
      {
        $full_filename = $full_filename2;
      }
      else
      {
        $full_filename = $full_filename1;
      }
    }
    else
    {
      $full_filename = $full_filename1;
    }
#print "Found \"$full_filename\".\n";
    return $full_filename;
}

#************************************************************
# given filename and path, return full name of file, or die if none found.
# when force_include_mode=1, only warn if an include file was not
# found, and return 0 (PvdS).
# Usage: find_file(name, ref_to_array_search_path, warn_on_continue)
sub find_file
#?? Need to use kpsewhich, if possible
{
  my $name = $_[0];
  my $ref_path = $_[1];
  my $dir;
  if ( $name =~ /^\// )
  {
    #Aboslute pathname (by UNIX standards)
    if ( (!-e $name) && ( $_[2] eq '' ) ) {
        if ($force_include_mode) {
           warn "Latexmk: Could not find file [$name]\n";
        }
        else {
           die "Latexmk: Could not find file [$name]\n";
        }
    }
    return $name;
  }
  # Relative pathname
  foreach $dir ( @{$ref_path} )
  {
#warn "\"$dir\", \"$name\"\n";
    if (-e "$dir/$name")
    {
      return("$dir/$name");
    }
  }
  if ($force_include_mode)
  {
	if ( $_[2] eq '' )
	{
	  warn "Latexmk: Could not find file [$name] in path [@{$ref_path}]\n";
	  warn "         assuming in current directory (./$name)\n";
	}
	return("./$name");
  }
  else
  {
	if ( $_[2] ne '' )
	{
	  return('');
	}
# warn "\"$name\", \"$ref_path\", \"$dir\"\n";
  	die "Latexmk: Could not find file [$name] in path [@{$ref_path}]\n";
  }
}

#************************************************************
# Usage: find_file1(name, ref_to_array_search_path)
# Modified find_file, which doesn't die.
# Given filename and path, return array of:
#             full name 
#             retcode
# On success: full_name = full name with path, retcode = 0
# On failure: full_name = given name, retcode = 1
sub find_file1
#?? Need to use kpsewhich, if possible
{
  my $name = $_[0];
  my $ref_path = $_[1];
  my $dir;
  if ( $name =~ /^\// )
  {
     # Absolute path (if under UNIX)
     # This needs fixing, in general
     if (-e $name)
        { return( $name, 0 );}
     else
        { return( $name, 1 );}
  }
  foreach $dir ( @{$ref_path} )
  {
#warn "\"$dir\", \"$name\"\n";
    if (-e "$dir/$name")
    {
      return("$dir/$name", 0);
    }
  }
  return("$name" , 1);
}

#************************************************************

sub find_file_list1
# Modified version of find_file_list that doesn't die.
# Given output and input arrays of filenames, a file suffix, and a path, 
# fill the output array with full filenames
# Return a status code:
# Retcode = 0 on success
# Retocde = 1 if at least one file was not found
# Usage: find_file_list1( ref_to_output_file_array, 
#                         ref_to_input_file_array, 
#                         suffix,
#                         ref_to_array_search_path
#                       )
{
  my $ref_output = $_[0];
  my $ref_input  = $_[1];
  my $suffix     = $_[2];
  my $ref_search = $_[3];

  my @return_list = ();    # Generate list in local array, since input 
                           # and output arrays may be same
  my $retcode = 0;
  foreach my $file (@$ref_input)
  {
    my ($tmp_file, $find_retcode) = &find_file1( "$file$suffix", $ref_search );
    if ($tmp_file)
    {
    	push @return_list, $tmp_file;
    }
    if ( $find_retcode != 0 ) {
        $retcode = 1;
    }
  }
  @$ref_output = @return_list;
  return $retcode;
}

#************************************************************

sub find_dirs1 {
   # Same as find_dirs, but argument is single string with directories
   # separated by $search_path_separator
   find_dirs( &split_search_path( $search_path_separator, ".", $_[0] ) );
}


#************************************************************

sub find_dirs {
# @_ is list of directories
# return: same list of directories, except that for each directory 
#         name ending in //, a list of all subdirectories (recursive)
#         is added to the list.
#   Non-existent directories and non-directories are removed from the list
#   Trailing "/"s and "\"s are removed
    local @result = ();
    my $find_action 
        = sub 
          { ## Subroutine for use in File::find
            ## Check to see if we have a directory
	       if (-d) { push @result, $File::Find::name; }
	  };
    foreach my $directory (@_) {
        my $recurse = ( $directory =~ m[//$] );
        # Remove all trailing /s, since directory name with trailing /
        #   is not always allowed:
        $directory =~ s[/+$][];
        # Similarly for MSWin reverse slash
        $directory =~ s[\\+$][];
	if ( ! -e $directory ){
            next;
	}
	elsif ( $recurse ){
            # Recursively search directory
            find( $find_action, $directory );
	}
        else {
            push @result, $directory;
	}
    }
    return @result;
}

#************************************************************

sub uniq 
# Read arguments, delete neighboring items that are identical,
# return array of results
{
    my @sort = ();
    my ($current, $prev);
    my $first = 1;
    while (@_)
    {
	$current = shift;
        if ($first || ($current ne $prev) )
	{
            push @sort, $current; 
            $prev = $current;
            $first = 0;
        }
    }
    return @sort;
}

#==================================================

sub uniq1 {
   # Usage: uniq1( strings )
   # Returns array of strings with duplicates later in list than
   # first occurence deleted.  Otherwise preserves order.

    my @strings = ();
    my %string_hash = ();

    foreach my $string (@_) {
        if (!exists( $string_hash{$string} )) { 
            $string_hash{$string} = 1;
            push @strings, $string; 
        }
    }
    return @strings;
}

#************************************************************

sub copy_file_and_time {
    # Copy file1 to file2, copying time
    # I think copy() already does this, but it may depend on version.
    my $source = shift;
    my $dest   = shift;
    my $retcode = copy ($source, $dest)
	and do {
              my $mtime = get_mtime($source);
              utime $mtime, $mtime, $dest;
	  };
    return $retcode;    
}

#************************************************************

sub copy_file_keep_time {
    # Copy file1 to file2, preserving time of file 2
    my $source = shift;
    my $dest   = shift;
    if (-e $dest) { return 1; }
    my $mtime = get_mtime($dest);
    my $retcode = copy ($source, $dest)
	and do {
              utime $mtime, $mtime, $dest;
	  };
    return $retcode;    
}

#************************************************************

sub diff {
   # diff(filename1, filename2): 
   #         Return 2 if either or both files cannot be opened.
   #                1 if the files are different
   #                0 if the files are the same
    my $file1 = new FileHandle;
    my $file2 = new FileHandle;
   # Note automatic close of files when they go out of scope.
    open ($file1, $_[0]) or return 2;
    open ($file2, $_[1]) or return 2;
    my $retcode = 0;
    while ( ( not eof($file1)) || ( not eof($file2) ) ){
	if ( <$file1> ne <$file2> ) {
            $retcode = 1;
            last;
        }
    }
    return $retcode;
}

#************************************************************

sub diff_OLDVERSION {
   # diff(filename1, filename2): 
   #         Return 2 if either or both files cannot be opened.
   #                1 if the files are different
   #                0 if the files are the same
    local (*file1, *file2);
    unless(  open (file1, $_[0]) ) {
        return 2;
    }
    unless ( open (file2, $_[1])) {
	close (file1);
        return 2;
    }
    my $retcode = 0;
    while ( ( not eof(file1)) && ( not eof(file2) ) ){
	if ( <file1> ne <file2> ) {
            $retcode = 1;
            last;
        }
    }
    close (file1);
    close (file2);
    return $retcode;
}

#************************************************************

sub split_search_path 
{
# Usage: &split_search_path( separator, default, string )
# Splits string by separator and returns array of the elements
# Allow empty last component.
# Replace empty terms by the default.
    my $separator = $_[0]; 
    my $default = $_[1]; 
    my $search_path = $_[2]; 
    my @list = split( /$separator/, $search_path);
    if ( $search_path =~ /$separator$/ ) {
        # If search path ends in a blank item, the split subroutine
	#    won't have picked it up.
        # So add it to the list by hand:
        push @list, "";
    }
    # Replace each blank argument (default) by current directory:
    for ($i = 0; $i <= $#list ; $i++ ) {
        if ($list[$i] eq "") {$list[$i] = $default;}
    }
    return @list;
}

#################################


sub tempfile1 {
    # Makes a temporary file of a unique name.  I could use file::temp,
    # but it is not present in all versions of perl
    # Filename is of form $tmpdir/$_[0]nnn$suffix, where nnn is an integer
    my $tmp_file_count = 0;
    my $prefix = $_[0];
    my $suffix = $_[1];
    while (1==1) {
        # Find a new temporary file, and make it.
        $tmp_file_count++;
        my $tmp_file = "${tmpdir}/${prefix}${tmp_file_count}${suffix}";
        if ( ! -e $tmp_file ) {
            open( TMP, ">$tmp_file" ) 
               or next;
            close(TMP);
            return $tmp_file;
	 }
     }
     die "Latexmk::tempfile1: BUG TO ARRIVE HERE\n";
}

#################################

#************************************************************
#************************************************************
#      Process/subprocess routines

sub Run_msg {
    # Same as Run, but give message about my running
    warn_running( "Running '$_[0]'" );
    Run($_[0]);
}

sub Run {
# Usage: Run ("program arguments ");
#    or  Run ("start program arguments");
#    or  Run ("NONE program arguments");
# First form is just a call to system, and the routine returns after the 
#    program has finished executing.  
# Second form (with 'start') runs the program detached, as appropriate for
#    the operating system: It runs "program arguments &" on UNIX, and 
#    "start program arguments" on WIN95 and WINNT.  If multiple start
#    words are at the beginning of the command, the extra ones are removed.
# Third form (with 'NONE') does not run anything, but prints an error
#    message.  This is provided to allow program names defined in the
#    configuration to flag themselves as unimplemented.
# Return value is a list (pid, exitcode):
#   If process is spawned sucessfully, and I know the PID,
#       return (pid, 0),
#   else if process is spawned sucessfully, but I do not know the PID,
#       return (0, 0),
#   else if process is run, 
#       return (0, exitcode of process)
#   else (I fail to run the requested process)
#       return (0, suitable return code)
#   where return code is 1 if cmdline is null or begins with "NONE" (for
#                      an unimplemented command)
#                     or the return value of the system subroutine.


# Split command line into one word per element, separating words by 
#    one (OR MORE) spaces:
# The purpose of this is to identify latexmk-defined pseudocommands
#  'start' and 'NONE'.
# After dealing with them, the command line is reassembled
    my $cmd_line = $_[0];
    if ( $cmd_line eq '' ) {
	warn "Latexmk::Run: Attempt to run a null program.";
        return (0, 1);
    }
    if ( $cmd_line =~ /^start +/ ) {
        #warn "Before: '$cmd_line'\n";
        # Run detached.  How to do this depends on the OS
        # But first remove extra starts (which may have been inserted
        # to force a command to be run detached, when the command
	# already contained a "start").
        while ( $cmd_line =~ s/^start +// ) {}
        #warn "After: '$cmd_line'\n";
        return &Run_Detached( $cmd_line );
    }
    elsif ( $cmd_line =~ /^NONE/ ) {
        warn "Latexmk::Run: ",
             "Program not implemented for this version.  Command line:\n";
	warn "   '$cmd_line'\n";
        return (0, 1);
    }
    else { 
       # The command is given to system as a single argument, to force shell
       # metacharacters to be interpreted:
       return( 0, system( $cmd_line ) );
   }
}

#************************************************************

sub Run_Detached {
# Usage: Run_Detached ("program arguments ");
# Runs program detached.  Returns 0 on success, 1 on failure.
# Under UNIX use a trick to avoid the program being killed when the 
#    parent process, i.e., me, gets a ctrl/C, which is undesirable for pvc 
#    mode.  (The simplest method, system ("program arguments &"), makes the 
#    child process respond to the ctrl/C.)
# Return value is a list (pid, exitcode):
#   If process is spawned sucessfully, and I know the PID,
#       return (pid, 0),
#   else if process is spawned sucessfully, but I do not know the PID,
#       return (0, 0),
#   else if I fail to spawn a process
#       return (0, 1)

    my $cmd_line = $_[0];

##    warn "Running '$cmd_line' detached...\n";
    if ( $cmd_line =~ /^NONE / ) {
        warn "Latexmk::Run: ",
             "Program not implemented for this version.  Command line:\n";
	warn "   '$cmd_line'\n";
        return (0, 1);
    }

    if ( "$^O" eq "MSWin32" ){
        # Win95, WinNT, etc: Use MS's start command:
        return( 0, system( "start $cmd_line" ) );
    } else {
        # Assume anything else is UNIX or clone
        # For this purpose cygwin behaves like UNIX.
        ## warn "Run_Detached.UNIX: A\n";
        my $pid = fork();
        ## warn "Run_Detached.UNIX: B pid=$pid\n";
        if ( ! defined $pid ) {
            ## warn "Run_Detached.UNIX: C\n";
	    warn "Latexmk:: Could not fork to run the following command:\n";
            warn "   '$cmd_line'\n";
            return (0, 1);
	}
        elsif( $pid == 0 ){
           ## warn "Run_Detached.UNIX: D\n";
           # Forked child process arrives here
           # Insulate child process from interruption by ctrl/C to kill parent:
           #     setpgrp(0,0);
           # Perhaps this works if setpgrp doesn't exist 
           #    (and therefore gives fatal error):
           eval{ setpgrp(0,0);};
           exec( $cmd_line );
           # Exec never returns; it replaces current process by new process
           die "Latexmk forked process: could not run the command\n",
               "  '$cmd_line'\n";
        }
        ##warn "Run_Detached.UNIX: E\n";
        # Original process arrives here
        return ($pid, 0);
    }
    # NEVER GET HERE.
    ##warn "Run_Detached.UNIX: F\n";
}

#************************************************************

sub find_process_id {
# find_process_id(string) finds id of process containing string and
# being run by the present user.  Typically the string will be the
# name of the process or part of its command line.
# On success, this subroutine returns the process ID.
# On failure, it returns 0.
# This subroutine only works on UNIX systems at the moment.

    if ( $pid_position < 0 ) {
        # I cannot do a ps on this system
        return (0);
    }

    my $looking_for = $_[0];
    my @ps_output = `$pscmd`;

# There may be multiple processes.  Find only latest, 
#   almost surely the one with the highest process number
# This will deal with cases like xdvi where a script is used to 
#   run the viewer and both the script and the actual viewer binary
#   have running processes.
    my @found = ();

    shift(@ps_output);  # Discard the header line from ps
    foreach (@ps_output)   {
	next unless ( /$looking_for/ ) ;
        my @ps_line = split (' ');
# OLD       return($ps_line[$pid_position]);
        push @found, $ps_line[$pid_position];
    }

    if ($#found < 0) {
       # No luck in finding the specified process.
       return(0);
    }
    @found = reverse sort @found;
    if ($diagnostics) {
       print "Found the following processes concerning '$looking_for'\n",
             "   @found\n",
             "   I will use $found[0]\n";
    }
    return $found[0];
}

#************************************************************

sub pushd {
    push @dir_stack, cwd();
    if ( $#_ > -1) { chdir $_[0]; }
}

#************************************************************

sub popd {
    if ($#dir_stack > -1 ) { chdir pop @dir_stack; }
}

#************************************************************

sub ifcd_popd {
    if ( $do_cd ) {
        warn "Latexmk: Undoing directory change\n";
        &popd;
    }
}

#************************************************************

sub finish_dir_stack {
    while ($#dir_stack > -1 ) { &popd; }
}

#************************************************************
