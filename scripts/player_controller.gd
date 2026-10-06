extends CharacterBody3D
## 草莓的碰撞、按屏幕方向移动、转身和球形脚步态。

@export var walk_speed: float = 6.0
@export var acceleration: float = 32.0
@export var braking: float = 42.0
@export var spawn_position := Vector3(0.0, 0.08, 3.0)

@onready var visual: Node3D = $Visual
@onready var left_foot: MeshInstance3D = $Visual/LeftFoot
@onready var right_foot: MeshInstance3D = $Visual/RightFoot
@onready var berry: Node3D = $Visual/Berry

var camera_rig: Node3D
var joystick: Control
var walk_phase: float = 0.0
var animation_weight: float = 0.0
var has_focus: bool = true
var left_rest: Vector3
var right_rest: Vector3


func _ready() -> void:
	left_rest = left_foot.position
	right_rest = right_foot.position
	add_to_group("player")


func movement_input() -> Vector2:
	if not has_focus:
		return Vector2.ZERO
	var keyboard := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP))
	).limit_length()
	var touch := Vector2.ZERO
	if is_instance_valid(joystick):
		touch = joystick.movement
	return (keyboard + touch).limit_length()


func _physics_process(delta: float) -> void:
	var stick: Vector2 = movement_input()
	var yaw: float = camera_rig.yaw if is_instance_valid(camera_rig) else 0.0
	var screen_right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var screen_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var direction: Vector3 = screen_right * stick.x - screen_forward * stick.y
	var target: Vector3 = direction * walk_speed
	var rate: float = braking if stick.is_zero_approx() else acceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 24.0 * delta
	var before: Vector3 = global_position
	move_and_slide()
	# 围墙有真实碰撞；额外限制防止从地图边缘掉下去。
	position.x = clampf(position.x, -17.5, 17.5)
	position.z = clampf(position.z, -12.2, 12.2)
	if position.y < -3.0:
		reset_player()
	var traveled: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var actual_speed: float = traveled / maxf(delta, 0.0001)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-15.0 * delta))
	_animate_walk(delta, actual_speed, traveled)


func _animate_walk(delta: float, actual_speed: float, traveled: float) -> void:
	animation_weight = move_toward(animation_weight, clampf(actual_speed / walk_speed, 0.0, 1.0), delta * 9.0)
	walk_phase += traveled * 5.4
	var stride: float = sin(walk_phase)
	left_foot.position = left_rest + Vector3(0.0, maxf(0.0, stride) * 0.17, stride * 0.15) * animation_weight
	right_foot.position = right_rest + Vector3(0.0, maxf(0.0, -stride) * 0.17, -stride * 0.15) * animation_weight
	left_foot.rotation.x = stride * 0.45 * animation_weight
	right_foot.rotation.x = -stride * 0.45 * animation_weight
	berry.position.y = absf(cos(walk_phase)) * 0.055 * animation_weight
	berry.rotation.z = stride * 0.045 * animation_weight
	berry.rotation.x = -0.065 * animation_weight


func reset_player() -> void:
	position = spawn_position
	velocity = Vector3.ZERO
	walk_phase = 0.0
	animation_weight = 0.0
	visual.rotation = Vector3(0.0, camera_rig.yaw if is_instance_valid(camera_rig) else 0.0, 0.0)
	_animate_walk(1.0, 0.0, 0.0)
	if is_instance_valid(joystick):
		joystick.release()


func _pressed(first: int, second: int) -> bool:
	return Input.is_physical_key_pressed(first) or Input.is_physical_key_pressed(second)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		has_focus = false
		velocity = Vector3.ZERO
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		has_focus = true
