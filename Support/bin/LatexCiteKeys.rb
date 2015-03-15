#!/usr/bin/env ruby18
require ENV["TM_BUNDLE_SUPPORT"] + "/lib/latex.rb"
phrase = STDIN.read.chomp
include LaTeX
items = LaTeX.get_citekeys
items = items.grep(/#{phrase}/) if phrase != ""
exit if items.empty?
puts items.join("\n")
