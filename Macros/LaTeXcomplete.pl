#!/usr/bin/perl


##  
##  Runs the appropriate LaTeX completion script depending on context.
##  Adding 'display' as an argument runs the tooltip-displaying portion
##  rather than the insertion/completion proper portion.
##  
##  This system is set up so that it can be mapped to a single macro in TM
##  with several parts: run command 'LaTeXcomplete.pl' with input whole
##  document and output replace selection; run command 'LaTeXcomplete.pl
##  display' with input whole document and output insert as snippet.
##  


$DISPLAYCOMMAND="display";

$dirname=`dirname "$0"`; chomp $dirname;
$line=$ENV{"TM_CURRENT_LINE"};
$col=$ENV{"TM_COLUMN_NUMBER"}-1;

$line=~s/^(.{$col}).*$/$1/g;

if ( $line =~ /^.*\\(cite|ref)[^\}\\]*\{[^\}\\]*$/ ) { $hit=$1 }

if ( $ARGV[0] eq $DISPLAYCOMMAND ) {
	if ( $hit eq "ref" ) { print `"$dirname"/LaTeXhint-ref.pl` }
	elsif ( $hit eq "cite" ) { print `"$dirname"/LaTeXhint-bib.pl` }
	else { print `"$dirname"/LaTeXhint-command.sh` }
}
else {
	if ( $hit eq "ref" ) { print `"$dirname"/LaTeXcomplete-ref.pl` }
	elsif ( $hit eq "cite" ) { print `"$dirname"/LaTeXcomplete-bib.pl` }
	else { print `"$dirname"/LaTeXcomplete-command.pl` }
}
