require 'strscan'
require 'pathname'
# The LaTeX module contains a lot of methods useful when dealing with LaTeX
# files.
#
# Authors:: Charilaos Skiadas, René Schwaiger
module LaTeX
  # Parse any %!TEX options in the first 20 lines of the file.
  #
  # We use the first 20 lines for compatibility with TeXShop.
  #
  # = Arguments
  #
  # [filepath] The path of the file that should be parsed.
  #
  # = Output
  #
  # This function returns a hash containing the tex directives contained in the
  # given file.
  #
  # = Examples
  #
  #  doctest: Parse the tex directives in 'xelatex.tex'
  #
  #  >> LaTeX.options('Tests/TeX/xelatex.tex')
  #  => {"TS-program"=>"xelatex"}
  #
  #  doctest: Parse the tex directives in 'packages_input1.tex'
  #
  #  >> LaTeX.options('Tests/TeX/input/packages_input1.tex')
  #  => {"root"=>"./packages_input2.tex"}
  def self.options(filepath)
    opts = {}
    File.foreach(filepath).first(20).each do |line|
      opts[Regexp.last_match[1]] = Regexp.last_match[2] if
        line =~ /^%!TEX (\S*) =\s*(\S.*\S)\s*$/
    end
    opts
  end

  # Returns the root/master file for the given filepath.
  #
  # If no master exists, then this function returns the given filepath. We stop
  # searching after 10 iterations, in case of a loop.
  #
  # = Arguments
  #
  # [filepath] The path of the file for which we want to determine the master
  #
  # = Output
  #
  # The function returns the path of the master file
  #
  # = Examples
  #
  #  doctest: Determine the master document of the file 'packages_input1.tex'
  #
  #  >> LaTeX.master('Tests/TeX/input/packages_input1.tex')
  #  => 'Tests/TeX/packages.tex'
  #
  #  doctest: Determine the master document of the file 'xelatex.tex'
  #
  #  >> LaTeX.master('Tests/TeX/xelatex.tex')
  #  => 'Tests/TeX/xelatex.tex'
  def self.master(filepath)
    return nil if filepath.nil?
    master = Pathname.new(filepath).cleanpath
    10.times do
      opts = options(master)
      return master.to_s unless opts.key?('root')
      new_master = (master.parent + Pathname.new(opts['root'])).cleanpath
      return master.to_s if new_master == master
      master = new_master
    end
  end

  # Implements general methods that give information about the LaTeX document.
  # Most of these commands recurse into \included files.
  class <<self
    # Get an array containing the label names of the current master file.
    #
    # If you want actual Label objects, then use +FileScanner.label_scan+.
    # The path to the master file has to be set via the environment variable
    # +TM_LATEX_MASTER+ or +TM_FILEPATH+.
    #
    # = Output
    #
    # The function returns a sorted list of label names.
    #
    # = Examples
    #
    #  doctest: Get the labels of the file 'references.tex'.
    #
    #  >> ENV['TM_FILEPATH'] = 'Tests/TeX/references.tex'
    #  >> LaTeX.labels
    #  => ["sec:first_section", "sec:included_section",
    #      "sec:second_section", "table:a_table_label"]
    #
    #  doctest: Get the labels of the file 'xelatex.tex'.
    #
    #  >> ENV['TM_LATEX_MASTER'] = 'Tests/TeX/xelatex.tex'
    #  >> LaTeX.labels
    #  => []
    def labels
      master_file = LaTeX.master(ENV['TM_LATEX_MASTER'] || ENV['TM_FILEPATH'])
      FileScanner.label_scan(master_file).map(&:label).sort
    end

    # Return an array of citation objects for the current tex file.
    #
    # If you only want the citekeys, then use +LaTeX.citekeys+.
    #
    # The path to the master file has to be set via the environment variable
    # +TM_LATEX_MASTER+ or +TM_FILEPATH+.
    #
    # = Output
    #
    # The function returns a list of citations hashes.
    #
    #  doctest: Get the citations of the file 'external_bibliography.tex'.
    #
    #  >> ENV.delete 'TM_LATEX_MASTER'
    #  >> ENV['TM_FILEPATH'] = 'Tests/TeX/external_bibliography.tex'
    #  >> citations = LaTeX.citations
    #  >> citations.length
    #  => 1
    #  >> first_cite = citations[0]
    #  >> first_cite['citekey']
    #  => 'Deltron3030'
    #
    #  doctest: Get the citations of the file 'external_bibliography_biber.tex'.
    #
    #  >> ENV['TM_FILEPATH'] = 'Tests/TeX/external_bibliography_biber.tex'
    #  >> citations = LaTeX.citations
    #  >> citations.length
    #  => 1
    #  >> first_cite = citations[0]
    #  >> first_cite['title']
    #  => 'Battlesong'
    #
    #  doctest: Get the citations of the file 'references.tex'.
    #
    #  >> ENV['TM_FILEPATH'] = 'Tests/TeX/references.tex'
    #  >> LaTeX.citations.length
    #  => 5
    def citations
      master_file = LaTeX.master(ENV['TM_LATEX_MASTER'] || ENV['TM_FILEPATH'])
      FileScanner.cite_scan(master_file).sort_by(&:citekey)
    end

    # Returns an array of the citekeys for the current master file.
    #
    # The path to the master file has to be set via the environment variable
    # +TM_LATEX_MASTER+ or +TM_FILEPATH+.
    #
    # = Output
    #
    # The function returns a list of all citekeys.
    #
    #  doctest: Get the citation keys of the file 'references.tex'.
    #
    #  >> ENV['TM_FILEPATH'] = 'Tests/TeX/references.tex'
    #  >> keys = LaTeX.citekeys
    #  >> keys.length
    #  => 5
    #  >> keys.member? 'embedded_bibitem'
    #  => true
    def citekeys
      citations.map(&:citekey).uniq
    end

    # Return the path to the TeX binaries.
    #
    # If the location is part of the environment variable +PATH+, then this
    # function returns the empty string. If +tex_path+ can not find the
    # location of the tex binaries, then it raises an error.
    #
    # = Output
    #
    # The function returns the prefix needed to execute tex programs.
    #
    # doctest: Get the path of the tex binaries.
    #
    #  >> LaTeX.tex_path
    #  => ""
    def tex_path
      # First try directly
      return '' if ENV['PATH'].split(':').find do |dir|
        File.exist? File.join(dir, 'kpsewhich')
      end
      # Then try some specific paths
      ['/usr/texbin/', '/opt/local/bin/'].each do |location|
        return location if File.exist?("#{location}kpsewhich")
      end
      # If all else fails, rely on /etc/profile. For most people, we should
      # never make it here.
      loc = `. /etc/profile; which kpsewhich`
      return loc.gsub(/kpsewhich$/, '') unless loc.match(/^no kpsewhich/)
      fail 'The tex binaries cannot be located!'
    end

    # Get the path for a certain file.
    #
    # = Arguments
    #
    # [filename] The name of the file we want to find
    #
    # [extension] The extension of the file we want to find.
    #
    # [relative] An explicit path that should be included in the
    #            paths to look at when searching for the file. This will
    #            typically be the path to the root document.
    #
    # = Output
    #
    # The function returns the filepath of the specified file or +nil+ if the
    # file could not be found.
    #
    # = Examples
    #
    #  doctest: Get the location of the file 'packages_input1.tex'
    #
    #  >> filepath = LaTeX.find_file('input/packages_input1', 'tex',
    #                                'Tests/TeX/')
    #  >> filepath.end_with?('Tests/TeX/input/packages_input1.tex')
    #  => true
    #
    #  doctest: Get the location of the file 'xelatex.tex'
    #
    #  >> filepath = LaTeX.find_file('xelatex.tex', 'tex', 'Tests/TeX/')
    #  >> filepath.end_with?('Tests/TeX/xelatex.tex')
    #  => true
    #
    #  doctest: Get the location of a file located in 'TEXINPUTS'
    #
    #  >> filepath = LaTeX.find_file('config/pdftexconfig', 'tex', '')
    #  >> filepath.end_with?('config/pdftexconfig.tex')
    #  => true
    def find_file(filename, extension, relative)
      filename.gsub!(/"/, '')
      filename.gsub!(/\.#{extension}$/, '')
      # First try the filename as is, without the extension. Then try with the
      # added extension
      [filename, "#{filename}.#{extension}"].each do |filepath|
        return filepath if file?(filepath)
      end
      # If it is an absolute path, and the above two tests didn't find it,
      # return nil
      return nil if filename.match(/^\//)
      find_file_kpsewhich(filename, extension, relative)
    end

    # Processes a bib file and return an array of citation objects.
    #
    # = Arguments
    #
    # [filepath] The path to the bib file that should be parsed
    #
    # = Output
    #
    # The function returns a list of citation objects.
    #
    # = Examples
    #
    #  doctest: Parse the file 'references.bib'
    #
    #  >> references = LaTeX.parse_bibfile('Tests/TeX/references.bib')
    #  >> references.length
    #  => 1
    #  >> citation = references[0]
    #  >> citation.author
    #  => 'Deltron 3030'
    #  >> citation.title
    #  => 'Battlesong'
    #
    #  doctest: Parse the file 'more_references.bib'
    #
    #  >> references = LaTeX.parse_bibfile('Tests/TeX/more_references.bib')
    #  >> references.length
    #  => 3
    #  >> citation = references[0]
    #  >> citation.author
    #  => 'Robertson, Venetia Laura Delano'
    #  >> citation.citekey
    #  => 'robertson2013ponies'
    #
    #  >> citation = references[2]
    #  >> citation.author
    #  => 'Hada, Erika'
    #  >> citation.title
    #  => 'My Little Pony'
    def parse_bibfile(filepath)
      entries = bib_entries(filepath)
      bib_citations(entries, bib_variables(entries))
    end

    # Parse a bib file and return a list of its entries.
    #
    # = Arguments
    #
    # [filepath] The path to the bib file that should be parsed
    #
    # = Output
    #
    # The function returns a list of entry strings.
    #
    # = Examples
    #
    #  doctest: Get the bib entries of the file 'references.bib'
    #
    #  >> references = LaTeX.bib_entries('Tests/TeX/more_references.bib')
    #  >> references.all? { |entry| !(entry =~ /^@[^{]+\{.*\}\Z/m).nil? }
    #  => true
    #
    #  doctest: Get the bib entries of the 'unformatted.bib'
    #
    #  >> references = LaTeX.bib_entries('Tests/TeX/unformatted.bib')
    #  >> references[1]
    #  => "@article{A, author = {A}}"
    def bib_entries(filepath)
      fail "Could not locate file: #{filepath}" unless file?(filepath)
      entries = File.read(filepath).scan(/^\s*@[^\{]*\{.*?(?=\n[ \t]*@|\z)/m)
      entries.map { |entry| entry.strip.gsub(/(?:^\s*%.*|\n)+$/m, '') }
    end

    # Extract variables from a list of bib entries.
    #
    # A bib entry that contains a variable has the syntax
    #
    #  @string { name = value }
    #
    # For example, the following code defines a variable named +favorite_pony+
    # containing the value +Fluttershy+.
    #
    #  @string { favorite_pony = "Fluttershy" }
    #
    # This function returns all variables saved in the given bib entries as
    # hash. The hash uses variable names as keys and the content of a variable
    # as values.
    #
    # = Arguments
    #
    # [bib_entries] A list of bib entries saved as string.
    #
    # = Output
    #
    # The function returns a hash containing variables and their values.
    #
    # = Examples
    #
    #  doctest: Parse some simple variable definitions
    #
    #  >> entries = ['@string { show = "Gravity Falls" }',
    #                '@string { characters =
    #                          "Dipper, Mabel, Stan, Soos, Wendy, Waddles" }',
    #                '@misc { key, author = {Author}}']
    #  >> variables = LaTeX.bib_variables(entries)
    #  >> variables['show']
    #  => 'Gravity Falls'
    #  >> variables['characters']
    #  => 'Dipper, Mabel, Stan, Soos, Wendy, Waddles'
    #
    #  doctest: Parse the variable definitions in the file 'unformatted.bib'
    #
    #  >> vars = LaTeX.bib_variables(
    #       LaTeX.bib_entries('Tests/TeX/unformatted.bib'))
    #  >> vars['pink_pony']
    #  => 'Pinkie Pie'
    #  >> vars['white_pony']
    #  => 'Deftones'
    def bib_variables(bib_entries)
      variables = bib_entries.select { |entry| entry.start_with? '@string' }
      variables.map! do |entry|
        entry.gsub(/@string\s*{\s*/m, '').gsub(/\s*\}$/m, '')
      end
      vars = {}
      variables.each do |var_value|
        key, value = var_value.split(/\s*=\s*(?:\{|")/)
        vars[key] = value[0..-2] unless value.nil?
      end
      vars
    end

    # Extract citations from a list of bib entries.
    #
    # = Arguments
    #
    # [bib_entries] A list containing bib entries
    # [bib_variables] A hash containing bib variables and their values
    #
    # = Output
    #
    # This function returns a list of citation objects.
    #
    # = Examples
    #
    #  doctest: Parse some simple bib entries
    #
    #  >> entries = ['@misc{key, author = "Author, Mrs.", title = "Title"}',
    #                '@article{Key, TiTLe = "Masters Of War",
    #                               Author = "Dylan, Bob"}']
    #  >> cites = LaTeX.bib_citations(entries, {})
    #  >> cites[0]['author']
    #  => 'Author, Mrs.'
    #  >> cites[1]['author']
    #  => 'Dylan, Bob'
    #  >> cites[1]['title']
    #  => 'Masters Of War'
    #
    #  doctest: Parse bib entries containing comments and variables
    #
    #  >> variables = { 'start' => "Tesla, you don't understand",
    #                   'end' => ' humor.' }
    #  >> entries = ['@COMMENT{ This is a comment}',
    #                '@electronic{tesla, author = "Tesla, Nikola",
    #                             year="1856",
    #                             title= start # " our " # {American} # end }']
    #  >> cites = LaTeX.bib_citations(entries, variables)
    #  >> cites[0]['title']
    #  >> "Tesla, you don't understand our American humor."
    def bib_citations(bib_entries, bib_variables)
      citations = bib_entries.select do |entry|
        (entry =~ /@(?:string|preamble|comment)/i).nil?
      end
      cites = citations.map do |citation|
        bib_citation(citation, bib_variables)
      end
      cites.compact
    end

    # Convert one citation bib entry to a +Citation+.
    #
    # = Arguments
    #
    # [bib_entry] The bib entry, which should be converted to a +Citation+
    # [bib_variables] A dictionary containing all bib variables and their values
    #
    # = Output
    #
    # The function returns a Citation object on success or +nil+ if it failed.
    #
    # = Examples
    #
    #  doctest: Parse a simple bib entry
    #
    #  >> entry = '@article{key,
    #                       author = "Mabel",
    #                       title = "On why pet pigs are " # synonym_nice}'
    #  >> variables = { 'synonym_nice' => 'awesome' }
    #  >> cites = LaTeX.bib_citation(entry, variables)
    #  >> cites['title']
    #  => "On why pet pigs are awesome"
    def bib_citation(bib_entry, bib_variables)
      bibtype, citekey, rest = bibentry_type_key_rest(bib_entry)
      return nil if bibtype.nil?
      cite = Citation.new('bibtype' => bibtype, 'citekey' => citekey)
      keys_and_values = rest[0..-2].split(/(?<="|\})\s*,/)
      keys_and_values.map! { |key_val| key_val.gsub(/^\s*|\s*$/, '') }
      keys_and_values.each do |key_value|
        key, value = bibitem_key_value(key_value, bib_variables)
        cite[key] = value unless key.nil?
      end
      cite
    end

    # Extract the bib type and citekey from a bib entry.
    #
    # = Arguments
    #
    # [bib_entries] A list containing bib entries.
    # [bib_variables] A hash containing bib variables and their values
    #
    # = Output
    #
    # The function returns a list containing the type, citekey and the remaining
    # part of a bib entry.
    #
    # = Examples
    #
    #  doctest: Get the type and key of a simple bib entry
    #
    #  >> entry = '@misc{key, author = "Author, Mrs.", title = "Title"}'
    #  >> LaTeX.bibentry_type_key_rest(entry)
    #  => ['misc', 'key', 'author = "Author, Mrs.", title = "Title"}']
    def bibentry_type_key_rest(bib_entry)
      scanner = StringScanner.new(bib_entry)
      scanner.scan(/\s*@/)
      bibtype = scanner.scan(/[^\s\{]+/)
      scanner.scan(/\s*\{\s*/)
      citekey = scanner.scan(/[^\s,]+(?=\s*,)/)
      scanner.scan(/\s*,\s*/)
      [bibtype, citekey, scanner.rest]
    end

    # Extract the key and value of a single item of a bib entry.
    #
    # = Arguments
    #
    # [bib_item] A string containing a single bib item and its value
    # [bib_variables] A hash containing bib variables and their values
    #
    # = Output
    #
    # The function returns the key and value of the bib item or +nil+ if the
    # key or value could not be extracted.
    #
    # = Examples
    #
    #  doctest: Get the key and value of a simple bib item
    #
    #  >> bib_item = 'editor = "TextMate"'
    #  >> key, value = LaTeX.bibitem_key_value(bib_item, {})
    #  >> key
    #  => 'editor'
    #  >> value
    #  => 'TextMate'
    #
    #  doctest: Get the key and value of a bib item containing a variable
    #
    #  >> bib_item = 'hulk = "Smash" # exclamation'
    #  >> key, value = LaTeX.bibitem_key_value(bib_item,
    #                                          { 'exclamation' => '!' })
    #  >> key
    #  => 'hulk'
    #  >> value
    #  => 'Smash!'
    #
    #  doctest: Get the key and value of a bib item containing a number sign
    #
    #  >> variables = { 'number_sign' => '#' }
    #  >> bib_item = 'item = "# number"# number_sign # {oh a {#} {sign}#}'
    #  >> _, item = LaTeX.bibitem_key_value(bib_item, variables)
    #  >> item
    #  => '# number#oh a {#} {sign}#'
    def bibitem_key_value(bib_item, bib_variables)
      key, value = bib_item.split(/\s*=\s*(?=\{|"|\w)/)
      return nil if value.nil?
      [key.downcase, bib_item_value(value, bib_variables)]
    end

    private

    def bib_item_value(string, bib_variables)
      scanner, value = [StringScanner.new(string), '']
      while first = scanner.getch # rubocop:disable Lint/AssignmentInCondition
        part = if first == '"' then consume_value_quotes(scanner)
               elsif first == '{' then consume_value_brackets(scanner)
               else consume_value_variable(scanner, first, bib_variables)
               end
        scanner.scan(/\s*#\s*/m)
        value += part unless part.nil?
      end
      value
    end

    def consume_value_quotes(scanner)
      scanned = scanner.scan(/(?:[^"]|(?<=\\)")+"/)
      scanned.nil? ? nil : scanned[0..-2]
    end

    def consume_value_brackets(scanner)
      missing_right_brackets, value = [1, '']
      while missing_right_brackets > 0
        scanned = scanner.scan(/(?:[^{}]|(?<=\\)[{}])+/)
        return nil if scanned.nil?
        value += scanned
        bracket = scanner.getch
        missing_right_brackets += (bracket == '{') ? 1 : -1
        value += bracket unless missing_right_brackets <= 0
      end
      value
    end

    def consume_value_variable(scanner, first_char, variables)
      scanned = scanner.scan(/[\w]*/)
      scanned.nil? ? nil : "#{variables[first_char + scanned]}"
    end

    def file?(filepath)
      !filepath.nil? && File.exist?(filepath) && !File.directory?(filepath)
    end

    # rubocop:disable Style/ClassVars
    def find_file_kpsewhich(filename, extension, relative)
      @@paths ||= {}
      @@paths[extension] ||= (
        `#{LaTeX.tex_path}kpsewhich -show-path=#{extension}`.chomp.split(
          /:!!|:/).map { |dir| dir.sub(/\/*$/, '/') }
          ).unshift(relative).unshift('')
      @@paths[extension].each do |path|
        fp = File.expand_path(File.join(path, filename))
        [fp, "#{fp}.#{extension}"].each { |file| return file if file?(file) }
      end
    end
  end

  # A class implementing a recursive scanner.
  # +root+ is the file to start the scanning from.
  # +includes+ is a hash with keys regular expressions and values blocks of
  #   code called when that expression matches. The block is passed the
  #   matched groups in the kind of array returned by String#scan as argument,
  #   and must return the full path to the file to be recursively scanned.
  # +extractors+ is a similar hash, dealing with the bits of text to be
  #   matched. The block is passed as arguments the current filename, the
  #   current line number counting from 0, the matched groups in the kind
  #   of array returned by String#scan and finally the entire file contents.
  class FileScanner
    attr_accessor :root, :includes, :extractors

    # Creates a new scanner object. If the argument +old_scanner+ is a String,
    # then it is set as the +root+ file. Otherwise, it is used to read the
    # values of the three variables.
    def initialize(old_scanner = nil)
      if old_scanner
        if old_scanner.is_a?(String)
          @root = old_scanner
          set_defaults
        else
          @root = old_scanner.root
          @includes = old_scanner.includes
          @extractors = old_scanner.extractors
        end
      else
        set_defaults
      end
    end

    # Default values for the +includes+ hash.
    def set_defaults
      @includes = {}
      # We ignore inputs and includes containing a hash since these are
      # usually used as arguments inside macros e.g. `#1` to access the first
      # argument of a macro
      @includes[/^[^%]*(?:\\include|\\input)\s*\{([^}\\#]*)\}/] = proc do |m|
        m[0].split(',').map do |it|
          LaTeX.find_file(it.strip, 'tex', File.dirname(@root)) || fail(
            "Could not locate any file named '#{it}'")
        end
      end
      @extractors = {}
    end

    # Performs the recursive scanning.
    def recursive_scan
      fail 'No root specified!' if @root.nil?
      fail "Could not find file #{@root}" unless File.exist?(@root)
      text = File.read(@root)
      text.split.each_with_index do |line, index|
        includes.each_pair do |regexp, block|
          line.scan(regexp).each do |m|
            newfiles = block.call(m)
            newfiles.each do |newfile|
              scanner = FileScanner.new(self)
              scanner.root = newfile.to_s
              scanner.recursive_scan
            end
          end
          extractors.each_pair do |extractor_regexp, extractor_block|
            line.scan(extractor_regexp).each do |m|
              extractor_block.call(root, index, m, text)
            end
          end
        end
      end
    end

    # Creates a FileScanner object and uses it to read all the labels from the
    # document. Returns a list of Label objects.
    def self.label_scan(root)
      # LaTeX.set_paths
      label_list = []
      scanner = FileScanner.new(root)
      scanner.extractors[/.*?\[.*label=(.*?)\,.*\]/] =
      proc do |filename, line, groups, text|
        label_list << Label.new(:file => filename, :line => line,
                                :label => groups[0], :contents => text)
      end
      scanner.extractors[/^[^%]*\\label\{([^\}]*)\}/] =
      proc do |filename, line, groups, text|
        label_list << Label.new(:file => filename, :line => line,
                                :label => groups[0], :contents => text)
      end
      scanner.recursive_scan
      label_list
    end

    # Creates a FileScanner object and uses it to read all the citations from
    # the document. Returns a list of Citation objects.
    def self.cite_scan(root)
      citation_list = []
      scanner = FileScanner.new(root)
      bibitem_regexp = /^[^%]*\\bibitem(?:\[[^\]]*\])?\{([^\}]*)\}(.*)/
      # We ignore bibliography files located on Windows drives by not matching
      # any path which starts with a single letter followed by a “:” e.g.: “c:”
      biblio_regexp = /^[^%]*\\bibliography\s*\{(?![a-zA-Z]:)([^\}]*)\}/
      addbib_regexp = /^[^%]*\\addbibresource\s*\{(?![a-zA-Z]:)([^\}]*)\}/
      scanner.extractors[bibitem_regexp] = proc do |_, _, groups, _|
        citation_list << Citation.new('citekey' => groups[0],
                                      'cite_data' => groups[1])
      end
      scanner.extractors[biblio_regexp] = proc do |_, _, groups, _|
        groups[0].split(',').each do |it|
          file = LaTeX.find_file(it.strip, 'bib', File.dirname(root))
          fail "Could not locate any file named '#{it}'" if file.nil?
          citation_list += LaTeX.parse_bibfile(file)
          citation_list += LaTeX.parse_bibfile(ENV['TM_LATEX_BIB']) unless
            ENV['TM_LATEX_BIB'].nil?
        end
      end
      scanner.extractors[addbib_regexp] = proc do |_, _, groups, _|
        groups[0].split(',').each do |it|
          file = LaTeX.find_file(it.strip, 'bib', File.dirname(root))
          fail "Could not locate any file named '#{it}'" if file.nil?
          citation_list += LaTeX.parse_bibfile(file)
          citation_list += LaTeX.parse_bibfile(
            ENV['TM_LATEX_BIB']) unless ENV['TM_LATEX_BIB'].nil?
        end
      end
      scanner.recursive_scan
      citation_list
    end
  end

  class Label
    attr_accessor :file, :line, :label, :contents

    def initialize(hash)
      hash.each { |key, value| send("#{key}=", value) }
    end

    def to_s
      label
    end

    # Returns the text around the label.
    def context(chars = 40, countlines = false)
      if countlines
        return contents.match(
          /(.*\n){#{chars / 2}}.*\\label\{#{label}\}.*\n(.*\n){#{chars / 2}}/)
      else
        return contents.gsub(/\s/, '').match(
          /.{#{chars / 2}}\\label\{#{label}\}.{#{chars / 2}}/)
      end
    end

    def file_line_label
      "#{file}:#{line}:#{label}"
    end
  end

  class Citation
    def initialize(hash = {})
      @hash = {}
      hash.each_pair do |key, value|
        @hash[key.downcase] = value
      end
    end

    def []=(key, value)
      @hash[key.downcase] = value
    end

    def [](key)
      @hash[key.downcase]
    end

    def author
      @hash['author'] || @hash['editor']
    end

    def title
      @hash['title']
    end

    def description
      @hash['cite_data'] || "#{author}, #{title}"
    end

    def citekey
      @hash['citekey']
    end
  end
end
# Example of use:
#
# include LaTeX
# # ar = FileScanner.cite_scan("/Users/haris/svnlocalrepos/repos/master.tex")
# ar = FileScanner.cite_scan("/Users/haris/Desktop/testing/Morten/test2.tex")
# puts ar.length
# ar.each do |citation|
#   puts citation.description
# end
