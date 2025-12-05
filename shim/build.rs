// Build script to generate C header using cbindgen

use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = env::var("OUT_DIR").unwrap();
    let profile = env::var("PROFILE").unwrap();
    
    // Determine target directory based on profile
    let target_dir = if profile == "release" {
        "target/release"
    } else {
        "target/debug"
    };
    
    let header_path = PathBuf::from(&crate_dir)
        .join(target_dir)
        .join("nito_shim.h");
    
    // Create directory if it doesn't exist
    if let Some(parent) = header_path.parent() {
        std::fs::create_dir_all(parent).unwrap();
    }

    let config_path = PathBuf::from(&crate_dir).join("cbindgen.toml");
    let config = if config_path.exists() {
        cbindgen::Config::from_file(&config_path)
            .unwrap_or_else(|_| cbindgen::Config::default())
    } else {
        cbindgen::Config::default()
    };

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .with_config(config)
        .with_header("/* Nito Shim - C-ABI Header for Nim FFI */")
        .with_include_guard("NITO_SHIM_H")
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(&header_path);
    
    println!("cargo:warning=Generated header at: {:?}", header_path);
}

