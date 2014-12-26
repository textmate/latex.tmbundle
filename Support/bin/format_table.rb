#!/usr/bin/env ruby

def reformat(table_content)
  lines = table_content
  s = lines.slice!(/^.*?\}\s*\n/)
  # Place any \hline's not on a line of their own in their own line
  lines.gsub!(/(\\hline\s*)(?!\n)/, '\\hline\\\\\\\\')
  lines = lines.split(/\\\\/)
  data = lines.map do |line|
    line.split(/[^\\]&/).map { |i| i.strip }
  end
  cols = data.map { |i| i.length }.max
  widths = []
  cols.times do |i|
    widths << data.reduce(0) do |maximum, line|
      (line.length <= i) ? maximum : [maximum, line[i].length].max
    end
  end
  pattern = widths.map { |i| "%#{i}s" }.join(' & ')
  print s.chomp
  prev = false
  data.each do |line|
    print(prev ? "\\\\\n" : "\n")
    if line.length <= 1
      print line.join('')
      prev = false
    else
      line.fill('', (line.length + 1)..cols)
      printf(pattern, *line)
      prev = true
    end
  end
  print "\n"
end
