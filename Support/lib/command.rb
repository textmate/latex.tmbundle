# Various code used by the commands of the LaTeX bundle
#
# Authors:: Charilaos Skiadas, Michael Sheets,
#           René Schwaiger (sanssecours@f-m.fm)

# -- Imports -------------------------------------------------------------------

require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes.rb'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui.rb'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/latex.rb'

# -- Functions -----------------------------------------------------------------

# ===========
# = General =
# ===========

# Display a menu of choices or use the first choice if there is only one.
#
# This function will abort execution if +choices+ is empty or the user does not
# select any of the displayed choices.
#
# = Arguments
#
# [choices] A list of strings. Each string represents a menu item.
def menu_choice_exit_if_empty(choices)
  TextMate.exit_discard if choices.empty?
  if choices.length > 1
    choice = TextMate::UI.menu(choices)
    TextMate.exit_discard if choice.nil?
    choices[choice]
  else
    choices[0]
  end
end

# Filter items according to input.
#
# = Arguments
#
# [input] A string used to filter +items+.
# [items] A list of possible selections.
#
# = Output
#
# A list of filtered items and a boolean value that states if +input+ should be
# replaced or extended.
#
# = Examples
#
#  doctest: Filter a list of simple items
#
#  >> filter_items_replace_input(['item1', 'item2'], '{')
#  => [['item1', 'item2'], false]
#  >> filter_items_replace_input(['item1', 'item2'], '2')
#  => [['item2'], true]
def filter_items_replace_input(items, input)
  # Check if we should use the input as part of the choice
  match_input = input.match(/^(?:$|[{}~])/).nil?
  items = items.grep(/#{input}/) if match_input
  [items, match_input]
end

# Insert a value based on a selection into the current document.
#
# = Arguments
#
# [selection] A string that is the basis for the output of this function
# [input] The current input/selection of the document
# [replace_input] A boolean that specifies if +input+ should be replaced or not
# [scope] A string that specifies the scope that should be checked. According to
#         this value a new label or citation is inserted into the document
def output_selection(selection, input, replace_input, scope = 'citation')
  if ENV['TM_SCOPE'].match(/#{scope}/)
    print(input.match(/^\{/).nil? ? selection : "{#{selection}}")
  else
    environment = (scope == 'citation') ? 'cite' : 'ref'
    TextMate.exit_insert_snippet(
      "#{replace_input ? '' : input}\\\\${1:#{environment}}\{#{selection}\}")
  end
end

# ======================
# = Command Completion =
# ======================

# Insert a command based on the current word into the document.
def command_completion
  completions = `"#{ENV['TM_BUNDLE_SUPPORT']}"/bin/LatexCommandCompletions.rb`
  print(menu_choice_exit_if_empty(completions.split("\n")))
rescue RuntimeError => e
  TextMate.exit_show_tool_tip(e.message)
end

# =========================================
# = Insert Citation Based On Current Word =
# =========================================

# Return a list of citation strings for the current document.
#
# +input+ is used to filter the possible citations.
#
# = Arguments
#
# [input] A string used to filter the citations for the current document
#
# = Output
#
# A list of citation strings and a boolean, which states if we should overwrite
# the input or keep it.
#
# = Examples
#
#  doctest: Get the citation in 'references.tex' containing the word 'robertson'
#
#  >> ENV['TM_LATEX_MASTER'] = 'Tests/TeX/references.tex'
#  >> cites, replace_input = citations('robertson')
#  >> cites.length
#  => 1
#  >> replace_input
#  => true
#
#  doctest: Get all citations for the file 'references.tex'
#
#  >> ENV['TM_LATEX_MASTER'] = 'Tests/TeX/references.tex'
#  >> cites, replace_input = citations('}')
#  >> cites.length
#  => 5
#  >> replace_input
#  => false
def citations(input)
  items = LaTeX.citations.map(&:to_s)
  filter_items_replace_input(items, input)
end

# Insert a citation into a document based on the given input.
#
# = Arguments
#
# [input] A string used to filter the possible citations for the current
#         document
def insert_citation(input)
  menu_items, replace_input = citations(input)
  selection = menu_choice_exit_if_empty(menu_items).slice(/^[^\s]+/)
  output_selection(selection, input, replace_input)
rescue RuntimeError => e
  TextMate.exit_show_tool_tip(e.message)
end

# ===================================
# = Insert Citation (Ref-TeX Style) =
# ===================================

# Display a menu that lets the user choose a certain cite environment.
#
# This function exits if none of the cite environments was chosen.
#
# = Output
#
# The function returns the chosen environment.
def choose_cite_environment
  items = ['c:  \\cite',
           't:  \\citet', '    \\citet*',
           'p:  \\citep', '    \\citep*',
           'e:  \\citep[e.g.]',
           's:  \\citep[see]',
           'a:  \\citeauthor', '    \\citeauthor*',
           'y:  \\citeyear',
           'r:  \\citeyearpar',
           'f:  \\footcite']
  menu_choice_exit_if_empty(items).gsub(/.*\\/, '')
end

# Insert an “extended” citation into a document based on the given input.
#
# = Arguments
#
# [input] A string used to filter the possible citations for the current
#         document
def insert_reftex_citation(input)
  if ENV['TM_SCOPE'].match(/citation/) then insert_citation(input)
  else
    cite_environment = choose_cite_environment
    citations, replace_input = citations(input)
    citation = menu_choice_exit_if_empty(citations).slice(/^[^\s]+/)
    TextMate.exit_insert_snippet("#{replace_input ? '' : input}" \
      "\\#{cite_environment}${1:[$2]}\{#{citation}$3\}$0")
  end
rescue RuntimeError => e
  TextMate.exit_insert_text(e.message)
end

# ======================================
# = Insert Label Based On Current Word =
# ======================================

# Insert a label into a document based on the given input.
#
# = Arguments
#
# [input] A string used to filter the possible labels for the current document
def insert_label(input)
  menu_items, replace_input = filter_items_replace_input(LaTeX.label_names,
                                                         input)
  selection = menu_choice_exit_if_empty(menu_items)
  # rubocop:disable Lint/UselessAssignment
  output_selection(selection, input, replace_input, scope = 'label')
rescue RuntimeError => e
  TextMate.exit_show_tool_tip(e.message)
end

# ======================
# = Open Included Item =
# ======================

# Get the location of an included item.
#
# = Arguments
#
# [input] The text that should be searched for an included item
#
# = Output
#
# The function returns a string that contains the location of an included item.
# If no location was found, then it returns an empty string
def locate_included_item(input)
  environment = '\\\\(?:include|input|includegraphics|lstinputlisting)'
  comment = '(?:%.*\n[ \t]*)?'
  option = '(?>\[.*?\])?'
  file = '(?>\{(.*?)\})'
  match = input.scan(/#{environment}#{comment}#{option}#{comment}#{file}/m)
  match.empty? ? '' : match.pop.pop.gsub(/(^\")?(\"$)?/, '')
end

# Get the path of the current master file.
#
# = Output
#
# A string containing the location of the master file.
def masterfile
  LaTeX.master(ENV['TM_LATEX_MASTER'] || ENV['TM_FILEPATH'])
end

# Get the currently selected text in TextMate
#
# If no text is selected, then content of the current line will be returned.
#
# = Output
#
# The function a string containing the current selection. If the selection is
# empty, then it returns the content current line.
def selection_or_line
  ENV['TM_SELECTED_TEXT'] || ENV['TM_CURRENT_LINE']
end

# Open the file located at +location+.
#
# = Arguments
#
# [location] The path to the file that should be opened.
def open_file(location)
  filepath = `kpsewhich #{e_sh location}`.chomp
  if filepath.empty?
    possible_files = Dir["#{location}*"]
    filepath = possible_files.pop unless possible_files.empty?
  end
  TextMate.exit_show_tool_tip('Could not locate file for path ' \
                              "`#{location}'") if filepath.empty?
  `open #{e_sh filepath}`
end

# Open an included item in a tex file.
#
# For example: If the current line contains `\input{included_item}`, then this
# command will open the file with the filename +included_item+.
def open_included_item
  master, input = masterfile, selection_or_line
  Dir.chdir(File.dirname(master)) unless master.nil?
  location = locate_included_item(input)
  TextMate.exit_show_tool_tip('Did not find any appropriate item to open in ' \
                              "#{input}") if location.empty?
  open_file(location)
end

# ====================
# = Open Master File =
# ====================

# Open the current master file in TextMate
def open_master_file
  master = masterfile
  if master
    master == ENV['TM_FILEPATH'] ? print('Already in master file') :
                                   `open -a TextMate #{e_sh master}`
  else
    print('No master file was defined.')
  end
end

# ==========================
# = Show Label As Tool Tip =
# ==========================

# Get the text surrounding a certain label.
#
# = Arguments
#
# [label] The label for which we want to get the surrounding text
#
# = Output
#
# This function returns a string containing the text around the given label.
def label_context(label)
  # Try to get as much context as possible
  label_surrounding = [10, 5, 2, 1, 0].each do |characters|
    context = label.context(characters, true)
    return context unless context.nil?
  end
end

# Print the text surrounding a label referenced in the string +input+.
#
# = Arguments
#
# [input] A string that is checked for references
def show_label_as_tooltip(input)
  TextMate.exit_show_tool_tip('Empty input! Please select a (partial) label' \
                              ' reference.') if input.empty?
  labels = LaTeX.labels.find_all { |label| label.label.match(/#{input}/) }
  TextMate.exit_show_tool_tip('No label found matching ' \
                              "“#{input}”") if labels.empty?
  print(label_context(labels[0]))
rescue RuntimeError => e
  TextMate.exit_insert_text(e.message)
end
