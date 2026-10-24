# RustSnip implementation notes

RustSnip is an independent Rust executable with a native AppKit bridge. It does not load, link or modify the original Snip binary. Rust owns the complete annotation document: shapes, point sequences, text, colors, stroke widths, selected tool, drag state machine, clamping, normalized rectangles, arrow geometry, undo/redo, and branch invalidation. `native/ui.m` forwards AppKit events into Rust, reads immutable shape snapshots, and handles the native window, drawing, image encoding, file dialogs, screenshot process and pasteboard. It contains no independent annotation/history store. This is a mixed Rust/Objective-C implementation, not a pure Rust port.

## Build

```sh
cargo test --offline
cargo build --release --offline
```

Requires Rust, clang and an installed macOS SDK. No third-party Cargo dependencies. This machine's `xcrun --show-sdk-path` may point to a missing SDK; `build.rs` falls back to its installed macOS 15.2 SDK.

## Run

```sh
target/release/rustsnip --open /absolute/path/image.png
target/release/rustsnip --fixture /absolute/path/annotation-fixture.png
```

The fixture command produces an 800×500 image with all five annotation tools and exits, without opening the editor. The normal editor provides Capture, Open, rectangle, ellipse, arrow, freehand pen, text, ink color, stroke width, Undo, Copy, and Export PNG. `Command-Z` undoes an annotation, `Command-Shift-Z` redoes it, and `Command-C` copies the rendered image. Capture acquires frozen display snapshots with macOS `/usr/sbin/screencapture -x -D` and renders its own in-place selection/annotation overlay, which may require Screen Recording permission. Escape cancels capture.

## Scope and limitations

The editor displays the input image at its pixel dimensions and uses scrollbars when larger than the window. It supports PNG/JPEG/TIFF/BMP/HEIC image import and PNG export. Annotations are flattened on export. There is no editable project format, annotation-object selection/repositioning, OCR, account, telemetry or cloud sync. The menu bar remains active after closing the editor; global Control+Command+S uses Carbon RegisterEventHotKey. Text is added through a native dialog. A new image clears annotation history. The capture toolbar now reuses the user-requested local Snip artwork; exact source paths and SHA256 values are recorded in assets/snip-toolbar/PROVENANCE.json. No private API is used.

Nine Rust unit tests cover all five tools, undo/redo and history branching, coordinate clamping and rectangle normalization, freehand point retention, endpoint updates, cancelled/empty gestures, style snapshots, arrow geometry, and document reset. UI behavior, clipboard PNG content, export pixels and actual screen capture require integration verification by the installing agent; a successful compile alone does not establish those outcomes.

## Integration verification

`--integration-test /absolute/output/directory` writes an asymmetric RGBA source image, loads and renders it through production Canvas, exercises every Rust annotation tool, compares undo/redo images, verifies PNG file roundtrip and checks an isolated uniquely named NSPasteboard. The result JSON reports eleven checks. It does not capture the screen, synthesize GUI events or use the general pasteboard. See `qa/TEST-REPORT.md` for separate observed UI coverage and remaining screenshot limitation.

## Preferences (0.3.0)

`native/preferences.m` provides native preferences, an immediate shortcut recorder, NSUserDefaults persistence, native menu hint updates, resolution conversion and unique atomic PNG output. Shortcut changes attempt exclusive Carbon registration before persisting; failure restores the prior registration. A user-selected login option writes a per-user RunAtLoad LaunchAgent with `--background`; it is off by default and never enabled by tests. Background launch leaves the editor hidden. QQ Mail and the legacy browser plugin are excluded.

Settings tests use an isolated defaults domain and temporary directory. Real login/reboot, speaker playback, and capture output behind Screen Recording permission remain separate manual checks.
