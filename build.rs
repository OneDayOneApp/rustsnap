use std::{env, path::PathBuf, process::Command};
fn main() {
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());
    let sdk = env::var("SDKROOT")
        .ok()
        .filter(|p| PathBuf::from(p).exists())
        .or_else(|| {
            Command::new("xcrun")
                .args(["--show-sdk-path"])
                .output()
                .ok()
                .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_owned())
                .filter(|p| PathBuf::from(p).exists())
        })
        .unwrap_or_else(|| "/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk".into());
    let target = env::var("TARGET").unwrap();
    let clang_target = match target.as_str() {
        "aarch64-apple-darwin" => "arm64-apple-macosx11.0",
        "x86_64-apple-darwin" => "x86_64-apple-macosx11.0",
        other => panic!("Unsupported macOS build target: {other}"),
    };
    let obj = out.join("ui.o");
    assert!(Command::new("clang")
        .args([
            "-target",
            clang_target,
            "-isysroot",
            &sdk,
            "-fobjc-arc",
            "-Wno-deprecated-declarations",
            "-c",
            "native/ui.m",
            "-o"
        ])
        .arg(&obj)
        .status()
        .unwrap()
        .success());
    assert!(Command::new("ar")
        .arg("rcs")
        .arg(out.join("libui.a"))
        .arg(obj)
        .status()
        .unwrap()
        .success());
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=ui");
    println!("cargo:rustc-link-lib=framework=AppKit");
    println!("cargo:rustc-link-lib=framework=CoreGraphics");
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=framework=Carbon");
    println!("cargo:rustc-link-arg=-Wl,-weak_framework,ScreenCaptureKit");
    println!("cargo:rerun-if-changed=native/ui.m");
    println!("cargo:rerun-if-changed=native/integration.m");
    println!("cargo:rerun-if-changed=native/model.h");
    println!("cargo:rerun-if-changed=native/menu_icon.h");
    println!("cargo:rerun-if-changed=native/capture_mode.m");
    println!("cargo:rerun-if-changed=native/pinned_notes.m");
    println!("cargo:rerun-if-changed=native/selection.h");
    println!("cargo:rerun-if-changed=native/hotkey.h");
    println!("cargo:rerun-if-changed=native/preferences.m");
}
