extends SceneTree
## 用真实按键、多指输入、物理碰撞、切开效果和比赛计分验证投掷与人机拾取。

var checks: Array[String] = []
var failures: Array[String] = []
var arena: Node3D
var player: CharacterBody3D
var target: CharacterBody3D
var combat: Node3D
var lane_origin := Vector3.ZERO
var lane_direction := Vector3.RIGHT
var ai_samples: Array[Dictionary] = []


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	(checks if condition else failures).append(description)
	print(("PASS: " if condition else "FAIL: ") + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _stage() -> void:
	combat.reset_round()
	arena.get_node("Interface").release_actions()
	for actor in combat.actors:
		actor.set_physics_process(false)
		actor.position = Vector3(30.0 + combat.actors.find(actor) * 4.0, 0.08, 30.0)
		if actor.is_in_group("wanderers"):
			actor.melee_enabled = false
	player.position = lane_origin
	player.visual.rotation.y = atan2(lane_direction.x, lane_direction.z)
	player.has_focus = true
	arena.camera_rig.yaw = 0.0
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_J, KEY_K, KEY_L]:
		_key(code, false)


func _throw(actor: CharacterBody3D, direction: Vector3) -> CharacterBody3D:
	actor.visual.rotation.y = atan2(direction.x, direction.z)
	actor.request_throw()
	actor.release_throw()
	return actor.thrown_boomerang


func _find_lane() -> bool:
	for x in range(-12, 13, 2):
		for z in range(-8, 9, 2):
			for direction in [Vector3.RIGHT, Vector3.BACK]:
				var origin := Vector3(x, 0.08, z)
				var ending: Vector3 = origin + direction * 8.0
				if absf(ending.x) > 15.0 or absf(ending.z) > 10.0 or combat.navigation.is_point_solid(Vector2i(x, z)):
					continue
				player.position = origin
				if not player.test_move(player.global_transform, direction * 8.0):
					lane_origin = origin
					lane_direction = direction
					return true
	return false


func _verify() -> void:
	root.size = Vector2i(1440, 810)
	arena = load("res://scenes/stone_arena.tscn").instantiate()
	arena.verification_mode = true
	root.add_child(arena)
	await process_frame
	combat = arena.combat
	player = arena.player
	target = combat.actors[1]
	for actor in combat.actors:
		actor.set_physics_process(false)
		actor.position = Vector3(30.0 + combat.actors.find(actor) * 4.0, 0.08, 30.0)
	combat.build_navigation()
	await _frames(3)
	_check(_find_lane(), "Find a real unobstructed eight-metre lane in the current arena")
	_check(is_equal_approx(combat.throw_range, 38.0), "Flight range reads the map's 38-metre long side")
	_stage()
	player.set_physics_process(true)
	await _frames(4)
	var start: Vector3 = player.position
	var slash_count: int = combat.sound_counts.slash
	var throw_id: int = player.throw_id
	_key(KEY_L, true)
	_key(KEY_D, true)
	await _frames(6)
	_check(player.attack_state == "aim" and player.aim_visual.visible and player.has_boomerang, "Holding L keeps the weapon in hand and shows an aiming arrow")
	_check(Vector2(player.position.x - start.x, player.position.z - start.z).length() < 0.001 and player.velocity.is_zero_approx(), "WASD changes aim without moving or drifting the character")
	_check(player.throw_direction.dot(Vector3.RIGHT) > 0.999 and combat.sound_counts.slash == slash_count and player.throw_id == throw_id, "D aims right without an early projectile or slash sound")
	_key(KEY_D, false)
	_key(KEY_W, true)
	await _frames(3)
	_check(player.throw_direction.dot(Vector3.FORWARD) > 0.999, "W updates the stationary aiming direction")
	_key(KEY_W, false)
	_key(KEY_L, true, true)
	_check(not player.request_attack() and not player.request_jump(), "Aiming rejects melee, jumping and repeated L presses")
	_key(KEY_L, false)
	var weapon: CharacterBody3D = player.thrown_boomerang
	_check(is_instance_valid(weapon) and player.throw_id == throw_id + 1 and combat.sound_counts.slash == slash_count + 1, "Releasing L launches exactly one projectile and approved slash sound")
	_check(player.attack_state == "idle" and not player.has_boomerang and not player.held_boomerang.visible and weapon.model.visible, "The thrown weapon replaces the held model and movement unlocks")
	_check(not player.request_attack() and not player.request_throw(), "An unarmed character cannot slash or throw again")
	_check(player.request_jump() and not player.request_attack() and not player.attack_buffered, "An unarmed character can jump but cannot buffer a slash")
	player.set_physics_process(false)
	player.position = Vector3(30, 0.08, 30)
	var frames: int = 0
	var constant_speed: bool = true
	while weapon.flying and frames < 150:
		constant_speed = constant_speed and absf(weapon.velocity.length() - 24.0) < 0.001
		await _frames(1)
		frames += 1
	_check(not weapon.flying and weapon.velocity.is_zero_approx() and absf(weapon.distance_traveled - 38.0) < 0.001, "The projectile stops after exactly one map length of cumulative travel")
	_check(constant_speed and weapon.bounce_count > 0 and frames <= 100, "Rock and boundary ricochets retain full speed and their remaining frame distance")
	await _frames(10)
	_check(not player.has_boomerang and not player.request_attack() and weapon.pickup_marker.visible, "Stopping never auto-returns the weapon; its drop marker stays visible")
	target.position = Vector3(weapon.position.x, 0.08, weapon.position.z)
	await _frames(2)
	_check(not player.has_boomerang and target.has_boomerang, "Another character cannot steal the owner's weapon")
	player.attack_state = "idle"
	player.position = target.position
	await _frames(2)
	_check(player.has_boomerang and player.held_boomerang.visible and combat.projectiles.is_empty(), "Walking near the stopped weapon restores it and removes the dropped model")
	_check(player.request_attack(), "Picking up restores melee attacks")

	_stage()
	player.set_physics_process(true)
	await _frames(3)
	var ui: CanvasLayer = arena.get_node("Interface")
	var stick: Control = ui.joystick
	var stick_center: Vector2 = stick.global_position + stick.size * 0.5
	var throw_center: Vector2 = ui.throw_button.global_position + ui.throw_button.size * 0.5
	_touch(10, stick_center + Vector2(stick.radius * 0.8, 0), true)
	_touch(11, throw_center, true)
	await _frames(3)
	start = player.position
	_check(player.attack_state == "aim" and stick.active_touch == 10 and ui.throw_button.touch_id == 11, "Two fingers independently own the joystick and held throw button")
	_drag(10, stick_center + Vector2(0, stick.radius * 0.8))
	await _frames(6)
	_check(player.position.distance_to(start) < 0.001 and player.throw_direction.dot(Vector3.BACK) > 0.999, "Dragging the joystick while holding throw rotates aim without walking")
	throw_id = player.throw_id
	_touch(11, throw_center, false)
	_check(player.throw_id == throw_id + 1 and stick.active_touch == 10 and ui.throw_button.touch_id == -1, "Lifting only the throw finger launches once and preserves the joystick finger")
	_touch(10, stick_center, false)
	_stage()
	throw_id = player.throw_id
	_touch(12, throw_center, true)
	_touch(12, throw_center, false, true)
	_check(player.attack_state == "idle" and player.has_boomerang and player.throw_id == throw_id and player.throw_sources.is_empty(), "Touch cancellation releases aim without throwing or losing the weapon")
	_key(KEY_L, true)
	player._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_key(KEY_L, false)
	_check(player.attack_state == "idle" and player.has_boomerang and player.throw_sources.is_empty() and player.throw_id == throw_id, "Focus loss cancels held throws without an accidental release shot")
	player.has_focus = true
	_key(KEY_L, true)
	_touch(13, throw_center, true)
	_key(KEY_L, false)
	_check(player.attack_state == "aim" and player.throw_id == throw_id, "Releasing keyboard L keeps aiming when the throw finger is still held")
	_touch(13, throw_center, false)
	_check(player.throw_id == throw_id + 1, "The final held input releases one projectile")
	combat.reset_round()
	_check(combat.projectiles.is_empty() and player.has_boomerang and not player.aim_visual.visible, "Round reset clears projectiles, aim and unarmed state")

	_stage()
	target.position = lane_origin + lane_direction * 6.0
	await _frames(2)
	combat.set_physics_process(false)
	var slice_count: int = combat.sound_counts.slice
	var kill_count: int = combat.kills
	weapon = _throw(player, lane_direction)
	weapon.advance(0.35)
	_check(not target.alive and combat.kills == kill_count + 1 and combat.sound_counts.slice == slice_count + 1, "Swept projectile hits cannot tunnel through a target at a large frame step")
	var halves: int = 0
	var dots: int = 0
	for child in combat.effects.get_children():
		halves += int(String(child.name).begins_with("FruitHalf"))
		dots += int(String(child.name).begins_with("BloodDot"))
	_check(halves == 2 and dots == 26, "Ranged hits reuse the melee fruit halves and 26 coloured particles")
	weapon.advance(0.01)
	_check(combat.kills == kill_count + 1 and combat.sound_counts.slice == slice_count + 1, "The same projectile never scores or plays slice twice for one victim")
	_stage()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.25, 3.0, 6.0) if lane_direction == Vector3.RIGHT else Vector3(6.0, 3.0, 0.25)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = lane_origin + lane_direction * 2.0 + Vector3.UP * 1.4
	target.position = lane_origin + lane_direction * 4.0
	await _frames(3)
	var incoming: Vector3 = lane_direction.rotated(Vector3.UP, 0.25)
	weapon = _throw(player, incoming)
	weapon.advance(0.15)
	_check(weapon.bounce_count == 1 and weapon.direction.dot(incoming.bounce(-lane_direction)) > 0.999 and absf(weapon.velocity.length() - 24.0) < 0.001, "An oblique obstacle hit obeys equal reflection angles and conserves speed")
	_check(target.alive, "A solid wall blocks projectile damage to the character behind it")
	_stage()
	box.size.y = 0.55
	wall.position.y = 0.275
	target.position = lane_origin + lane_direction * 4.0
	await _frames(2)
	weapon = _throw(player, incoming)
	weapon.advance(0.15)
	_check(weapon.bounce_count == 1 and target.alive and weapon.direction.dot(incoming.bounce(-lane_direction)) > 0.999, "Low stone barriers also reflect projectiles instead of letting them pass overhead")
	wall.queue_free()
	combat.clear_boomerangs()
	combat.set_physics_process(true)
	await _frames(2)

	arena.match_controller.legacy_mode = false
	arena.match_controller.phase = "lobby"
	for role in range(6):
		arena.match_controller.return_to_lobby()
		arena.match_controller.configure(1, role % 3, [0, role])
		arena.match_controller.start_match()
		player = arena.player
		target = combat.actors[1]
		_stage()
		target.melee_enabled = true
		target.position = lane_origin
		target.spawn_position = lane_origin
		target.jump_cooldown = 99.0
		target.random.seed = 31007
		player.position = lane_origin + lane_direction * 6.0
		target.set_physics_process(true)
		var beginning: Vector3 = target.position
		var elapsed: int = 0
		while target.throw_id == 0 and elapsed < 120:
			await _frames(1)
			elapsed += 1
		_check(target.throw_id == 1 and not target.has_boomerang and Vector2(target.position.x - beginning.x, target.position.z - beginning.z).length() < 0.01, "Role %d AI autonomously aims, stays still and releases a ranged attack" % role)
		player.position = Vector3(30, 0.08, 30)
		elapsed = 0
		while not target.has_boomerang and elapsed < 600:
			await _frames(1)
			elapsed += 1
		_check(target.has_boomerang and combat.projectiles.is_empty(), "Role %d AI follows its flying weapon and retrieves it around map obstacles" % role)
		_check(target.has_boomerang and target.request_attack(), "Role %d AI can attack again after retrieving its weapon" % role)
		ai_samples.append({"role": role, "difficulty": role % 3, "pickup_frames": elapsed, "position": str(target.position)})

	arena.match_controller.return_to_lobby()
	arena.match_controller.configure(2, 1, [0, 1, 2], arena.match_controller.ScoringMode.KILLS)
	arena.match_controller.start_match()
	player = arena.player
	target = combat.actors[1]
	_stage()
	combat.set_physics_process(false)
	target.position = lane_origin + lane_direction * 3.8
	combat.actors[2].position = lane_origin + lane_direction * 7.5
	await _frames(2)
	weapon = _throw(player, lane_direction)
	weapon.advance(0.35)
	_check(arena.match_controller.scores[0] == 2 and arena.match_controller.round_points[0] == 2, "Ranged eliminations award the original thrower two real kill points")
	_stage()
	arena.match_controller.scores[0] = 9
	target.position = lane_origin + lane_direction * 3.8
	combat.actors[2].position = lane_origin + lane_direction * 7.5
	await _frames(2)
	weapon = _throw(player, lane_direction)
	weapon.advance(0.35)
	_check(arena.match_controller.phase == "match_over" and arena.match_controller.scores[0] == 10 and combat.actors[2].alive, "A ranged tenth point immediately ends the match before further projectile hits")
	arena.match_controller.return_to_lobby()
	arena.match_controller.start_match()
	_check(combat.projectiles.is_empty() and arena.player.has_boomerang, "Starting another match removes old projectiles before replacing their owners")
	var file := FileAccess.open("res://artifacts/throw-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": checks.size(), "failures": failures, "checks": checks, "ai_samples": ai_samples}, "\t"))
	print("THROW_VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
