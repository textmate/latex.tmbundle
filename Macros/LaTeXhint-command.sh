#!/bin/sh


##  
##  Displays a LaTeX command hint. 
##  


COMMANDFILE="`dirname \"$0\"`/collected syntax hints";
SUGGESTIONTEXT="No hints match perfectly, but how about:"

if [[ "$TM_COLUMNS"=="" ]]; then WRAPCOL=78; else WRAPCOL=$TM_COLUMNS; fi

cat >/dev/null # throw out stdin, since TM macro may provide it

if [[ "$TM_CURRENT_WORD" == "" || "$TM_CURRENT_WORD" == "\\" ]]; then 
	echo "Not enough to work with"
else
	hint=`egrep "^[\\@]?$TM_CURRENT_WORD(\W|$)" "$COMMANDFILE" | \
		fold -sw $WRAPCOL`
	if [[ "$hint" == "" ]]; then # second try
		hint=` \
			echo "$SUGGESTIONTEXT" ;
			egrep "$TM_CURRENT_WORD" "$COMMANDFILE" | \
			fold -sw $WRAPCOL
		`
	fi
	if [[ "$hint" == "$SUGGESTIONTEXT" ]]; then
		echo "No matching hints"
	else
		echo "$hint"
	fi
fi
