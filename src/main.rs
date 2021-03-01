extern crate yaml_rust;

mod cli;
mod error;
mod opts;
mod runners;

fn main() {
    println!("Hello, world!");

    let matches = cli::parse();
    println!("{:?}", matches);
    let opts = opts::Opts::new(matches);
    println!("{:?}", opts);
    let runners = runners::Runners::new(&opts.config_paths);
    println!("{:?}", runners);
}
