#!/usr/bin/perl


##  
##  Completes a reference on the basis of previous ones in the current
##  document.
##  


$sel=$ENV{'TM_SELECTED_TEXT'};
$line=$ENV{'TM_CURRENT_LINE'};
$pos=$ENV{'TM_COLUMN_NUMBER'}-1;

# break line at cursor:
$line=~/^(.{$pos})(.*)$/; $lineL=$1;
if ( $lineL=~/^(.*)$sel$/ ) { $lineL=$1 };
	# (adjusts for if cursor is at end of selection)

# determine stem (text immed left of cursor):
if ( $lineL=~/.*\\ref[^\{\}]*?\{(.*?)$/ ) {
	$stem=$1;
}
else {
	$stem=$lineL;
} 

# selected text is old completion:
if ( $sel ) { $oldcomp=$sel }

# get whole doc as input, and slurp it:
$/=undef;
$leftover=<>;

# collect matching labels:
while ( $leftover =~ /^.*?label\{(.*?)\}(.*)$/s ) {
	
	# delete everything up to this label:
	$leftover=$2;
	
	# add label to the labels list, if it mathces and isn't already there:
	$nextlabel=$1;
	if ( $nextlabel=~/^$stem/ && ! grep /^$nextlabel$/, @labels ) {
		@labels=( @labels , $nextlabel );
	}

}

$suggestion="";

# if stem+oldcomp matches a whole label, go with the 
# previous label:
$i=0;
foreach (@labels) {
	if ( /^$stem$oldcomp$/ ) {
		if ( $i>0 ) { 
			$suggestion=$labels[$i-1];
		}
		else { 
			$suggestion=$labels[$#labels];
		}
		last; # exit loop
	};
	$i++;
}

# if we still haven't found a completion, check if it matches the start of
# a label:
if ( ! $suggestion ) { 
	@i=grep /^$stem/, @labels;
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
