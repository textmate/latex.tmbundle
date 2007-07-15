#!/usr/bin/env ruby

# Basically a copy of options.sh
# I'd like to replace options.sh with this, but I'd be doing just as much
# work in options.sh to parse the output of this script as I'm already doing

require 'pathname'

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
          if line =~ /^%!TEX (\S*) =\s*(.*)\s*$/
            opts[$1] = $2
          end
        end
      end
    rescue EOFError
      # Don't do anything
    end
    opts
  end
  
  # Returns the root file for the given filepath
  # If no master exists, return the given filepath
  # Stop searching after 10 iterations, in case of loop
  def self.master(filepath)
    return nil if filepath.nil?
    master = Pathname.new(filepath).cleanpath
    opts = options(master)
    iter = 0
    while opts.has_key?('root') and iter < 10
      new_master = (master.parent + Pathname.new(opts['root'])).cleanpath
      break if new_master == master
      master = new_master
      opts = options(master)
      iter += 1
    end
    master.to_s
  end
end
