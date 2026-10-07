extends "res://scripts/food_character_controller.gd"
## 玩家选择的食物角色读取键盘与摇杆，K 独立前跳，J 跳斩。

const JUMP_DISTANCE: float = HOP_DISTANCE * 2.0
const JUMP_TIME: float = HOP_TIME * 2.0

var camera_rig: Node3D
var joystick: Control
var has_focus: bool = true
var jump_time: float = 0.0
var jump_origin := Vector3.ZERO
var jump_direction := Vector3.FORWARD
var jump_id: int = 0
var attack_buffered: bool = false


func _ready() -> void:
	super._ready()
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and has_focus and round_active:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.physical_keycode == KEY_J or key.keycode == KEY_J:
				request_attack()
				get_viewport().set_input_as_handled()
			elif key.physical_keycode == KEY_K or key.keycode == KEY_K:
				request_jump()
				get_viewport().set_input_as_handled()


func request_jump() -> bool:
	if not round_active or not has_focus or not alive or attack_state != "idle" or attack_requested:
		return false
	jump_origin = global_position
	jump_direction = facing_direction()
	jump_time = 0.0
	jump_id += 1
	attack_buffered = false
	attack_state = "jump"
	velocity = Vector3.ZERO
	_animate_walk(1.0, 0.0, 0.0)
	_reset_weapon_pose()
	return true


func request_attack() -> bool:
	if not round_active or not has_focus or not alive:
		return false
	if attack_state == "jump":
		if attack_buffered:
			return false
		# 独立跳跃期间只记一次输入，落地后交给统一战斗结算器启动。
		attack_buffered = true
		return true
	return super.request_attack()


func _process_attack(delta: float) -> void:
	if attack_state != "jump":
		super._process_attack(delta)
		return
	jump_time += delta
	_advance_hop(jump_direction, JUMP_DISTANCE, JUMP_TIME, jump_time, delta)
	var amount: float = clampf(jump_time / JUMP_TIME, 0.0, 1.0)
	visual.position.y = sin(amount * PI) * 0.65
	body_visual.rotation.x = -0.12 * sin(amount * PI)
	if jump_time >= JUMP_TIME:
		attack_state = "idle"
		velocity = Vector3.ZERO
		visual.position.y = 0.0
		_reset_weapon_pose()
		if attack_buffered:
			attack_buffered = false
			request_attack()


func movement_input() -> Vector2:
	if not round_active or not has_focus:
		return Vector2.ZERO
	var keyboard := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP))
	).limit_length()
	var touch := Vector2.ZERO
	if is_instance_valid(joystick):
		touch = joystick.movement
	return (keyboard + touch).limit_length()


func movement_direction(_delta: float) -> Vector3:
	var stick: Vector2 = movement_input()
	var yaw: float = camera_rig.yaw if is_instance_valid(camera_rig) else 0.0
	var screen_right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var screen_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return screen_right * stick.x - screen_forward * stick.y


func reset_player() -> void:
	super.reset_character()
	visual.rotation = Vector3(0.0, camera_rig.yaw if is_instance_valid(camera_rig) else 0.0, 0.0)
	jump_time = 0.0
	jump_origin = global_position
	jump_direction = facing_direction()
	attack_buffered = false
	if is_instance_valid(joystick):
		joystick.release()


func reset_character() -> void:
	reset_player()


func die() -> void:
	attack_buffered = false
	super.die()


func _pressed(first: int, second: int) -> bool:
	return Input.is_physical_key_pressed(first) or Input.is_physical_key_pressed(second)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		has_focus = false
		attack_requested = false
		attack_buffered = false
		velocity = Vector3.ZERO
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		has_focus = true
