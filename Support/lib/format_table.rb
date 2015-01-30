#!/usr/bin/env ruby

##
# Format a latex tabular environment.
#
# = Arguments
#
# [table_content] A string containing the tabular environment
#
# = Output
#
# The function returns a string containing a properly formatted latex table.
#
# = Examples
#
# doctest: Reformat a table containing only one line
#
#   >> reformat 'First Item & Second Item'
#   => "\nFirst Item & Second Item"
#
# doctest: Reformat a table containing an escaped `&` sign
#
#   >> output = reformat('First Item & Second Item\\\\He \& Ho & Hi')
#   >> expected =
#    '
#    First Item & Second Item\\\\
#      He \& Ho &          Hi'
#   >> output.eql? expected
#   => true
#
# doctest: Reformat a table containing empty cells
#
#   >> output = reformat(' & 2\\\\\\hline & 4 \\\\ Turbostaat & 6')
#   >> expected =
#    '
#               & 2\\\\
#    \\hline
#               & 4\\\\
#    Turbostaat & 6'
#   >> output.eql? expected
#   => true
#
# doctest: Reformat a table containing manual spacing
#
#   >> output = reformat('1 & 2\\\\[1cm]\hline Three & Four')
#   >> expected =
#    '
#         1 &    2\\\\[1cm]
#    \\hline
#     Three & Four'
#   >> output.eql? expected
#   => true
#
def reformat(table_content)
  before_table = table_content.slice!(/^.*?\}\s*\n/)
  # Place any \hline's not on a line of their own in their own line
  table_content.gsub!(/(\\hline\s*)(?!\n)/, '\\hline\\\\\\\\')
  lines = table_content.split(/\\\\/)

  # Check for manual horizontal spacing in the form [space] e.g.: [1cm]
  space_markers = lines.map do |line|
    line.slice!(/\s*\[\.?\d+.*\]/)
  end

  cells = lines.map { |line| line.split(/[^\\]&|^&/).map(&:strip) }
  max_number_columns = cells.map(&:length).max
  widths = []
  max_number_columns.times do |column|
    widths << cells.reduce(0) do |maximum, line|
      (column >= line.length) ? maximum : [maximum, line[column].length].max
    end
  end
  pattern = widths.map { |width| "%#{width}s" }.join(' & ')
  output = before_table ? before_table.chomp : ''
  previous_line_contained_cells = false
  cells.each_with_index do |line, index|
    output +=
      previous_line_contained_cells ? "\\\\#{space_markers[index]}\n" : "\n"
    if line.length <= 1
      output += line.join ''
      previous_line_contained_cells = false
    else
      line.fill('', (line.length + 1)..max_number_columns)
      output += sprintf(pattern, *line)
      previous_line_contained_cells = true
    end
  end
  output
end
