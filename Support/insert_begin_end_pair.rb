#!/usr/bin/env ruby

commands = /^cite|footnote|label|ref$/
shortcuts = { "it" => "textit", "bf" => "textbf" }

sel = ENV['TM_SELECTED_TEXT'].to_s
lab = ENV['TM_LATEX_INSERT_LABEL'].to_i
if(sel.strip != '')
	name = sel.strip[/^\S+/]
  if(commands.match(name))
    print("\\#{name}{$1}")
  elsif !shortcuts[name].nil?
    print("\\#{shortcuts[name]}{$1}")
  else
    if (lab == 1) 
      labPrefix = name.slice(0,3)
      print("\\begin{#{name}}\n\\label{#{labPrefix}:}\n\t$1\n\\end{#{name}}")
    else
      print("\\begin{#{name}}\n\t$1\n\\end{#{name}}")
    end
  end
else
	print("#{sel}\\begin{${1:name}}\n#{sel}\t$2\n#{sel}\\end{$1}")
end
