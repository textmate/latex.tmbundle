#!/usr/bin/ruby

# -- Imports -------------------------------------------------------------------

require 'fileutils'
require 'optparse'
require 'pathname'
require 'yaml'

require ENV['TM_BUNDLE_SUPPORT'] + '/lib/Ruby/lib/unf'

# -- Classes -------------------------------------------------------------------

# This class implements a very basic option parser.
class ArgumentParser
  DESCRIPTION = %(
      clean — Remove auxiliary files created by various TeX commands

  Synopsis

      clean [-h|--help] [LOCATION]

  Description

    If LOCATION is a directory then this tool removes auxiliary files
    contained in the top level of the directory.

    If LOCATION is a file, then it removes all auxiliary files matching the
    supplied file name.

    If LOCATION is not specified, then clean removes auxiliary files in
    the current directory.
  ).freeze

  # This method parses all command line arguments.
  #
  # The function returns a string containing the path of an existing file if
  #
  #   - +arguments+ is empty or
  #   - +arguments+ contains only a single element that represents a valid path.
  #
  # If +arguments+ contains a path that does not exist, then the function
  # aborts program execution. The function also stops program execution if the
  # user asks the program to print a help message via a switch such as +-h+. In
  # this case the function prints a help message before it exits.
  #
  # = Arguments
  #
  # [arguments] This is a list of strings containing command line arguments.
  #
  # = Output
  #
  # This function returns a string containing a file location.
  #
  # = Examples
  #
  # doctest: Parse command line arguments containing an existing directory
  #
  #   >> ArgumentParser.parse ['Support']
  #   => 'Support'
  #
  # doctest: Parse command line arguments containing an existing file
  #
  #   >> ArgumentParser.parse ['Tests/TeX/packages.tex']
  #   => 'Tests/TeX/packages.tex'
  #
  # doctest: Parse empty command line arguments
  #
  #   >> ArgumentParser.parse([]) == Dir.pwd
  #   => true
  def self.parse(arguments)
    location = parse_options(arguments).join ''
    return Dir.pwd if location.empty?
    return location if File.exist? location

    $stderr.puts "#{location}: No such file or directory"
    exit
  end

  class << self
    private

    def parse_options(arguments)
      option_parser = OptionParser.new do |opts|
        opts.banner = DESCRIPTION
        opts.separator "  Arguments\n\n"
        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          exit
        end
      end
      option_parser.parse! arguments
    end
  end
end

# This class saves information about auxiliary TeX files.
class Auxiliary
  CONFIG_FILE = "#{ENV['TM_BUNDLE_SUPPORT']}/config/auxiliary.yaml".freeze
  CONFIGURATION = YAML.load_file CONFIG_FILE

  # This method returns a list of directory prefixes.
  #
  # = Output
  #
  # This function returns a list of strings. Each string specifies a prefix of
  # a directory that contains auxiliary TeX files.
  #
  # = Examples
  #
  # doctest: Read the list of auxiliary directory prefixes
  #
  #   >> Auxiliary.directory_prefixes
  #   => ['pythontex-files-', '_minted-']
  def self.directory_prefixes
    CONFIGURATION['directories']
  end

  # This method returns a list of auxiliary TeX file extensions.
  #
  # = Output
  #
  # The function returns a list of strings. Each string specifies the extension
  # of an auxiliary TeX file.
  #
  # = Examples
  #
  # doctest: Read the list of auxiliary file extensions
  #
  #   >> extensions = Auxiliary.file_extensions
  #   >> %w(aux ilg synctex.gz).each { |ext| extensions.member? ext }.all?
  #   => true
  def self.file_extensions
    CONFIGURATION['files']
  end
end

# We extend the directory class to support the removal of auxiliary TeX files.
class Dir
  # This function removes auxiliary files from the current directory.
  #
  # = Output
  #
  # The function returns a list of strings. Each string specifies the location
  # of a file this function successfully deleted.
  #
  # = Examples
  #
  # doctest: Remove auxiliary files from a directory
  #
  #   >> require 'tmpdir'
  #   >> test_directory = Dir.mktmpdir
  #
  #   >> aux_files = ['Fjørt.aux', 'Fjørt.toc', 'Wide Open Spaces.synctex.gz',
  #                   '😱.glo']
  #   >> non_aux_files = ['Fjørt.tex', 'Wide Open Spaces', '🙈🙉🙊.txt']
  #   >> all_files = aux_files + non_aux_files
  #   >> all_files.each do |filename|
  #        File.new(File.join(test_directory, filename), 'w').close
  #        end
  #
  #   >> filename = 'Hau Ab Die Schildkröte'
  #   >> aux_directories = ["_minted-#{filename.gsub ' ', '_'}",
  #                         "pythontex-files-#{filename.gsub ' ', '-'}"]
  #   >> non_aux_directories = ['Do Not Delete Me']
  #   >> all_directories = aux_directories + non_aux_directories
  #   >> all_directories.each do |filename|
  #        Dir.mkdir(File.join test_directory, filename)
  #        end
  #
  #   >> deleted = Dir.new(test_directory).delete_aux
  #   >> deleted.map { |path| File.basename path } ==
  #      (aux_files + aux_directories).sort
  #   => true
  def delete_aux
    files_to_remove = aux_files.map { |filename| File.join(self, filename) }
    dirs_to_remove = aux_directories.map { |dir| File.join(self, dir) }
    (FileUtils.rm(files_to_remove, :force => true) +
     FileUtils.rm_rf(dirs_to_remove)).sort
  end

  private

  def aux_files
    entries.map(&:to_nfc).select do |filename|
      filename[/.+\.(?:#{Auxiliary.file_extensions.join '|'})$/] &&
        File.file?(File.join(self, filename))
    end
  end

  def aux_directories
    entries.map(&:to_nfc).select do |filename|
      filename[/^(?:#{Auxiliary.directory_prefixes.join '|'}).+/] &&
        File.directory?(File.join(self, filename))
    end
  end
end

# +TeXFile+ provides an API to remove auxiliary files produced for a specific
# TeX file.
class TeXFile
  def initialize(path)
    @path = Pathname.new path.to_nfc
  end

  # This function removes auxiliary files for a certain TeX file.
  #
  # = Output
  #
  # The function returns a list of strings. Each string specifies the location
  # of a file this function successfully deleted.
  #
  # doctest: Remove auxiliary files for a certain TeX file
  #
  #   >> require 'tmpdir'
  #   >> test_directory = Dir.mktmpdir
  #
  #   >> aux_files = ['Fjørt.aux', 'Fjørt.toc', 'Wide Open Spaces.synctex.gz',
  #                   '😘.glo']
  #   >> non_aux_files = ['Fjørt.tex', 'D.E.A.D. R.A.M.O.N.E.S.']
  #   >> all_files = aux_files + non_aux_files
  #   >> all_files.each do |filename|
  #        File.new(File.join(test_directory, filename), 'w').close
  #        end
  #
  #   >> filename = 'Hau Ab Die Schildkröte'
  #   >> aux_directories = ["_minted-#{filename.gsub ' ', '_'}",
  #                         "pythontex-files-#{filename.gsub ' ', '-'}",
  #                         '_minted-👻']
  #   >> non_aux_directories = ['Außer Dir']
  #   >> all_directories = aux_directories + non_aux_directories
  #   >> all_directories.each do |filename|
  #       Dir.mkdir(File.join test_directory, filename)
  #       end
  #
  #   >> tex_file = TeXFile.new(File.join test_directory, filename)
  #   >> tex_file.delete_aux.map { |path| File.basename path } ==
  #      aux_directories.select { |dir| dir.end_with? 'Schildkröte' }
  #   => true
  #
  #   >> tex_file = TeXFile.new(File.join test_directory, 'Fjørt')
  #   >> tex_file.delete_aux.map { |path| File.basename path } ==
  #      aux_files.select { |file| file.start_with? 'Fjørt' }
  def delete_aux
    (FileUtils.rm(aux_files, :force => true) +
     FileUtils.rm_rf(aux_directories)).sort
  end

  private

  def aux_files
    aux_pattern = "#{File.basename(@path).sub(/\.tex$/, '')}" \
                  "\.(?:#{Auxiliary.file_extensions.join '|'})$"
    @path.parent.children.map { |path| path.to_s.to_nfc }.select do |filepath|
      filepath[/#{aux_pattern}/] && File.file?(filepath)
    end
  end

  def aux_directories
    aux_pattern = "(?:#{Auxiliary.directory_prefixes.join '|'})" \
                  "#{File.basename(@path).sub(/\.tex$/, '').gsub(' ', '[_-]')}$"
    @path.parent.children.map { |path| path.to_s.to_nfc }.select do |filepath|
      filepath[/#{aux_pattern}/] && File.directory?(filepath)
    end
  end
end

# -- Main ----------------------------------------------------------------------

if __FILE__ == $PROGRAM_NAME
  location = ArgumentParser.parse(ARGV)
  tex_location = if File.directory?(location) then Dir.new(location)
                 else TeXFile.new(location)
                 end
  tex_location.delete_aux.map { |path| puts(File.basename(path)) }
end
