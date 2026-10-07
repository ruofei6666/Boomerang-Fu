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


func _stage_strike(seat: int, targets: Array) -> void:
	# 只固定动作与位置；命中、淘汰、击杀归属和计分仍由真实 Combat 处理。
	arena.combat.enabled = false
	_freeze_actors()
	for index in range(arena.combat.actors.size()):
		var actor: CharacterBody3D = arena.combat.actors[index]
		actor.position = Vector3(-12.0 + index * 4.0, 0.08, 8.0)
		actor.attack_state = "idle"
		actor.hit_targets.clear()
	var attacker: CharacterBody3D = arena.combat.actors[seat]
	attacker.position = Vector3(0.0, 0.08, 5.0)
	for index in range(targets.size()):
		arena.combat.actors[targets[index]].position = Vector3((index - (targets.size() - 1) * 0.5) * 1.8, 0.08, 3.5)
	await _frames(2)
	arena.combat.enabled = true
	attacker.attack_state = "swing"
	attacker.attack_direction = Vector3.FORWARD
	attacker.attack_time = 0.07


func _strike(seat: int, targets: Array) -> void:
	await _stage_strike(seat, targets)
	arena.combat.resolve_hits()


func _verify_kill_scoring() -> void:
	match_controller.return_to_lobby()
	ui.scoring_choice.item_selected.emit(1)
	_check(match_controller.scoring_mode == 1 and ui.scoring_choice.selected == 1 and ui.rules_label.text.contains("每击杀"), "Scoring dropdown selects kills and explains its rules")
	match_controller.configure(5, 1, [0, 0, 0, 2, 1, 3])
	_check(match_controller.scoring_mode == 1, "Changing bots, difficulty or roles preserves the chosen scoring mode")
	ui.start_button.pressed.emit()
	_freeze_actors()
	_check(match_controller.round_points == [0, 0, 0, 0, 0, 0], "New kill-scored match initializes all per-round gains")
	match_controller.configure(1, 0, [3, 2], 0)
	_check(match_controller.scoring_mode == 1 and match_controller.bot_count == 5, "Scoring rules cannot change during an active match")
	await _strike(0, [2, 3])
	_check(match_controller.scores == [2, 0, 0, 0, 0, 0] and match_controller.round_points == [2, 0, 0, 0, 0, 0], "One real swing killing two opponents awards exactly two player points")
	arena.combat.resolve_hits()
	_check(match_controller.scores[0] == 2, "Repeated hit resolution cannot count an already killed victim twice")
	await _strike(1, [0])
	_check(not arena.player.alive and match_controller.scores == [2, 1, 0, 0, 0, 0], "A bot receives its kill point while the eliminated player keeps theirs")
	await _strike(1, [4])
	_check(match_controller.scores == [2, 2, 0, 0, 0, 0], "Identical food models keep separate scores by attacker seat")
	await _strike(5, [1])
	await _frames(65)
	_check(match_controller.phase == "scores" and match_controller.round_winner == 5 and match_controller.scores == [2, 2, 0, 0, 0, 1], "Last survivor ends a kill-scored round without an extra survival point")
	_check(ui.score_result.text.contains("不额外加分") and ui.score_caption.text.contains("击杀计分"), "Kill scoreboard states the active rule and excludes a survival bonus")
	var gained_label: Label = ui.score_list.get_child(0).find_child("RoundGain", true, false)
	_check(gained_label != null and gained_label.text == "+2", "Scoreboard displays the actual two-point round gain")
	await _frames(75)
	_check(match_controller.scores == [2, 2, 0, 0, 0, 1], "Paused kill scoreboard cannot award points again")
	ui.next_button.pressed.emit()
	_check(match_controller.scoring_mode == 1 and match_controller.round_points == [0, 0, 0, 0, 0, 0] and match_controller.scores == [2, 2, 0, 0, 0, 1], "Next round retains kill totals and rule, but clears the round gains")
	await _stage_strike(0, [1])
	var opponent: CharacterBody3D = arena.combat.actors[1]
	opponent.attack_state = "swing"
	opponent.attack_direction = Vector3.BACK
	opponent.attack_time = 0.07
	arena.combat.resolve_hits()
	_check(arena.player.alive and opponent.alive and match_controller.round_points == [0, 0, 0, 0, 0, 0], "Real player clash awards no kill points to either seat")
	_leave_alive(0)
	await _frames(65)
	_check(match_controller.phase == "scores" and match_controller.scores == [2, 2, 0, 0, 0, 1], "Deaths without a combat attacker and mere survival earn no kill points")
	ui.next_button.pressed.emit()
	# 保留现有允许玩家同帧换命的命中规则，核对全灭时实际击杀分仍累计。
	for actor in arena.combat.actors:
		actor.position = Vector3(0.0, 0.08, 5.0)
		actor.attack_state = "swing"
		actor.attack_direction = Vector3.FORWARD
		actor.attack_time = 0.07
		actor.hit_targets.clear()
	var previous_kills: int = arena.combat.kills
	arena.combat.resolve_hits()
	await _frames(2)
	var total_gained: int = 0
	for points in match_controller.round_points:
		total_gained += points
	_check(match_controller.phase == "scores" and match_controller.round_winner == -1 and total_gained == 6 and arena.combat.kills - previous_kills == 6, "All-dead kill round retains one point for each actual simultaneous elimination")
	_check(ui.score_result.text.contains("击杀分保留"), "An all-dead kill round explains that earned points remain")
	ui.lobby_button.pressed.emit()
	_check(ui.scoring_choice.selected == 1, "Returning to settings keeps the kill-scoring selection")
	match_controller.configure(2, 1, [0, 1, 2])
	ui.start_button.pressed.emit()
	_freeze_actors()
	_check(match_controller.scores == [0, 0, 0] and match_controller.champion == -1, "Restarting a kill match clears the previous totals and champion")
	for point in range(1, 11):
		await _strike(0, [1, 2] if point == 10 else [1])
		if point < 10:
			arena.combat.actors[2].die()
			await _frames(65)
			ui.next_button.pressed.emit()
	_check(match_controller.phase == "match_over" and match_controller.champion == 0 and match_controller.scores == [10, 0, 0], "Tenth real kill immediately wins the match before another survival award")
	_check(int(arena.combat.actors[1].alive) + int(arena.combat.actors[2].alive) == 1 and not arena.combat.enabled, "Ten-point victory stops remaining hits even when another opponent is still alive")
	_check(ui.score_title.text.contains("获胜") and ui.score_result.text.contains("击杀计分") and ui.next_button.text == "再玩一场", "Kill victory screen identifies the rule and offers a new match")
	ui.next_button.pressed.emit()
	ui.scoring_choice.item_selected.emit(0)
	match_controller.configure(1, 1, [0, 1])
	ui.start_button.pressed.emit()
	_freeze_actors()
	await _strike(0, [1])
	_check(match_controller.scores == [0, 0], "Switching back to survival mode does not count the actual kill itself")
	await _frames(65)
	_check(match_controller.scores == [1, 0] and match_controller.round_points == [1, 0], "Survival mode still gives exactly one point after the full hold")


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
	var expected_roles: Array[String] = ["草莓", "茄子", "南瓜", "胡萝卜", "蓝莓", "西瓜"]
	var choices_match: bool = true
	for selector in ui.role_selectors:
		choices_match = choices_match and selector.item_count == expected_roles.size()
		for role in range(mini(selector.item_count, expected_roles.size())):
			choices_match = choices_match and selector.get_item_text(role) == expected_roles[role]
	_check(choices_match, "Every seat offers pumpkin, blueberry and watermelon in the six-food roster")
	_check(match_controller.bot_count == 3 and ui.difficulty_choice.item_count == 3, "Default three bots and exactly three difficulty choices")
	_check(match_controller.scoring_mode == 0 and ui.scoring_choice.item_count == 2 and ui.scoring_choice.selected == 0, "Lobby provides exactly two scoring modes and defaults to survival")
	ui.plus_button.pressed.emit()
	ui.plus_button.pressed.emit()
	_check(match_controller.bot_count == 5 and ui.plus_button.disabled and ui.seat_rows[5].visible, "Bot plus button reaches five and reveals every seat")
	for index in range(4):
		ui.minus_button.pressed.emit()
	_check(match_controller.bot_count == 1 and ui.minus_button.disabled and not ui.seat_rows[2].visible, "Bot minus button reaches one and hides extra seats")
	for index in range(4):
		ui.plus_button.pressed.emit()
	ui.difficulty_choice.item_selected.emit(2)
	var roles: Array[int] = [3, 0, 0, 2, 4, 5]
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
	for role in range(match_controller.ROLE_NAMES.size()):
		match_controller.configure(1, 1, [role, (role + 1) % match_controller.ROLE_NAMES.size()])
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
		_check(matching_dots == 26 and cap_count == 2, "Role %d keeps its death color and solid cut geometry after changing seats" % role)
		match_controller.return_to_lobby()
	await _verify_kill_scoring()
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
