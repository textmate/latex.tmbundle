#!/usr/bin/env ruby -s
$: << ENV['TM_SUPPORT_PATH'] + '/lib'
require 'escape'
def esc(str)
  e_sn(str).gsub(/\}/, '\\}') # escaping inside a placeholder
end

style = $style || 'texttt'

s = STDIN.read
if s.empty? then
  print "\\#{style}{$1}"
elsif s =~ /^\\#{Regexp.escape style}\{(.*)\}$/ then
  print "${1:#{esc $1}}"
elsif ENV.has_key? 'TM_SELECTED_TEXT'
  print "${1:\\#{style}{#{esc s}\\}}"
else
  print "\\#{style}{#{e_sn s}}"
end