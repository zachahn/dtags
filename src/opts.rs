#[derive(Debug)]
pub struct Opts {
    pub config_paths: Vec<String>,
    pub delegatee_names: Vec<String>,
    pub output_path: String,
    pub working_dir: String,
    pub timeout: f32,
}

impl Opts {
    pub fn new(matches: getopts::Matches) -> Opts {
        let mut instance = Opts {
            config_paths: [].to_vec(),
            delegatee_names: [].to_vec(),
            output_path: "tags".to_string(),
            working_dir: ".dtags/".to_string(),
            timeout: 10.0,
        };

        if !matches.opt_present("clear-config-paths") {
            instance.config_paths.push(".git/dtags.yaml".to_string());
            instance.config_paths.push("dtags.yaml".to_string());
            instance.config_paths
                .push("~/.config/dtags/dtags.yaml".to_string());
            instance.config_paths.push("~/.dtags.yaml".to_string());
        }

        instance.config_paths.append(&mut matches.opt_strs("config"));
        instance.delegatee_names
            .append(&mut matches.opt_strs("delegatee"));

        match matches.opt_str("out") {
            Some(out) => instance.output_path = out,
            None => {}
        }

        match matches.opt_str("workdir") {
            Some(working) => instance.working_dir = working,
            None => {}
        }

        match matches.opt_str("timeout") {
            Some(timeout_str) => match timeout_str.parse::<f32>() {
                Ok(timeout) => instance.timeout = timeout,
                Err(_) => {
                    println!(
                        "Couldn't parse timeout: {}. Using default: {}",
                        timeout_str, instance.timeout
                    )
                }
            },
            None => {}
        }

        return instance;
    }
}
