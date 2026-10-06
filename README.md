# 草莓散步 · Strawberry Walk

Godot 4.7.2 的 3D 草莓角色试玩。草莓身体、叶冠、五官和两颗圆球脚都是真实网格，角色有碰撞体、转身和脚步动画。

## 直接试玩

[在线试玩（GitHub Pages）](https://ruofei6666.github.io/Boomerang-Fu/)。电脑用 WASD / 方向键，手机用左下角摇杆；在线版无需电脑保持开机。

电脑双击 `run-map.cmd` 打开原生游戏，使用 **WASD / 方向键** 控制草莓。

双击 `run-web.cmd` 启动浏览器版本，也可以打开 <http://localhost:8060>。手机与电脑连接同一 Wi-Fi 后，在手机浏览器打开电脑 Wi-Fi 地址的 8060 端口，例如 <http://192.168.0.197:8060>。Wi-Fi 地址可能变化；电脑必须保持开机，试玩服务必须运行。

手机拖动左下角摇杆走动，松手停下。横屏和竖屏均有适配；右下角“回到起点”可重置角色。摇杆也支持电脑鼠标拖动。

| 操作 | 功能 |
| --- | --- |
| WASD / 方向键 | 按屏幕方向走动 |
| 手机摇杆 / 鼠标拖动摇杆 | 模拟方向与速度 |
| 滚轮 | 缩放 |
| Q / E | 转动镜头 |
| R / 跟随视角按钮 | 恢复跟随镜头 |
| 中键 / 右键拖动 | 自由查看地图，按 R 恢复跟随 |
| 回到起点 | 重置草莓位置 |
| F11 | 原生版全屏 |

斜向移动不会加速。草莓会被岩石挡住，并沿岩石侧面滑动；地图边缘有保护。触控有死区、单指控制、取消事件和失焦复位。

## 项目文件

- `scenes/stone_arena.tscn`：原有岩石庭院和草莓实例。
- `scenes/strawberry_player.tscn`：可在 Godot 编辑器中查看的独立 3D 草莓场景。
- `scripts/player_controller.gd`：移动、碰撞、转身和两颗球形脚的动画。
- `scripts/virtual_joystick.gd`：手机触屏和鼠标摇杆。
- `scripts/camera_controller.gd`：跟随、缩放、转向和地图拖动。
- `assets/fonts/noto_sans_sc_ui.ttf`：按界面文字裁剪的 Noto Sans SC，随附 OFL 许可证。
- `tools/serve_web.mjs`：仅提供 `build/web` 里的试玩文件，监听 8060 端口。
- `artifacts/strawberry_chibi.png`：先前生成的角色参考图。
- `artifacts/verification.json`：Godot 实际输入和物理验证记录。
- `artifacts/browser-verification.json`：最近一次浏览器自动验证的状态。
- `artifacts/browser-manual-verification.json`：实际浏览器的局域网、摇杆、重置和横竖屏验证记录。

## 构建和验证

GitHub Pages 发布源为 `main` 分支的 `/docs`。`prepare_pages.mjs` 将导出的游戏和所需许可证复制到 `docs/`，保留 `.nojekyll` 并生成 SHA-256 清单。更新网页版本时，重新导出、运行兼容补丁及复制脚本，再提交并推送 `main`；Pages 会自动发布。编译文件在仓库子路径内使用相对 URL。

将下面的 `godot` 替换为本机 Godot 可执行文件路径：

```powershell
godot --headless --path . --script res://tools/build_character.gd
godot --headless --editor --path . --import
godot --headless --path . --script res://tools/verify_scene.gd
godot --headless --path . --export-release Web build/web/index.html
node tools/patch_web_export.mjs
node tools/prepare_pages.mjs
godot --path . -- --capture-ui
```

Web 使用 Compatibility 渲染器和单线程模板，导出预设保存在 `export_presets.cfg`。没有模板时，可以运行 `python tools/fetch_web_template.py`，再运行同一命令并添加 `--template web_nothreads_debug.zip`；脚本从 Godot 官方发布包中仅下载所需的 Web 模板，验证 ZIP CRC。

地图材质已按先前的浅绿地面、蓝紫岩石截图校准 Compatibility 的亮度，并关闭地图材质的镜面高光，避免网页版本过曝发白。角色材质和灯光保持原有设置。

每次重新导出后运行 `node tools/patch_web_export.mjs`。它为 Godot 4.7.2 的 Web 音频初始化加上能力检查；HTML 启动页在 HTTP 局域网页面明确选择引擎的 ScriptProcessor 后备方式，HTTPS 页面保留 AudioWorklet。当前试玩没有音效资源。此兼容修改核对了官方源文件 `.firecrawl/godot-web-audio-js.md`、`.firecrawl/godot-web-audio-header.md`。

Godot 输入和物理检查已通过 32 项。实际浏览器已验证局域网加载、摇杆移动、松手停止、回到起点和手机横竖屏布局。

浏览器自动检查使用 Python Playwright，运行 `.venv\Scripts\python.exe tools\verify_browser.py`。当前 Microsoft Edge 无头运行在加载检查时超时，完整自动检查尚未通过；旧版记录保存在 `artifacts/browser-verification.previous.json`。实际浏览器操作使用鼠标，Godot 输入检查另行覆盖触屏事件；真实手机体验仍需真机验证。

`tools/map_builder.gd` 保留地图布局和材质的确定性生成逻辑，并加入草莓实例。重新生成地图会覆盖场景文件，手动调整后请先保存副本。

参考官方接口：[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[Web 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。核对后的文档缓存位于 `.firecrawl/godot-characterbody3d.md`、`.firecrawl/godot-web-export.md`。

