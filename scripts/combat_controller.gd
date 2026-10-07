extends Node3D
## 先判定玩家对刀，再收集同帧命中；人机互砍按出刀先后结算。

signal character_eliminated(attacker: CharacterBody3D, victim: CharacterBody3D)

const EFFECTS = preload("res://scripts/combat_effects.gd")
const PROJECTILE = preload("res://scripts/boomerang_projectile.gd")
const SLASH = preload("res://assets/audio/slash.wav")
const CLASH = preload("res://assets/audio/clash.wav")
const SLICE = preload("res://assets/audio/slice.wav")
const RANGE: float = 2.15
const FRONT_COS: float = 0.48

var actors: Array[CharacterBody3D] = []
var player: CharacterBody3D
var effects: Node3D
var sound_counts := {"slash": 0, "clash": 0, "slice": 0}
var kills: int = 0
var clashes: int = 0
var enabled: bool = true
var navigation: AStarGrid2D
var projectiles: Array[CharacterBody3D] = []
var throw_range: float = 38.0


func _ready() -> void:
	process_physics_priority = 100
	var ground: Node = get_parent().find_child("GroundCollision", true, false)
	if is_instance_valid(ground) and ground.get_child_count() > 0:
		var shape: CollisionShape3D = ground.get_child(0) as CollisionShape3D
		if shape and shape.shape is BoxShape3D:
			throw_range = maxf(shape.shape.size.x, shape.shape.size.z)
	effects = Node3D.new()
	effects.name = "CombatEffects"
	effects.set_script(EFFECTS)
	add_child(effects)
	for actor in get_tree().get_nodes_in_group("food_characters"):
		if actor.get_parent() == get_parent():
			actors.append(actor)
			actor.combat = self
			if actor.is_in_group("player"):
				player = actor


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	for actor in actors:
		if actor.attack_requested and actor.alive:
			actor.begin_attack()
	resolve_hits()
	for weapon in projectiles.duplicate():
		if enabled and is_instance_valid(weapon):
			weapon.advance(delta)


func resolve_hits() -> void:
	if not enabled:
		return
	# 优先处理对刀，取消这一击的全部伤害；不依赖节点在场景中的顺序。
	var recoiling: Dictionary = {}
	for first in range(actors.size()):
		var a: CharacterBody3D = actors[first]
		if not _attacking(a):
			continue
		for second in range(first + 1, actors.size()):
			var b: CharacterBody3D = actors[second]
			# 人机之间直接结算命中；玩家参与时仍可对刀。
			if a.is_in_group("wanderers") and b.is_in_group("wanderers"):
				continue
			if not _attacking(b) or (a.attack_state != "swing" and b.attack_state != "swing"):
				continue
			if a.attack_direction.dot(b.attack_direction) > -0.55:
				continue
			if in_front(a, b) and in_front(b, a) and clear_path(a, b):
				recoiling[a.get_instance_id()] = a
				recoiling[b.get_instance_id()] = b
				clashes += 1
				play_sound("clash", (a.global_position + b.global_position) * 0.5)
				effects.clash((a.global_position + b.global_position) * 0.5 + Vector3.UP)
	for actor in recoiling.values():
		actor.recoil()
	var hits: Array[Dictionary] = []
	for attacker in actors:
		if not attacker.alive or attacker.attack_state != "swing":
			continue
		# 同时出刀时随机决定先手，不固定偏向场景中排在前面的角色。
		var initiative: float = randf()
		for target in actors:
			if target == attacker or not target.alive or target.get_instance_id() in recoiling:
				continue
			if target.get_instance_id() in attacker.hit_targets:
				continue
			if in_front(attacker, target) and clear_path(attacker, target):
				hits.append({"attacker": attacker, "target": target, "direction": attacker.attack_direction, "swing_time": attacker.attack_time, "initiative": initiative})
	hits.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first.swing_time != second.swing_time:
			return first.swing_time > second.swing_time
		return first.initiative > second.initiative
	)
	for hit in hits:
		# 达到整场胜利分数时立即停止，后续命中不再属于这场比赛。
		if not enabled:
			break
		var attacker: CharacterBody3D = hit.attacker
		var victim: CharacterBody3D = hit.target
		if not victim.alive:
			continue
		# 人机互砍不允许已死亡的一方继续反杀，双人交锋最多淘汰一个。
		if attacker.is_in_group("wanderers") and victim.is_in_group("wanderers") and not attacker.alive:
			continue
		attacker.hit_targets[victim.get_instance_id()] = true
		eliminate(attacker, victim, hit.direction)


func eliminate(attacker: CharacterBody3D, victim: CharacterBody3D, direction: Vector3) -> void:
	if not enabled or not victim.alive:
		return
	effects.slice(victim, direction)
	play_sound("slice", victim.global_position)
	victim.die()
	kills += 1
	character_eliminated.emit(attacker, victim)


func launch_boomerang(actor: CharacterBody3D, direction: Vector3) -> CharacterBody3D:
	if not enabled or not actor.alive or not actor.round_active or not actor.has_boomerang:
		return null
	var weapon := CharacterBody3D.new()
	weapon.set_script(PROJECTILE)
	weapon.name = "ThrownBoomerang%d" % (actor.throw_id + 1)
	weapon.owner_actor = actor
	weapon.combat = self
	weapon.direction = direction.normalized()
	weapon.flight_range = throw_range
	weapon.position = to_local(actor.global_position + Vector3.UP * 1.1)
	add_child(weapon)
	projectiles.append(weapon)
	return weapon


func resolve_projectile_segment(weapon: CharacterBody3D, from: Vector3, to: Vector3) -> void:
	var motion: Vector3 = to - from
	for actor in actors:
		if not enabled:
			break
		if actor == weapon.owner_actor or not actor.alive or actor.get_instance_id() in weapon.hit_targets:
			continue
		var collider: CollisionShape3D = actor.get_node("BodyCollision")
		var center: Vector3 = collider.global_position
		var amount: float = clampf((center - from).dot(motion) / maxf(motion.length_squared(), 0.000001), 0.0, 1.0)
		var radius: float = collider.shape.radius + weapon.RADIUS
		if center.distance_to(from + motion * amount) <= radius:
			weapon.hit_targets[actor.get_instance_id()] = true
			eliminate(weapon.owner_actor, actor, weapon.direction)


func clear_point_path(actor: CharacterBody3D, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.1, Vector3(point.x, actor.global_position.y + 1.1, point.z))
	var excluded: Array[RID] = []
	for other in actors:
		excluded.append(other.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func remove_boomerang(weapon: CharacterBody3D) -> void:
	projectiles.erase(weapon)
	weapon.queue_free()


func reclaim_boomerang(actor: CharacterBody3D) -> void:
	for weapon in projectiles.duplicate():
		if is_instance_valid(weapon) and weapon.owner_actor == actor:
			remove_boomerang(weapon)
	actor.thrown_boomerang = null


func clear_boomerangs() -> void:
	for weapon in projectiles:
		if is_instance_valid(weapon):
			if is_instance_valid(weapon.owner_actor):
				weapon.owner_actor.thrown_boomerang = null
			weapon.queue_free()
	projectiles.clear()


func _attacking(actor: CharacterBody3D) -> bool:
	return actor.alive and actor.attack_state in ["hop", "swing"]


func in_front(attacker: CharacterBody3D, target: CharacterBody3D) -> bool:
	var offset: Vector3 = target.global_position - attacker.global_position
	if absf(offset.y) > 1.2:
		return false
	offset.y = 0.0
	var distance: float = offset.length()
	return distance <= RANGE and (distance < 0.05 or attacker.attack_direction.dot(offset / distance) >= FRONT_COS)


func clear_path(attacker: CharacterBody3D, target: CharacterBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(attacker.global_position + Vector3.UP * 1.1, target.global_position + Vector3.UP * 1.1)
	query.exclude = [attacker.get_rid(), target.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func play_sound(kind: String, at: Vector3) -> void:
	sound_counts[kind] += 1
	var audio := AudioStreamPlayer.new()
	audio.name = "Sound_" + kind
	audio.stream = {"slash": SLASH, "clash": CLASH, "slice": SLICE}[kind]
	audio.volume_db = -3.0 if kind == "slash" else -1.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


func reset_round() -> void:
	clear_boomerangs()
	effects.clear()
	for actor in actors:
		actor.reset_character()
		if actor.is_in_group("wanderers"):
			actor.reset_round_dodges()


func build_navigation() -> void:
	# 共用静态地图路径；不把正在移动的角色烘焙成永久障碍。
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(-16, -11, 33, 23)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.88
	shape.height = 2.26
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var excluded: Array[RID] = []
	for actor in actors:
		excluded.append(actor.get_rid())
	query.exclude = excluded
	for x in range(-16, 17):
		for z in range(-11, 12):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.30, z))
			navigation.set_point_solid(Vector2i(x, z), not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())


func navigation_cell(at: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(at.x), -16, 16), clampi(roundi(at.z), -11, 11))
	if not navigation.is_point_solid(cell):
		return cell
	for radius in range(1, 5):
		var closest := cell
		var distance: float = INF
		for x in range(cell.x - radius, cell.x + radius + 1):
			for z in range(cell.y - radius, cell.y + radius + 1):
				var candidate := Vector2i(x, z)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate):
					var next_distance: float = Vector2(x - at.x, z - at.z).length_squared()
					if next_distance < distance:
						distance = next_distance
						closest = candidate
		if distance < INF:
			return closest
	return cell
