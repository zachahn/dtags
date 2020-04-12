# Dtags

**D**elegate C**tags**


## Description

Dtags delegates tag generation to language specific tools, then it merges all
the results into one tag file.

For example, on a project that uses both Haskell and Ruby, dtags could delegate
tag generation to `hasktags` and `ripper-tags`, then generate a single merged
`tags` file.

Although ctags is very convenient, I've personally found that language specific
tag generators are more accurate than ctags' parsers.

Dtags can delegate to ctags.


## Installation

```sh
git clone https://github.com/zachahn/dtags
crystal build --release src/dtags.cr
mv dtags ~/.bin # for example
```


## Usage

```
Usage: dtags [options]

Options:
    --clear-config-paths             Empties the list of search paths. Should be called before `--config`
    --config=FILE                    Prepend config search path
    --delegatee=DELEGATEE            Name of runner to run. Overrides delegatees specified in config file
    -o RESULT, --out=RESULT          Path to the final file
    --working=PREFIX                 Path to intermediary tags
    --version                        Print the following and quit: v0.0.0
    -h, --help                       Show this help

Defaults: (compensating for the current working directory)
    --config=current/working/dir/.git/dtags.yaml
    --config=current/working/dir/dtags.yaml
    --config=~/.config/dtags/dtags.yaml
    --config=~/.dtags.yaml
    --out=current/working/dir/tags
    --working=current/working/dir/.dtags

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
```


## License

Open source. MIT license. See [LICENSE](LICENSE).
