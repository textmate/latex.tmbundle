#!/usr/bin/perl


##  
##  Completes a LaTeX command.
##  


$COMMANDFILE="collected syntax hints";
$dirname=`dirname "$0"`; chomp $dirname;
$COMMANDFILE=$dirname."/".$COMMANDFILE;

$sel=$ENV{'TM_SELECTED_TEXT'};
$line=$ENV{'TM_CURRENT_LINE'};
$pos=$ENV{'TM_COLUMN_NUMBER'}-1;

# break line at cursor:
$line=~/^(.{$pos})(.*)$/; $lineL=$1; 
if ( $lineL=~/$sel$/ ) { $lineL=~s/^(.*)$sel$/$1/g; } # (adjusts for if cursor
	                                                  # is at end of
	                                                  # selection)

# determine stem (text immed left of cursor):
if ( $lineL=~/(\\|\@)(\w*)$/ ) {
	$stem=$2;
	$prefix="\Q$1\E"; # needs fancy quoting for use in REs below
}

# if null stem and it's not a BibTeX command, bail out silently (because it'd
# be stupid to just start going over evey LaTeX command alphabetically):
if ( !$stem && $prefix ne "\Q@\E" ) { print $sel; exit; };

# selected text is old completion:
if ( $sel ) { $oldcomp=$sel };

# collect matching commands:
open COMMANDFILE, "$COMMANDFILE";
while (<COMMANDFILE>) {
	if ( /^$prefix$stem/ ) {
	
		# extract command:
		s/^$prefix(\w+).*?$/$1/g;
		chomp;
		
		# remember it, if not already in list:
		$command=$_;
		if (! grep /^$command$/, @commands ) {
			@commands=( @commands , $command );
		}

	}
}

@commands=sort @commands; 
$suggestion=""; 

# if the stem+oldcomp matches a whole command, go with the next one:
$i=0;
foreach (@commands) {
	if ( /^$stem$oldcomp$/ ) {
		if ( $i<$#commands ) { 
			$suggestion=$commands[$i+1];
		}
		else { 
			$suggestion=$commands[0];
		}
		last; # exit loop
	};
	$i++;
}

# if we still haven't found a completion, check if stem matches the
# start of a command:
if ( ! $suggestion ) {
	@i=grep /^$stem/, @commands;
	$suggestion="$i[0]";
}

if ( $suggestion ) { 
	$suggestion=~s/^$stem(.*)$/$1/g; 	# cut off portion of $suggestion 
										# that matches $stem
	print $suggestion;
} 
else { 
	print $sel;
}
