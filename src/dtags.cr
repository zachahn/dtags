require "random"
require "log"
require "option_parser"
require "yaml"

# TODO: Write documentation for `Dtags`
module Dtags
  VERSION = "0.0.0"
  Log = ::Log.for("Dtags", ::Log::Severity::Debug)
  Log.backend = ::Log::IOBackend.new
  Rand = Random.new

  alias ArgInterpolation = NamedTuple(abspath: String)

  class Runner
    @identifier : String?

    def initialize(@command : Array(String))
      Log.trace { "#{identifier} Initialized command from config: #{@command}" }
    end

    def call(
      channel : Channel(Tuple(String, Tuple(Path, Int32))),
      name : String,
      abspath : Path,
      args_interpolation : ArgInterpolation
    ) : Nil
      cmd = @command.first
      args = @command[1..-1].map do |arg|
        arg % args_interpolation
      end

      Log.trace { "#{identifier} Args: #{args_interpolation}" }

      status = Process.run(cmd, args)
      channel.send({name, {abspath, status.exit_code}})
      Log.trace { "#{identifier} Completed successfully" }
    rescue
      channel.send({name, {abspath, -1}})
      Log.trace { "#{identifier} Failed" }
    end

    private def identifier : String
      @identifier ||= Rand.hex(8)
    end
  end

  class Main
    def call(environment : Environment) : Nil
      pid = Process.pid
      prefix_path = "#{environment.working_path}-#{pid}"
      Log.trace { "Starting! pid: #{pid}, prefix: #{prefix_path}" }

      paths_and_exit_codes =
        Log.with_context do
          Log.context.set(step: "running runners")
          run_runners(environment.delegatees, environment.runners, prefix_path)
        end
      Log.with_context do
        Log.context.set(step: "combining results")
        combine(paths_and_exit_codes, environment.result_path, prefix_path)
      end
      Log.with_context do
        Log.context.set(step: "cleaning")
        clean(paths_and_exit_codes)
      end
    end

    private def clean(paths_and_exit_codes) : Nil
      paths_and_exit_codes.each do |path, _exit_code|
        Log.trace { "Attempting to delete file: #{path}" }
        if File.exists?(path)
          Log.trace { "File exists, deleting: #{path}" }
          File.delete(path)
        end
      end
    end

    private def combine(all_paths_and_exit_codes, output_path, tmp_path) : Nil
      paths_and_exit_codes = all_paths_and_exit_codes.select do |input_path, exit_code|
        if exit_code != 0
          Log.trace { "Runner returned error code #{exit_code} - ignoring #{input_path}" }
          next false
        end

        true
      end

      new_lines = paths_and_exit_codes.flat_map do |input_path, _exit_code|
        next [] of String if !File.exists?(input_path)

        contents = File.read(input_path)
        contents.lines.reject { |line| line[/^!_TAG_/]? }
      end

      # TODO: Ensure _TAG_FILE_FORMAT is consistent from all delegated outputs
      headers = [
        %(!_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append \";\" to lines/),
        %(!_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/),
        %(!_TAG_PROGRAM_AUTHOR	Zach Ahn	//),
        %(!_TAG_PROGRAM_NAME	dtags	/Delegate Ctags/),
        %(!_TAG_PROGRAM_URL	https://github.com/zachahn/dtags/	//),
        %(!_TAG_PROGRAM_VERSION	#{Dtags::VERSION}	//),
      ]

      Log.trace { "Writing merged output to: #{tmp_path}" }
      File.write(tmp_path, (headers + new_lines.sort).join("\n") + "\n")
      Log.trace { "Renaming merged output to: #{output_path}" }
      File.rename(tmp_path, output_path.to_s)
    end

    private def run_runners(delegatees, runners, prefix) : Array(Tuple(Path, Int32))
      channel = Channel(Tuple(String, Tuple(Path, Int32))).new

      existing_delegatees = delegatees.compact_map do |delegatee|
        next delegatee if runners.has_key?(delegatee)

        Log.error { "Couldn't find a runner named: #{delegatee}" }

        nil
      end

      existing_delegatees = existing_delegatees.uniq

      Log.trace { "Delegatees: #{existing_delegatees}" }

      existing_delegatees.each_with_index do |delegatee, i|
        runner = runners[delegatee]

        spawn do
          relpath = "#{prefix}-#{i}"
          abspath = Path[relpath].expand
          args_interpolation = { abspath: abspath.to_s }

          runner.call(channel, delegatee, abspath, args_interpolation)
        end
      end

      results = existing_delegatees.size.times.map { channel.receive.last }.to_a

      Log.trace { "#{results}" }

      results
    end
  end

  abstract class Environment
    abstract def runners : Hash(String, Runner)
    abstract def delegatees : Array(String)
    abstract def working_path : Path
    abstract def result_path : Path

    class FromFile < Environment
      @raw_configs : Array(Tuple(Path, YAML::Any | Nil))

      getter runners : Hash(String, Runner)
      getter working_path : Path
      getter result_path : Path

      def initialize(
        @config_search_paths : Array(Path),
        @cli_delegatees : Array(String),
        @working_path : Path,
        @result_path : Path
      )
        @config_delegatees = [] of String
        @runners = {} of String => Runner
        @raw_configs = gather_raw_configs

        @raw_configs.each do |_path, contents|
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

            next if name.nil?
            next if runner.nil?

            runner_command = runner["command"]?.try(&.as_a?)
            next if runner_command.nil?

            runner_command = runner_command.map do |part|
              part.as_s?
            end

            next if runner_command.any? { |part| part.is_a?(Nil) }

            if @runners.has_key?(name)
              puts "Runner already defined. Overriding: #{name}"
            end

            @runners[name] = Runner.new(runner_command.compact)
          end
        end
      end

      def delegatees : Array(String)
        if @cli_delegatees.empty?
          return @config_delegatees
        end

        @cli_delegatees
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
  end

  class Cli
    @config_search_paths : Array(Path)
    @parser : OptionParser
    @result_path : Path
    @working_path : Path
    @verbosity : Int32

    def initialize
      @config_search_paths = [
        Path.new(".git", "dtags.yaml").expand,
        Path.new("dtags.yaml").expand,
        Path.new(ENV.fetch("XDG_CONFIG_HOME", Path.home.join(".config", "dtags", "dtags.yaml").to_s)).expand,
        Path.home.join(".dtags.yaml"),
      ]
      @delegatees = [] of String
      @result_path = Path["."].expand.join("tags").normalize
      @working_path = Path["."].expand.join(".dtags").normalize
      @verbosity = ::Log::Severity::Error.value.to_i
      @parser = initialize_parser
    end

    def parse(argv)
      @parser.parse(argv)
      severities = ::Log::Severity.values.map { |severity| severity.value }.sort
      @verbosity = @verbosity.clamp(severities.first, severities.last)
      Log.level = ::Log::Severity.from_value(@verbosity)

      Environment::FromFile.new(
        config_search_paths: @config_search_paths,
        cli_delegatees: @delegatees,
        working_path: @working_path,
        result_path: @result_path
      )
    end

    private def initialize_parser : OptionParser
      OptionParser.new do |parser|
        parser.banner = "Usage: dtags [options]"
        parser.separator
        parser.separator("Options:")
        parser.on("--clear-config-paths", "Empties the list of search paths. Should be called before `--config`") do
          @config_search_paths = [] of Path
        end
        parser.on("--config=FILE", "Prepend config search path") do |path|
          @config_search_paths.unshift(Path.new(path).expand)
        end
        parser.on("--delegatee=DELEGATEE", "Name of runner to run. Overrides delegatees specified in config file") do |delegatee|
          @delegatees.push(delegatee)
        end
        parser.on("-o RESULT", "--out=RESULT", "Path to the final file") do |path|
          @result_path = Path[path].expand.normalize
        end
        parser.on("--working=PREFIX", "Path to intermediary tags") do |working_path|
          @working_path = Path[working_path].expand.normalize
        end
        parser.on("--version", "Print the following and quit: v#{Dtags::VERSION}") do
          puts("v#{Dtags::VERSION}")
          exit
        end
        parser.on("-v", "--verbose", "Increase verbosity") do
          @verbosity -= 1
        end
        parser.on("-h", "--help", "Show this help") do
          puts(parser)
          exit
        end
        parser.separator
        parser.separator(<<-MORE)
        Defaults: (compensating for the current working directory)
        #{@config_search_paths.map { |path| "    --config=#{path}" }.join("\n")}
            --out=#{@result_path}
            --working=#{@working_path}

        Config file:

        The config file keeps track of runners (the commands that can be run
        to generate tag files) and delegatees (the list of project-specific
        runners).

        Dtags reads from multiple configuration files at once and merges them.
        It'll usually make sense to keep reusable runners separate from the
        delegatees.

            ---
            runners:
              ripper-exclude-vendor:
                command:
                  - ripper-tags
                  - -R
                  - --exclude=vendor
                  - --tag-file=%{abspath}
            delegate:
              - ripper-exclude-vendor
        MORE

        parser.invalid_option do |flag|
          STDOUT.puts("ERROR: #{flag} is not a valid option.")
          STDOUT.puts(parser)
          exit(1)
        end
      end
    end
  end
end

cli = Dtags::Cli.new
environment = cli.parse(ARGV.dup)

Dtags::Main.new.call(environment)
