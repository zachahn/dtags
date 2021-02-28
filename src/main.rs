mod cli;
mod opts;

fn main() {
    println!("Hello, world!");

    let matches = cli::parse();
    println!("{:?}", matches);
    let opts = opts::Opts::new(matches);
    println!("{:?}", opts);
}
