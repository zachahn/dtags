use crate::error;

use std::collections::HashMap;
use std::error::Error;
use std::fs;
use std::process;
use yaml_rust::{Yaml, YamlLoader};

#[derive(Debug)]
pub struct ConfigFiles {
    runner_registry: HashMap<String, Vec<String>>,
    yaml_registry: HashMap<String, Yaml>,
}

impl ConfigFiles {
    pub fn new(config_paths: &Vec<String>) -> ConfigFiles {
        let mut instance = ConfigFiles {
            runner_registry: HashMap::new(),
            yaml_registry: HashMap::new(),
        };

        for config_path in config_paths.iter() {
            let _ = parse_config_files(config_path, &mut instance.yaml_registry);
            let _ = extract_runners(config_path, &instance.yaml_registry, &mut instance.runner_registry);
        }

        return instance;
    }

    pub fn find_and_run(
        &self,
        name: &String,
    ) -> Result<Result<process::Child, std::io::Error>, Box<dyn Error>> {
        if !self.runner_registry.contains_key(name) {
            return Err(Box::new(error::DtagError {}));
        }

        if self.runner_registry[name].len() < 2 {
            return Err(Box::new(error::DtagError {}));
        }

        let (head, tail) = self.runner_registry[name].split_at(1);
        return Ok(process::Command::new(head[0].as_str())
            .args(&tail[..])
            .spawn());
    }
}

fn parse_config_files(
    path: &String,
    yaml_registry: &mut HashMap<String, Yaml>,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(path)?;
    let docs = YamlLoader::load_from_str(contents.as_str())?;

    match docs.into_iter().nth(0) {
        Some(doc) => { yaml_registry.insert(path.to_string(), doc); },
        None => {},
    }

    return Ok(());
}

fn extract_runners(
    path: &String,
    yaml_registry: &HashMap<String, Yaml>,
    runner_registry: &mut HashMap<String, Vec<String>>,
) -> Result<(), Box<dyn Error>> {
    if !yaml_registry.contains_key(path) {
        return Err(Box::new(error::DtagError {}));
    }

    let doc = &yaml_registry[path];
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
                runner_registry.insert(name.to_string(), args);
            }
        }
    }

    return Ok(());
}
