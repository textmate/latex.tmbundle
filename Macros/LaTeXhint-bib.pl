#!/usr/bin/perl


##  
##  Finds the bibliography entry corresponding to a currently selected cite
##  string and displays it; if it can't find one, displays some likely
##  suspects.
##  


$BIBLIOG=$ENV{'TM_BIBFILE'};
if ( ! $BIBLIOG ) { 
	print "You need to define an environment variable \$TM_BIBFILE ";
	print "containing the full pathname of the BiBTeX bibliography to use.\n";
	die;
}

$sel=$ENV{"TM_SELECTED_TEXT"};

# get line up to cursor, and break it at cursor:
$line=$ENV{'TM_CURRENT_LINE'};
$pos=$ENV{'TM_COLUMN_NUMBER'}-1;
$line=~/^(.{$pos})(.*)$/; $lineL=$1; 
if ( $lineL=~/$sel$/ ) { $lineL=~s/^(.*)$sel$/$1/g; } 
	# (adjusts for if cursor is at end of selection)

# determine stem (text immed left of cursor):
if ( $lineL=~/.*\\cite[^\{\}]*?\{(?:.*?\,)*(.*?)$/ ) {
	$stem=$1;
}
else {
	$stem="";
} 

# find the entry matching the current citekey:
open BIBFILE, "$BIBLIOG";
while (<BIBFILE>) {
	if ( /\@.*?\{$stem$sel\}?\,/ ) {
		
		# found entry, so get title:
		do {
			$titleline=<BIBFILE>;
		} until $titleline =~ /.*Title.*/;
		
		$titleline=~ s/.*?{(.*)}.*?$/\1/g;
		chomp $titleline;
		$titlestring="\'$titleline\'\n";
		
	}
}

# if no title was found, complain:
if ( ! $titlestring) {

	if ( length($stem)>1 ) {
		$searchling=$searchling.`
			~/bin/searchling "$stem" | 
			while read i ; do
				read j
				echo "\$i \$j"
				read
			done | 
			sort -fud 
		`;
	}
	elsif ( length($sel)>1 ) {
		$searchling=`
			~/bin/searchling "$sel" | 
			while read i ; do
				read j
				echo "\$i \$j"
				read
			done |
			sort -fud 
		`;
	}
	elsif ( length($stem.$sel)==0 ) {
		print "Not enough to work with";
		exit;
	}
	
	if ( ! $searchling ) { print "No matches\n" } 
		else { print "No entries match perfectly, but how about:\n$searchling" };
	
}

# otherwise, display title:
else {
	print "$titlestring";
}
