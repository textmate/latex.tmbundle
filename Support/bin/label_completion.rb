#!/usr/bin/env ruby18
require ENV["TM_BUNDLE_SUPPORT"] + "/lib/latex.rb"
phrase = ENV['TM_CURRENT_WORD']
include LaTeX
items = LaTeX.labels
items = items.grep(/^#{Regexp.escape(phrase)}/) if phrase != ""
exit if items.empty?
puts items.join("\n")
