extends Node3D
## 将 3D 草莓、镜头和虚拟摇杆连接到同一套移动控制。

@onready var player: CharacterBody3D = $StrawberryPlayer
@onready var camera_rig: Node3D = $CameraRig

var browser_verification: bool = false
var report_timer: float = 0.0
var web_blur_callback: JavaScriptObject
var web_focus_callback: JavaScriptObject
var web_visibility_callback: JavaScriptObject
var web_window: JavaScriptObject
var web_canvas: JavaScriptObject


func _ready() -> void:
	player.camera_rig = camera_rig
	player.joystick = $Interface/Root/VirtualJoystick
	camera_rig.follow_target = player
	camera_rig.reset_view()
	if OS.has_feature("web"):
		browser_verification = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('verify')", true))
		var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		var browser_document: JavaScriptObject = JavaScriptBridge.get_interface("document")
		web_window = browser_window
		web_canvas = browser_document.getElementById("canvas")
		web_blur_callback = JavaScriptBridge.create_callback(_web_blur)
		web_focus_callback = JavaScriptBridge.create_callback(_web_focus)
		web_visibility_callback = JavaScriptBridge.create_callback(_web_visibility)
		browser_window.addEventListener("blur", web_blur_callback)
		browser_window.addEventListener("focus", web_focus_callback)
		browser_document.addEventListener("visibilitychange", web_visibility_callback)
	if "--capture" in OS.get_cmdline_user_args() or "--capture-ui" in OS.get_cmdline_user_args():
		_capture_preview.call_deferred()


func _capture_preview() -> void:
	# 从 Godot 实际渲染的 viewport 保存预览，避免示意图与项目不一致。
	var include_interface: bool = "--capture-ui" in OS.get_cmdline_user_args()
	$Interface.visible = include_interface
	for index in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output_path: String = "res://artifacts/strawberry_game_ui.png" if include_interface else "res://artifacts/strawberry_game.png"
	var result: Error = screenshot.save_png(output_path)
	if result != OK:
		push_error("Failed to save viewport screenshot: %s" % error_string(result))
		get_tree().quit(1)
	else:
		print("CAPTURE_SAVED: ", output_path)
		get_tree().quit()


func _process(delta: float) -> void:
	# 仅验证链接启用，供浏览器测试读取真实物理位置和触控状态。
	if not browser_verification:
		return
	report_timer += delta
	if report_timer < 0.1:
		return
	report_timer = 0.0
	var stick: Control = player.joystick
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var pixels := Vector2(DisplayServer.window_get_size())
	pixels = Vector2(float(web_window.innerWidth), float(web_window.innerHeight))
	var screen_ratio: Vector2 = pixels / logical
	var center: Vector2 = (stick.global_position + stick.size * 0.5) * screen_ratio
	var state := {
		"position": [player.position.x, player.position.y, player.position.z],
		"velocity": [player.velocity.x, player.velocity.z],
		"feet": [player.left_foot.position.y, player.right_foot.position.y],
		"joystick": [stick.movement.x, stick.movement.y],
		"touch": stick.active_touch,
		"stick_center": [center.x, center.y],
		"stick_radius": stick.radius * screen_ratio.x,
		"camera": [camera_rig.position.x, camera_rig.position.z],
		"yaw": camera_rig.yaw,
		"viewport": [logical.x, logical.y]
	}
	web_canvas.setAttribute("data-game-state", JSON.stringify(state))


func _web_blur(_arguments: Array) -> void:
	player.has_focus = false
	player.velocity = Vector3.ZERO
	player.joystick.release()
	camera_rig._end_drag()
	# 浏览器外松开按键时收不到 keyup；主动释放，回来后不会继续走。
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E]:
		var released := InputEventKey.new()
		released.keycode = code
		released.physical_keycode = code
		released.pressed = false
		Input.parse_input_event(released)


func _web_focus(_arguments: Array) -> void:
	player.has_focus = true


func _web_visibility(_arguments: Array) -> void:
	if bool(JavaScriptBridge.get_interface("document").hidden):
		_web_blur([])
	else:
		_web_focus([])

