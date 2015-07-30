# -- Imports -------------------------------------------------------------------

require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes.rb'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui.rb'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/Ruby/indent.rb'

# -- Class ---------------------------------------------------------------------

# This class represents a LaTeX table.
class Table
  # This function initializes a new LaTeX table.
  #
  # The default dimensions of the table are determined by reading the current
  # selection. If there is no selection, then the values will be read via a pop
  # up window.
  #
  # = Arguments
  #
  # [rows] The number of table rows
  # [columns] The number of table columns
  def initialize(rows = nil, columns = nil)
    @rows = rows
    @columns = columns
    @rows, @columns = self.class.read_parameters unless @rows && @columns
    @i1 = indent
    @i2 = @i1 * 2
    @array_header_start = '\textbf{'
    @array_header_end = '}'
    @insertion_point_array_header = 2
    @insertion_point_array = @insertion_point_array_header + @columns
  end

  # This function returns a string representation of the current table.
  #
  # = Output
  #
  # The function returns a string containing LaTeX code for the table.
  #
  # = Examples
  #
  #  doctest: Create a small table
  #
  #  >> table = Table.new(2, 2)
  #  >> i1 = indent(1)
  #  >> i2 = indent(2)
  #  >> table_representation = [
  #       "\\begin{table}[htb!]",
  #       "#{i1}\\caption{\\it ${1:caption}}",
  #       "#{i1}\\label{table:${2:label}}",
  #       "#{i1}\\centering",
  #       "#{i1}\\begin{tabular}{cc}",
  #       "#{i2}\\toprule",
  #       "#{i2}\\textbf{${3:Header 1}} & \\textbf{${4:Header 2}}\\\\\\\\",
  #       "#{i2}             ${5:r2c1} &              ${6:r2c2}\\\\\\\\",
  #       "#{i2}\\toprule",
  #       "#{i1}\\end{tabular}",
  #       "\\end{table}"].join("\n")
  #  >> table.to_s == table_representation
  #  => true
  def to_s
    [header, array_header, array, footer].join("\n")
  end

  private

  def header
    "\\begin{table}[htb!]\n" \
    "#{@i1}\\caption{\\it \${1:caption}}\n" \
    "#{@i1}\\label{table:\${2:label}}\n" \
    "#{@i1}\\centering\n" \
    "#{@i1}\\begin{tabular}{#{'c' * @columns}}\n" \
    "#{@i2}\\toprule"
  end

  def footer
    "#{@i2}\\toprule\n#{@i1}\\end{tabular}\n\\end{table}"
  end

  def array_header(insertion_point = @insertion_point_array_header)
    @i2 + @columns.times.collect do |c|
      @array_header_start + \
        "${#{insertion_point += 1}:#{array_header_text(c)}}" + \
        @array_header_end
    end.join(' & ') + '\\\\\\\\'
  end

  def array_header_text(column)
    "Header #{column + 1}"
  end

  def array_header_length(column)
    array_header_text(column).length + @array_header_start.length + \
      @array_header_end.length
  end

  # rubocop:disable Metrics/AbcSize
  def array(insertion_point = @insertion_point_array)
    (@rows - 1).times.collect do |r|
      @i2 + @columns.times.collect do |c|
        text = "r#{r + 2}c#{c + 1}"
        padding = ' ' * (array_header_length(c) - text.length)
        "#{padding}${#{insertion_point += 1}:#{text}}"
      end.join(' & ') + '\\\\\\\\'
    end.join("\n")
  end

  class <<self
    def read_parameters
      result = if ENV.key?('TM_SELECTED_TEXT') then ENV['TM_SELECTED_TEXT']
               else TextMate::UI.request_string(
                 :title => 'LaTeX Table Creation',
                 :prompt => 'Number of rows and columns:',
                 :default => '6 4',
                 :button1 => 'Create')
               end
      TextMate.exit_discard if result.nil?
      parse_parameters(result)
    end

    def parse_parameters(result)
      m = /(\d+)\D+(\d+)/.match(result.to_s)
      TextMate.exit_discard if m.nil?
      [m[1].to_i, m[2].to_i]
    end
  end
end
