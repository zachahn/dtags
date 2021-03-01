use std::fmt;

use std::error::Error;

#[derive(Debug, Clone)]
pub struct DtagError {}

impl fmt::Display for DtagError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "something bad happened")
    }
}

impl Error for DtagError {}
