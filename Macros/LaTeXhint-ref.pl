#!/usr/bin/perl


##  
##  Finds the label corresponding to a currently selected ref string and
##  displays it in context; if it can't find one, displays a list of
##  labels.
##  


$sel=$ENV{"TM_SELECTED_TEXT"};

# get line up to cursor, and break it at cursor:
$line=$ENV{'TM_CURRENT_LINE'};
$pos=$ENV{'TM_COLUMN_NUMBER'}-1;
$line=~/^(.{$pos})(.*)$/; $lineL=$1; 
if ( $lineL=~/$sel$/ ) { $lineL=~s/^(.*)$sel$/$1/g; } 
	# (adjusts for if cursor is at end of selection)

# determine stem (text immed left of cursor):
if ( $lineL=~/.*\\ref[^\{\}]*?\{(.*?)$/ ) {
	$stem=$1;
}
else {
	$stem="";
} 

# get whole doc as input, and slurp it:
$/=undef;
$doc=<>;

# find it:
$doc=~/^.*?(.)?(.{0,80}\\label\{$stem$sel\}.{0,80})(.)?/s;
$labelstuff=$2; $beforestuff=$1; $afterstuff=$3;

# if label not found, show them all:
if (! $labelstuff ) { 
	
	# loop through all the labels:
	while ( $doc =~ /^.*?label\{(.*?)\}(.*)$/s ) {
	
		# delete everything up to this label:
		$doc=$2;
	
		# add label to the labels list, if it's not already there:
		$nextlabel=$1;
		if (! grep /^$nextlabel$/, @labels ) {
			@labels=( @labels , $nextlabel );
		}

	}
	
	if ( @labels) { 
		@labels=sort @labels;
		print "No matching labels, but how about:\n";
		$"="\n"; print "@labels";
	}
	else {
		print "No labels found";
	}
	
} 

# otherwise, if label found, print it and its context:
else {
	
	print "..." if ( $beforestuff =~ /./ );
	print "$beforestuff$labelstuff$afterstuff";
	print "..." if ( $afterstuff =~ /./ );
	print "\n";

}
