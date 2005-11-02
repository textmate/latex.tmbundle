#!/usr/bin/env ruby

sel = ENV['TM_SELECTED_TEXT']
if(sel.to_s.strip != '')
	name = sel.strip[/^\S+/]
	print("\\begin{#{name}}\n\t$1\n\\end{#{name}}")
else
	print("#{sel}\\begin{${1:name}}\n#{sel}\t$2\n#{sel}\\end{$1}")
end
