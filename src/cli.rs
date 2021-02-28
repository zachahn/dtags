extern crate getopts;

use std::env;
use std::process;

const CARGO_PKG_VERSION: &'static str = env!("CARGO_PKG_VERSION");

pub fn parse() -> getopts::Matches {
    let args: Vec<String> = env::args().collect();
    let program = args[0].clone();
    let mut opts = getopts::Options::new();

    opts.optflag("", "clear-config-paths", "Clear the default search paths");
    opts.optmulti("", "config", "Prepend config search path", "FILE");
    opts.optmulti(
        "",
        "delegatee",
        "Name of runner to run. Overrides delegatees specified in config file",
        "NAME",
    );
    opts.optopt("o", "out", "Path to the final file", "RESULT");
    opts.optopt("", "workdir", "Path to intermediary tags", "PATH");
    opts.optopt(
        "",
        "timeout",
        "Max duration of a runner before it is stopped",
        "SECONDS",
    );
    opts.optflag(
        "",
        "version",
        format!("Print the following and quit: v{}", CARGO_PKG_VERSION).as_str(),
    );
    opts.optflag("h", "help", "Show this help");

    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(f) => {
            println!("{}", f.to_string());
            process::exit(1);
        }
    };

    if matches.opt_present("help") {
        print_usage(&program, opts);
        process::exit(0);
    }

    if matches.opt_present("version") {
        println!("v{}", CARGO_PKG_VERSION);
        process::exit(0);
    }

    return matches;
}

fn print_usage(program: &str, opts: getopts::Options) {
    let brief = format!("Usage: {} [options]", program);
    print!("{}", opts.usage(&brief));
    println!(
        r#"
Defaults:
    --config=current/path/.git/dtags.yaml
    --config=current/path/dtags.yaml
    --config=~/.config/dtags/dtags.yaml
    --config=~/.dtags.yaml
    --out=current/path/tags
    --working=current/path/.dtags/

Config file:

A runner is an application that can generate tag files. A delegatee
is a runner that's configured to run in a specific project.

Dtags can read from multiple config files. If you're using Dtags
privately without committing the config files, it may be helpful
to keep your shareable runners in a global location.

    ---
    runners:
      ripper-exclude-vendor:
        command:
          - ripper-tags
          - -R
          - --exclude=vendor
          - --tag-file=%{{abspath}}
    delegate:
      - ripper-exclude-vendor
    "#
    )
}
