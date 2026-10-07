# 水果乱斗 · Boomerang Arena

Godot 4.7.2 的 3D 食物角色乱斗游戏。进入游戏先设置 1–5 个人机、简单 / 普通 / 困难三档难度，以及自己和每个人机的角色，再点击“开始游戏”。草莓、茄子、甜甜圈和胡萝卜都可作为玩家或人机，也可以重复选择；分数按参赛席位独立累计。四种角色都有真实网格、立体五官、两颗圆球脚、碰撞体、转身和脚步动画。

每一小局所有角色分散在地图的安全位置，出生点彼此相距至少 7 米。剩最后一个角色后继续运行 1 秒；它保持存活就获得 1 分，如果所有角色都死了则立即结束，所有分数不变。小局结束后暂停战斗并显示每个角色的当前分数，点击“下一小局”复活全部角色、重新分散出生，分数继续累计。任意席位先到 10 分后显示整场获胜，可点击“再玩一场”回到设置。

人机在整张地图追击附近的存活对手，沿安全格路径绕过岩石，也会互相砍击。人机之间相向挥砍最多淘汰一个：先出刀者先结算，完全同时出刀则随机决定先手，被淘汰的人机不能继续反杀另一人机；对刀回弹只在有玩家参与时发生。简单、普通、困难的移动速度分别为 6.5 / 8.0 / 9.0，反应等待分别为 0.56 / 0.30 / 0.14 秒，攻击间隔分别为 1.15 / 0.80 / 0.48 秒并附少量随机延迟；所有角色仍然一击淘汰。玩家淘汰后镜头跟随仍存活的人机，等待真实战斗决出小局结果。

三档人机都会独立跳跃：在直线通路足够宽、距离足够远时向对手跳进，发现对手朝自己起手砍击时尝试向侧面或后方跳开。人机和玩家共用 5.70 距离、0.32 秒的跳跃动作，起跳后锁定方向，全程保留岩石和角色碰撞；跳跃本身不造成伤害。起跳前检查整条路线和落点边界，近距离仍使用原有跳斩。简单、普通、困难的跳跃间隔分别为 2.8 / 2.0 / 1.2 秒并附少量随机延迟，避砍反应分别为 0.08 / 0.05 / 0.025 秒；下一小局清除跳跃和 AI 决策状态。

茄子有紫色身体和绿色叶帽；甜甜圈有真正贯穿的圆孔、粉色糖霜和彩糖；胡萝卜有渐尖的橙色身体、纹路和绿叶。四种角色各有两颗同色同大的圆球手，左手和右手对称地放在身体两侧，右手握着与角色配色一致的立体圆角 V 形回旋镖：草莓红、茄子紫、甜甜圈粉、胡萝卜橙。两只手都随身体一起转身和走动。键盘和摇杆只控制设置页里“你”所选的角色。

## 直接试玩

[在线试玩（GitHub Pages）](https://ruofei6666.github.io/Boomerang-Fu/)。电脑用 WASD / 方向键，手机用左下角摇杆；在线版无需电脑保持开机。

电脑双击 `run-map.cmd` 打开原生游戏，先设置参赛角色并点击开始，再使用 **WASD / 方向键** 控制自己的角色。

双击 `run-web.cmd` 启动浏览器版本，也可以打开 <http://localhost:8060>。手机与电脑连接同一 Wi-Fi 后，在手机浏览器打开电脑 Wi-Fi 地址的 8060 端口，例如 <http://192.168.0.197:8060>。Wi-Fi 地址可能变化；电脑必须保持开机，试玩服务必须运行。

手机拖动左下角摇杆调整移动方向，越过中心死区后立即以最大走动速度移动，起步、推动幅度和换向都不会主动降低速度，松手停下。摇杆上方的操作提示已移除。原来放大到 123% 的视角作为当前 100% 基准；手机默认放大到 120%，横竖屏都会按此缩放比例适配视野。电脑默认保持 100%。右上角视角按钮已移除，电脑仍可按 R 恢复当前设备默认视野。右上角“返回设置”结束当前整场比赛，重新开始时分数归零。右侧砍击与跳跃图标下移，与摇杆底部对齐。设置页和计分页支持手机横竖屏；角色较多时可滚动列表。摇杆也支持电脑鼠标拖动。

按 **J**，或用另一根手指点右侧带挥砍轨迹的圆形图标，执行跳斩：向前跳约三米（距离设为 2.85，是上一版 1.90 的 1.5 倍，0.16 秒），落地后挥动回旋镖（0.14 秒），随后后摇 0.28 秒。跳跃准备和后摇阶段不能重复攻击；攻击方向在起跳时锁定。

按 **K**，或点右侧带向上箭头和圆脚的 **“跳 K”** 图标，沿角色面朝方向向前跳 **5.70**，恰好是砍击前移距离 **2.85** 的两倍，持续 **0.32 秒**。独立跳跃只移动，不挥砍；起跳时锁定方向，落地后恢复走动。跳跃过程中可以按 **J** 或点 **砍击图标** 预输入一次砍击，落地后自动执行原有的跳斩；松开按键或图标仍保留预输入，连续按只记录一次。重开、死亡或失焦会清除预输入。跳跃和砍击不能互相打断，岩石、其他角色和地图边界会阻挡前进。手机竖屏时跳跃图标位于砍击图标上方，横屏时两者并排；摇杆和动作图标分别记录手指，可以边拖摇杆边用另一根手指跳跃。

正面挥砍命中即死亡，播放切水果声；角色原有网格被裁成两半，切口封面保留甜甜圈的洞，两半向附近飞散，同时散出 26 颗角色颜色的小圆点。玩家与对手相向攻击时优先判定对刀，播放对刀声并产生火花，双方在 0.20 秒内弹回各自起跳前的位置，再经过后摇恢复。人机互砍按出刀先后结算，死亡的一方不能继续反杀，避免双人交锋同时死亡。岩石可阻挡跳跃和攻击。

进入下一小局时复活全部角色，并清理碎块、圆点、跳跃状态和预输入砍击。音效位于 `assets/audio/`，来源与截取区间记录在 `assets/audio/source.json`；砍击用此前提取的 0.23 秒片段，对刀和切开根据用户对 25–28 秒原声的标注重新定位，分别截取 24.640–25.430 秒和 25.820–26.085 秒。对刀保留原始立体声；切开先用本地 MDX 模型分离重叠人声，只保留用户指定的第二下，再保持双声道、对齐音量并加极短淡入淡出。

| 操作 | 功能 |
| --- | --- |
| WASD / 方向键 | 按屏幕方向走动 |
| 手机摇杆 / 鼠标拖动摇杆 | 调整方向，以最大走动速度移动；松手停止 |
| J / 右侧挥砍轨迹图标 | 向前小跳、挥镖砍击和后摇 |
| K / 右侧跳跃图标 | 沿面朝方向跳 5.70，是砍击前移距离的两倍 |
| 滚轮 | 缩放 |
| Q / E | 转动镜头 |
| R | 恢复默认镜头 |
| 中键 / 右键拖动 | 自由查看地图，按 R 恢复跟随 |
| 下一小局 | 从计分页复活全部角色并重新分散出生，保留累计分数 |
| 返回设置 / 再玩一场 | 回到人机和角色设置；再次开始时分数归零 |
| F11 | 原生版全屏 |

斜向移动不会加速。所有角色都会被岩石挡住，并沿岩石侧面滑动；地图边缘有保护。触控有死区、单指控制、取消事件和失焦复位。

## 项目文件

- `scenes/stone_arena.tscn`：原有岩石庭院和草莓实例。
- `scenes/strawberry_player.tscn`：可在 Godot 编辑器中查看的独立 3D 草莓场景。
- `scenes/eggplant_npc.tscn`、`scenes/donut_npc.tscn`、`scenes/carrot_npc.tscn`：可独立查看、摆放和配置的人机角色场景。
- `scripts/food_character_controller.gd`：四个角色共用的碰撞、跳跃、跳斩、转身和球形脚动画。
- `scripts/player_controller.gd`：玩家所选角色的键盘、摇杆和按镜头方向移动。
- `scripts/wander_controller.gd`：三档自由混战 AI，追击所有存活对手、跳跃追赶和避砍、沿共用路径绕过岩石、动态碰撞避让；保留独立散步回归模式。
- `scripts/match_controller.gd`：参赛配置、分散出生、存活 1 秒判定、全灭平局、累计分数、手动下一局和 10 分胜利。
- `scripts/interface.gd`、`scripts/score_track.gd`：设置页、逐席位计分页、十个得分点，以及手机横竖屏布局。
- `scripts/combat_controller.gd`：统一结算对刀、正面命中和一次性音效。
- `scripts/combat_effects.gd`、`assets/effects/cut_half.gdshader`：原角色网格的两半、切面、同色圆点和火花。
- `scripts/melee_button.gd`：可与摇杆同时使用的砍击图标和多指触控。
- `scripts/jump_button.gd`：独立跳跃图标，复用动作按钮的多指触控与取消处理。
- `tools/build_food_characters.gd`、`tools/food_character_builder.gd`：确定性生成三个人机角色的网格和独立场景。
- `tools/held_boomerang_builder.gd`：四个角色共用的两颗圆球手、右手回旋镖网格和各自配色；生成后保存在独立场景里。
- `scripts/virtual_joystick.gd`：手机触屏和鼠标摇杆。
- `scripts/camera_controller.gd`：跟随、缩放、转向和地图拖动。
- `assets/fonts/noto_sans_sc_ui.ttf`：按界面文字裁剪的 Noto Sans SC，随附 OFL 许可证。
- `tools/serve_web.mjs`：仅提供 `build/web` 里的试玩文件，监听 8060 端口。
- `artifacts/strawberry_chibi.png`：先前生成的角色参考图。
- `artifacts/verification.json`：Godot 实际输入和物理验证记录。
- `artifacts/wanderers-verification.json`：连续 20 秒的三个人机散步与碰撞验证记录。
- `artifacts/food_characters.png`：由 Godot 实际渲染的四个角色近景合照。
- `artifacts/browser-verification.json`：最近一次浏览器自动验证的状态。
- `artifacts/browser-manual-verification.json`：实际浏览器的局域网、摇杆、重置和横竖屏验证记录。

## 构建和验证

GitHub Pages 发布源为 `main` 分支的 `/docs`。`prepare_pages.mjs` 将导出的游戏和所需许可证复制到 `docs/`，保留 `.nojekyll` 并生成 SHA-256 清单。更新网页版本时，重新导出、运行兼容补丁及复制脚本，再提交并推送 `main`；Pages 会自动发布。编译文件在仓库子路径内使用相对 URL。

将下面的 `godot` 替换为本机 Godot 可执行文件路径：

```powershell
godot --headless --path . --script res://tools/build_character.gd
godot --headless --path . --script res://tools/build_food_characters.gd
godot --headless --editor --path . --import
godot --headless --path . --script res://tools/verify_scene.gd
godot --headless --path . --script res://tools/verify_wanderers.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_combat.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_match.gd
godot --headless --path . --fixed-fps 60 --script res://tools/verify_ai_jump.gd
godot --headless --path . --export-release Web build/web/index.html
node tools/patch_web_export.mjs
node tools/prepare_pages.mjs
.venv\Scripts\python.exe tools\verify_match_browser.py --software-rendering
godot --path . -- --capture-ui
godot --path . --script res://tools/capture_food_characters.gd
```

Web 使用 Compatibility 渲染器和单线程模板，导出预设保存在 `export_presets.cfg`。没有模板时，可以运行 `python tools/fetch_web_template.py`，再运行同一命令并添加 `--template web_nothreads_debug.zip`；脚本从 Godot 官方发布包中仅下载所需的 Web 模板，验证 ZIP CRC。

地图材质已按先前的浅绿地面、蓝紫岩石截图校准 Compatibility 的亮度，并关闭地图材质的镜面高光，避免网页版本过曝发白。角色材质和灯光保持原有设置。

每次重新导出后运行 `node tools/patch_web_export.mjs`。它为 Godot 4.7.2 的 Web 音频初始化加上能力检查；HTML 启动页在 HTTP 局域网页面明确选择引擎的 ScriptProcessor 后备方式，HTTPS 页面保留 AudioWorklet。三种短 WAV 音效会随场景一起打包。此兼容修改核对了官方源文件 `.firecrawl/godot-web-audio-js.md`、`.firecrawl/godot-web-audio-header.md`。

Godot 草莓输入和物理检查通过 36 项，人机移动检查通过 34 项，战斗与跳跃检查通过 93 项，共 163 项。检查覆盖 J / K 键、摇杆与另一根手指同时砍击或跳跃、跳跃中键盘与触控预输入砍击、落地后仅执行一次、预输入在重开/死亡/失焦时清除、实测 2.85 / 5.70 距离与两倍比例、不同朝向、跳跃后才命中、动作锁定、死亡两半与四种角色配色、玩家对刀公平性及精确回弹、人机同时或先后互砍只淘汰一个且死亡后不能反杀、障碍和边界阻挡、人机攻击、空中重开与失焦保护。移动回归检查关闭近战 AI 和人机碰撞，以独立检查原有操作。

浏览器自动检查使用 Python Playwright，运行 `.venv\Scripts\python.exe tools\verify_browser.py`；无头硬件 WebGL 不可用时添加 `--software-rendering` 使用 SwiftShader。检查包括三个人机自行走动、草莓等待玩家输入、键盘和摇杆移动、松手停止、回到起点和横竖屏布局。最近结果保存在 `artifacts/browser-verification.json`；真实手机体验仍需真机验证。

战斗与跳跃网页检查运行 `.venv\Scripts\python.exe tools\verify_combat_browser.py --url http://127.0.0.1:8060 --software-rendering`，最新通过 27 项，无浏览器错误。检查包括桌面 J / K 键、实测 2.85 / 5.70 距离与两倍比例、跳跃落地停止、键盘与触控预输入砍击及落地后仅执行一次、真实 WebAudio 样本启动、手机多指摇杆加砍击或跳跃、模拟鼠标防重复、取消触摸，以及横竖屏两个动作图标的布局与不重叠。输入检查通过专用验证链接固定人机并关闭其碰撞，正常试玩不受影响；人机战斗与角色碰撞由原生检查覆盖。结果保存在 `artifacts/combat-browser-verification.json`，网页截图为 `artifacts/combat_browser_*.png`。音频文件检查为 `artifacts/audio-verification.json`。真实手机的性能和听感仍需真机体验。

`tools/map_builder.gd` 保留地图布局和材质的确定性生成逻辑，并加入草莓实例。重新生成地图会覆盖场景文件，手动调整后请先保存副本。

比赛流程原生验证运行 `tools/verify_match.gd`，46 项通过，覆盖界面配置、四种模型由玩家控制、最多六个席位、出生点安全与间距、连续存活 1 秒、计分唯一性、全灭平局、保留分数和角色、手动下一局、10 分获胜、换角色后的切面与圆点配色，以及玩家淘汰后的真实人机对战。结果保存在 `artifacts/match-verification.json`。加上原有移动、人机散步和战斗检查，原生合计 209 项通过。

人机跳跃验证运行 `tools/verify_ai_jump.gd`，56 项通过，使用真实地图和物理帧检查四种模型的 5.70 距离、锁定方向、抬起和落地、三档自主追赶与实际避砍、空中冷却、墙体和角色碰撞、边界拒绝、死亡和暂停保护及重开复位。结果保存在 `artifacts/ai-jump-verification.json`。本次同时复测移动 36 项、散步 34 项、战斗 93 项和比赛 46 项，原生合计 265 项通过。

网页检查运行 `tools/verify_match_browser.py --software-rendering`，27 项通过，实际点击设置和继续按钮、检查手机横竖屏与胜利页，并确认三档人机在真实混战中自主跳跃；仅专用 `?verify=1&match_testing=1` 链接允许测试注入死亡，计时、计分、状态转换和界面均运行真实逻辑。加上原有战斗、跳跃、音效和多指触控检查，网页合计 54 项通过，无脚本错误。结果保存在 `artifacts/match-browser-verification.json`，截图为 `artifacts/match_*.png`，人机跳跃的网页对战截图为 `artifacts/ai_jump_web_*.png`；横屏下六个角色的选择项和分数可完整展示，额外布局记录在 `artifacts/compact-layout-verification.json`。手机检查使用浏览器触控模拟，尚未做真机验证。

参考官方接口：[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[Web 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。核对后的文档缓存位于 `.firecrawl/godot-characterbody3d.md`、`.firecrawl/godot-web-export.md`。

