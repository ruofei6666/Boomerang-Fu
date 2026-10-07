extends SceneTree
## 在真实物理帧中验证人机独立散步、随机停顿、避障、动画和控制隔离。

var checks: Array[String] = []
var failures: Array[String] = []
var actor_names: Array[String] = ["EggplantNPC", "DonutNPC", "CarrotNPC"]


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	(checks if condition else failures).append(description)
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: " + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _inside_rock(actor: CharacterBody3D) -> bool:
	var collision: CollisionShape3D = actor.get_node("BodyCollision")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.exclude = [actor.get_rid()]
	for hit in actor.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var parent: Node = hit.collider.get_parent()
		if parent.name == "InteriorRocks" or parent.name == "PerimeterCliffs":
			return true
	return false


func _verify() -> void:
	var packed: PackedScene = load("res://scenes/stone_arena.tscn") as PackedScene
	var arena: Node3D = packed.instantiate() as Node3D
	arena.verification_mode = true
	var actors: Array[CharacterBody3D] = []
	for index in range(actor_names.size()):
		var actor: CharacterBody3D = arena.get_node(actor_names[index])
		actor.melee_enabled = false
		actor.random_seed = 31007 + index * 107
		actors.append(actor)
	root.add_child(arena)
	await process_frame
	await _frames(18)
	var player: CharacterBody3D = arena.get_node("StrawberryPlayer")
	_check(get_nodes_in_group("food_characters").size() == 4, "Four food characters share the arena")
	_check(get_nodes_in_group("player").size() == 1 and get_first_node_in_group("player") == player, "Only the strawberry belongs to the player group")
	_check(get_nodes_in_group("wanderers").size() == 3, "Exactly three autonomous food characters")
	var resting_positions: Array[Vector3] = []
	for actor in actors:
		_check(actor.is_on_floor() and not _inside_rock(actor), "%s spawns on clear ground" % actor.name)
		_check(actor.get_node("BodyCollision").shape is CapsuleShape3D, "%s has a solid collision body" % actor.name)
		_check(actor.left_foot.mesh is SphereMesh and actor.right_foot.mesh is SphereMesh, "%s has two spherical feet" % actor.name)
		actor.idle_time = 100.0
		resting_positions.append(actor.position)
	var before: Vector3 = player.position
	_key(KEY_D, true)
	await _frames(24)
	_key(KEY_D, false)
	_check(player.position.x > before.x + 1.0, "Keyboard still moves the strawberry")
	for index in range(actors.size()):
		_check(actors[index].position.distance_to(resting_positions[index]) < 0.03, "%s ignores the player's keyboard input" % actors[index].name)
	await _frames(18)
	player.reset_player()
	for actor in actors:
		actor.idle_time = 0.0
	await _frames(24)
	for actor in actors:
		_check(Vector2(actor.velocity.x, actor.velocity.z).length() > 0.5, "%s walks without keyboard or touch input" % actor.name)
		_check(actor.walk_phase > 0.1 and actor.animation_weight > 0.1, "%s animates its feet and body while walking" % actor.name)
	var distances: Array[float] = [0.0, 0.0, 0.0]
	var saw_idle: Array[bool] = [false, false, false]
	var saw_turn: Array[bool] = [false, false, false]
	var previous: Array[Vector3] = []
	var headings: Array[float] = []
	for actor in actors:
		previous.append(actor.position)
		headings.append(actor.visual.rotation.y)
	var safe: bool = true
	var continuous: bool = true
	var no_rock_overlap: bool = true
	# 连续 20 秒，覆盖多次走动、停顿和重新选方向。
	for frame in range(1200):
		await physics_frame
		for index in range(actors.size()):
			var actor: CharacterBody3D = actors[index]
			var traveled: float = actor.position.distance_to(previous[index])
			distances[index] += traveled
			previous[index] = actor.position
			continuous = continuous and traveled < 0.20
			safe = safe and absf(actor.position.x) <= 17.501 and absf(actor.position.z) <= 12.201 and actor.position.y > -0.06
			saw_idle[index] = saw_idle[index] or (not actor.walking and Vector2(actor.velocity.x, actor.velocity.z).length() < 0.03)
			saw_turn[index] = saw_turn[index] or absf(angle_difference(headings[index], actor.visual.rotation.y)) > 0.6
			if frame % 30 == 0:
				no_rock_overlap = no_rock_overlap and not _inside_rock(actor)
	for index in range(actors.size()):
		_check(distances[index] > 12.0, "%s keeps wandering over time" % actors[index].name)
		_check(saw_idle[index] and saw_turn[index], "%s naturally pauses and changes direction" % actors[index].name)
	_check(safe, "All NPCs stay on the ground and inside the arena")
	_check(continuous, "NPC movement uses continuous physics without teleporting")
	_check(no_rock_overlap, "NPC collision bodies never enter the rocks")
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01 and player.position.distance_to(Vector3(0.0, 0.01, 3.0)) < 0.06, "NPC wandering leaves the idle strawberry under player control")
	# 强制朝东侧高石头走，检查碰撞探测会改路而不是穿透。
	var probe: CharacterBody3D = actors[0]
	probe.position = Vector3(1.8, 0.05, -0.49)
	probe.velocity = Vector3.ZERO
	await _frames(12)
	probe.destination = Vector3(10.0, 0.05, -0.49)
	probe.walking = true
	probe.decision_time = 60.0
	await _frames(120)
	_check(not _inside_rock(probe) and probe.destination.distance_to(Vector3(10.0, 0.05, -0.49)) > 0.1, "A blocked NPC chooses another route around the eastern rock")
	probe.reset_character()
	await _frames(12)
	_check(probe.position.distance_to(probe.spawn_position) < 0.12, "NPC reset uses its own spawn position")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/wanderers-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": checks.size(), "failed": failures.size(), "checks": checks, "failures": failures, "distance_walked": distances, "simulated_seconds": 20}, "\t"))
	print("WANDERERS_VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
