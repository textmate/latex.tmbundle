#!/usr/bin/ruby

# -- Imports -------------------------------------------------------------------

require ENV['TM_BUNDLE_SUPPORT'] + '/lib/latex.rb'

# -- Main ----------------------------------------------------------------------

puts(LaTeX.label_names.join("\n"))
