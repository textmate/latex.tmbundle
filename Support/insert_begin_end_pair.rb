#!/usr/bin/env ruby

commands = /^cite|footnote|label|ref$/
shortcuts = { "it" => "textit", "bf" => "textbf" }

sel = ENV['TM_SELECTED_TEXT']
if(sel.to_s.strip != '')
	name = sel.strip[/^\S+/]
  if(commands.match(name))
    print("\\#{name}{$1}")
  elsif !shortcuts[name].nil?
    print("\\#{shortcuts[name]}{$1}")
  else
    print("\\begin{#{name}}\n\t$1\n\\end{#{name}}")
  end
else
	print("#{sel}\\begin{${1:name}}\n#{sel}\t$2\n#{sel}\\end{$1}")
end
