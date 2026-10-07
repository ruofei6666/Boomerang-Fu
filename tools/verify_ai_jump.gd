extends SceneTree
## 在真实地图、角色碰撞和战斗结算中检查人机的独立跳跃。

var checks: Array[String] = []
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var arena: Node3D
var bot: CharacterBody3D
var player: CharacterBody3D
var lane_origin := Vector3.ZERO
var lane_direction := Vector3.RIGHT


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	(checks if condition else failures).append(description)
	print(("PASS: " if condition else "FAIL: ") + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _start(role: int, difficulty: int) -> void:
	arena.match_controller.return_to_lobby()
	arena.match_controller.configure(1, difficulty, [0, role])
	arena.match_controller.start_match()
	player = arena.player
	bot = arena.combat.actors[1]
	for actor in arena.combat.actors:
		actor.set_physics_process(false)
	player.position = Vector3(30.0, 0.08, 30.0)
	bot.position = lane_origin
	bot.spawn_position = lane_origin
	bot.jump_cooldown = 0.0
	bot.idle_time = 9999.0
	bot.random.seed = 31007
	await _frames(2)
	player.position = lane_origin + lane_direction * 12.0


func _find_lane() -> bool:
	# 从当前地图找一条实际无障碍的长走廊，不依赖地图生成器的固定布局。
	for x in range(-12, 13, 3):
		for z in range(-8, 9, 2):
			for direction in [Vector3.RIGHT, Vector3.BACK]:
				var origin := Vector3(x, 0.08, z)
				var ending: Vector3 = origin + direction * 12.0
				if absf(ending.x) > 15.0 or absf(ending.z) > 10.0:
					continue
				if arena.combat.navigation.is_point_solid(Vector2i(x, z)):
					continue
				bot.position = origin
				var collider: CollisionShape3D = bot.get_node("BodyCollision")
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = collider.shape
				query.transform = collider.global_transform
				query.exclude = [bot.get_rid(), player.get_rid()]
				var blocked: bool = false
				for hit in bot.get_world_3d().direct_space_state.intersect_shape(query, 16):
					if hit.collider.get_parent().name in ["InteriorRocks", "PerimeterCliffs"]:
						blocked = true
				if not blocked and not bot.test_move(bot.global_transform, direction * 12.0):
					lane_origin = origin
					lane_direction = direction
					return true
	return false


func _land() -> void:
	var elapsed: int = 0
	while bot.attack_state == "jump" and elapsed < 30:
		await _frames(1)
		elapsed += 1
	bot.set_physics_process(false)


func _verify() -> void:
	arena = load("res://scenes/stone_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.match_controller.set_physics_process(false)
	await _start(1, 1)
	player.position = Vector3(30.0, 0.08, 30.0)
	var found: bool = _find_lane()
	_check(found, "The real arena contains a clear test corridor")
	if not found:
		quit(1)
		return
	# 四种模型作为人机时，共用与玩家相同的动作和碰撞，而非视觉假跳。
	for role in range(4):
		await _start(role, 1)
		bot.melee_enabled = false
		bot.visual.rotation.y = atan2(lane_direction.x, lane_direction.z)
		var attack_id: int = bot.attack_id
		var slash_count: int = arena.combat.sound_counts.slash
		_check(bot.request_jump(), "Role %d NPC accepts an independent jump" % role)
		bot.set_physics_process(true)
		await _frames(8)
		_check(bot.attack_state == "jump" and bot.visual.position.y > 0.4, "Role %d NPC visibly rises during its jump" % role)
		_check(not bot.request_jump() and not bot.request_attack(), "Role %d NPC cannot interrupt the jump with another action" % role)
		bot.visual.rotation.y += PI * 0.5
		await _land()
		var traveled: Vector3 = bot.global_position - bot.jump_origin
		traveled.y = 0.0
		_check(traveled.distance_to(lane_direction * 5.70) < 0.005, "Role %d NPC travels exactly 5.70 in the locked direction" % role)
		_check(bot.attack_state == "idle" and bot.velocity.is_zero_approx() and is_zero_approx(bot.visual.position.y) and bot.attack_id == attack_id and arena.combat.sound_counts.slash == slash_count and player.alive, "Role %d NPC lands without swinging or dealing damage" % role)
		bot.reset_character()
		_check(bot.jump_time == 0.0 and bot.attack_state == "idle" and bot.position.is_equal_approx(bot.spawn_position) and bot.last_jump_reason.is_empty(), "Role %d NPC reset clears jump motion and AI decisions" % role)
	var intervals: Array[float] = []
	var dodge_delays: Array[float] = []
	for difficulty in range(3):
		await _start(1, difficulty)
		intervals.append(bot.jump_interval)
		dodge_delays.append(bot.dodge_delay)
		var before: int = bot.jump_id
		bot.set_physics_process(true)
		var elapsed: int = 0
		while bot.jump_id == before and bot.alive and elapsed < 120:
			await _frames(1)
			elapsed += 1
		_check(bot.jump_id == before + 1 and bot.last_jump_reason == "chase", "Difficulty %d autonomously jumps to chase a distant opponent" % difficulty)
		_check(bot.jump_direction.dot(lane_direction) > 0.99, "Difficulty %d chase jump aims toward the opponent" % difficulty)
		var initial_cooldown: float = bot.jump_cooldown
		await _land()
		var traveled: Vector3 = bot.position - bot.jump_origin
		traveled.y = 0.0
		_check(traveled.distance_to(lane_direction * 5.70) < 0.005, "Difficulty %d decision frame adds no walking step to its jump" % difficulty)
		_check(bot.jump_cooldown < initial_cooldown and bot.jump_cooldown > 0.0 and not bot._begin_ai_jump(lane_direction, "chase"), "Difficulty %d cooldown ticks while airborne and prevents consecutive jumps" % difficulty)
		samples.append({"difficulty": difficulty, "chase_reaction_frames": elapsed, "jump_distance": traveled.length()})
		await _start(1, difficulty)
		bot.position = lane_origin + lane_direction * 6.0
		player.position = bot.position - lane_direction * 3.8
		player.visual.rotation.y = atan2(lane_direction.x, lane_direction.z)
		before = bot.jump_id
		player.begin_attack()
		player.set_physics_process(true)
		bot.set_physics_process(true)
		elapsed = 0
		while bot.jump_id == before and bot.alive and elapsed < 15:
			await _frames(1)
			elapsed += 1
		_check(bot.alive and bot.jump_id == before + 1 and bot.last_jump_reason == "dodge", "Difficulty %d reacts to a real incoming slash with a dodge jump" % difficulty)
		_check(bot.jump_direction.dot(lane_direction) >= -0.01, "Difficulty %d dodges sideways or away from the attacker" % difficulty)
		await _land()
		_check(bot.alive and player.alive and bot.attack_state == "idle", "Difficulty %d escapes the slash through movement and safely lands" % difficulty)
		samples[difficulty]["dodge_reaction_frames"] = elapsed
	_check(intervals[0] > intervals[1] and intervals[1] > intervals[2] and dodge_delays[0] > dodge_delays[1] and dodge_delays[1] > dodge_delays[2], "Higher difficulty jumps more often and reacts faster to danger")
	await _start(1, 2)
	bot.position = lane_origin + lane_direction * 6.0
	player.position = bot.position - lane_direction * 3.8
	player.visual.rotation.y = atan2(-lane_direction.x, -lane_direction.z)
	player.begin_attack()
	player.set_physics_process(true)
	bot.set_physics_process(true)
	await _frames(12)
	_check(bot.jump_id == 0 and bot.last_jump_reason.is_empty(), "An opponent swinging away does not trigger a false dodge")
	await _start(1, 1)
	bot.melee_enabled = false
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 3.0, 1.0)
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = lane_origin + lane_direction * 2.8 + Vector3.UP * 1.5
	await _frames(2)
	_check(not bot._can_jump(lane_direction) and not bot._begin_ai_jump(lane_direction, "chase"), "AI checks the full route and rejects a jump through solid obstacles")
	bot.visual.rotation.y = atan2(lane_direction.x, lane_direction.z)
	bot.request_jump()
	bot.set_physics_process(true)
	await _land()
	var blocked_travel: Vector3 = bot.position - lane_origin
	blocked_travel.y = 0.0
	_check(blocked_travel.length() < 2.2 and bot.attack_state == "idle", "NPC jump physics still stops at an obstacle and lands")
	wall.queue_free()
	await _frames(2)
	bot.reset_character()
	bot.jump_cooldown = 0.0
	player.position = lane_origin + lane_direction * 3.0
	await _frames(2)
	_check(not bot._can_jump(lane_direction), "AI rejects a jump into another character")
	bot.visual.rotation.y = atan2(lane_direction.x, lane_direction.z)
	bot.request_jump()
	bot.set_physics_process(true)
	await _land()
	var actor_travel: Vector3 = bot.position - lane_origin
	actor_travel.y = 0.0
	_check(actor_travel.length() < 2.0 and bot.alive and player.alive, "NPC jump stops at a character without dealing damage")
	bot.position = Vector3(16.0, 0.08, 0.0)
	bot.jump_cooldown = 0.0
	_check(not bot._can_jump(Vector3.RIGHT) and not bot._begin_ai_jump(Vector3.RIGHT, "chase"), "AI rejects a landing beyond the arena boundary")
	bot.round_active = false
	_check(not bot.request_jump(), "A paused round rejects NPC jumps")
	bot.round_active = true
	bot.attack_requested = true
	_check(not bot.request_jump(), "An already requested slash cannot be replaced by an NPC jump")
	bot.die()
	_check(not bot.request_jump(), "A dead NPC cannot jump")
	var report := {"passed": checks.size(), "failed": failures.size(), "checks": checks, "failures": failures, "samples": samples, "lane_origin": [lane_origin.x, lane_origin.z], "lane_direction": [lane_direction.x, lane_direction.z]}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/ai-jump-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("AI_JUMP_VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
