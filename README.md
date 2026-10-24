# RustSnap

**简体中文** | [English](README.en.md)

基于本机 Snip 2.0 的 REA/Ghidra 静态分析，独立重写的截图标注核心版本。Rust 负责标注模型、几何、手势与撤销/重做；AppKit 原生桥接负责窗口、图像绘制、截图进程、文件对话框和剪贴板。不是整个 Snip 的完整源码移植。

安装位置：`~/Applications/RustSnap.app`。

## 使用

按 **Control + Command + S（⌃⌘S）** 或点击菜单栏“截屏”进入冻结桌面选区。拖动选择区域，松开后出现 237×79 点浮动工具栏，可直接画矩形、椭圆、箭头、画笔或添加文字。进入标注后选区固定。主窗口的 **Open…** 可载入已有图片。

- `⌘Z`：撤销；`⌘⇧Z`：重做。
- **Copy** / `⌘C`：复制合成图片。
- **Export PNG…**：导出 PNG，标注会合并至图片。
- 全局 `⌃⌘S`：截图（窗口隐藏后仍可用，菜单“截屏”右侧显示同一快捷键）。
- 选区拖动移动、八点缩放；Shift 拖动锁定比例；方向键微调。
- Enter / 双击选区 / 完成按钮：完成并复制；`⌘S`：保存 PNG；Esc：取消。

如 macOS 提示截图权限，请到“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”授权 RustSnap（通过终端启动时也可能显示启动终端），然后重新启动。程序不会自动更改系统隐私权限。

## 构建与安装

```sh
git clone https://github.com/OneDayOneApp/rustsnap.git
cd rustsnap
cargo test --offline
./install.sh
```

安装脚本离线编译、复制到当前用户 Applications 并 ad hoc 签名。需要本机 Rust、clang 和 macOS SDK，无第三方 Cargo 依赖。

## 验证

```sh
target/release/rustsnip --fixture qa/annotation-fixture.png
target/release/rustsnip --integration-test qa
```

测试输出保存在本地 `qa/`，不纳入版本控制。逆向分析记录保存在开发环境的 `snip-research/`，未包含在本仓库。

菜单栏使用 18 pt 原创“截图取景框 + 标注笔”模板图标，点击可截屏、打开标注窗口、查看关于信息及退出。图标自动适配系统浅色/深色菜单栏，提供全局 `⌃⌘S` 截图。

当前范围不含已有标注的选中/移动、完整原版设置及像素级等价。大图按图片像素尺寸显示，可使用滚动条；没有可编辑项目文件。

关闭窗口后继续驻留菜单栏，保留当前图片和标注；点击菜单栏“打开标注窗口…”或 Dock 图标可恢复。最小化后也可从菜单恢复。仅“退出 RustSnap”或 `⌘Q` 完全退出。

## 截图模式复刻依据

新增流程来自 REA 对 Snip 自有截图/选区/工具栏类的反编译。原工具栏 PNG（含 Retina、选中态）随包安装，来源与 SHA256 见 `assets/snip-toolbar/PROVENANCE.json`；布局、遮罩、边框、圆形手柄、工具栏间距、标注时锁定选区均有静态依据。详细分析记录保存在开发环境的 `snip-research/SNAPSHOT-CAPTURE.md`，未包含在本仓库。尚未验证所有显示器、所有系统主题及原版每个细节的像素等价。

正式截图函数不接收测试图片参数。`--fixture` 仅生成自动测试文件后退出，不参与全局快捷键或菜单截图。

## 偏好设置

菜单栏 → **偏好设置…**，或 `⌘,` 打开。支持：

- 点击快捷键框录入新组合；冲突时保留原组合；右侧 × 或录入时 Delete 可清除。默认 `⌃⌘S`，菜单提示随设置更新。
- 截图完成后播放声音；Retina 输出 1× 逻辑尺寸图片。
- 保存目录；“同时保存到剪贴板”；“只保存到剪贴板”。勾选后者时忽略自动文件保存，前者暂时不可选。显式 `⌘S` 仍可选择文件保存。
- 开机自动启动：勾选后创建当前用户的 `~/Library/LaunchAgents/dev.local.rustsnip.plist`，下次登录以 `--background` 启动；取消勾选后移除此配置。
- 设置立即保存，退出重启后保持。QQ 邮箱绑定和旧 Snip 浏览器插件未实现。

偏好设置检查：`qa/preferences-test.m` 编译运行使用独立 defaults 域和临时目录，不更改真实偏好、剪贴板或登录项。结果输出到本地 `qa/preferences-results.json`。

0.3.2 行为：Dock 的“退出”仅收起编辑器与 Dock 图标，保持顶部菜单栏和全局快捷键运行；顶部菜单“退出 RustSnap”及 `⌘Q` 才完全终止应用。顶部“打开标注窗口…”可恢复编辑器和 Dock 图标。系统注销、重启或关机时正常退出。

默认启动仅驻留顶部菜单栏，不自动显示标注窗口或 Dock 图标。通过菜单“打开标注窗口…”打开编辑器；显式使用 `--open 图片路径` 时会显示图片编辑窗口。


## 桌面浮动便签

- 截屏选区工具栏点击图钉，可将当前选区（含标注）钉到桌面。
- 标注窗口点击图钉，或使用“文件 → 钉到桌面”（⇧⌘P），可创建独立截图便签。
- 可拖动图片移动窗口，拖动窗口边缘调整大小；图钉切换置顶，另有复制和保存 PNG 按钮。
- 红色关闭按钮隐藏便签；菜单栏“显示全部浮动便签”可重新显示。退出前会保存位置，重启后恢复未关闭的便签。
- 便签截图与位置保存在当前用户的 `~/Library/Application Support/RustSnap/PinnedNotes/`。

## macOS 安装介质

运行 `./package.sh` 默认构建同时支持 Intel（x86_64）和 Apple Silicon（arm64）的 Universal DMG 与 ZIP，输出到 `dist/`，同时生成 SHA-256 校验文件。两个架构使用同一套 rustup stable 工具链，构建前需安装相应目标：

```sh
rustup target add --toolchain stable aarch64-apple-darwin x86_64-apple-darwin
./package.sh
```

如只需当前机器架构，可运行 `RUSTSNAP_ARCH=native ./package.sh`；`./install.sh` 仍按当前机器架构构建。最低系统版本为 macOS 11。DMG 包含 RustSnap.app、Applications 拖放入口和中文安装说明。打包不会改动已安装应用或个人配置。创建磁盘镜像需要可访问系统磁盘镜像服务的终端环境。当前版本为本地临时签名，未做 Apple 公证。
