extends CharacterBody3D
## 连续扫掠岩石，按法线完全弹性反射；总路程用尽后落地，原主人走近拾回。

const SPEED: float = 24.0
const RADIUS: float = 0.20
const PICKUP_RADIUS: float = 1.30
const BOUNDS := Rect2(-17.3, -12.0, 34.6, 24.0)

var owner_actor: CharacterBody3D
var combat: Node3D
var direction := Vector3.FORWARD
var flight_range: float = 38.0
var distance_traveled: float = 0.0
var flying: bool = true
var bounce_count: int = 0
var hit_targets: Dictionary = {}
var model: Node3D
var pickup_marker: MeshInstance3D
var idle_time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	# 竖直碰撞柱也覆盖低矮石墙，镖不会穿过角色走不过去的障碍。
	var sphere := CapsuleShape3D.new()
	sphere.radius = RADIUS
	sphere.height = 2.0
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	add_child(shape)
	for actor in combat.actors:
		add_collision_exception_with(actor)
	model = owner_actor.held_boomerang.duplicate(0) as Node3D
	model.name = "FlyingBlade"
	model.position = Vector3.ZERO
	model.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	model.show()
	add_child(model)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.66
	disc.bottom_radius = 0.66
	disc.height = 0.025
	pickup_marker = MeshInstance3D.new()
	pickup_marker.name = "PickupMarker"
	pickup_marker.mesh = disc
	pickup_marker.position.y = -0.25
	pickup_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.94, 0.50, 0.40)
	pickup_marker.material_override = material
	add_child(pickup_marker)
	pickup_marker.hide()
	velocity = direction * SPEED


func advance(delta: float) -> void:
	if not flying:
		idle_time += delta
		pickup_marker.scale = Vector3.ONE * (1.0 + sin(idle_time * 5.0) * 0.12)
		_try_pickup()
		return
	model.rotation.y += delta * 22.0
	var remaining: float = minf(SPEED * delta, flight_range - distance_traveled)
	# 一帧内保留碰撞后的剩余路程，反弹不会损失速度或多算射程。
	for iteration in range(12):
		if remaining <= 0.00001 or not combat.enabled:
			break
		var border: Dictionary = _border_contact(remaining)
		var step_distance: float = border.distance
		var before: Vector3 = global_position
		var collision: KinematicCollision3D = move_and_collide(direction * step_distance, false, 0.001)
		var traveled: float = before.distance_to(global_position)
		distance_traveled += traveled
		remaining = maxf(0.0, remaining - traveled)
		combat.resolve_projectile_segment(self, before, global_position)
		if distance_traveled >= flight_range - 0.0001:
			distance_traveled = flight_range
			_stop()
			break
		var normal := Vector3.ZERO
		if collision:
			normal = collision.get_normal()
			normal.y = 0.0
		elif border.hit:
			normal = border.normal
		else:
			break
		if normal.is_zero_approx():
			break
		normal = normal.normalized()
		direction = direction.bounce(normal).normalized()
		velocity = direction * SPEED
		bounce_count += 1
		global_position += normal * 0.002


func _border_contact(step: float) -> Dictionary:
	var distance: float = step
	var normal := Vector3.ZERO
	if direction.x > 0.00001:
		var next: float = maxf(0.0, (BOUNDS.end.x - global_position.x) / direction.x)
		if next <= distance:
			distance = next
			normal = Vector3.LEFT
	elif direction.x < -0.00001:
		var next: float = maxf(0.0, (BOUNDS.position.x - global_position.x) / direction.x)
		if next <= distance:
			distance = next
			normal = Vector3.RIGHT
	if direction.z > 0.00001:
		var next: float = maxf(0.0, (BOUNDS.end.y - global_position.z) / direction.z)
		if next <= distance:
			distance = next
			normal = Vector3.FORWARD
	elif direction.z < -0.00001:
		var next: float = maxf(0.0, (BOUNDS.position.y - global_position.z) / direction.z)
		if next <= distance:
			distance = next
			normal = Vector3.BACK
	return {"distance": distance, "normal": normal, "hit": not normal.is_zero_approx()}


func _stop() -> void:
	flying = false
	velocity = Vector3.ZERO
	collision_mask = 0
	global_position.y = 0.30
	pickup_marker.show()


func _try_pickup() -> void:
	if not is_instance_valid(owner_actor) or not owner_actor.alive or not owner_actor.round_active:
		return
	var offset: Vector3 = owner_actor.global_position - global_position
	offset.y = 0.0
	if offset.length() <= PICKUP_RADIUS and combat.clear_point_path(owner_actor, global_position):
		owner_actor.pickup_boomerang(self)
		combat.remove_boomerang(self)
