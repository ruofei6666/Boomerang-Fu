extends "res://scripts/food_character_controller.gd"
## 混战人机追击、跳跃和避砍；独立散步模式保留随机停顿与避障。

@export var random_seed: int = 0
@export var wander_radius: float = 8.0
@export var wander_bounds := Rect2(-15.5, -10.5, 31.0, 21.0)

const MAX_DODGES_PER_OPPONENT: int = 2

var random := RandomNumberGenerator.new()
var destination: Vector3
var walking: bool = false
var idle_time: float = 0.0
var decision_time: float = 0.0
var blocked_time: float = 0.0
@export var melee_enabled: bool = true
var melee_reaction: float = 0.0
var melee_cooldown: float = 0.0
var arena_ai: bool = false
var ai_difficulty: int = 1
var reaction_delay: float = 0.30
var attack_interval: float = 0.80
var target_actor: CharacterBody3D
var target_timer: float = 0.0
var path_timer: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var evasion_side: float = 1.0
var jump_cooldown: float = 0.0
var jump_reaction: float = 0.0
var dodge_reaction: float = 0.0
var jump_interval: float = 2.0
var dodge_delay: float = 0.05
var last_jump_reason: String = ""
# 按角色实例计数，同一模型的不同参赛者也各有两次额度；仅下一小局清零。
var dodges_by_opponent: Dictionary[int, int] = {}
var ranged_reaction: float = 0.0
var ranged_cooldown: float = 0.0
var ranged_aim_time: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("wanderers")
	if random_seed == 0:
		random.randomize()
	else:
		random.seed = random_seed
	destination = position
	idle_time = random.randf_range(0.55, 1.25)


func _physics_process(delta: float) -> void:
	if round_active and alive:
		jump_cooldown = maxf(0.0, jump_cooldown - delta)
		ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	super._physics_process(delta)


func movement_direction(delta: float) -> Vector3:
	melee_cooldown = maxf(0.0, melee_cooldown - delta)
	if arena_ai and melee_enabled and is_instance_valid(combat):
		return _arena_direction(delta)
	if melee_enabled and not has_boomerang and is_instance_valid(combat):
		return _retrieve_boomerang(delta)
	if melee_enabled and is_instance_valid(combat) and combat.player.alive:
		var to_player: Vector3 = combat.player.global_position - global_position
		to_player.y = 0.0
		if _try_ranged_attack(combat.player, to_player, delta):
			return Vector3.ZERO
		if to_player.length() < 2.65 and to_player.length() > 0.1 and melee_cooldown <= 0.0 and combat.clear_path(self, combat.player):
			melee_reaction += delta
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to_player.x, to_player.z), 1.0 - exp(-15.0 * delta))
			if melee_reaction >= 0.42:
				visual.rotation.y = atan2(to_player.x, to_player.z)
				request_attack()
				melee_reaction = 0.0
				melee_cooldown = 0.95
			return Vector3.ZERO
		else:
			melee_reaction = 0.0
	if not walking:
		idle_time -= delta
		if idle_time > 0.0:
			return Vector3.ZERO
		_choose_destination()
		if not walking:
			return Vector3.ZERO
	decision_time -= delta
	var offset: Vector3 = destination - position
	offset.y = 0.0
	if offset.length() < 0.45 or decision_time <= 0.0:
		_rest()
		return Vector3.ZERO
	var direction: Vector3 = offset.normalized()
	# 使用角色自己的碰撞体探测，岩石和其他食物角色都会让人机换路。
	if test_move(global_transform, direction * 1.1):
		_choose_destination()
		if not walking:
			return Vector3.ZERO
		offset = destination - position
		offset.y = 0.0
		direction = offset.normalized()
	return direction


func set_difficulty(level: int) -> void:
	ai_difficulty = clampi(level, 0, 2)
	reaction_delay = [0.56, 0.30, 0.14][ai_difficulty]
	attack_interval = [1.15, 0.80, 0.48][ai_difficulty]
	walk_speed = [6.5, 8.0, 9.0][ai_difficulty]
	jump_interval = [2.8, 2.0, 1.2][ai_difficulty]
	dodge_delay = [0.08, 0.05, 0.025][ai_difficulty]


func _arena_direction(delta: float) -> Vector3:
	target_timer -= delta
	path_timer -= delta
	if target_timer <= 0.0 or not is_instance_valid(target_actor) or not target_actor.alive:
		var previous: CharacterBody3D = target_actor
		target_actor = null
		var nearest: float = INF
		for actor in combat.actors:
			if actor != self and actor.alive:
				var distance: float = global_position.distance_squared_to(actor.global_position)
				if distance < nearest:
					nearest = distance
					target_actor = actor
		target_timer = [0.55, 0.30, 0.16][ai_difficulty]
		if previous != target_actor:
			melee_reaction = 0.0
			ranged_reaction = 0.0
			jump_reaction = 0.0
			path_timer = 0.0
	if not is_instance_valid(target_actor):
		walking = false
		jump_reaction = 0.0
		dodge_reaction = 0.0
		return Vector3.ZERO
	if _try_dodge_jump(delta):
		return Vector3.ZERO
	if not has_boomerang:
		return _retrieve_boomerang(delta)
	var offset: Vector3 = target_actor.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var clear: bool = combat.clear_path(self, target_actor)
	# 留出近战距离，落地时不会越过目标或撞上目标的身体。
	if distance >= JUMP_DISTANCE + 2.0 and clear and jump_cooldown <= 0.0 and _can_jump(offset.normalized()):
		jump_reaction += delta
		if jump_reaction >= reaction_delay and _begin_ai_jump(offset.normalized(), "chase"):
			return Vector3.ZERO
	else:
		jump_reaction = 0.0
	if jump_reaction <= 0.0 and _try_ranged_attack(target_actor, offset, delta):
		return Vector3.ZERO
	if distance < 2.75 and distance > 0.05 and clear:
		walking = false
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(offset.x, offset.z), 1.0 - exp(-15.0 * delta))
		if melee_cooldown <= 0.0:
			melee_reaction += delta
			if melee_reaction >= reaction_delay:
				visual.rotation.y = atan2(offset.x, offset.z)
				request_attack()
				melee_reaction = 0.0
				melee_cooldown = attack_interval + random.randf_range(0.02, 0.25)
		# 攻击间隔带少量随机延迟，避免同难度人机始终同时出刀。
		return Vector3.ZERO
	melee_reaction = 0.0
	walking = true
	return _navigate_toward(target_actor.global_position, clear)


func _navigate_toward(destination_point: Vector3, clear: bool) -> Vector3:
	var offset: Vector3 = destination_point - global_position
	offset.y = 0.0
	var direction: Vector3 = offset.normalized()
	if not clear or test_move(global_transform, direction * 1.15):
		if is_instance_valid(combat.navigation):
			if path_timer <= 0.0:
				path = combat.navigation.get_point_path(combat.navigation_cell(global_position), combat.navigation_cell(destination_point))
				path_index = 1 if path.size() > 1 else 0
				path_timer = 0.40
			while path_index < path.size():
				var waypoint := Vector3(path[path_index].x, 0.0, path[path_index].y)
				var toward: Vector3 = waypoint - global_position
				toward.y = 0.0
				if toward.length() > 0.50:
					direction = toward.normalized()
					break
				path_index += 1
		# 路径之外还探测动态碰撞；沿障碍一侧绕开。
		if test_move(global_transform, direction * 0.85):
			var found: bool = false
			for angle in [0.7, -0.7, 1.2, -1.2, 1.8, -1.8, PI]:
				var alternative: Vector3 = direction.rotated(Vector3.UP, float(angle) * evasion_side)
				if not test_move(global_transform, alternative * 1.25):
					direction = alternative
					found = true
					break
			if not found:
				return Vector3.ZERO
	return direction


func _try_ranged_attack(target: CharacterBody3D, offset: Vector3, delta: float) -> bool:
	var distance: float = offset.length()
	if not has_boomerang or ranged_cooldown > 0.0 or distance < 3.3 or distance > 18.0 or not combat.clear_path(self, target):
		ranged_reaction = 0.0
		return false
	target_actor = target
	walking = false
	ranged_reaction += delta
	visual.rotation.y = atan2(offset.x, offset.z)
	if ranged_reaction >= reaction_delay:
		ranged_aim_time = 0.0
		request_throw()
		ranged_reaction = 0.0
	return true


func aim_direction(_delta: float) -> Vector3:
	if not is_instance_valid(target_actor) or not target_actor.alive:
		return throw_direction
	var distance: float = global_position.distance_to(target_actor.global_position)
	# 根据飞行时间预判走动；较高难度的提前量更准确。
	var lead: float = distance / 24.0 * [0.35, 0.65, 0.9][ai_difficulty]
	var predicted: Vector3 = target_actor.global_position + target_actor.velocity * lead
	return predicted - global_position


func _process_aim(delta: float) -> void:
	super._process_aim(delta)
	if not is_instance_valid(target_actor) or not target_actor.alive or not combat.clear_path(self, target_actor):
		cancel_throw()
		ranged_reaction = 0.0
		return
	ranged_aim_time += delta
	if ranged_aim_time >= [0.56, 0.38, 0.22][ai_difficulty]:
		ranged_aim_time = 0.0
		release_throw()
		ranged_cooldown = attack_interval + 0.8


func _retrieve_boomerang(delta: float) -> Vector3:
	melee_reaction = 0.0
	ranged_reaction = 0.0
	jump_reaction = 0.0
	if not is_instance_valid(thrown_boomerang):
		walking = false
		return Vector3.ZERO
	path_timer -= delta
	walking = true
	return _navigate_toward(thrown_boomerang.global_position, combat.clear_point_path(self, thrown_boomerang.global_position))


func _can_jump(direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	var landing: Vector3 = global_position + direction * JUMP_DISTANCE
	# 全程保留碰撞；落点留出角色半径，不朝岩石、其他角色或地图边缘跳。
	if absf(landing.x) > 16.5 or absf(landing.z) > 11.2:
		return false
	return not test_move(global_transform, direction * JUMP_DISTANCE)


func dodge_count_against(opponent: CharacterBody3D) -> int:
	if not is_instance_valid(opponent):
		return 0
	return dodges_by_opponent.get(opponent.get_instance_id(), 0)


func _begin_ai_jump(direction: Vector3, reason: String, opponent: CharacterBody3D = null) -> bool:
	if reason == "dodge":
		if not is_instance_valid(opponent) or opponent == self or not opponent.alive:
			return false
		if dodge_count_against(opponent) >= MAX_DODGES_PER_OPPONENT:
			return false
	if jump_cooldown > 0.0 or not _can_jump(direction):
		return false
	visual.rotation.y = atan2(direction.x, direction.z)
	if not request_jump():
		return false
	jump_cooldown = jump_interval + random.randf_range(0.05, 0.25)
	jump_reaction = 0.0
	dodge_reaction = 0.0
	melee_reaction = 0.0
	walking = false
	path_timer = 0.0
	last_jump_reason = reason
	if reason == "dodge":
		dodges_by_opponent[opponent.get_instance_id()] = dodge_count_against(opponent) + 1
	return true


func _try_dodge_jump(delta: float) -> bool:
	if jump_cooldown > 0.0:
		dodge_reaction = 0.0
		return false
	var threat: CharacterBody3D
	var nearest: float = HOP_DISTANCE + combat.RANGE + 0.5
	for actor in combat.actors:
		if actor == self or not actor.alive or actor.attack_state not in ["hop", "swing"]:
			continue
		if dodge_count_against(actor) >= MAX_DODGES_PER_OPPONENT:
			continue
		var away: Vector3 = global_position - actor.global_position
		away.y = 0.0
		var distance: float = away.length()
		if distance > 0.05 and distance < nearest and actor.attack_direction.dot(away / distance) >= combat.FRONT_COS and combat.clear_path(actor, self):
			threat = actor
			nearest = distance
	if not is_instance_valid(threat):
		dodge_reaction = 0.0
		return false
	dodge_reaction += delta
	if dodge_reaction < dodge_delay:
		return false
	var away: Vector3 = global_position - threat.global_position
	away.y = 0.0
	away = away.normalized()
	var side: Vector3 = away.rotated(Vector3.UP, PI * 0.5 * evasion_side)
	for direction in [side, -side, away, away.rotated(Vector3.UP, PI * 0.25), away.rotated(Vector3.UP, -PI * 0.25)]:
		if _begin_ai_jump(direction, "dodge", threat):
			return true
	return false


func _choose_destination() -> void:
	for attempt in range(16):
		var angle: float = random.randf_range(-PI, PI)
		var distance: float = random.randf_range(2.5, 6.0)
		var candidate: Vector3 = position + Vector3(sin(angle), 0.0, cos(angle)) * distance
		candidate.x = clampf(candidate.x, wander_bounds.position.x, wander_bounds.end.x)
		candidate.z = clampf(candidate.z, wander_bounds.position.y, wander_bounds.end.y)
		var from_home := Vector2(candidate.x - spawn_position.x, candidate.z - spawn_position.z)
		if from_home.length() > wander_radius:
			continue
		var offset: Vector3 = candidate - position
		offset.y = 0.0
		if offset.length() < 1.2 or test_move(global_transform, offset.normalized() * 1.35):
			continue
		destination = candidate
		walking = true
		decision_time = random.randf_range(1.4, 3.2)
		blocked_time = 0.0
		return
	_rest()


func _rest() -> void:
	walking = false
	idle_time = random.randf_range(0.35, 1.15)
	blocked_time = 0.0


func _after_move(delta: float, traveled: float) -> void:
	if not walking:
		return
	blocked_time = blocked_time + delta if traveled < walk_speed * delta * 0.12 else 0.0
	# 动态角色也可能从侧面挡住人机；被挡住后重新选路，避免一直顶着障碍。
	if blocked_time > 0.45:
		if arena_ai:
			evasion_side *= -1.0
			path_timer = 0.0
			blocked_time = 0.0
		else:
			_choose_destination()


func reset_character() -> void:
	super.reset_character()
	melee_reaction = 0.0
	melee_cooldown = 0.0
	ranged_reaction = 0.0
	ranged_cooldown = 0.0
	ranged_aim_time = 0.0
	jump_cooldown = random.randf_range(0.25, 0.70)
	jump_reaction = 0.0
	dodge_reaction = 0.0
	last_jump_reason = ""
	target_actor = null
	target_timer = 0.0
	path_timer = 0.0
	path = PackedVector2Array()
	path_index = 0
	evasion_side = -1.0 if random.randf() < 0.5 else 1.0
	destination = spawn_position
	_rest()


func reset_round_dodges() -> void:
	# 小局重开才恢复额度，地图跌落后的角色复位仍保留本局次数。
	dodges_by_opponent.clear()
