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
  # [full_table] Specify if this table represents a full table or only a tabular
  #              environment
  def initialize(rows = nil, columns = nil, full_table = true)
    @rows = rows
    @columns = columns
    @full_table = full_table
    @rows, @columns, @full_table = self.class.read_parameters unless
      @rows && @columns
    @i1 = indent
    @i2 = @i1 * 2
    @array_header_start = '\textbf{'
    @array_header_end = '}'
    @insertion_points_header = @full_table ? 2 : 0
  end

  # This function returns a string representation of the current table.
  #
  # = Output
  #
  # The function returns a string containing LaTeX code for the table.
  #
  # = Examples
  #
  #  doctest: Check the representation of a small table
  #
  #  >> table = Table.new(2, 2)
  #  >> i1 = indent(1)
  #  >> i2 = indent(2)
  #  >> start = ["\\begin{table}[htb!]",
  #              "#{i1}\\caption{\\it ${1:caption}}",
  #              "#{i1}\\label{table:${2:label}}",
  #              "#{i1}\\centering"]
  #  >> ending = ["#{i2}\\toprule",
  #               "#{i1}\\end{tabular}",
  #               "\\end{table}"]
  #  >> middle = [
  #       "#{i1}\\begin{tabular}{cc}",
  #       "#{i2}\\toprule",
  #       "#{i2}\\textbf{${3:Header 1}} & \\textbf{${4:Header 2}}\\\\\\\\",
  #       "#{i2}             ${5:r2c1} &              ${6:r2c2}\\\\\\\\"]
  #  >> table_representation = (start + middle + ending).join("\n")
  #  >> table.to_s == table_representation
  #  => true
  #
  #  doctest: Check the representation of a tiny table
  #
  #  >> table = Table.new(1, 1)
  #  >> middle = [
  #       "#{i1}\\begin{tabular}{c}",
  #       "#{i2}\\toprule",
  #       "#{i2}\\textbf{${3:Header 1}}\\\\\\\\"]
  #  >> table_representation = (start + middle + ending).join("\n")
  #  >> table.to_s == table_representation
  #  => true
  #
  #  doctest: Check the representation of a small tabular environment
  #
  #  >> table = Table.new(2, 3, false)
  #  >> table_representation = [
  #       "\\begin{tabular}{ccc}",
  #       "#{i1}${1:r1c1} & ${2:r1c2} & ${3:r1c3}\\\\\\\\",
  #       "#{i1}${4:r2c1} & ${5:r2c2} & ${6:r2c3}\\\\\\\\",
  #       "\\end{tabular}"].join("\n")
  #  >> table.to_s == table_representation
  #  => true
  def to_s
    if @full_table
      [header, array_header, @rows <= 1 ? nil : array, footer].compact
    else
      ["\\begin{tabular}{#{'c' * @columns}}", array, '\\end{tabular}']
    end.join("\n")
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

  def array_header(insertion_point = @insertion_points_header)
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

  def array
    rows = @rows - (@full_table ? 1 : 0)
    insertion_point = @full_table ? @insertion_points_header + @columns : 0
    indentation = @full_table ? @i2 : @i1
    create_array(rows, indentation, insertion_point)
  end

  # rubocop:disable Metrics/AbcSize
  def create_array(rows, indentation, insertion_point)
    rows.times.collect do |row|
      row += @full_table ? 2 : 1
      padding = ' ' * (@rows.to_s.length - row.to_s.length) unless @full_table
      indentation + @columns.times.collect do |c|
        text = "r#{row}c#{c + 1}"
        padding = ' ' * (array_header_length(c) - text.length) if @full_table
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
      one_upto_hundred = '([1-9]\d?|100)'
      rows_default = 2
      m = /^(?:#{one_upto_hundred}\D+)?#{one_upto_hundred}\s*(t)?$/.match(
        result.to_s)
      TextMate.exit_show_tool_tip(usage(rows_default, 100, 100)) if m.nil?
      [m[1] ? m[1].to_i : rows_default, m[2].to_i, m[3].nil?]
    end

    def usage(rows_default, rows_max, columns_max)
      "USAGE: [#rows] #columns [t] \n\n" \
      "#rows: Number of table rows (Default: #{rows_default}, " \
      "Maximum: #{rows_max})\n" \
      "#columns: Number of table columns (Maximum: #{columns_max})\n" \
      't: Create a tabular environment only'
    end
  end
end
