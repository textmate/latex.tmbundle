require "#{ENV['TM_SUPPORT_PATH']}/lib/exit_codes.rb"
require "#{ENV['TM_SUPPORT_PATH']}/lib/ui.rb"

def create_table
  if ENV.has_key?('TM_SELECTED_TEXT') then
    result=ENV['TM_SELECTED_TEXT']
  else
    result = TextMate::UI.request_string(
      :title => 'LaTeX Array Creation',
      :prompt => 'Number of rows and columns:',
      :default => '6 4',
      :button1 => 'Create'
    )
    TextMate.exit_discard if result.nil?
  end
  # print "Result: #{result}"
  m = /(\d+)\D+(\d+)/.match(result.to_s)
  exit if m.nil?
  rows, columns = m[1].to_i, m[2].to_i
  # print "Rows: #{rows}"
  # print "Columns: #{columns}"
  print "\\begin{table}[htb!]
  	\\caption{\\it \${1:caption}}
  	\\label{table:\${2:label}}
  	\\centering
  	\\begin{tabular}{"
  (columns-1).times {print("c ")}
  puts "c}
  	\\toprule\n"
  n=3
  rows.times do |r|
    (columns-1).times do |c|
      n+=1
  	if r == 0
  		print "		\\textbf{${#{n}:Header #{c+1}}} & "
  	else
  		print "		${#{n}:r#{r+1}c#{c+1}} & "
  	end
    end
    n+=1
  	if r == 0
  		print "		\\textbf{${#{n}:Header #{columns}}}\\\\\\\\\n"
  	else
  		print "			${#{n}:r#{r+1}c#{columns}}\\\\\\\\\n"
  	end

    end
  puts "    \\toprule\n  \\end{tabular}\n\\end{table}"
end
