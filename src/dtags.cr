require "option_parser"
require "yaml"

# TODO: Write documentation for `Dtags`
module Dtags
  VERSION = "0.0.0"

  class Runner
    getter command

    def initialize(@command : Array(String))
    end
  end

  class Main
    def call(environment)
      delegatees = environment.delegatees

      runners = delegatees.compact_map do |delegatee|
        runner = environment.runners[delegatee]?

        if runner.nil?
          puts "Couldn't find a runner named: #{delegatee}"
        end

        runner
      end

      paths_and_exit_codes = run_runners(runners)
      combine(paths_and_exit_codes, Path["tags"].expand)
      # TODO: ensure clean
    end

    private def combine(all_paths_and_exit_codes, output_path)
      paths_and_exit_codes = all_paths_and_exit_codes.select do |input_path, exit_code|
        exit_code == 0
      end

      new_lines = paths_and_exit_codes.flat_map do |input_path, exit_code|
        contents = File.read(input_path)
        contents.lines.reject { |line| line[/^!_TAG_/]? }
      end

      pid = Process.pid
      tmp_path = ".dtags-#{pid}"
      # TODO: http://ctags.sourceforge.net/FORMAT
      File.write(tmp_path, new_lines.join("\n") + "\n")
      File.rename(tmp_path, "tags")
    end

    private def run_runners(runners) : Array(Tuple(Path, Int32))
      channel = Channel(Tuple(Path, Int32)).new
      pid = Process.pid

      runners.each_with_index do |runner, i|
        spawn do
          relpath = ".dtags-#{pid}-#{i}"
          abspath = Path[relpath].expand
          command = runner.command.first
          args = runner.command[1..-1].map do |arg|
            arg % { relpath: relpath, abspath: abspath.to_s }
          end

          status = Process.run(command, args)
          channel.send({abspath, status.exit_code})
        end
      end

      runners.size.times.map { channel.receive }.to_a
    end
  end

  class Environment
    @raw_configs : Array(Tuple(Path, YAML::Any | Nil))

    getter runners
    getter cli_delegatees
    getter config_delegatees

    def initialize(@config_search_paths : Array(Path), @cli_delegatees : Array(String))
      @config_delegatees = [] of String
      @runners = {} of String => Runner
      @raw_configs = gather_raw_configs

      @raw_configs.each do |path, contents|
        next if contents.nil?

        config_delegatees = contents["delegate"]?.try(&.as_a?)
        if config_delegatees
          config_delegatees = config_delegatees.compact_map { |delegatee| delegatee.as_s? }
          @config_delegatees.concat(config_delegatees)
        end

        runners = contents["runners"]?.try(&.as_h?)

        next if runners.nil?

        runners.each do |name, runner|
          name = name.as_s?
          runner_command = runner.try(&.as_h?)

          next if name.nil?
          next if runner.nil?

          runner_command = runner["command"]?.try(&.as_a?)
          next if runner_command.nil?

          runner_command = runner_command.map do |part|
            part.as_s?
          end

          next if runner_command.any? { |part| part.is_a?(Nil) }

          # TODO: Require that command is an array of strings
          # TODO: Warn when there are multiple runners of the same name
          @runners[name] = Runner.new(runner_command.compact)
        end
      end
    end

    def output_paths
      {
        abspath: Path["ctags"].expand,
        relpath: "ctags"
      }
    end

    def delegatees
      if cli_delegatees.empty?
        return config_delegatees
      end

      cli_delegatees
    end

    private def gather_raw_configs
      @config_search_paths.map do |path|
        if !File.file?(path)
          next {path, nil}
        end

        contents = File.open(path) { |file| YAML.parse(file) }

        {path, contents}
      end
    end
  end

  class Cli
    property config_search_paths : Array(Path)
    getter exit_code : Int32
    getter? quit : Bool
    getter? help : Bool

    @parser : OptionParser

    def initialize
      @config_search_paths = [
        Path.new(".git", "dtags.yaml").expand,
        Path.new("dtags.yaml").expand,
        Path.new(ENV.fetch("XDG_CONFIG_HOME", Path.home.join("config", "dtags", "dtags.yaml").to_s)).expand,
        Path.home.join(".dtags.yaml"),
      ]
      @quit = false
      @help = false
      @exit_code = 0
      @delegatees = [] of String
      @parser = initialize_parser
    end

    def parse(argv)
      @parser.parse(argv)

      Environment.new(config_search_paths: @config_search_paths, cli_delegatees: @delegatees)
    end

    private def initialize_parser : OptionParser
      OptionParser.new do |parser|
        parser.banner = "Usage: dtags [options]"
        parser.separator
        parser.separator("Options:")
        parser.on("--clear-config-paths", "Empties the list of search paths") do
          @config_search_paths = [] of Path
        end
        parser.on("--config=FILE", "Prepend config search path") do |path|
          @config_search_paths.unshift(Path.new(path).expand)
        end
        parser.on("--delegatee=DELEGATEE", "Specify delegatee. Overrides delegatees specified in config file") do |delegatee|
          @delegatees.push(delegatee)
        end
        parser.on("--version", "Prints the following: v#{Dtags::VERSION}") do
          puts("v#{Dtags::VERSION}")
          exit
        end
        parser.on("-h", "--help", "Show this help") do
          puts(parser)
          exit
        end
        parser.invalid_option do |flag|
          STDOUT.puts("ERROR: #{flag} is not a valid option.")
          exit(1)
        end
      end
    end
  end
end

cli = Dtags::Cli.new
environment = cli.parse(ARGV.dup)

Dtags::Main.new.call(environment)

# pp! environment
