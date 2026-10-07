# iOS 打包工程

这是供 Mac 接手的 **Xcode 工程包**，尚未生成可安装的 `.ipa`。

Windows 上已使用 Godot 4.7.2 的官方 iOS 模板导出实际 Xcode 工程。工程带有 Release 游戏资源和 iPhone / iPad 引擎库，并附当前 Godot 源码。`UNSIGNED00` 是显式的 Team ID 占位值，不代表有效签名或开发者账号。

## 在 Mac 上安装到自己的 iPhone

1. 解压 `BoomerangArena-iOS-Xcode.zip`，安装并启动完整 Xcode，完成首次设置和 iOS SDK 安装。
2. 打开 `Xcode/BoomerangArena.xcodeproj`。
3. 在 Xcode 的 **Settings → Accounts** 中登录自己的 Apple 账号。在项目 target 的 **Signing & Capabilities** 中启用 **Automatically manage signing**，选择自己的 **Team**，替换 `UNSIGNED00`。
4. 检查 **Bundle Identifier**。当前默认值是 `io.github.ruofei6666.boomerangarena`；如有冲突，改成自己的唯一标识。
5. 连接 iPhone，按 Xcode 和手机提示配置开发测试，选择该手机，点击 **Run ▶** 安装运行。

免费个人账号可先使用 Xcode 真机运行。需要向其他设备分发安装包时，应使用支持对应分发方式的 Apple 开发者账号、证书和描述文件。

## 导出 .ipa

在已配置签名的 Mac 上，在解压后的目录运行：

```bash
IOS_TEAM_ID=你的10位TeamID bash build-ipa.sh --build
```

如果需要 Xcode 自动向 Apple 管理描述文件，明确设置：

```bash
IOS_TEAM_ID=你的10位TeamID IOS_ALLOW_PROVISIONING_UPDATES=1 bash build-ipa.sh --build
```

默认使用 `development` 签名，输出到 `output/日期时间/ipa/`。需要 Ad Hoc 包时再设置 `IOS_EXPORT_METHOD=ad-hoc`。开发和 Ad Hoc 包都只能安装到描述文件包含的设备，不能把未签名工程 ZIP 当作安装包。脚本只在本地归档、导出，不上传应用。

也可以在 Xcode 选择 **Product → Archive**，再在 **Organizer → Distribute App** 中选择适合自己账号与设备的分发方式。签名条件不满足时，先完成 Xcode 真机运行，再处理分发。

## 工程内容和验证边界

- `Xcode/`：实际导出的 `.xcodeproj`、Release `.pck`、`.xcframework`、图标和启动页。
- `GodotProject/`：当前工作目录中的游戏源码、场景、素材、iOS 导出预设和工具；包括尚未提交的游戏修改。
- `build-ipa.sh`：Mac 上的归档与签名导出脚本。`bash build-ipa.sh --open` 可打开工程。
- `manifest.json`：文件大小、SHA-256、引擎版本、占位签名状态和验证结果。
- `verification/`：本次检查的记录。Windows 上的原生检查、Xcode 文件检查不能替代 Mac 编译与 iPhone 真机测试。

本工程沿用已有手机摇杆、砍击、跳跃和横竖屏布局；iOS 预设启用方向感应，iOS 默认镜头使用已有手机 120% 基准。源码和图片保留原始内容，不含 `.git`、本地缓存、开发环境或签名私钥。

## 从源码重新导出

安装 Godot **4.7.2** 及相同版本的官方 iOS 导出模板。在 `GodotProject` 目录中运行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
mkdir -p build/ios/Xcode
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release iOS build/ios/Xcode/BoomerangArena.xcodeproj
```

预设的 `application/export_project_only=true` 表示先生成 Xcode 工程。每次修改游戏源码后都应重新导出，旧 Xcode 工程不会自动包含新内容。不要把 Web 的 `index.pck` 复制进 iOS 工程，iOS 包由对应平台预设独立导出。

官方参考：[Godot iOS 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)、[Godot iOS 导出选项](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformios.html)。
