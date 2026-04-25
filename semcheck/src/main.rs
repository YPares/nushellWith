use std::env;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: semcheck <version> <req>");
        process::exit(2);
    }

    let version = match args[1].parse::<semver::Version>() {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Invalid version '{}': {}", args[1], e);
            process::exit(2);
        }
    };

    let req = match args[2].parse::<semver::VersionReq>() {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Invalid requirement '{}': {}", args[2], e);
            process::exit(2);
        }
    };

    if req.matches(&version) {
        process::exit(0);
    } else {
        process::exit(1);
    }
}
