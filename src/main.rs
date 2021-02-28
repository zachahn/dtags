mod cli;

fn main() {
    println!("Hello, world!");

    let matches = cli::parse();
    println!("{:?}", matches);
}
