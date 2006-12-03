#!/usr/bin/env ruby

# Basically a copy of options.sh
# I'd like to replace options.sh with this, but I'd be doing just as much
# work in options.sh to parse the output of this script as I'm already doing

module LaTeX
  # parse any %!TEX options in the first 20 lines of the file
  # Only use the first 20 lines for compatibility with TeXShop
  # returns a hash of the results
  def self.options(filepath)
    opts = {}
    begin
      File.open(filepath, "r") do |file|
        1.upto(20) do
          line = file.readline
          if line =~ /^%!TEX (?>(.*?) )= (.*?) *$/
            opts[$1] = $2
          end
        end
      end
    rescue EOFError, Errno::ENOENT
      # Don't do anything
    end
    opts
  end
end