# RustSnap

[English](README.md) | **简体中文**

一款轻量的 macOS 菜单栏截图工具，支持截图标注和桌面贴图，使用 Rust 与原生 AppKit 构建。

[下载 macOS 版](https://github.com/OneDayOneApp/rustsnap/releases/latest) · [全部版本](https://github.com/OneDayOneApp/rustsnap/releases)

## 功能

- **区域截图**：通过全局快捷键冻结桌面，拖动选择区域，直接进行标注。
- **截图标注**：支持画笔、矩形、椭圆、箭头、文字、橡皮擦和马赛克，可调整颜色和线条粗细。
- **复制与保存**：将完成的图片复制到剪贴板，或导出合并标注后的 PNG。
- **桌面贴图**：将截图钉在独立浮动窗口中，支持移动、缩放和置顶。
- **菜单栏常驻**：无需打开编辑器即可截图，也可打开已有图片进行标注。
- **个性化设置**：自定义截图快捷键、保存位置、截图音效、Retina 输出比例和开机启动。

## 安装

需要 **macOS 11 或更新版本**。Universal DMG 同时支持 **Apple Silicon 和 Intel Mac**。

1. 在 [Releases](https://github.com/OneDayOneApp/rustsnap/releases/latest) 下载 **RustSnap-0.4.1-macOS-universal.dmg**。
2. 打开 DMG，将 **RustSnap.app** 拖入 **Applications（应用程序）**。
3. 启动 RustSnap，顶部菜单栏会显示图标；编辑器默认不打开。
4. 按提示到 **系统设置 → 隐私与安全性 → 屏幕与系统音频录制**（部分 macOS 版本称为“屏幕录制”）授予权限，然后重新启动 RustSnap。

当前版本使用本地临时签名，尚未经过 Apple 公证。如果 macOS 阻止打开，请确认下载来源后，在“隐私与安全性”中使用针对该应用的“仍要打开”选项（如果显示）。发布附件提供 SHA-256 校验文件，可用于核对下载内容。

## 第一次截图

1. 按 **Control + Command + S（`⌃⌘S`）**，或在菜单栏选择 **截屏**。
2. 拖动选择区域。开始标注前，可移动选区或拖动八个手柄缩放；按住 Shift 约束比例，使用方向键微调。
3. 选择标注工具并绘制。开始标注后，选区固定。
4. 按 **Enter**、双击选区或点击 **完成**，结束截图并复制图片。到其他应用按 `⌘V` 粘贴。
5. 如需保存文件，按 `⌘S` 选择 PNG 保存位置；按 Esc 取消截图。

界面部分标签使用英文，下文保留相应按钮名称，方便查找。

## 标注已有图片

在菜单栏选择 **打开标注窗口…**，再点击 **Open…** 载入图片。支持 PNG、JPEG、TIFF、BMP 和 HEIC 等格式。

通过工具栏添加标注、选择颜色和调整线条粗细。橡皮擦擦除标注笔迹，保留原图；马赛克用于将局部区域像素化。点击 **Copy** 复制合成图片，点击 **Export PNG…** 将图片和标注合并导出。

大图可通过滚动条浏览。暂不支持单独选中或移动已有标注，也没有可编辑项目文件格式。

## 将截图钉到桌面

点击截图工具栏或编辑器中的 **图钉**，或选择 **文件 → 钉到桌面**（`⇧⌘P`）。

- 拖动图片移动窗口，拖动窗口边缘调整大小。
- 点击图钉切换置顶，通过复制和保存 PNG 按钮再次使用图片。
- 红色关闭按钮会隐藏便签；选择 **显示全部浮动便签** 可重新显示。
- 便签位置会保存，重启应用后恢复此前可见的便签。

便签保存在本机 `~/Library/Application Support/RustSnap/PinnedNotes/`。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 区域截图（可自定义） | `⌃⌘S` |
| 撤销／重做标注 | `⌘Z` / `⌘⇧Z` |
| 复制图片 | `⌘C` |
| 保存 PNG | `⌘S` |
| 完成截图并复制 | Enter / 双击选区 |
| 取消截图 | Esc |
| 钉到桌面 | `⇧⌘P` |
| 偏好设置 | `⌘,` |
| 退出应用 | `⌘Q` |

## 偏好设置与应用行为

在菜单栏选择 **偏好设置…**，或按 `⌘,`。

- **截图快捷键**：点击快捷键框，按下新组合。发生冲突时保留原设置；点击 × 或在录入时按 Delete 可清除。
- **输出方式**：设置保存目录，选择仅复制到剪贴板，或保存文件并同时复制。选择“只保存到剪贴板”后，不再自动保存文件；仍可通过 `⌘S` 显式保存。
- **Retina**：开启 1× 输出，按屏幕逻辑尺寸生成图片，而非完整 Retina 像素尺寸。
- **其他选项**：截图音效、开机自动启动。设置在退出和重启后保持。

关闭编辑器后，RustSnap 继续驻留菜单栏，保留当前图片和标注。从 Dock 选择“退出”也只会收起编辑器，截图仍可使用。如需完全退出，请使用顶部菜单 **退出 RustSnap** 或 `⌘Q`。

## 从源码构建

需要 Rust、clang 和 macOS SDK，无第三方 Cargo 依赖。

```sh
git clone https://github.com/OneDayOneApp/rustsnap.git
cd rustsnap
cargo test --offline
./install.sh
```

安装脚本按当前机器架构构建，将应用安装到 `~/Applications/RustSnap.app` 并进行本地临时签名。

构建 Universal DMG 和 ZIP，输出至 `dist/`：

```sh
rustup target add --toolchain stable aarch64-apple-darwin x86_64-apple-darwin
./package.sh
```

仅构建当前架构时，使用 `RUSTSNAP_ARCH=native ./package.sh`。

## 致谢与资源来源

RustSnap 的截图流程参考了对 Snip 2.0 的静态分析。随包工具栏资源来自 Snip，来源和 SHA-256 记录见 [PROVENANCE.json](assets/snip-toolbar/PROVENANCE.json)。
