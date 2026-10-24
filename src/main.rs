mod model;
mod selection;
use std::ffi::{c_char, CString};
extern "C" {
    fn run_app(path: *const c_char) -> i32;
    fn run_fixture(path: *const c_char) -> i32;
    fn run_integration(path: *const c_char) -> i32;
}
fn main() {
    let args: Vec<_> = std::env::args().collect();
    if let Some(a) = args.windows(2).find(|a| a[0] == "--integration-test") {
        let p = CString::new(a[1].as_str()).unwrap();
        std::process::exit(unsafe { run_integration(p.as_ptr()) });
    }
    if let Some(a) = args.windows(2).find(|a| a[0] == "--fixture") {
        let p = CString::new(a[1].as_str()).unwrap();
        std::process::exit(unsafe { run_fixture(p.as_ptr()) });
    }
    let p = args
        .windows(2)
        .find(|a| a[0] == "--open")
        .map(|a| a[1].as_str())
        .unwrap_or("");
    let p = CString::new(p).unwrap();
    std::process::exit(unsafe { run_app(p.as_ptr()) });
}
