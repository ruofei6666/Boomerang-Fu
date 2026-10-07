extends CharacterBody3D
## 所有食物角色共用的碰撞、转身和两颗球形脚步态。

@export var walk_speed: float = 9.0
@export var acceleration: float = 32.0
@export var braking: float = 42.0
@export var spawn_position := Vector3(0.0, 0.08, 3.0)
@export var body_path: NodePath = ^"Visual/Berry"

@onready var visual: Node3D = $Visual
@onready var left_foot: MeshInstance3D = $Visual/LeftFoot
@onready var right_foot: MeshInstance3D = $Visual/RightFoot
@onready var body_visual: Node3D = get_node(body_path)

var walk_phase: float = 0.0
var animation_weight: float = 0.0
var left_rest: Vector3
var right_rest: Vector3
var combat: Node
var alive: bool = true
var round_active: bool = true
var attack_state: String = "idle"
var attack_time: float = 0.0
var attack_requested: bool = false
var attack_origin := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var recoil_from := Vector3.ZERO
var attack_id: int = 0
var hit_targets: Dictionary = {}
var rest_collision_layer: int
var rest_collision_mask: int
var hand_rest := Vector3.ZERO
var hand_rotation_rest := Vector3.ZERO
var boomerang_rotation_rest := Vector3.ZERO
var slash_visual: MeshInstance3D
var slash_material: StandardMaterial3D
var right_hand: Node3D
var held_boomerang: Node3D

const HOP_TIME: float = 0.16
const HOP_DISTANCE: float = 2.85
const SWING_TIME: float = 0.14
const RECOVERY_TIME: float = 0.28
const RECOIL_TIME: float = 0.20


func _ready() -> void:
	left_rest = left_foot.position
	right_rest = right_foot.position
	add_to_group("food_characters")
	rest_collision_layer = collision_layer
	rest_collision_mask = collision_mask
	right_hand = body_visual.get_node("RightHand")
	held_boomerang = right_hand.get_node("Boomerang")
	hand_rest = right_hand.position
	hand_rotation_rest = right_hand.rotation
	boomerang_rotation_rest = held_boomerang.rotation
	_make_slash_visual()


func movement_direction(_delta: float) -> Vector3:
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not round_active or not alive:
		velocity = Vector3.ZERO
		return
	if attack_state != "idle":
		_process_attack(delta)
		return
	var direction: Vector3 = movement_direction(delta)
	var target: Vector3 = direction * walk_speed
	var rate: float = braking if direction.is_zero_approx() else acceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 24.0 * delta
	var before: Vector3 = global_position
	move_and_slide()
	# 所有角色都受岩石碰撞和同一条地图边界约束。
	position.x = clampf(position.x, -17.5, 17.5)
	position.z = clampf(position.z, -12.2, 12.2)
	if position.y < -3.0:
		reset_character()
		return
	var traveled: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var actual_speed: float = traveled / maxf(delta, 0.0001)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-15.0 * delta))
	_animate_walk(delta, actual_speed, traveled)
	_after_move(delta, traveled)


func _after_move(_delta: float, _traveled: float) -> void:
	pass


func _animate_walk(delta: float, actual_speed: float, traveled: float) -> void:
	animation_weight = move_toward(animation_weight, clampf(actual_speed / walk_speed, 0.0, 1.0), delta * 9.0)
	walk_phase += traveled * 5.4
	var stride: float = sin(walk_phase)
	left_foot.position = left_rest + Vector3(0.0, maxf(0.0, stride) * 0.17, stride * 0.15) * animation_weight
	right_foot.position = right_rest + Vector3(0.0, maxf(0.0, -stride) * 0.17, -stride * 0.15) * animation_weight
	left_foot.rotation.x = stride * 0.45 * animation_weight
	right_foot.rotation.x = -stride * 0.45 * animation_weight
	body_visual.position.y = absf(cos(walk_phase)) * 0.055 * animation_weight
	body_visual.rotation.z = stride * 0.045 * animation_weight
	body_visual.rotation.x = -0.065 * animation_weight


func reset_character() -> void:
	alive = true
	attack_state = "idle"
	attack_requested = false
	attack_time = 0.0
	hit_targets.clear()
	collision_layer = rest_collision_layer
	collision_mask = rest_collision_mask
	visual.show()
	visual.position.y = 0.0
	_reset_weapon_pose()
	position = spawn_position
	velocity = Vector3.ZERO
	walk_phase = 0.0
	animation_weight = 0.0
	visual.rotation = Vector3.ZERO
	_animate_walk(1.0, 0.0, 0.0)


func request_attack() -> bool:
	if not round_active or not alive or attack_state != "idle" or attack_requested:
		return false
	attack_requested = true
	return true


func facing_direction() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))


func begin_attack() -> void:
	attack_requested = false
	if not round_active or not alive or attack_state != "idle":
		return
	attack_origin = global_position
	attack_direction = facing_direction()
	attack_state = "hop"
	attack_time = 0.0
	attack_id += 1
	hit_targets.clear()
	velocity = Vector3.ZERO
	_animate_walk(1.0, 0.0, 0.0)


func _process_attack(delta: float) -> void:
	attack_time += delta
	velocity = Vector3.ZERO
	if attack_state == "hop":
		_advance_hop(attack_direction, HOP_DISTANCE, HOP_TIME, attack_time, delta)
		var amount: float = clampf(attack_time / HOP_TIME, 0.0, 1.0)
		visual.position.y = sin(amount * PI) * 0.34
		body_visual.rotation.x = -0.12 * sin(amount * PI)
		right_hand.rotation.y = -0.9 * amount
		if attack_time >= HOP_TIME:
			attack_state = "swing"
			attack_time = 0.0
			visual.position.y = 0.0
			if is_instance_valid(combat):
				combat.play_sound("slash", global_position)
	elif attack_state == "swing":
		var amount: float = clampf(attack_time / SWING_TIME, 0.0, 1.0)
		var angle: float = lerpf(-1.15, 1.65, amount)
		right_hand.position = Vector3(sin(angle) * 1.1, hand_rest.y, cos(angle) * 1.1)
		right_hand.rotation.y = angle - 0.4
		held_boomerang.rotation.z = boomerang_rotation_rest.z + sin(amount * PI) * 0.6
		body_visual.rotation.y = lerpf(-0.12, 0.16, amount)
		slash_visual.show()
		slash_material.albedo_color.a = sin(amount * PI) * 0.82
		if attack_time >= SWING_TIME:
			attack_state = "recovery"
			attack_time = 0.0
			slash_visual.hide()
	elif attack_state == "recovery":
		var amount: float = clampf(attack_time / RECOVERY_TIME, 0.0, 1.0)
		right_hand.position = right_hand.position.lerp(hand_rest, amount)
		right_hand.rotation = right_hand.rotation.lerp(hand_rotation_rest, amount)
		body_visual.rotation.y *= 1.0 - amount
		if attack_time >= RECOVERY_TIME:
			attack_state = "idle"
			_reset_weapon_pose()
	elif attack_state == "recoil":
		var amount: float = clampf(attack_time / RECOIL_TIME, 0.0, 1.0)
		# 起点是起跳前已经通过物理碰撞确认的安全位置；对刀精确弹回那里。
		global_position = recoil_from.lerp(attack_origin, smoothstep(0.0, 1.0, amount))
		visual.position.y = sin(amount * PI) * 0.24
		if attack_time >= RECOIL_TIME:
			global_position = attack_origin
			visual.position.y = 0.0
			attack_state = "recovery"
			attack_time = 0.0
			_reset_weapon_pose()


func _advance_hop(direction: Vector3, distance: float, duration: float, elapsed: float, delta: float) -> void:
	# 最后一帧只走剩余时间，保证砍击和独立跳跃的距离不随物理帧率增加。
	var step_time: float = minf(delta, maxf(0.0, duration - (elapsed - delta)))
	velocity = direction * (distance / duration) * (step_time / delta)
	velocity.y = -0.1 if is_on_floor() else -24.0 * delta
	move_and_slide()
	position.x = clampf(position.x, -17.5, 17.5)
	position.z = clampf(position.z, -12.2, 12.2)


func recoil() -> void:
	attack_requested = false
	attack_state = "recoil"
	attack_time = 0.0
	recoil_from = global_position
	velocity = Vector3.ZERO
	_reset_weapon_pose()


func die() -> void:
	alive = false
	attack_state = "dead"
	attack_requested = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visual.hide()
	slash_visual.hide()


func _reset_weapon_pose() -> void:
	if is_instance_valid(right_hand):
		right_hand.position = hand_rest
		right_hand.rotation = hand_rotation_rest
		held_boomerang.rotation = boomerang_rotation_rest
		body_visual.rotation = Vector3.ZERO
	if is_instance_valid(slash_visual):
		slash_visual.hide()


func _make_slash_visual() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(28):
		var first: float = lerpf(-1.1, 1.1, float(segment) / 28.0)
		var second: float = lerpf(-1.1, 1.1, float(segment + 1) / 28.0)
		var a := Vector3(sin(first), 0.0, cos(first))
		var b := Vector3(sin(second), 0.0, cos(second))
		for vertex in [a * 1.18, b * 1.18, a * 2.05, a * 2.05, b * 1.18, b * 2.05]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	slash_visual = MeshInstance3D.new()
	slash_visual.name = "SlashArc"
	slash_visual.mesh = surface.commit()
	slash_visual.position.y = 1.05
	slash_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slash_material = StandardMaterial3D.new()
	slash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	slash_material.albedo_color = Color(1.0, 0.96, 0.78, 0.8)
	slash_visual.material_override = slash_material
	visual.add_child(slash_visual)
	slash_visual.hide()
