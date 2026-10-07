extends Node3D
## 连接玩家、镜头、战斗和整场比赛流程。

const COMBAT_SCRIPT = preload("res://scripts/combat_controller.gd")
const MATCH_SCRIPT = preload("res://scripts/match_controller.gd")

@onready var player: CharacterBody3D = $StrawberryPlayer
@onready var camera_rig: Node3D = $CameraRig

var browser_verification: bool = false
var report_timer: float = 0.0
var web_blur_callback: JavaScriptObject
var web_focus_callback: JavaScriptObject
var web_visibility_callback: JavaScriptObject
var web_window: JavaScriptObject
var web_canvas: JavaScriptObject
var combat: Node3D
var match_controller: Node
var verification_mode: bool = false
var match_testing: bool = false


func _ready() -> void:
	bind_player(player)
	combat = Node3D.new()
	combat.name = "Combat"
	combat.set_script(COMBAT_SCRIPT)
	add_child(combat)
	if OS.has_feature("web"):
		browser_verification = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('verify')", true))
		var input_only: bool = browser_verification and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('input_only')", true))
		verification_mode = verification_mode or (browser_verification and (input_only or bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('movement_only')", true))))
		match_testing = browser_verification and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('match_testing')", true))
		# 移动回归检查可关闭近战 AI；普通试玩和战斗检查始终使用真实对战规则。
		if browser_verification and (input_only or bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('movement_only')", true))):
			for actor in combat.actors:
				if actor.is_in_group("wanderers"):
					actor.melee_enabled = false
					if input_only:
						# 输入检查固定人机并关闭其碰撞，重开后也不挤走玩家。
						actor.set_physics_process(false)
						actor.collision_layer = 0
						actor.collision_mask = 0
						actor.rest_collision_layer = 0
						actor.rest_collision_mask = 0
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
	match_controller = Node.new()
	match_controller.name = "Match"
	match_controller.set_script(MATCH_SCRIPT)
	match_controller.legacy_mode = verification_mode
	add_child(match_controller)
	if "--capture" in OS.get_cmdline_user_args() or "--capture-ui" in OS.get_cmdline_user_args():
		_capture_preview.call_deferred()


func bind_player(actor: CharacterBody3D) -> void:
	player = actor
	player.camera_rig = camera_rig
	player.joystick = $Interface/Root/VirtualJoystick
	camera_rig.follow_target = player
	camera_rig.reset_view()
	$Interface.bind_player(player)


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
	if match_testing:
		_run_match_test_command()
	var stick: Control = player.joystick
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var pixels := Vector2(DisplayServer.window_get_size())
	pixels = Vector2(float(web_window.innerWidth), float(web_window.innerHeight))
	var screen_ratio: Vector2 = pixels / logical
	var center: Vector2 = (stick.global_position + stick.size * 0.5) * screen_ratio
	var wanderers: Array[Dictionary] = []
	for actor in get_tree().get_nodes_in_group("wanderers"):
		wanderers.append({
			"name": actor.name,
			"position": [actor.position.x, actor.position.y, actor.position.z],
			"velocity": [actor.velocity.x, actor.velocity.z],
			"walking": actor.walking,
			"feet": [actor.left_foot.position.y, actor.right_foot.position.y],
			"alive": actor.alive,
			"attack_state": actor.attack_state
		})
	var state := {
		"physics_frame": Engine.get_physics_frames(),
		"position": [player.position.x, player.position.y, player.position.z],
		"velocity": [player.velocity.x, player.velocity.z],
		"feet": [player.left_foot.position.y, player.right_foot.position.y],
		"joystick": [stick.movement.x, stick.movement.y],
		"touch": stick.active_touch,
		"stick_center": [center.x, center.y],
		"stick_radius": stick.radius * screen_ratio.x,
		"camera": [camera_rig.position.x, camera_rig.position.z],
		"yaw": camera_rig.yaw,
		"alive": player.alive,
		"attack_state": player.attack_state,
		"attack_id": player.attack_id,
		"attack_buffered": player.attack_buffered,
		"jump_id": player.jump_id,
		"jump_origin": [player.jump_origin.x, player.jump_origin.y, player.jump_origin.z],
		"jump_distance": player.JUMP_DISTANCE,
		"hop_distance": player.HOP_DISTANCE,
		"jump_height": player.visual.position.y,
		"attack_origin": [player.attack_origin.x, player.attack_origin.y, player.attack_origin.z],
		"slash_visible": player.slash_visual.visible,
		"sound_counts": combat.sound_counts,
		"kills": combat.kills,
		"clashes": combat.clashes,
		"effects": combat.effects.pieces.size(),
		"attack_button": [($Interface.melee_button.global_position.x + $Interface.melee_button.size.x * 0.5) * screen_ratio.x, ($Interface.melee_button.global_position.y + $Interface.melee_button.size.y * 0.5) * screen_ratio.y],
		"attack_radius": $Interface.melee_button.size.x * 0.5 * screen_ratio.x,
		"jump_button": [($Interface.jump_button.global_position.x + $Interface.jump_button.size.x * 0.5) * screen_ratio.x, ($Interface.jump_button.global_position.y + $Interface.jump_button.size.y * 0.5) * screen_ratio.y],
		"jump_radius": $Interface.jump_button.size.x * 0.5 * screen_ratio.x,
		"wanderers": wanderers,
		"viewport": [logical.x, logical.y]
	}
	state["match"] = $Interface.verification_state()
	web_canvas.setAttribute("data-game-state", JSON.stringify(state))


func _run_match_test_command() -> void:
	# 仅专用验证链接开放死亡注入；计时、计分和页面按钮仍走真实比赛逻辑。
	var raw: String = str(web_canvas.getAttribute("data-match-command"))
	if raw.is_empty() or raw == "<null>" or raw == "null":
		return
	web_canvas.removeAttribute("data-match-command")
	var command: Variant = JSON.parse_string(raw)
	if not command is Dictionary or match_controller.phase != "playing":
		return
	if command.get("action") == "eliminate":
		for index in command.get("seats", []):
			if int(index) >= 0 and int(index) < combat.actors.size():
				combat.actors[int(index)].die()


func _web_blur(_arguments: Array) -> void:
	player.has_focus = false
	player.attack_requested = false
	player.attack_buffered = false
	player.velocity = Vector3.ZERO
	player.joystick.release()
	camera_rig._end_drag()
	# 浏览器外松开按键时收不到 keyup；主动释放，回来后不会继续走。
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E, KEY_J, KEY_K]:
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

