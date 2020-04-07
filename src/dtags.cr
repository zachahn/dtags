require "option_parser"

# TODO: Write documentation for `Dtags`
module Dtags
  VERSION = "0.0.0"

  class Config
    property config_search_paths : Array(Path)
    getter exit_code
    getter? quit
    getter? help

    def initialize
      @config_search_paths = [
        Path.new(".git", "dtags.yaml").expand,
        Path.home.join(".dtags.yaml"),
      ]
      @quit = false
      @help = false
      @exit_code = 0
    end

    def help!
      @help = true
    end

    def quit!
      @quit = true
    end

    def quit!(@exit_code : Int32)
      @quit = true
    end
  end
end

config = Dtags::Config.new

parser = OptionParser.parse do |parser|
  parser.banner = "Usage: dtags [options] [files]"
  parser.separator
  parser.separator("Options:")
  parser.on("--clear-config-paths", "Empties the list of search paths") do
    config.config_search_paths = [] of Path
    puts config.config_search_paths
  end
  parser.on("--config=FILE", "Prepend config search path") do |path|
    path = Path.new(path).expand
    config.config_search_paths.unshift(path)
  end
  parser.on("--version", "Prints the following: v#{Dtags::VERSION}") do
    puts "v#{Dtags::VERSION}"
    config.quit!
  end
  parser.on("-h", "--help", "Show this help") do
    config.help!
    config.quit!
  end
  parser.invalid_option do |flag|
    STDERR.puts("ERROR: #{flag} is not a valid option.")
    config.help!
    config.quit!(1)
  end
end

if config.help?
  output =
    if config.exit_code == 0
      STDOUT
    else
      STDERR
    end

  output.puts(parser)
  output.puts
  output.puts("Config paths:")
  config.config_search_paths.each do |path|
    output.puts("    #{path}")
  end
end

if config.quit?
  exit(config.exit_code)
end
