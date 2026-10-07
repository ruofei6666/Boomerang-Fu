extends SceneTree
## 使用引擎物理帧、真实键盘/多指事件验证跳跃、跳斩、死亡、对刀和重开。

var checks: Array[String] = []
var failures: Array[String] = []
var arena: Node3D
var player: CharacterBody3D
var target: CharacterBody3D
var combat: Node3D


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	(checks if condition else failures).append(description)
	print(("PASS: " if condition else "FAIL: ") + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(pressed: bool, echo: bool = false, code: int = KEY_J) -> void:
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


func _pair(spacing: float = 2.60, opposite: bool = false) -> void:
	combat.reset_round()
	for actor in combat.actors:
		if actor != player and actor != target:
			actor.position = Vector3(12.0, 0.01, -10.0)
			actor.set_physics_process(false)
			actor.collision_layer = 0
			actor.collision_mask = 0
		if actor.is_in_group("wanderers"):
			actor.melee_enabled = false
			actor.walking = false
			actor.idle_time = 9999.0
	player.position = Vector3(0.0, 0.01, 5.0)
	player.visual.rotation.y = 0.0
	target.position = Vector3(0.0, 0.01, 5.0 + spacing)
	target.visual.rotation.y = PI if opposite else 0.0
	target.set_physics_process(true)
	player.has_focus = true


func _verify() -> void:
	root.size = Vector2i(1440, 810)
	arena = load("res://scenes/stone_arena.tscn").instantiate()
	arena.verification_mode = true
	for name in ["EggplantNPC", "PumpkinNPC", "CarrotNPC", "BlueberryNPC", "WatermelonNPC"]:
		arena.get_node(name).melee_enabled = false
	root.add_child(arena)
	await process_frame
	await _frames(12)
	player = arena.get_node("StrawberryPlayer")
	target = arena.get_node("EggplantNPC")
	combat = arena.combat
	_check(combat.actors.size() == 6 and combat.player == player, "All six characters use one combat resolver")
	_check(combat.SLASH.get_length() > 0.20 and combat.SLASH.get_length() < 0.25, "Slash uses the approved short video clip")
	_check(combat.CLASH.get_length() > 0.05 and combat.SLICE.get_length() > 0.05, "Clash and fruit slice audio resources load")
	_pair()
	await _frames(4)
	var origin: Vector3 = player.position
	var slash_count: int = combat.sound_counts.slash
	_key(true)
	_key(false)
	await _frames(2)
	_check(player.attack_state == "hop", "J begins a forward hop before swinging")
	_check(not player.request_attack(), "A second attack cannot interrupt the hop")
	await _frames(4)
	_check(player.visual.position.y > 0.12 and player.position.z > origin.z + 0.20, "Hop visibly rises and advances toward the facing direction")
	_check(target.alive and combat.sound_counts.slash == slash_count, "Jump windup does not hit or play the swing early")
	await _frames(6)
	_check(player.attack_state == "swing" and player.slash_visual.visible, "Landing starts the boomerang swing and slash trail")
	_check(not target.alive and target.attack_state == "dead", "A frontal slash immediately kills the target")
	_check(combat.sound_counts.slash == slash_count + 1 and combat.sound_counts.slice == 1, "One swing and one death each play their own sound once")
	_check(target.collision_layer == 0 and not target.visual.visible and not target.request_attack(), "Dead characters disappear, stop blocking, and cannot attack")
	var halves: int = 0
	var dots: int = 0
	var caps: int = 0
	var matching: bool = true
	for child in combat.effects.get_children():
		if String(child.name).begins_with("FruitHalf"):
			halves += 1
			for part in child.get_children():
				if String(part.name).begins_with("CutFace"):
					caps += 1
		elif String(child.name).begins_with("BloodDot"):
			dots += 1
			matching = matching and child.mesh is SphereMesh and child.material_override.albedo_color.is_equal_approx(Color("7549ad"))
	_check(halves == 2 and caps >= 2, "Death produces two clipped fruit halves with solid cut faces")
	_check(dots == 26 and matching, "Blood consists of small round dots in the victim's color")
	var slices: int = combat.sound_counts.slice
	combat.resolve_hits()
	combat.resolve_hits()
	_check(combat.sound_counts.slice == slices, "A corpse cannot trigger repeated slicing or audio")
	await _frames(9)
	_check(player.attack_state == "recovery" and not player.slash_visual.visible and not player.request_attack(), "The swing has recovery time that prevents attack spamming")
	_key(true, true)
	_key(false)
	await _frames(22)
	_check(player.attack_state == "idle" and player.attack_id == 1, "Recovery returns to idle and key repeats do not create another slash")
	_check(player.right_hand.position.is_equal_approx(player.hand_rest) and is_zero_approx(player.visual.position.y), "Hands and jump height return to the resting pose")
	_pair()
	await _frames(4)
	var stick: Control = player.joystick
	var button: Control = arena.get_node("Interface").melee_button
	var center: Vector2 = stick.global_position + stick.size * 0.5
	var button_center: Vector2 = button.global_position + button.size * 0.5
	_touch(11, center + Vector2(stick.radius * 0.7, 0.0), true)
	_touch(12, button_center, true)
	await _frames(2)
	_check(player.attack_state == "hop" and button.touch_id == 12, "A second finger on the slash icon triggers the same attack")
	_check(stick.active_touch == 11 and stick.movement.x > 0.5, "Attacking with a second finger preserves joystick ownership")
	_touch(12, button_center, false, true)
	_check(button.touch_id == -1 and stick.active_touch == 11, "Canceling the attack touch does not release the joystick")
	_touch(11, center, false)
	_pair(3.0, true)
	await _frames(4)
	var first_origin: Vector3 = player.position
	var second_origin: Vector3 = target.position
	var clashes_before: int = combat.clashes
	var deaths_before: int = combat.kills
	player.request_attack()
	target.request_attack()
	await _frames(14)
	_check(combat.clashes == clashes_before + 1 and combat.sound_counts.clash == 1, "Facing simultaneous slashes create exactly one clash sound")
	_check(player.alive and target.alive and combat.kills == deaths_before, "Clash is resolved before death and both fighters survive")
	_check(player.attack_state == "recoil" and target.attack_state == "recoil", "Both fighters enter the recoil animation")
	await _frames(18)
	_check(player.position.distance_to(first_origin) < 0.002 and target.position.distance_to(second_origin) < 0.002, "Clash returns both fighters precisely to their pre-hop locations")
	_check(not player.request_attack() and not target.request_attack(), "Clash also retains recovery time")
	await _frames(22)
	_check(player.attack_state == "idle" and target.attack_state == "idle", "Both fighters can attack again after clash recovery")
	combat.actors.reverse()
	_pair(3.0, true)
	await _frames(4)
	clashes_before = combat.clashes
	player.request_attack()
	target.request_attack()
	await _frames(36)
	_check(combat.clashes == clashes_before + 1 and player.alive and target.alive, "Reversing actor iteration order does not change clash fairness")
	_pair(-1.8)
	await _frames(4)
	player.request_attack()
	await _frames(24)
	_check(target.alive, "A slash does not hit a target behind the attacker")
	# 新的 2.85 跳距加上 2.15 刀距已能覆盖原来的 5 米测试点。
	_pair(6.0)
	await _frames(4)
	player.request_attack()
	await _frames(24)
	_check(target.alive, "A slash cannot hit a distant target")
	_pair()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.5)
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(0.0, 1.5, 6.4)
	await _frames(4)
	_check(not combat.clear_path(player, target), "An obstacle blocks the melee line of sight")
	origin = player.position
	player.request_attack()
	await _frames(24)
	_check(target.alive and player.position.z < origin.z + 0.70, "The hop respects solid collisions and cannot cut through a rock")
	wall.queue_free()
	await process_frame
	_pair()
	await _frames(4)
	for actor in combat.actors:
		combat.effects.clear()
		combat.effects.slice(actor, Vector3.FORWARD)
		var actor_halves: int = 0
		var actor_dots: int = 0
		var actor_caps: int = 0
		var color_matches: bool = true
		for item in combat.effects.pieces:
			if item.half:
				actor_halves += 1
				for part in item.node.get_children():
					if String(part.name).begins_with("CutFace"):
						actor_caps += 1
			else:
				actor_dots += 1
				color_matches = color_matches and item.node.material_override.albedo_color.is_equal_approx(combat.effects.COLORS[String(actor.name)])
		_check(color_matches, "%s blood dots retain their character color" % actor.name)
		_check(actor_halves == 2 and actor_dots == 26 and actor_caps == 2, "%s splits into two solid capped halves" % actor.name)
	# 粒子色已经逐个检查；真实敌人也必须能触发砍击和死亡。
	combat.effects.clear()
	_pair(2.6, true)
	target.melee_enabled = true
	await _frames(44)
	_check(not player.alive and target.alive, "A nearby NPC reacts, hops, and can slash the player")
	arena.get_node("Interface")._respawn()
	_check(combat.effects.pieces.is_empty(), "Restart removes scattered halves, dots, and sparks")
	var restored: bool = true
	for actor in combat.actors:
		actor.set_physics_process(true)
		if actor.is_in_group("wanderers"):
			actor.melee_enabled = false
		restored = restored and actor.alive and actor.visual.visible and actor.collision_layer != 0 and actor.position.is_equal_approx(actor.spawn_position)
	_check(restored, "Restart revives all six characters at their own spawn positions")
	# 在同一条空路上实测两种动作，独立跳跃必须恰好是砍击前移的两倍。
	_pair(-2.6)
	await _frames(4)
	origin = player.position
	player.request_attack()
	await _frames(42)
	var hop_distance: float = Vector2(player.position.x - origin.x, player.position.z - origin.z).length()
	_check(absf(hop_distance - 2.85) < 0.005, "Slash hop travels exactly 2.85 without a full extra physics step")
	_pair(-2.6)
	await _frames(4)
	origin = player.position
	var jump_id: int = player.jump_id
	var old_id: int = player.attack_id
	slash_count = combat.sound_counts.slash
	_key(true, false, KEY_K)
	_key(false, false, KEY_K)
	await _frames(8)
	_check(player.attack_state == "jump" and player.jump_id == jump_id + 1, "K starts one independent forward jump")
	_check(player.visual.position.y > 0.4 and player.position.z > origin.z + 1.0, "Independent jump visibly rises and advances toward the facing direction")
	_check(not player.request_jump(), "An airborne jump cannot be interrupted by another jump")
	_key(true, true, KEY_K)
	_key(false, false, KEY_K)
	await _frames(20)
	var jump_distance: float = Vector2(player.position.x - origin.x, player.position.z - origin.z).length()
	_check(absf(jump_distance - hop_distance * 2.0) < 0.005, "Measured independent jump is exactly twice the slash hop (5.70)")
	_check(player.jump_id == jump_id + 1 and player.attack_id == old_id, "Held K does not queue another jump or trigger a slash")
	_check(player.attack_state == "idle" and is_zero_approx(player.visual.position.y) and player.velocity.is_zero_approx(), "Landing restores the resting pose and stops forward motion")
	_check(combat.sound_counts.slash == slash_count and not player.slash_visual.visible, "Independent jumping does not swing the weapon or play slash audio")
	_pair(-2.6)
	await _frames(4)
	origin = player.position
	old_id = player.attack_id
	slash_count = combat.sound_counts.slash
	_key(true, false, KEY_K)
	_key(false, false, KEY_K)
	await _frames(6)
	_key(true)
	_key(false)
	_check(player.attack_buffered and player.attack_state == "jump" and player.attack_id == old_id, "J during a jump buffers the slash without interrupting the airborne motion")
	_check(not player.request_attack(), "Repeated attack input cannot add a second buffered slash")
	_key(true, true)
	_key(false)
	await _frames(6)
	_check(player.attack_state == "jump" and player.attack_buffered and target.alive and combat.sound_counts.slash == slash_count, "Releasing J retains the input without early damage or slash audio")
	await _frames(10)
	var landing_offset: Vector3 = player.attack_origin - origin
	landing_offset.y = 0.0
	_check(player.attack_state == "hop" and player.attack_id == old_id + 1 and not player.attack_buffered, "Landing automatically starts the buffered slash once")
	_check(landing_offset.distance_to(player.jump_direction * 5.70) < 0.005, "Buffered slash starts at the full jump's landing point")
	await _frames(40)
	_check(player.attack_state == "idle" and player.attack_id == old_id + 1 and combat.sound_counts.slash == slash_count + 1, "One buffered input produces exactly one full slash and recovery")
	for yaw in [PI * 0.25, PI * 0.5, PI]:
		_pair()
		target.position = Vector3(12.0, 0.01, -10.0)
		target.set_physics_process(false)
		player.visual.rotation.y = yaw
		await _frames(4)
		origin = player.position
		var expected: Vector3 = player.facing_direction() * 5.70
		player.request_jump()
		await _frames(24)
		var offset: Vector3 = player.position - origin
		offset.y = 0.0
		_check(offset.distance_to(expected) < 0.005, "Jump follows the actual facing direction at yaw %.2f" % yaw)
	_pair(1.5)
	await _frames(4)
	player.request_jump()
	await _frames(24)
	_check(target.alive and player.alive, "Jumping toward a nearby character does not deal melee damage")
	_pair(-2.6)
	await _frames(4)
	var jump_button: Control = arena.get_node("Interface").jump_button
	var jump_center: Vector2 = jump_button.global_position + jump_button.size * 0.5
	jump_id = player.jump_id
	old_id = player.attack_id
	_touch(21, center + Vector2(stick.radius * 0.7, 0.0), true)
	_touch(22, jump_center, true)
	await _frames(2)
	_check(player.attack_state == "jump" and jump_button.touch_id == 22 and player.jump_id == jump_id + 1, "The jump icon starts the same action with a second finger")
	_check(stick.active_touch == 21 and stick.movement.x > 0.5, "Jumping preserves the first finger's joystick control")
	var simulated_mouse := InputEventMouseButton.new()
	simulated_mouse.device = -1
	simulated_mouse.button_index = MOUSE_BUTTON_LEFT
	simulated_mouse.position = jump_center
	simulated_mouse.pressed = true
	Input.parse_input_event(simulated_mouse)
	Input.flush_buffered_events()
	_check(player.jump_id == jump_id + 1 and player.attack_id == old_id, "A simulated mouse copy cannot duplicate the jump or trigger a slash")
	_touch(22, jump_center, false, true)
	_check(jump_button.touch_id == -1 and stick.active_touch == 21, "Canceling the jump touch releases only that button")
	_touch(21, center, false)
	await _frames(24)
	_pair(-2.6)
	await _frames(4)
	old_id = player.attack_id
	slash_count = combat.sound_counts.slash
	_touch(31, center + Vector2(stick.radius * 0.7, 0.0), true)
	_touch(32, jump_center, true)
	await _frames(4)
	_check(button._action_ready() and not jump_button._action_ready(), "The slash icon is available for buffering while the jump icon stays locked")
	_touch(33, button_center, true)
	_check(player.attack_buffered and player.attack_state == "jump" and button.touch_id == 33, "Touching the slash icon during a jump buffers the same attack as J")
	_check(stick.active_touch == 31 and stick.movement.x > 0.5 and not button._action_ready(), "Buffered touch preserves joystick ownership and shows the slash as queued")
	_touch(33, button_center, false, true)
	_touch(32, jump_center, false, true)
	_check(player.attack_buffered and button.touch_id == -1 and jump_button.touch_id == -1 and stick.active_touch == 31, "Releasing or canceling action touches keeps the buffered slash and joystick finger")
	_touch(31, center, false)
	await _frames(60)
	_check(player.attack_id == old_id + 1 and combat.sound_counts.slash == slash_count + 1 and not player.attack_buffered, "Touch buffering starts exactly one slash after landing")
	_pair(-2.6)
	var jump_wall := StaticBody3D.new()
	var jump_collider := CollisionShape3D.new()
	var jump_box := BoxShape3D.new()
	jump_box.size = Vector3(3.0, 3.0, 0.5)
	jump_collider.shape = jump_box
	jump_wall.add_child(jump_collider)
	arena.add_child(jump_wall)
	jump_wall.position = Vector3(0.0, 1.5, 6.4)
	await _frames(4)
	origin = player.position
	player.request_jump()
	await _frames(24)
	_check(player.position.z < origin.z + 0.70 and player.attack_state == "idle", "The longer jump respects solid obstacles and still lands")
	jump_wall.queue_free()
	await process_frame
	_pair(-2.6)
	player.position.z = 11.0
	player.request_jump()
	await _frames(24)
	_check(player.position.z <= 12.2 and player.attack_state == "idle", "Jumping cannot cross the map boundary")
	_pair(-2.6)
	# 将目标移开，避免重开瞬间旧的物理碰撞位置与玩家出生点重叠。
	target.position = Vector3(12.0, 0.01, -10.0)
	target.set_physics_process(false)
	await _frames(4)
	player.request_jump()
	await _frames(6)
	player.request_attack()
	old_id = player.attack_id
	arena.get_node("Interface")._respawn()
	await _frames(26)
	var reset_offset := Vector2(player.position.x - player.spawn_position.x, player.position.z - player.spawn_position.z)
	_check(reset_offset.length() < 0.005 and player.attack_state == "idle" and is_zero_approx(player.visual.position.y), "Restart during a jump clears its movement and airborne pose")
	_check(not player.attack_buffered and player.attack_id == old_id, "Restart discards the buffered slash instead of attacking after respawn")
	player.request_jump()
	player.request_attack()
	player.die()
	_check(not player.request_jump(), "A dead player cannot jump")
	_check(not player.attack_buffered and not player.request_attack(), "Death discards the buffered slash and prevents new attack input")
	player.reset_player()
	player.request_jump()
	player.request_attack()
	old_id = player.attack_id
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames(26)
	_check(not player.attack_buffered and player.attack_id == old_id and player.attack_state == "idle", "Losing focus during a jump clears the buffered slash before landing")
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	player.request_jump()
	player.request_attack()
	arena._web_blur([])
	await _frames(26)
	_check(not player.attack_buffered and player.attack_id == old_id, "Web blur also clears the buffered slash before landing")
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	old_id = player.attack_id
	jump_id = player.jump_id
	_key(true)
	_key(false)
	_key(true, false, KEY_K)
	_key(false, false, KEY_K)
	arena.get_node("Interface")._jump()
	await _frames(2)
	_check(player.attack_id == old_id and not player.attack_requested, "Losing focus cannot queue a keyboard attack")
	_check(player.jump_id == jump_id and player.attack_state == "idle", "Losing focus blocks keyboard and touch jump requests")
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	# 用真实跳斩验证人机互砍，双方同时或先后出刀都只能淘汰一个。
	var second_bot: CharacterBody3D = arena.get_node("PumpkinNPC")
	for reversed_order in [false, true]:
		for delay in [0, 3]:
			_pair(3.0, true)
			player.position = Vector3(12.0, 0.01, -10.0)
			player.set_physics_process(false)
			player.collision_layer = 0
			player.collision_mask = 0
			second_bot.position = Vector3(0.0, 0.01, 5.0)
			second_bot.visual.rotation.y = 0.0
			second_bot.collision_layer = second_bot.rest_collision_layer
			second_bot.collision_mask = second_bot.rest_collision_mask
			second_bot.set_physics_process(true)
			await _frames(4)
			clashes_before = combat.clashes
			var clash_sounds_before: int = combat.sound_counts.clash
			var slice_sounds_before: int = combat.sound_counts.slice
			deaths_before = combat.kills
			second_bot.request_attack()
			await _frames(delay)
			target.request_attack()
			await _frames(14)
			_check(combat.clashes == clashes_before and combat.sound_counts.clash == clash_sounds_before, "Bot slashes produce no clash (reversed=%s, delay=%d)" % [reversed_order, delay])
			_check(second_bot.alive != target.alive and combat.kills == deaths_before + 1 and combat.sound_counts.slice == slice_sounds_before + 1, "Bot exchange kills exactly one and plays one slice (reversed=%s, delay=%d)" % [reversed_order, delay])
			if delay > 0:
				_check(second_bot.alive and not target.alive, "The earlier bot slash wins (reversed=%s)" % reversed_order)
			await _frames(36)
			_check(second_bot.alive != target.alive and combat.kills == deaths_before + 1 and combat.sound_counts.slice == slice_sounds_before + 1, "The defeated bot cannot retaliate during later frames (reversed=%s, delay=%d)" % [reversed_order, delay])
		combat.actors.reverse()
	player.set_physics_process(true)
	var report := {"passed": checks.size(), "failed": failures.size(), "checks": checks, "failures": failures, "sounds": combat.sound_counts, "distances": {"slash_hop": hop_distance, "jump": jump_distance, "ratio": jump_distance / hop_distance}}
	var file := FileAccess.open("res://artifacts/combat-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("COMBAT_VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
