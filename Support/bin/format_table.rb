#!/usr/bin/env ruby18

def reformat(table_content)
  lines = table_content
  s = lines.slice!(/^.*?\}\s*\n/)
  # Place any \hline's not on a line of their own in their own line
  lines.gsub!(/(\\hline\s*)(?!\n)/,"\\hline\\\\\\\\")
  lines = lines.split(/\\\\/)
  data = lines.map do |line|
    line.split(/&/).map{|i| i.strip}
  end
  cols = data.map{|i| i.length}.max
  widths = []
  cols.times do |i|
    widths << data.inject(0) do |maximum,line| if line.length <= i then maximum else [maximum,line[i].length].max end end
  end
  pattern = widths.map{|i| "%#{i}s"}.join(" & ")
  print s.chomp
  prev=false
  for line in data do
    print(prev ? "\\\\\n" : "\n")
    if line.length <= 1 then
      print line
      prev=false
    else
      line.fill("",(line.length+1)..cols)
      printf(pattern,*line)
      prev=true
    end
  end
  print "\n"
end
