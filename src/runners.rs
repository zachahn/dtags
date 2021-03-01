use crate::error;

use std::collections::HashMap;
use std::error::Error;
use std::fs;
use std::process;
use yaml_rust::YamlLoader;

#[derive(Debug)]
pub struct Runners {
    registry: HashMap<String, Vec<String>>,
}

impl Runners {
    pub fn new(config_paths: &Vec<String>) -> Runners {
        let mut instance = Runners {
            registry: HashMap::new(),
        };

        for config_path in config_paths.iter() {
            match extract_runners(config_path, &mut instance.registry) {
                Ok(_) => {}
                Err(_) => {}
            }
        }

        return instance;
    }

    pub fn find_and_run(
        &self,
        name: &String,
    ) -> Result<Result<process::Child, std::io::Error>, Box<dyn Error>> {
        if !self.registry.contains_key(name) {
            return Err(Box::new(error::DtagError {}));
        }

        if self.registry[name].len() < 2 {
            return Err(Box::new(error::DtagError {}));
        }

        let (head, tail) = self.registry[name].split_at(1);
        return Ok(process::Command::new(head[0].as_str())
            .args(&tail[..])
            .spawn());
    }
}

fn extract_runners(
    path: &String,
    registry: &mut HashMap<String, Vec<String>>,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(path)?;
    let docs = YamlLoader::load_from_str(contents.as_str())?;
    let doc = &docs[0];

    let runners = doc["runners"]
        .as_hash()
        .ok_or_else(|| YamlLoader::load_from_str("{}").unwrap())
        .unwrap();

    'outer: for (runner_name, runner_data) in runners {
        if let Some(name) = runner_name.as_str() {
            if let Some(command) = runner_data["command"].as_vec() {
                let mut args: Vec<String> = Vec::new();
                for unparsed_fragment in command {
                    if let Some(fragment) = unparsed_fragment.as_str() {
                        args.push(fragment.to_string());
                    } else {
                        continue 'outer;
                    }
                }
                registry.insert(name.to_string(), args);
            }
        }
    }

    return Ok(());
}
