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
  items = LaTeX.citations.map do |cite|
    cite.citekey + (cite.description.empty? ? '' : " — #{cite.description}")
  end
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

# ======================================
# = Insert Label Based On Current Word =
# ======================================

# Insert a label into a document based on the given input.
#
# = Arguments
#
# [input] A string used to filter the possible labels for the current document
def insert_label(input)
  menu_items, replace_input = filter_items_replace_input(LaTeX.labels, input)
  selection = menu_choice_exit_if_empty(menu_items)
  # rubocop:disable Lint/UselessAssignment
  output_selection(selection, input, replace_input, scope = 'label')
rescue RuntimeError => e
  TextMate.exit_show_tool_tip(e.message)
end
