# RustSnap

[简体中文](README.md) | **English**

An independent reimplementation of the core screenshot and annotation features, informed by REA/Ghidra static analysis of a locally installed copy of Snip 2.0. Rust handles the annotation model, geometry, gestures, and undo/redo. A native AppKit bridge handles windows, image rendering, screen capture, file dialogs, and the clipboard. This is not a complete source port of Snip.

Installation path: `~/Applications/RustSnap.app`.

## Usage

Press **Control + Command + S (⌃⌘S)** or choose “截屏” (Capture) from the menu bar to select a region on a frozen view of the desktop. Drag to select a region; releasing the mouse reveals a floating toolbar measuring 237 × 79 points. Draw rectangles, ellipses, arrows, or freehand strokes, or add text. The selection is locked once annotation begins. Use **Open…** in the main window to load an existing image.

- `⌘Z`: undo; `⌘⇧Z`: redo.
- **Copy** / `⌘C`: copy the image with annotations flattened into it.
- **Export PNG…**: export a PNG with annotations flattened into the image.
- Global `⌃⌘S`: take a screenshot, even when the window is hidden. The Capture menu item displays the same shortcut.
- Drag the selection to move it; resize it using its eight handles. Hold Shift while dragging to lock the aspect ratio, or use the arrow keys for fine adjustments.
- Enter / double-click the selection / Done: finish and copy. `⌘S`: save a PNG. Esc: cancel.

If macOS requests screen capture permission, authorize RustSnap under **System Settings → Privacy & Security → Screen & System Audio Recording**, then restart the app. If launched from a terminal, macOS may list that terminal instead. The app does not automatically change system privacy permissions.

## Build and install

```sh
git clone https://github.com/OneDayOneApp/rustsnap.git
cd rustsnap
cargo test --offline
./install.sh
```

The installer builds offline, copies the app to the current user's Applications directory, and applies an ad hoc signature. Rust, clang, and the macOS SDK must be installed locally. There are no third-party Cargo dependencies.

## Verification

```sh
target/release/rustsnip --fixture qa/annotation-fixture.png
target/release/rustsnip --integration-test qa
```

Test output is stored locally in `qa/` and excluded from version control. Reverse engineering notes are stored in `snip-research/` in the development environment and are not included in this repository.

The menu bar uses an original 18-point template icon combining a screenshot frame and an annotation pen. Its menu provides screen capture, the annotation window, About, and Quit. The icon adapts to light and dark menu bars. Global screen capture is available via `⌃⌘S`.

The current implementation does not support selecting or moving existing annotations, the complete original preferences, or pixel-perfect equivalence. Large images are displayed at their pixel dimensions and can be scrolled. There is no editable project file format.

Closing the window keeps the app in the menu bar and retains the current image and annotations. Choose “打开标注窗口…” (Open Annotation Window…) from the menu bar or click the Dock icon to restore it. Minimized windows can also be restored from the menu. Only “退出 RustSnap” (Quit RustSnap) or `⌘Q` fully exits the app.

## Basis for the screen capture implementation

The capture workflow is informed by REA decompilation of Snip's own capture, selection, and toolbar classes. The original toolbar PNGs, including Retina and selected-state variants, are bundled with the app. Their sources and SHA-256 hashes are recorded in `assets/snip-toolbar/PROVENANCE.json`. Static analysis supports the layout, overlay, borders, circular handles, toolbar spacing, and selection locking during annotation. Detailed analysis notes are stored in `snip-research/SNAPSHOT-CAPTURE.md` in the development environment and are not included in this repository. Pixel-perfect equivalence has not been verified across all displays, system themes, or details of the original app.

The production capture function does not accept test image arguments. `--fixture` only generates automated test files and then exits; it is not used by the global shortcut or menu capture flow.

## Preferences

Choose “偏好设置…” (Preferences…) from the menu bar, or press `⌘,`. Available settings include:

- Click the shortcut field to record a new combination. If a conflict occurs, the previous shortcut is retained. Click × on the right, or press Delete while recording, to clear it. The default is `⌃⌘S`, and the menu hint updates with the setting.
- Play a sound after capturing; output Retina images at 1× logical resolution.
- Save directory; “同时保存到剪贴板” (Also Save to Clipboard); “只保存到剪贴板” (Clipboard Only). Selecting Clipboard Only disables automatic file saving and temporarily disables Also Save to Clipboard. An explicit `⌘S` still lets you save a file.
- Launch at login: enabling this creates `~/Library/LaunchAgents/dev.local.rustsnip.plist` for the current user and launches the app with `--background` at the next login. Disabling it removes that configuration.
- Settings are saved immediately and persist across restarts. QQ Mail account linking and the legacy Snip browser plugin are not implemented.

Preferences verification: compiling and running `qa/preferences-test.m` uses an isolated defaults domain and temporary directories, without changing actual preferences, the clipboard, or login items. Results are written locally to `qa/preferences-results.json`.

Behavior introduced in 0.3.2: choosing Quit from the Dock hides the editor and Dock icon while keeping the menu bar and global shortcut active. “退出 RustSnap” (Quit RustSnap) in the menu bar and `⌘Q` fully terminate the app. “打开标注窗口…” (Open Annotation Window…) restores the editor and Dock icon. The app exits normally on logout, restart, or shutdown.

By default, the app starts in the menu bar without showing the annotation window or Dock icon. Open the editor through “打开标注窗口…” (Open Annotation Window…). Launching explicitly with `--open <image-path>` shows the image editor window.

## Floating desktop notes

- Click the pin in the capture selection toolbar to pin the current region, including annotations, to the desktop.
- Click the pin in the annotation window, or choose “文件 → 钉到桌面” (File → Pin to Desktop, `⇧⌘P`), to create a separate screenshot note.
- Drag the image to move the window, or drag the window edges to resize it. The pin toggles always-on-top behavior; Copy and Save PNG buttons are also available.
- The red close button hides a note. Choose “显示全部浮动便签” (Show All Floating Notes) from the menu bar to reveal hidden notes. Positions are saved before quitting, and notes that have not been closed are restored on restart.
- Note screenshots and positions are stored in `~/Library/Application Support/RustSnap/PinnedNotes/` for the current user.

## macOS installation packages

By default, `./package.sh` builds Universal DMG and ZIP packages for both Intel (x86_64) and Apple Silicon (arm64), writes them to `dist/`, and generates SHA-256 checksum files. Both architectures use the same rustup stable toolchain. Install the required targets before building:

```sh
rustup target add --toolchain stable aarch64-apple-darwin x86_64-apple-darwin
./package.sh
```

To build only for the current machine's architecture, run `RUSTSNAP_ARCH=native ./package.sh`. `./install.sh` always builds for the current machine's architecture. macOS 11 or later is required. The DMG includes RustSnap.app, an Applications shortcut for drag-and-drop installation, and installation instructions in Chinese. Packaging does not change the installed app or personal settings. Creating a disk image requires a terminal environment with access to the system disk image service. The current build uses a local ad hoc signature and has not been notarized by Apple.
