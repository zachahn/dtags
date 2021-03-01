extern crate yaml_rust;

mod cli;
mod config_files;
mod error;
mod opts;

fn main() {
    println!("Hello, world!");

    let matches = cli::parse();
    println!("{:?}", matches);
    let opts = opts::Opts::new(matches);
    println!("{:?}", opts);
    let config_files = config_files::ConfigFiles::new(&opts.config_paths);
    println!("{:?}", config_files);
}
