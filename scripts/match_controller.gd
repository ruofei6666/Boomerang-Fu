extends Node
## 设置 -> 小局 -> 计分 -> 下一小局 / 整场获胜。分数按参赛席位保存。

signal phase_changed

const WIN_SCORE: int = 10
const SURVIVOR_HOLD: float = 1.0
const MAX_BOTS: int = 5
const ROLE_NAMES: Array[String] = ["草莓", "茄子", "甜甜圈", "胡萝卜"]
const ROLE_COLORS: Array[Color] = [Color("d94a66"), Color("8661b5"), Color("e38aa7"), Color("df8c3a")]
const ROLE_SCENES: Array[PackedScene] = [
	preload("res://scenes/strawberry_player.tscn"),
	preload("res://scenes/eggplant_npc.tscn"),
	preload("res://scenes/donut_npc.tscn"),
	preload("res://scenes/carrot_npc.tscn")
]
const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const BOT_SCRIPT = preload("res://scripts/wander_controller.gd")

var phase: String = "lobby"
var bot_count: int = 3
var difficulty: int = 1
var role_choices: Array[int] = [0, 1, 2, 3, 0, 1]
var scores: Array[int] = []
var round_number: int = 0
var round_winner: int = -1
var champion: int = -1
var survivor: int = -1
var survivor_time: float = 0.0
var legacy_mode: bool = false
var random := RandomNumberGenerator.new()
var arena: Node3D
var combat: Node3D


func _ready() -> void:
	process_physics_priority = 200
	arena = get_parent()
	combat = arena.combat
	random.randomize()
	if legacy_mode:
		phase = "practice"
	else:
		_set_active(false)
	arena.get_node("Interface").bind_match(self)


func configure(count: int, level: int, choices: Array) -> void:
	if phase != "lobby":
		return
	bot_count = clampi(count, 1, MAX_BOTS)
	difficulty = clampi(level, 0, 2)
	for index in range(mini(choices.size(), role_choices.size())):
		role_choices[index] = clampi(choices[index], 0, ROLE_NAMES.size() - 1)


func seat_name(index: int) -> String:
	return "你" if index == 0 else "人机 %d" % index


func start_match() -> void:
	if phase != "lobby":
		return
	_set_active(false)
	combat.effects.clear()
	# 换模型和控制脚本，四种食物都能成为玩家或人机，可重复选择。
	var old_actors: Array[CharacterBody3D] = combat.actors.duplicate()
	combat.actors.clear()
	for actor in old_actors:
		arena.remove_child(actor)
		actor.free()
	scores.clear()
	for index in range(bot_count + 1):
		var role: int = role_choices[index]
		var actor: CharacterBody3D = ROLE_SCENES[role].instantiate()
		var saved_body_path: NodePath = actor.body_path
		actor.set_script(PLAYER_SCRIPT if index == 0 else BOT_SCRIPT)
		actor.body_path = saved_body_path
		actor.name = "Player" if index == 0 else "Bot%d" % index
		actor.round_active = false
		actor.walk_speed = 9.0
		actor.acceleration = 32.0
		actor.braking = 42.0
		actor.set_meta("seat", index)
		actor.set_meta("role", role)
		if index > 0:
			actor.arena_ai = true
			actor.set_difficulty(difficulty)
		arena.add_child(actor)
		actor.combat = combat
		combat.actors.append(actor)
		scores.append(0)
	combat.player = combat.actors[0]
	arena.bind_player(combat.player)
	combat.build_navigation()
	champion = -1
	round_number = 0
	_begin_round()


func next_round() -> void:
	if phase == "scores":
		_begin_round()


func return_to_lobby() -> void:
	if legacy_mode:
		return
	_set_active(false)
	phase = "lobby"
	phase_changed.emit()


func _begin_round() -> void:
	_set_active(false)
	combat.effects.clear()
	var positions: Array[Vector3] = _spawn_positions()
	for index in range(combat.actors.size()):
		var actor: CharacterBody3D = combat.actors[index]
		actor.spawn_position = positions[index]
		actor.reset_character()
		actor.visual.rotation.y = atan2(-actor.position.x, -actor.position.z)
		if index == 0:
			actor.joystick.release()
	round_number += 1
	round_winner = -1
	survivor = -1
	survivor_time = 0.0
	phase = "playing"
	_set_active(true)
	arena.camera_rig.follow_target = arena.player
	arena.camera_rig.reset_view()
	phase_changed.emit()


func _spawn_positions() -> Array[Vector3]:
	# 从路径图的安全格中取点；每局换位，并保证任意两个出生点相距至少 7 米。
	var candidates: Array[Vector3] = []
	for x in range(-14, 15):
		for z in range(-9, 10):
			if not combat.navigation.is_point_solid(Vector2i(x, z)):
				candidates.append(Vector3(x, 0.08, z))
	var chosen: Array[Vector3] = []
	chosen.append(candidates[random.randi_range(0, candidates.size() - 1)])
	while chosen.size() < combat.actors.size():
		var best := Vector3.ZERO
		var best_distance: float = -1.0
		for candidate in candidates:
			var distance: float = INF
			for existing in chosen:
				distance = minf(distance, candidate.distance_squared_to(existing))
			# 少量随机扰动使每局的方位变化，同时优先选离已有角色最远的位置。
			var rating: float = distance + random.randf_range(0.0, 3.0)
			if distance >= 49.0 and rating > best_distance:
				best_distance = rating
				best = candidate
		chosen.append(best)
	return chosen


func _physics_process(delta: float) -> void:
	if phase != "playing":
		return
	var living: Array[int] = []
	for index in range(combat.actors.size()):
		if combat.actors[index].alive:
			living.append(index)
	if not arena.player.alive and not living.is_empty():
		arena.camera_rig.follow_target = combat.actors[living[0]]
	if living.is_empty():
		_finish_round(-1)
	elif living.size() == 1:
		if survivor != living[0]:
			survivor = living[0]
			survivor_time = 0.0
		survivor_time += delta
		if survivor_time + 0.00001 >= SURVIVOR_HOLD:
			_finish_round(survivor)
	else:
		survivor = -1
		survivor_time = 0.0


func _finish_round(winner: int) -> void:
	if phase != "playing":
		return
	round_winner = winner
	if winner >= 0:
		scores[winner] += 1
		if scores[winner] >= WIN_SCORE:
			champion = winner
	_set_active(false)
	phase = "match_over" if champion >= 0 else "scores"
	phase_changed.emit()


func _set_active(active: bool) -> void:
	combat.enabled = active
	for actor in combat.actors:
		actor.round_active = active
		actor.velocity = Vector3.ZERO
		actor.attack_requested = false
		if actor.is_in_group("player"):
			actor.attack_buffered = false
	var ui: CanvasLayer = arena.get_node("Interface")
	ui.release_actions()
