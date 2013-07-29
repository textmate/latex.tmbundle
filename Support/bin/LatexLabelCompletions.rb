#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby
require ENV["TM_BUNDLE_SUPPORT"] + "/lib/LaTeXUtils.rb"
phrase = ENV['TM_CURRENT_WORD']
include LaTeX
items = LaTeX.get_labels
items = items.grep(/^#{Regexp.escape(phrase)}/) if phrase != ""
exit if items.empty?
puts items.join("\n")