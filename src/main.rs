const DATA_DIR: &str = "/data";
const BARE_BONES_CONFIG_FILE: &str = "/etc/mumble/bare_config.ini";
const CONFIG_REGEX: &str = r"^(;|#)? *([a-zA-Z_0-9]+)=.*";
use regex::Regex;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::Command;
use std::{collections::HashMap, env, fs, os::unix::prelude::MetadataExt};

const SENSITIVE_CONFIGS: [&str; 6] = [
    "dbPassword",
    "icesecretread",
    "icesecretwrite",
    "serverpassword",
    "registerpassword",
    "sslPassPhrase",
];

fn slice_contains(slice: &[&'static str; 6], search: &str) -> bool {
    for entry in slice.iter() {
        if *entry == search {
            return true;
        }
    }
    false
}

fn normalize_name(name: &str) -> String {
    name.to_uppercase().replace('_', "")
}

fn set_config_internal(
    config_file_content: &mut String,
    used_configs: &mut Vec<String>,
    config_name: &str,
    config_value: &str,
    is_default: bool,
) {
    if is_default && used_configs.contains(&config_name.to_string()) {
        //Do not overwrite user specified options with defaults
        return;
    }
    if slice_contains(&SENSITIVE_CONFIGS, config_name) {
        println!("Setting config \"{}\" to: *********", config_name);
    } else {
        println!("Setting config \"{}\" to: {}", config_name, config_value);
    }
    used_configs.push(String::from(config_name));
    config_file_content.push_str(&format!("{}={}\n", config_name, config_value));
}

fn list_mumble_config_secrets() -> Vec<(String, String)> {
    let mut result: Vec<(String, String)> = Vec::new();
    if let Ok(read_dir) = fs::read_dir("/run/secrets/") {
        for entry in read_dir {
            let file_name_os = entry.unwrap().file_name();
            let file_name_str = file_name_os.to_str().unwrap().to_string();
            if file_name_str.starts_with("MUMBLE_CONFIG_") {
                let file_content = fs::read_to_string(&file_name_str).unwrap();
                result.push((file_name_str, file_content));
            }
        }
    }
    result
}

fn list_mumble_config_env_vars() -> Vec<(String, String)> {
    let mut result: Vec<(String, String)> = Vec::new();
    for env_var in env::vars() {
        if env_var.0.starts_with("MUMBLE_CONFIG_") {
            result.push(env_var);
        }
    }
    result
}

fn get_existing_config_options(
    bare_bones_config: &str,
    option_for: &mut HashMap<String, String>,
) -> Vec<String> {
    let config_line_regex = Regex::new(CONFIG_REGEX).unwrap();
    let mut existing_config_options: Vec<String> = Vec::new();
    for line in bare_bones_config.lines() {
        let captures = config_line_regex.captures(line);
        if let Some(matches) = captures {
            let option = matches.get(2).unwrap();
            let option_string = option.as_str().to_string();
            option_for.insert(
                format!("MUMBLE_CONFIG_{}", normalize_name(&option_string)),
                option_string.clone(),
            );
            existing_config_options.push(option_string.clone());
        }
    }
    existing_config_options
}

fn set_superuser_password(server_invocation: &[String], mumble_supw_password_secret: String) {
    let mut set_secret_server_invocation = server_invocation.to_owned();
    set_secret_server_invocation.push(String::from("-supw"));
    set_secret_server_invocation.push(mumble_supw_password_secret);
    let status = Command::new(&set_secret_server_invocation[0])
        .args(&set_secret_server_invocation[1..])
        .status()
        .expect("Could not set superuse password");
    println!(
        "Successfully configured superuser password with exit status {}",
        status
    );
}

fn main() {
    let mut used_config_options: Vec<String> = Vec::new();
    let mut option_for: HashMap<String, String> = HashMap::new();
    let mut config_file = format!("{DATA_DIR}/mumble_server_config.ini");
    let mut config_file_content: String = String::from("# Config file automatically generated from the MUMBLE_CONFIG_* environment variables or secrets in /run/secrets/MUMBLE_CONFIG_* files\n");
    let bare_bones_config =
        fs::read_to_string(BARE_BONES_CONFIG_FILE).expect("Could not read barebones config file");
    get_existing_config_options(&bare_bones_config, &mut option_for);
    let mut set_config = |config_name: &str, config_value: &str, is_default: bool| {
        set_config_internal(
            &mut config_file_content,
            &mut used_config_options,
            config_name,
            config_value,
            is_default,
        );
    };
    match env::var("MUMBLE_CUSTOM_CONFIG_FILE") {
        Ok(custom_config_path) => {
            println!("Using manually specified config file at $MUMBLE_CUSTOM_CONFIG_FILE\nAll MUMBLE_CONFIG variables will be ignored");
            config_file = custom_config_path;
        }
        Err(_e) => {
            for mumble_env in list_mumble_config_env_vars() {
                let config_option = option_for.get(mumble_env.0.as_str());
                match config_option {
                    Some(config_name) => {
                        set_config(config_name, &mumble_env.1, false);
                    }
                    None => {
                        println!("Could not find config option for variable {}", mumble_env.0);
                    }
                }
            }

            for mumble_secret in list_mumble_config_secrets() {
                let config_option = option_for.get(mumble_secret.0.as_str());
                match config_option {
                    Some(config_name) => set_config(config_name, &mumble_secret.1, false),
                    None => {
                        println!(
                            "Could not find config option for secret {}",
                            mumble_secret.0
                        );
                    }
                }
            }

            //Apply default settings if they're missing
            let old_db_file = format!("{DATA_DIR}/murmur.sqlite");
            if Path::new(&old_db_file).is_file() {
                set_config("database", &old_db_file, true);
            } else {
                set_config(
                    "database",
                    &format!("{DATA_DIR}/mumble-server.sqlite"),
                    true,
                );
            }
            set_config("ice", "\"tcp -h 127.0.0.1 -p 6502\"", true);
            set_config(
                        "welcometext",
                        "\"<br />Welcome to this server, running the official Mumble Docker image.<br />Enjoy your stay!<br />\"",
                        true,
                    );

            set_config("port", "64738", true);
            set_config("users", "100", true);
            config_file_content
                .push_str("\n[Ice]\nIce.Warn.UnknownProperties=1\nIce.MessageSizeMax=65536");
            fs::write(&config_file, &config_file_content)
                .expect("Could not write generated config file");
        }
    }
    let mut server_invocation: Vec<String> = env::args().skip(1).collect();
    server_invocation.push(String::from("-ini"));
    server_invocation.push(config_file);
    let variable = env::var("MUMBLE_SUPERUSER_PASSWORD").ok();
    let mumble_supw_secret_path = Path::new("/run/secrets/MUMBLE_SUPERUSER_PASSWORD");
    if mumble_supw_secret_path.is_file() {
        let mumble_supw_password_secret = fs::read_to_string(mumble_supw_secret_path).unwrap();
        set_superuser_password(&server_invocation, mumble_supw_password_secret);
    } else if variable.is_some() {
        set_superuser_password(&server_invocation, variable.unwrap());
    }

    let user_uid = unsafe { libc::getuid() };
    let user_gid = unsafe { libc::getgid() };
    println!("Running Mumble server as UID={user_uid} GID={user_gid}");
    let metadata = Path::new(DATA_DIR)
        .metadata()
        .expect("Could not query permissions for data directory");
    println!(
        "{DATA_DIR} has the following permissions set: {:o} with UID={} and GID={}",
        metadata.mode(),
        metadata.uid(),
        metadata.gid()
    );

    println!("Command run to start the service: {:?}", server_invocation);
    Command::new(&server_invocation[0])
        .args(&server_invocation[1..])
        .exec();
}
