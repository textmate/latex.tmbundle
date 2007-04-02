#!/usr/bin/env ruby -s
$: << ENV['TM_SUPPORT_PATH'] + '/lib'
require 'escape'
def esc(str)
  e_sn(str).gsub(/\}/, '\\}') # escaping inside a placeholder
end

is_math = !ENV['TM_SCOPE'].match(/math/).nil?
style = $style || 'texttt'
# The following line might be problematic if the command is used elsewhere
style = style.sub(/^text/,'math').sub(/^emph$/,'mathit') if is_math
s = STDIN.read
if s.empty? then
  print "\\#{style}{$1}"
elsif s =~ /^\\#{Regexp.escape style}\{(.*)\}$/ then
  print "${1:#{esc $1}}"
else
  print "\\#{style}{#{e_sn s}}"
end