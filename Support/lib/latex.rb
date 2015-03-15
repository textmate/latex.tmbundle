require 'strscan'
require 'pathname'
# The LaTeX module contains a lot of methods useful when dealing with LaTeX
# files.
#
# Authors:: Charilaos Skiadas, René Schwaiger
# Date::    2014-09-28
module LaTeX
  # Simple conversion of bib field names to a simpler form
  def e_var(name)
    name.gsub(/[^a-zA-Z0-9\-_]/, '').gsub(/\-/, '_')
  end

  # parse any %!TEX options in the first 20 lines of the file
  # Only use the first 20 lines for compatibility with TeXShop
  # returns a hash of the results
  def self.options(filepath)
    opts = {}
    File.foreach(filepath).first(20).each do |line|
      opts[Regexp.last_match[1]] = Regexp.last_match[2] if
        line =~ /^%!TEX (\S*) =\s*(\S.*\S)\s*$/
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
    while opts.key?('root') && iter < 10
      new_master = (master.parent + Pathname.new(opts['root'])).cleanpath
      break if new_master == master
      master = new_master
      opts = options(master)
      iter += 1
    end
    master.to_s
  end

  # Implements general methods that give information about the LaTeX document.
  # Most of these commands recurse into \included files.
  class <<self
    # Returns an array of the label names. If you want actual Label objects,
    # then use FileScanner.label_scan
    def get_labels
      master_file = LaTeX.master(ENV['TM_LATEX_MASTER'] || ENV['TM_FILEPATH'])
      FileScanner.label_scan(master_file).map(&:label).sort
    end

    # Returns an array of the citation objects. If you only want the citekeys,
    # use LaTeX.get_citekeys
    def get_citations
      master_file = LaTeX.master(ENV['TM_LATEX_MASTER'] || ENV['TM_FILEPATH'])
      FileScanner.cite_scan(
        master_file).map { |i| i }.sort { |a, b| a.citekey <=> b.citekey }
    end

    # Returns an array of the citekeys in the document.
    def get_citekeys
      get_citations.map { |i| i['citekey'] }.uniq
    end

    # Returns the path to the TeX binaries, or raises an exception if it can't
    # find them.
    def tex_path
      # First try directly
      return '' if ENV['PATH'].split(':').find do |dir|
        File.exist? File.join(dir, 'kpsewhich')
      end
      # Then try some specific paths
      locs = ['/usr/texbin/', '/opt/local/bin/']
      locs.each do |loc|
        return loc if File.exist?(loc + 'kpsewhich')
      end
      # If all else fails, rely on /etc/profile. For most people, we should
      # never make it here.
      loc = `. /etc/profile; which kpsewhich`
      return loc.gsub(/kpsewhich$/, '') unless loc.match(/^no kpsewhich/)
      fail 'The tex binaries cannot be located!'
    end

    # Uses kpsewhich to locate the file with name +filename+ and +extension+.
    # +relative+ determines an explicit path that should be included in the
    # paths to look at when searching for the file. This will typically be the
    # path to the root document.
    # TODO: The following method should probably be simplified dramatically
    # rubocop:disable Style/ClassVars
    def find_file(filename, extension, relative)
      filename.gsub!(/"/, '')
      filename.gsub!(/\.#{extension}$/, '')
      # First try the filename as is, without the extension
      return filename if File.exist?(filename) && !File.directory?(filename)
      # Then try with the added extension
      return "#{filename}.#{extension}" if
        File.exist?("#{filename}.#{extension}")
      # If it is an absolute path, and the above two tests didn't find it,
      # return nil
      return nil if filename.match(/^\//)
      texpath = LaTeX.tex_path
      @@paths ||= {}
      @@paths[extension] ||= (
        [`#{texpath}kpsewhich -show-path=#{extension}`.chomp.split(
          /:!!|:/)].flatten.map { |i| i.sub(/\/*$/, '/') }
          ).unshift(relative).unshift('')
      @@paths[extension].each do |path|
        testpath = File.expand_path(File.join(path, filename + '.' + extension))
        return testpath if File.exist?(testpath) && !File.directory?(testpath)
        testpath = File.expand_path(File.join(path, filename))
        return testpath if File.exist?(testpath) && !File.directory?(testpath)
      end
      nil
    end

    # Processes the .bib file with title +file+, and returns an array of the
    # Citation objects.
    def parse_bibfile(file)
      fail "Could not locate file: #{file}" if file.nil? || !File.exist?(file)
      entries = File.read(file).scan(/^\s*@[^\{]*\{.*?(?=\n[ \t]*@|\z)/m)
      citations = entries.map do |text|
        c = Citation.new
        s = StringScanner.new(text)
        s.scan(/\s+@/)
        c['bibtype'] = s.scan(/[^\s\{]+/)
        s.scan(/\s*\{\s*/)
        c['citekey'] = s.scan(/[^\s,]+(?=\s*,)/)
        if c['citekey'].nil?
          c = nil
          next
        end
        # puts "Found citekey: #{c["citekey"]}"
        s.scan(/\s*,/)
        until s.eos? || s.scan(/\s*\,?\s*\}/)
          s.scan(/\s+/)
          key = s.scan(/[\w\-\.]+/)
          unless s.scan(/\s*=\s*/)
            s.scan(/[^@]*/m)
            c = nil
            next
          end
          # puts "Found key: #{key}"
          contents = ''
          nest_level = 0
          until nest_level <= 0 && s.check(/[\},]/)
            contents << (s.scan(/[^\{\}#{nest_level == 0 ? "," : ""}]+/) || '')
            if s.scan(/\{/)
              contents << "\{" unless nest_level == 0
              nest_level += 1
            elsif s.check(/\}/)
              nest_level -= 1
              contents << "\}" unless nest_level <= 0
              s.scan(/\}/) unless nest_level == -1
            end
          end
          c[key] = contents
          # puts "Found contents: #{contents}"
          fail 'Unexpected end of bib entry' unless s.scan(/\s*(\,|\})\s*/)
        end
        c
      end
      citations.compact
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
      text.each_with_index do |line, index|
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
      scanner.extractors[/.*?\[.*label=(.*?)\,.*\]/] = proc do |filename, line,
                                                                groups, text|
        label_list << Label.new(:file => filename, :line => line,
                                :label => groups[0], :contents => text)
      end
      scanner.extractors[/^[^%]*\\label\{([^\}]*)\}/] = proc do |filename,
                                                                 line, groups,
                                                                 text|
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
