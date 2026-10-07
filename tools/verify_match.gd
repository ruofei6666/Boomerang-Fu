extends SceneTree
## 用真实场景、界面按钮和物理帧验证整场比赛，不用计分逻辑的替身。

var checks: Array[String] = []
var failures: Array[String] = []
var arena: Node3D
var match_controller: Node
var ui: CanvasLayer


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	(checks if condition else failures).append(description)
	print(("PASS: " if condition else "FAIL: ") + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _freeze_actors() -> void:
	for actor in arena.combat.actors:
		actor.set_physics_process(false)
		actor.velocity = Vector3.ZERO


func _leave_alive(seat: int) -> void:
	for index in range(arena.combat.actors.size()):
		if index != seat:
			arena.combat.actors[index].die()


func _clear_spawn(actor: CharacterBody3D) -> bool:
	var collider: CollisionShape3D = actor.get_node("BodyCollision")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	var excluded: Array[RID] = []
	for other in arena.combat.actors:
		excluded.append(other.get_rid())
	query.exclude = excluded
	for hit in actor.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if hit.collider.get_parent().name in ["InteriorRocks", "PerimeterCliffs"]:
			return false
	return true


func _verify() -> void:
	root.size = Vector2i(1440, 810)
	arena = load("res://scenes/stone_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await _frames(4)
	match_controller = arena.match_controller
	ui = arena.get_node("Interface")
	_check(match_controller.phase == "lobby" and ui.lobby_panel.visible, "Entering the game opens match settings")
	_check(not arena.combat.enabled and not arena.player.round_active, "Lobby freezes the arena and combat")
	_check(not arena.player.request_attack() and not arena.player.request_jump(), "Lobby rejects slash and jump input")
	_check(match_controller.bot_count == 3 and ui.difficulty_choice.item_count == 3, "Default three bots and exactly three difficulty choices")
	ui.plus_button.pressed.emit()
	ui.plus_button.pressed.emit()
	_check(match_controller.bot_count == 5 and ui.plus_button.disabled and ui.seat_rows[5].visible, "Bot plus button reaches five and reveals every seat")
	for index in range(4):
		ui.minus_button.pressed.emit()
	_check(match_controller.bot_count == 1 and ui.minus_button.disabled and not ui.seat_rows[2].visible, "Bot minus button reaches one and hides extra seats")
	for index in range(4):
		ui.plus_button.pressed.emit()
	ui.difficulty_choice.item_selected.emit(2)
	var roles: Array[int] = [3, 0, 0, 2, 1, 3]
	for index in range(roles.size()):
		ui.role_selectors[index].item_selected.emit(roles[index])
	_check(match_controller.difficulty == 2 and match_controller.role_choices == roles, "UI applies difficulty and each seat's chosen role")
	ui.start_button.pressed.emit()
	await _frames(4)
	_check(match_controller.phase == "playing" and match_controller.round_number == 1 and arena.combat.actors.size() == 6, "Start creates the configured six-player first round")
	_check(match_controller.scores == [0, 0, 0, 0, 0, 0], "A new match starts every seat at zero")
	_check(arena.player.get_node_or_null("Visual/Body") != null and arena.player.get_meta("role") == 3, "Carrot can be the manually controlled player")
	_check(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("wanderers").size() == 5, "Only one player receives input, all five other seats are bots")
	_check(ui.melee_button.player == arena.player and ui.jump_button.player == arena.player and arena.camera_rig.follow_target == arena.player, "Both actions and camera follow the selected player model")
	_check(arena.combat.actors[1].get_meta("role") == 0 and arena.combat.actors[2].get_meta("role") == 0, "Multiple bots can select strawberry without sharing a score")
	var clear: bool = true
	var separated: bool = true
	for first in range(arena.combat.actors.size()):
		clear = clear and _clear_spawn(arena.combat.actors[first])
		for second in range(first + 1, arena.combat.actors.size()):
			separated = separated and arena.combat.actors[first].spawn_position.distance_to(arena.combat.actors[second].spawn_position) >= 7.0
	_check(clear and separated, "Six actors spawn on clear ground at least seven meters apart")
	var bot: CharacterBody3D = arena.combat.actors[1]
	bot.set_difficulty(0)
	var easy_reaction: float = bot.reaction_delay
	var easy_interval: float = bot.attack_interval
	bot.set_difficulty(1)
	var normal_reaction: float = bot.reaction_delay
	var normal_interval: float = bot.attack_interval
	bot.set_difficulty(2)
	_check(easy_reaction > normal_reaction and normal_reaction > bot.reaction_delay and easy_interval > normal_interval and normal_interval > bot.attack_interval, "Easy, normal and hard have distinct reaction and attack cadence")
	_freeze_actors()
	ui.hide()
	_leave_alive(1)
	await _frames(55)
	_check(match_controller.phase == "playing" and match_controller.scores[1] == 0, "A sole survivor does not score before one second")
	await _frames(10)
	_check(match_controller.phase == "scores" and match_controller.scores == [0, 1, 0, 0, 0, 0], "One second awards only the surviving bot and opens scores")
	_check(match_controller.round_winner == 1 and ui.score_list.get_child_count() == 6, "Scoreboard includes all six seats and the round winner")
	_check(ui.visible, "A previously hidden HUD automatically reappears for the score screen")
	_check(not arena.combat.enabled and not arena.player.request_attack() and not arena.player.request_jump(), "Scores freeze combat and reject action input")
	await _frames(90)
	_check(match_controller.phase == "scores" and match_controller.round_number == 1 and match_controller.scores[1] == 1, "Scores wait for a click and cannot award the same round twice")
	var old_starts: Array[Vector3] = []
	for actor in arena.combat.actors:
		old_starts.append(actor.spawn_position)
	ui.next_button.pressed.emit()
	await _frames(2)
	var revived: bool = true
	var changed: bool = false
	for index in range(arena.combat.actors.size()):
		var actor: CharacterBody3D = arena.combat.actors[index]
		revived = revived and actor.alive and actor.round_active and actor.attack_state == "idle"
		changed = changed or old_starts[index] != actor.spawn_position
	_check(match_controller.round_number == 2 and revived and changed, "Next round revives every role and redistributes starts")
	_check(match_controller.scores == [0, 1, 0, 0, 0, 0], "Next round preserves accumulated seat scores")
	_leave_alive(0)
	await _frames(24)
	_check(match_controller.phase == "playing" and match_controller.survivor_time < 0.6, "The survivor hold remains active for the full second")
	arena.player.die()
	await _frames(2)
	_check(match_controller.phase == "scores" and match_controller.round_winner == -1 and match_controller.scores == [0, 1, 0, 0, 0, 0], "If the last survivor dies during the hold, no one gains a point")
	_check(ui.score_result.text.contains("本局不加分"), "A drawn round explicitly displays no score change")
	ui.next_button.pressed.emit()
	_leave_alive(0)
	await _frames(25)
	arena.combat.actors[1].reset_character()
	await _frames(3)
	_check(match_controller.survivor_time == 0.0 and match_controller.survivor == -1, "Two living roles reset the continuous survivor timer")
	arena.combat.actors[1].die()
	await _frames(55)
	_check(match_controller.phase == "playing", "A new sole survivor must wait a fresh full second")
	await _frames(10)
	_check(match_controller.scores[0] == 1, "Player receives the same survivor point as a bot")
	ui.next_button.pressed.emit()
	# 同一帧命中快照：重叠且同向挥砍，不触发相向对刀，所有席位同时死亡。
	for actor in arena.combat.actors:
		actor.position = Vector3(0.0, 0.08, 5.0)
		actor.attack_state = "swing"
		actor.attack_direction = Vector3.FORWARD
		actor.hit_targets.clear()
	arena.combat.resolve_hits()
	await _frames(2)
	_check(match_controller.phase == "scores" and match_controller.round_winner == -1 and match_controller.scores == [1, 1, 0, 0, 0, 0], "Real simultaneous combat deaths finish a draw immediately")
	ui.lobby_button.pressed.emit()
	_check(match_controller.phase == "lobby" and match_controller.bot_count == 5 and match_controller.role_choices == roles, "Returning to settings preserves the chosen configuration")
	match_controller.configure(1, 1, [0, 1])
	ui.start_button.pressed.emit()
	_freeze_actors()
	for round_index in range(10):
		_leave_alive(0)
		await _frames(65)
		if round_index < 9:
			ui.next_button.pressed.emit()
	_check(match_controller.phase == "match_over" and match_controller.champion == 0 and match_controller.scores == [10, 0], "The first role to ten wins the entire match")
	_check(ui.next_button.text == "再玩一场" and ui.score_title.text.contains("获胜"), "Match victory replaces next-round action with a new-match action")
	var final_round: int = match_controller.round_number
	match_controller.next_round()
	_check(match_controller.round_number == final_round and match_controller.phase == "match_over", "A completed match cannot start an eleventh round")
	ui.next_button.pressed.emit()
	_check(match_controller.phase == "lobby", "Play again returns to editable match settings")
	for role in range(4):
		match_controller.configure(1, 1, [role, (role + 1) % 4])
		ui.start_button.pressed.emit()
		_freeze_actors()
		_check(arena.player.body_visual == arena.player.get_node(arena.player.body_path) and arena.player.get_meta("role") == role and arena.player.request_jump(), "Role %d supports player controls and its correct body mesh" % role)
		arena.combat.effects.slice(arena.player, Vector3.RIGHT)
		var matching_dots: int = 0
		var cap_count: int = 0
		for effect in arena.combat.effects.get_children():
			if effect.is_queued_for_deletion():
				continue
			if String(effect.name).begins_with("BloodDot") and effect.material_override.albedo_color == arena.combat.effects.ROLE_COLORS[role]:
				matching_dots += 1
			elif String(effect.name).begins_with("FruitHalf"):
				for part in effect.get_children():
					cap_count += int(String(part.name).begins_with("CutFace"))
		_check(matching_dots == 26 and cap_count == (4 if role == 2 else 2), "Role %d keeps its death color and correct cut geometry after changing seats" % role)
		match_controller.return_to_lobby()
	# 玩家死亡后仍由真实 AI 决出结果，不能因为缺少玩家目标而停摆。
	match_controller.configure(2, 1, [0, 1, 3])
	ui.start_button.pressed.emit()
	var previous_kills: int = arena.combat.kills
	arena.player.die()
	await _frames(2)
	_check(arena.camera_rig.follow_target != arena.player and arena.camera_rig.follow_target.alive, "Eliminated player watches a living bot through the following camera")
	var elapsed: int = 0
	while match_controller.phase == "playing" and elapsed < 3600:
		await _frames(30)
		elapsed += 30
	_check(match_controller.phase == "scores" and match_controller.round_winner in [-1, 1, 2], "Bots continue real FFA to a resolved round after the player is eliminated")
	_check(arena.combat.kills > previous_kills, "Autonomous FFA uses real collision, attack and hit resolution")
	var report := {"passed": checks.size(), "failed": failures.size(), "checks": checks, "failures": failures, "ai_resolution_seconds": elapsed / 60.0}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/match-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MATCH_VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
