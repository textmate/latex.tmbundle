#!/usr/bin/perl


##  
##  Completes a bibiographic citation.
##  


$BIBLIOG=$ENV{'TM_BIBFILE'};
if ( ! $BIBLIOG ) { 
	print "You need to define an environment variable \$TM_BIBFILE ";
	print "containing the full pathname of the BiBTeX bibliography to use.\n";
	die;
}

$sel=$ENV{'TM_SELECTED_TEXT'};
$line=$ENV{'TM_CURRENT_LINE'};
$pos=$ENV{'TM_COLUMN_NUMBER'}-1;

# break line at cursor:
$line=~/^(.{$pos})(.*)$/; $lineL=$1; 
if ( $lineL=~/$sel$/ ) { $lineL=~s/^(.*)$sel$/$1/g; } 
	# (adjusts for if cursor is at end of selection)

# determine stem (text immed left of cursor):
if ( $lineL=~/.*\\cite[^\{\}]*?\{(?:.*?\,)*(.*?)$/ ) {
	$stem=$1;
}
else {
	$stem=$lineL;
} 

# if null stem, bail out silently:
if ( ! $stem) { print $sel; exit; };

# selected text is old completion:
if ( $sel ) { $oldcomp=$sel }

# collect matching citekeys:
open BIBFILE, "$BIBLIOG";
while (<BIBFILE>) {
	if ( /\@.*?\{$stem/i ) {
		
		# extract citekey:
		s/^.*?\{(.*)\}?\,.*?$/$1/g;
		chomp;
		
		# remember it, if not already in list:
		$citekey=$_;
		if (! grep /^$citekey$/, @citekeys ) {
			@citekeys=( @citekeys , $citekey );
		}

	}
}

@citekeys=sort @citekeys; 
$suggestion="";

# if the stem+oldcomp matches a whole citekey, go with the next one:
$i=0;
foreach (@citekeys) {
	if ( /^$stem$oldcomp$/ ) {
		if ( $i<$#citekeys ) { 
			$suggestion=$citekeys[$i+1];
		}
		else { 
			$suggestion=$citekeys[0];
		}
		last; # exit loop
	};
	$i++;
}

# if we still haven't found a completion, check if stem matches the
# start of a citekey:
if ( ! $suggestion ) {
	@i=grep /^$stem/, @citekeys;
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
