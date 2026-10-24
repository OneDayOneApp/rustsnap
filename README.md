# RustSnap

**English** | [简体中文](README.zh-CN.md)

A lightweight macOS menu bar app for capturing, annotating, and pinning screenshots. Built with Rust and native AppKit.

[Download for macOS](https://github.com/OneDayOneApp/rustsnap/releases/latest) · [All releases](https://github.com/OneDayOneApp/rustsnap/releases)

## Features

- **Capture a region:** press a global shortcut, select an area on the frozen desktop, and annotate it immediately.
- **Mark up screenshots:** freehand pen, rectangles, ellipses, arrows, text, eraser, and mosaic, with color and stroke-width controls.
- **Copy or save:** copy the finished image to the clipboard or export a flattened PNG.
- **Pin images to the desktop:** keep screenshots in floating windows that you can move, resize, and keep on top.
- **Work from the menu bar:** capture without opening the editor, or load an existing image for annotation.
- **Customize your workflow:** change the capture shortcut, save location, capture sound, Retina output scale, and launch-at-login behavior.

## Install

Requires **macOS 11 or later**. The Universal DMG supports both **Apple Silicon and Intel Macs**.

1. Download **RustSnap-0.4.1-macOS-universal.dmg** from [Releases](https://github.com/OneDayOneApp/rustsnap/releases/latest).
2. Open the DMG and drag **RustSnap.app** into **Applications**.
3. Launch RustSnap. Its icon appears in the menu bar; the editor stays hidden until you open it.
4. When prompted, allow screen recording in **System Settings → Privacy & Security → Screen & System Audio Recording** (called Screen Recording on some macOS versions), then restart RustSnap.

The current build is ad hoc signed and has not been notarized by Apple. If macOS blocks opening it, use the app-specific **Open Anyway** option in Privacy & Security, if available, after checking the download source. Release assets include a SHA-256 checksum file for verifying the download.

## Take your first screenshot

1. Press **Control + Command + S (`⌃⌘S`)**, or choose **截屏** (Capture) from the menu bar.
2. Drag to select a region. Before annotating, move the selection or resize it with its eight handles. Hold Shift to constrain proportions; use the arrow keys for fine adjustments.
3. Choose an annotation tool and draw. The selection becomes fixed once annotation begins.
4. Press **Enter**, double-click the selection, or click **Done** to finish and copy the image. Paste it into another app with `⌘V`.
5. To save a file instead, press `⌘S` and choose a PNG destination. Press Esc to cancel the capture.

Some interface labels are in Chinese; their English meanings are included here for reference.

## Annotate an existing image

Choose **打开标注窗口…** (Open Annotation Window…) from the menu bar, then **Open…** to load an image. Supported formats include PNG, JPEG, TIFF, BMP, and HEIC.

Use the toolbar to add annotations, choose a color, and adjust stroke width. The eraser removes annotation strokes without erasing the original image. Use mosaic to pixelate an area. **Copy** copies the combined image; **Export PNG…** saves it with annotations flattened into the image.

Large images can be scrolled. Existing annotations cannot be selected or moved individually, and there is no editable project format.

## Pin screenshots to your desktop

Click the **pin** in the capture toolbar or editor, or choose **文件 → 钉到桌面** (File → Pin to Desktop, `⇧⌘P`).

- Drag the image to move it; drag the window edges to resize it.
- Use the pin to toggle always-on-top behavior, or the Copy and Save PNG buttons to reuse the image.
- The red close button hides a note. Choose **显示全部浮动便签** (Show All Floating Notes) to reveal it again.
- Note positions are saved, and visible notes return when the app restarts.

Notes are stored locally in `~/Library/Application Support/RustSnap/PinnedNotes/`.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Capture a region (customizable) | `⌃⌘S` |
| Undo / redo annotation | `⌘Z` / `⌘⇧Z` |
| Copy image | `⌘C` |
| Save PNG | `⌘S` |
| Finish and copy a capture | Enter / double-click selection |
| Cancel capture | Esc |
| Pin to desktop | `⇧⌘P` |
| Preferences | `⌘,` |
| Quit the app | `⌘Q` |

## Preferences and app behavior

Open **偏好设置…** (Preferences…) from the menu bar, or press `⌘,`.

- **Capture shortcut:** click the shortcut field and press a new combination. Conflicting shortcuts leave the previous setting in place. Click × or press Delete while recording to clear it.
- **Output:** choose a save folder, copy-only output, or file saving together with clipboard copying. Clipboard Only disables automatic file saving; explicit `⌘S` still lets you save a file.
- **Retina:** enable 1× output to use logical display dimensions rather than full Retina pixel dimensions.
- **Other settings:** play a capture sound or launch automatically at login. Settings persist across restarts.

Closing the editor keeps RustSnap running in the menu bar and retains the current image and annotations. Choosing Quit from the Dock also hides the editor while leaving capture available. To fully exit, choose **退出 RustSnap** (Quit RustSnap) from the menu bar or press `⌘Q`.

## Build from source

Requires Rust, clang, and the macOS SDK. There are no third-party Cargo dependencies.

```sh
git clone https://github.com/OneDayOneApp/rustsnap.git
cd rustsnap
cargo test --offline
./install.sh
```

The installer builds for the current machine and installs to `~/Applications/RustSnap.app` with an ad hoc signature.

To build Universal DMG and ZIP packages in `dist/`:

```sh
rustup target add --toolchain stable aarch64-apple-darwin x86_64-apple-darwin
./package.sh
```

For the current architecture only, use `RUSTSNAP_ARCH=native ./package.sh`.

## Credits

RustSnap's capture workflow was informed by static analysis of Snip 2.0. Bundled toolbar resources originate from Snip; their sources and SHA-256 hashes are documented in [PROVENANCE.json](assets/snip-toolbar/PROVENANCE.json).
