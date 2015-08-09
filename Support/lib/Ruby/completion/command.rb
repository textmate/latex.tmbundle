# -- Imports -------------------------------------------------------------------

require ENV['TM_SUPPORT_PATH'] + '/lib/exit_codes'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/Ruby/command'

# -- Main ----------------------------------------------------------------------

# Insert a command based on the current word into the document.
def command_completion
  print(menu_choice_exit_if_empty(get_completions))
rescue RuntimeError => e
  TextMate.exit_show_tool_tip(e.message)
end

def recursiveFileSearch(initialList)
  extraPathList = []
  regexp = /\\(?:include|input)\{([^}]*)\}/   # ?: don't capture group
  visitedFilesList = Hash.new
  tempFileList = initialList.clone
  listToReturn = Array.new
  until (tempFileList.empty?)
    filename = tempFileList.shift
    # Have we visited this file already?
    unless visitedFilesList.has_key?(filename) then
      visitedFilesList[filename] = filename
      # First, find file's path.
      filepath = File.dirname(filename) + "/"
      File.open(filename) do |file|
        file.each do |line|
          # search for links
          if line.match(regexp) then
            m = $1
            # Need to deal with the case of multiple words here, separated by comma.
            list = m.split(',')
            list.each do |item|
              item.strip!
              # need to look at all paths in extraPathList for the file
              (extraPathList << filepath).each do |path|
                testFilePath = path + if (item.slice(-4,4) != ".#{fileExt}") then item + ".#{fileExt}" else item end
                if File.exist?(testFilePath) then
                  listToReturn << testFilePath
                  if (fileExt == "tex") then tempFileList << testFilePath end
                  if block_given? then
                    File.open(testFilePath) {|file| yield file}
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return listToReturn
end

def get_completions
  ######################
  # Program start
  ######################
  #
  # Work with the current file; if TM_LATEX_MASTER is set, work with both
  # Thanks to Alan Schussman
  #
  filelist = []
  filelist << ENV["TM_FILEPATH"] if ENV.has_key?("TM_FILEPATH")
  filelist << ENV["TM_LATEX_MASTER"] if ENV.has_key?("TM_LATEX_MASTER")
  # Recursively find all relevant files. Don't forget to include current files
  filelist += recursiveFileSearch(filelist)
  # Get word prefix to expand
  # if !(ENV.has_key?("TM_CURRENT_WORD")) then
  # matchregex = /\\#{ENV["TM_CURRENT_WORD"] || ""}\w+/
  # end
  # Process the filelist looking for all matching commands.
  completionslist = File.open(ENV['TM_BUNDLE_SUPPORT'] + "/config/completions.txt", "r").read.split("\n")

  filelist.uniq.each {|filename|
    File.open("#{filename}") do |theFile|
      completionslist += theFile.read.scan(/\\([\w@]+)/).map{|i| i[0]}.reject{|i| i.length <= 2}
    end
  }
  completionslist = completionslist.grep(/^#{ENV['TM_CURRENT_WORD']}/) unless ENV['TM_CURRENT_WORD'].nil?
  completionslist.uniq.sort
end
