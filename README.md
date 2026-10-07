# 水果乱斗 · Boomerang Arena

Godot 4.7.2 的 3D 食物角色乱斗游戏。进入游戏先设置 1–5 个人机、简单 / 普通 / 困难三档难度、存活加分 / 击杀计分两种计分方式，以及自己和每个人机的角色，再点击“开始游戏”。草莓、茄子、南瓜、胡萝卜、蓝莓和西瓜都可作为玩家或人机，也可以重复选择；分数按参赛席位独立累计。六种角色都有真实网格、立体五官、两颗圆球脚、碰撞体、转身和脚步动画。

设置页的“计分方式”可选择以下两种规则，默认保持“存活加分”：

- **存活加分**：最后一个角色连续存活 1 秒后获得 1 分；如果全员淘汰则不加分，击杀本身不计分。
- **击杀计分**：每真正击杀一名对手，击杀者立即获得 1 分；玩家和人机使用相同规则，一刀击杀多人按人数加分。角色死亡或全员淘汰都保留已获得的击杀分，最后存活者不额外加分。

每一小局所有角色分散在地图的安全位置，出生点彼此相距至少 7 米。剩最后一个角色后继续运行 1 秒，全员淘汰则立即结束。小局结束后暂停战斗，显示每个席位的累计分数和本局新增分数；点击“下一小局”复活全部角色、重新分散出生，分数继续累计。两种模式都是任意席位先到 10 分即整场获胜；击杀模式达到 10 分立即停止战斗，即使其他对手仍存活。点击“再玩一场”回到设置，保留计分方式选择，重新开始时分数归零。

人机在整张地图追击附近的存活对手，沿安全格路径绕过岩石，也会互相砍击。人机之间相向挥砍最多淘汰一个：先出刀者先结算，完全同时出刀则随机决定先手，被淘汰的人机不能继续反杀另一人机；对刀回弹只在有玩家参与时发生。简单、普通、困难的移动速度分别为 6.5 / 8.0 / 9.0，反应等待分别为 0.56 / 0.30 / 0.14 秒，攻击间隔分别为 1.15 / 0.80 / 0.48 秒并附少量随机延迟；所有角色仍然一击淘汰。玩家淘汰后镜头跟随仍存活的人机，等待真实战斗决出小局结果。

三档人机都会独立跳跃：在直线通路足够宽、距离足够远时向对手跳进，发现对手朝自己起手砍击时尝试向侧面或后方跳开。每个人机在一小局内，对每个其他参赛角色最多成功闪避两次，玩家和其他人机分别计数；相同食物模型的不同参赛者也各自拥有两次额度。次数记在实际攻击者身上，与当前追击目标无关；只有成功起跳才消耗一次，第三次闪避会被拒绝。砍击、走动、换目标、冷却结束、追击跳跃和本局内角色复位都不清空次数，进入下一小局才统一重置。人机和玩家共用 5.70 距离、0.32 秒的跳跃动作，起跳后锁定方向，全程保留岩石和角色碰撞；跳跃本身不造成伤害。起跳前检查整条路线和落点边界，近距离仍使用原有跳斩。简单、普通、困难的跳跃间隔分别为 2.8 / 2.0 / 1.2 秒并附少量随机延迟，避砍反应分别为 0.08 / 0.05 / 0.025 秒；下一小局清除跳跃和 AI 决策状态。

茄子有紫色身体和绿色叶帽；胡萝卜有渐尖的橙色身体、纹路和绿叶；南瓜有橙色分瓣、绿色瓜柄和叶片；蓝莓有圆润的蓝紫身体和顶部五角花萼；西瓜是有厚度的红瓤切片，带黑籽、浅色内皮和绿色瓜皮。六种角色各有两颗同色同大的圆球手，左手和右手对称地放在身体两侧，右手握着与角色配色一致的立体圆角 V 形回旋镖：草莓红、茄子紫、南瓜橙、胡萝卜橙、蓝莓蓝紫、西瓜红绿。两只手都随身体一起转身和走动。键盘和摇杆只控制设置页里“你”所选的角色。

## 直接试玩

[在线试玩（GitHub Pages）](https://ruofei6666.github.io/Boomerang-Fu/)。电脑用 WASD / 方向键，手机用左下角摇杆；在线版无需电脑保持开机。

### 手机安装、离线玩和更新

普通手机浏览器进入时会显示安装教程；从已安装的 App 进入时跳过。右上角「安装 / 离线」可以随时重新打开教程，打开时整场比赛暂停，关闭后继续。

- **安卓**：用 Chrome 打开 HTTPS 游戏网址 → 右上角「⋮」→「安装应用」，或「安装并创建快捷方式 → 安装」→ 回到桌面点击「水果乱斗」。
- **iPhone / iPad**：用 Safari 打开 →「共享」→「添加到主屏幕」→ 如果出现「作为网页 App 打开」，保持开启 →「添加」→ 从桌面图标进入。系统状态栏和手势条可能仍保留。
- **离线玩**：第一次保持联网，等教程里的状态显示「离线可玩」。完整包约 40 MB，包含引擎、角色、地图、音效和教程。从桌面 App 进入后也确认一次此状态，再断网即可与人机对战。清理网站数据或系统回收缓存后需重新下载；「检查更新」会补齐缺失资源。
- **更新**：联网打开、恢复联网或从后台返回会检查新版本，也可点「检查更新」。新版完整下载后入口显示「有新版本」；点击「更新并重开」才重新加载，当前比赛分数会清零。点「稍后」继续比赛；下载失败保留旧版离线包。

安装与离线缓存需要 **HTTPS**（本机 localhost 也可测试）。普通 `http://192.168.x.x:8060` 局域网地址仍可在线试玩，但不能安装离线 App。微信 / QQ 内请先选择在浏览器中打开。

教程步骤参考 [Chrome 官方指引](https://support.google.com/chrome/answer/9658361?hl=zh-Hans&co=GENIE.Platform%3DAndroid) 和 [Apple 官方指引](https://support.apple.com/zh-cn/guide/iphone/iphea86e5236/ios)。

电脑双击 `run-map.cmd` 打开原生游戏，先设置参赛角色并点击开始，再使用 **WASD / 方向键** 控制自己的角色。

双击 `run-web.cmd` 启动浏览器版本，也可以打开 <http://localhost:8060>。手机与电脑连接同一 Wi-Fi 后，在手机浏览器打开电脑 Wi-Fi 地址的 8060 端口，例如 <http://192.168.0.197:8060>。Wi-Fi 地址可能变化；电脑必须保持开机，试玩服务必须运行。

手机拖动左下角摇杆调整移动方向，越过中心死区后立即以最大走动速度移动，起步、推动幅度和换向都不会主动降低速度，松手停下。摇杆上方的操作提示已移除。原来放大到 123% 的视角作为当前 100% 基准；手机默认放大到 120%，横竖屏都会按此缩放比例适配视野。电脑默认保持 100%。右上角视角按钮已移除，电脑仍可按 R 恢复当前设备默认视野。右上角“返回设置”结束当前整场比赛，重新开始时分数归零。右侧砍击与跳跃图标下移，与摇杆底部对齐。设置页和计分页支持手机横竖屏；角色较多时可滚动列表。摇杆也支持电脑鼠标拖动。

按 **J**，或用另一根手指点右侧带挥砍轨迹的圆形图标，执行跳斩：向前跳约三米（距离设为 2.85，是上一版 1.90 的 1.5 倍，0.16 秒），落地后挥动回旋镖（0.14 秒），随后后摇 0.28 秒。跳跃准备和后摇阶段不能重复攻击；攻击方向在起跳时锁定。

按住 **L**，或按住右侧 **“投 L”** 图标，角色立即停在原地并显示瞄准箭头；用 **WASD / 方向键 / 左侧摇杆** 调整方向，松开投掷键或投掷手指时才飞出回旋镖，并播放原来的挥砍音效。没有方向输入时保留最后瞄准方向。手机的摇杆手指与投掷手指分别记录，松开投掷手指不会抢走摇杆；触摸取消、失焦和暂停只取消瞄准，避免误投。

回旋镖以 **24 米/秒** 飞行，岩石、低矮石墙和地图边缘都按碰撞法线等角反弹，速度保持不变。累计飞行路程达到地图长边 **38 米** 后落地停住，显示拾取标记；反弹后的路程也计入射程。命中使用与近战相同的切开两半、同色圆点、切水果音效和击杀计分。投掷后空手时仍能移动和独立跳跃，但不能砍击、预输入砍击或再次投掷；走近自己已经停住的回旋镖即可自动拾回并恢复攻击。回旋镖不会自动飞回手里。下一小局恢复所有人的武器，并清理地图上的飞镖。

六种食物人机和三档难度都会在有直线通路的中远距离瞄准投掷，按照目标速度预判方向，较高难度反应与预判更快。空手人机追踪自己的武器，利用同一张地图路径绕过岩石，停住后拾回，再继续攻击。近距离继续使用跳斩，远距离追赶与逐对手两次闪避额度仍然保留。

手机竖屏时三个动作图标从上到下排列为“投 L”“跳 K”“砍 J”；横屏时并排，较窄横屏将投掷图标放在砍击上方。三个图标与左下角摇杆分别接收触摸。

按 **K**，或点右侧带向上箭头和圆脚的 **“跳 K”** 图标，沿角色面朝方向向前跳 **5.70**，恰好是砍击前移距离 **2.85** 的两倍，持续 **0.32 秒**。独立跳跃只移动，不挥砍；起跳时锁定方向，落地后恢复走动。跳跃过程中可以按 **J** 或点 **砍击图标** 预输入一次砍击，落地后自动执行原有的跳斩；松开按键或图标仍保留预输入，连续按只记录一次。重开、死亡或失焦会清除预输入。跳跃和砍击不能互相打断，岩石、其他角色和地图边界会阻挡前进。手机竖屏时跳跃图标位于砍击图标上方，横屏时两者并排；摇杆和动作图标分别记录手指，可以边拖摇杆边用另一根手指跳跃。

正面挥砍命中即死亡，播放切水果声；角色原有网格被裁成两半，切口封面封住实体身体，两半向附近飞散，同时散出 26 颗角色颜色的小圆点。西瓜碎块保留红瓤、内皮和瓜皮的原有配色。玩家与对手相向攻击时优先判定对刀，播放对刀声并产生火花，双方在 0.20 秒内弹回各自起跳前的位置，再经过后摇恢复。人机互砍按出刀先后结算，死亡的一方不能继续反杀，避免双人交锋同时死亡。岩石可阻挡跳跃和攻击。

进入下一小局时复活全部角色，并清理碎块、圆点、跳跃状态和预输入砍击。音效位于 `assets/audio/`，来源与截取区间记录在 `assets/audio/source.json`；砍击用此前提取的 0.23 秒片段，对刀和切开根据用户对 25–28 秒原声的标注重新定位，分别截取 24.640–25.430 秒和 25.820–26.085 秒。对刀保留原始立体声；切开先用本地 MDX 模型分离重叠人声，只保留用户指定的第二下，再保持双声道、对齐音量并加极短淡入淡出。

| 操作 | 功能 |
| --- | --- |
| WASD / 方向键 | 按屏幕方向走动 |
| 手机摇杆 / 鼠标拖动摇杆 | 调整方向，以最大走动速度移动；松手停止 |
| J / 右侧挥砍轨迹图标 | 向前小跳、挥镖砍击和后摇 |
| L / 右侧投掷图标 | 按住原地瞄准，WASD / 摇杆转向，松开投掷；停住后走近拾回 |
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
- `scenes/eggplant_npc.tscn`、`scenes/pumpkin_npc.tscn`、`scenes/carrot_npc.tscn`、`scenes/blueberry_npc.tscn`、`scenes/watermelon_npc.tscn`：可独立查看、摆放和配置的人机角色场景。
- `scripts/food_character_controller.gd`：六个角色共用的碰撞、跳跃、跳斩、转身和球形脚动画。
- `scripts/player_controller.gd`：玩家所选角色的键盘、摇杆和按镜头方向移动。
- `scripts/wander_controller.gd`：三档自由混战 AI，追击所有存活对手、跳跃追赶和避砍、沿共用路径绕过岩石、动态碰撞避让；保留独立散步回归模式。
- `scripts/match_controller.gd`：参赛配置、两种计分方式、按席位累计击杀分、存活 1 秒判定、分散出生、手动下一局和 10 分胜利。
- `scripts/interface.gd`、`scripts/score_track.gd`：设置页、逐席位计分页、十个得分点，以及手机横竖屏布局。
- `scripts/combat_controller.gd`：统一结算对刀、正面命中、真实击杀归属和一次性音效。
- `scripts/combat_effects.gd`、`assets/effects/cut_half.gdshader`：原角色网格的两半、切面、同色圆点和火花。
- `scripts/melee_button.gd`：可与摇杆同时使用的砍击图标和多指触控。
- `scripts/jump_button.gd`：独立跳跃图标，复用动作按钮的多指触控与取消处理。
- `scripts/throw_button.gd`：按住瞄准与释放投掷的独立触点；取消、失焦不会误投。
- `scripts/boomerang_projectile.gd`：连续碰撞反弹、38 米累计路程、飞行命中、落地标记与主人拾取。
- `tools/build_food_characters.gd`、`tools/food_character_builder.gd`：确定性生成五种人机角色的网格和独立场景；可在命令末尾用 `-- pumpkin blueberry watermelon` 只重新生成指定角色。
- `tools/held_boomerang_builder.gd`：六个角色共用的两颗圆球手、右手回旋镖网格和各自配色；生成后保存在独立场景里。
- `scripts/virtual_joystick.gd`：手机触屏和鼠标摇杆。
- `scripts/camera_controller.gd`：跟随、缩放、转向和地图拖动。
- `assets/fonts/noto_sans_sc_ui.ttf`：按界面文字裁剪的 Noto Sans SC，随附 OFL 许可证。
- `tools/serve_web.mjs`：仅提供 `build/web` 里的试玩文件，监听 8060 端口。
- `artifacts/strawberry_chibi.png`：先前生成的角色参考图。
- `artifacts/verification.json`：Godot 实际输入和物理验证记录。
- `artifacts/wanderers-verification.json`：连续 20 秒的五个人机散步与碰撞验证记录。
- `artifacts/food_characters.png`：由 Godot 实际渲染的六个角色近景合照。
- `artifacts/browser-verification.json`：最近一次浏览器自动验证的状态。
- `artifacts/browser-manual-verification.json`：实际浏览器的局域网、摇杆、重置和横竖屏验证记录。

## 构建和验证

本次发布通过 **546 项回归检查**：原生移动 36 项、人机移动 50 项、战斗与跳跃 97 项、比赛 76 项、人机跳跃 143 项、投掷 52 项，共 454 项；砍击与跳跃网页检查 27 项、投掷网页检查 16 项、比赛网页检查 49 项，共 92 项。投掷覆盖按住原地瞄准、正常松手只投一次、键盘和摇杆转向、斜角等速反弹、低矮石墙阻挡、38 米累计射程、落地拾取、六种人机投掷与寻路拾取、真实切开和击杀计分、10 分即时停止，以及失焦、取消触摸与横竖屏三个动作图标。网页取消事件在引擎输入前按触点处理，取消投掷不会误发射，也不清除其他手指的正常操作。

投掷原生检查运行 `tools/verify_throw.gd`，结果保存到 `artifacts/throw-verification.json`；网页检查运行 `python tools/verify_throw_browser.py --software-rendering`，结果保存到 `artifacts/throw-browser-verification.json`。网页检查读取实际导出游戏状态与 WebAudio 输出，并模拟浏览器触摸事件；截图保存为 `artifacts/throw_browser_*.png`。手机触控与布局已通过浏览器模拟，尚未做真机验证。本地 Web 包、局域网实际提供的包和 `docs/index.pck` 已逐包核对 SHA-256；线上包使用 `tools/verify_pages.py` 对照发布清单校验。

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
godot --headless --path . --fixed-fps 60 --script res://tools/verify_throw.gd
godot --headless --path . --export-release Web build/web/index.html
node tools/patch_web_export.mjs
node tools/prepare_pages.mjs
.venv\Scripts\python.exe tools\verify_pwa_browser.py --software-rendering
.venv\Scripts\python.exe tools\verify_match_browser.py --software-rendering
python tools/verify_throw_browser.py --software-rendering
godot --path . -- --capture-ui
godot --path . --script res://tools/capture_food_characters.gd
```

Web 使用 Compatibility 渲染器和单线程模板，导出预设保存在 `export_presets.cfg`。没有模板时，可以运行 `python tools/fetch_web_template.py`，再运行同一命令并添加 `--template web_nothreads_debug.zip`；脚本从 Godot 官方发布包中仅下载所需的 Web 模板，验证 ZIP CRC。

地图材质已按先前的浅绿地面、蓝紫岩石截图校准 Compatibility 的亮度，并关闭地图材质的镜面高光，避免网页版本过曝发白。角色材质和灯光保持原有设置。

每次重新导出后运行 `node tools/patch_web_export.mjs`。它为 Godot 4.7.2 的 Web 音频初始化加上能力检查；HTML 启动页在 HTTP 局域网页面明确选择引擎的 ScriptProcessor 后备方式，HTTPS 页面保留 AudioWorklet。三种短 WAV 音效会随场景一起打包。此兼容修改核对了官方源文件 `.firecrawl/godot-web-audio-js.md`、`.firecrawl/godot-web-audio-header.md`。

该补丁同时运行 `tools/prepare_web_pwa.mjs`，复制 `web/` 的教程、安装清单和图标，并生成带内容版本及完整 SHA-256 资源清单的 `sw.js`；`prepare_pages.mjs` 将这些文件一并打包到 `docs/`。自定义 worker 会核对每个下载文件，完整成功才启用新版，并只清理本游戏当前路径下的旧缓存，保护同域其他游戏。Godot 自带的自动 PWA 导出保持关闭，以免与此 worker 冲突。图标来源为已有 `assets/icons/ios.png`；需要重做尺寸时运行 `godot --headless --path . --script res://tools/prepare_pwa_icons.gd`。

PWA 检查运行 `.venv\Scripts\python.exe tools\verify_pwa_browser.py --software-rendering`，在独立浏览器数据目录和仓库子路径下验证安装条件、安卓 / 苹果教程、横竖屏、离线重启后的真实游戏、更新确认、失败回退和其他项目缓存保护；结果写入 `artifacts/pwa-browser-verification.json`。手机检查使用浏览器模拟，真机的安装菜单、系统缓存回收和性能仍需在手机上体验。

Godot 草莓输入和物理检查通过 36 项，人机移动检查通过 50 项，战斗与跳跃检查通过 97 项，共 183 项。检查覆盖 J / K 键、摇杆与另一根手指同时砍击或跳跃、跳跃中键盘与触控预输入砍击、落地后仅执行一次、预输入在重开/死亡/失焦时清除、实测 2.85 / 5.70 距离与两倍比例、不同朝向、跳跃后才命中、动作锁定、死亡两半与角色配色、玩家对刀公平性及精确回弹、人机同时或先后互砍只淘汰一个且死亡后不能反杀、障碍和边界阻挡、人机攻击、空中重开与失焦保护。移动回归检查关闭近战 AI 和人机碰撞，以独立检查原有操作。

浏览器自动检查使用 Python Playwright，运行 `.venv\Scripts\python.exe tools\verify_browser.py`；无头硬件 WebGL 不可用时添加 `--software-rendering` 使用 SwiftShader。检查包括三个人机自行走动、草莓等待玩家输入、键盘和摇杆移动、松手停止、回到起点和横竖屏布局。最近结果保存在 `artifacts/browser-verification.json`；真实手机体验仍需真机验证。

战斗与跳跃网页检查运行 `.venv\Scripts\python.exe tools\verify_combat_browser.py --url http://127.0.0.1:8060 --software-rendering`，最新通过 27 项，无浏览器错误。检查包括桌面 J / K 键、实测 2.85 / 5.70 距离与两倍比例、跳跃落地停止、键盘与触控预输入砍击及落地后仅执行一次、真实 WebAudio 样本启动、手机多指摇杆加砍击或跳跃、模拟鼠标防重复、取消触摸，以及横竖屏两个动作图标的布局与不重叠。输入检查通过专用验证链接固定人机并关闭其碰撞，正常试玩不受影响；人机战斗与角色碰撞由原生检查覆盖。结果保存在 `artifacts/combat-browser-verification.json`，网页截图为 `artifacts/combat_browser_*.png`。音频文件检查为 `artifacts/audio-verification.json`。真实手机的性能和听感仍需真机体验。

`tools/map_builder.gd` 保留地图布局和材质的确定性生成逻辑，并加入草莓实例。重新生成地图会覆盖场景文件，手动调整后请先保存副本。

比赛流程原生验证运行 `tools/verify_match.gd`，最新 76 项通过，覆盖两种计分方式的界面选择、真实一刀多杀、击杀归属、死亡后保留分数、全灭仍保留击杀分、切回存活模式、10 分即时胜利，以及原有界面配置、六种模型由玩家控制、最多六个席位、出生点安全与间距、连续存活 1 秒、计分唯一性、手动下一局、换角色后的切面与圆点配色和玩家淘汰后的真实人机对战。最新结果保存在 `artifacts/match-verification.json`。本次同时复测移动 36 项、人机散步 50 项、人机跳跃与逐对手闪避 143 项、战斗 97 项和投掷 52 项，原生合计 454 项通过。

人机跳跃验证运行 `tools/verify_ai_jump.gd`，最新 143 项通过，使用真实地图和物理帧检查四种模型的 5.70 距离、锁定方向、抬起和落地、三档自主追赶与实际避砍、空中冷却、墙体和角色碰撞、边界拒绝、死亡和暂停保护及重开复位。逐对手闪避检查对三种难度分别验证：面对玩家和另一名同模型人机都能实际避砍两次，各自第三次被拒绝；追击目标与攻击者不同时仍正确归属次数；换目标、冷却、追击跳跃、实际砍击与本局复位不恢复额度；没有攻击者或受障碍、边界、暂停阻止的闪避不消耗额度；下一小局统一清零、恢复实际避砍，空中重开也能清零。结果保存在 `artifacts/ai-jump-verification.json`。

网页检查运行 `tools/verify_match_browser.py --software-rendering`，最新 49 项通过，无浏览器或 Godot 脚本错误。检查实际点击两种计分方式、角色设置和继续按钮，覆盖真实击杀计分、10 分即时胜利、手机横竖屏与胜利页，并确认三档人机在真实混战中自主跳跃、分别报告对每个其他参赛者的闪避次数且各不超过两次；仅专用 `?verify=1&match_testing=1` 链接允许测试注入死亡和布置真实挥砍。预设计分场景暂停角色物理更新，避免人机提前投掷影响测试布置；独立的三档混战检查恢复全部角色的物理更新。命中、击杀归属、计时、计分、状态转换和界面均运行真实逻辑。结果保存在 `artifacts/match-browser-verification.json`，截图为 `artifacts/match_*.png`，人机跳跃的网页对战截图为 `artifacts/ai_jump_web_*.png`。手机检查使用浏览器触控模拟，尚未做真机验证。

专用网页验证链接会报告每个人机对其他参赛者的本局累计闪避次数（`dodges_by_opponent`）。网页混战检查核对每个对手分别有记录且次数在 0–2 之间；三档第三次拒绝、砍击后额度不恢复和下一局清零由上述原生检查覆盖。

参考官方接口：[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[Web 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。核对后的文档缓存位于 `.firecrawl/godot-characterbody3d.md`、`.firecrawl/godot-web-export.md`。

## iOS 打包工程

运行 `python tools/package_ios.py --godot 本机Godot路径` 可独立导出 iOS Release 资源和 Xcode 工程，再生成 `build/ios/BoomerangArena-iOS-Xcode.zip`。脚本仅下载 Godot 4.7.2 官方模板中的 `ios.zip`，检查工程、引擎库与资源包启动，并逐文件验证 ZIP 的 SHA-256。

该 ZIP 供 Mac 接手，包含 Xcode 工程、当前游戏源码和 Mac 构建脚本；`UNSIGNED00` 是待替换的 Team ID 占位值。最终 `.ipa` 需要在装有 Xcode 的 Mac 上用自己的 Apple 账号、证书及描述文件构建和签名。详细操作见 [iOS 打包说明](ios/README.md)。

