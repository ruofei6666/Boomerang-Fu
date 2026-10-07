extends SceneTree
## 使用真实引擎输入和物理帧验证角色、碰撞、镜头及多指摇杆。

var failures: Array[String] = []
var checks: Array[String] = []


func _initialize() -> void:
	_verify.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		checks.append(description)
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(index: int, pressed: bool, at: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = at
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _verify() -> void:
	root.size = Vector2i(1440, 810)
	var packed: PackedScene = load("res://scenes/stone_arena.tscn") as PackedScene
	_check(packed != null, "Main scene loads")
	if packed == null:
		quit(1)
		return
	var arena: Node3D = packed.instantiate() as Node3D
	arena.verification_mode = true
	# 此脚本只测移动和触控；战斗与人机攻击由 verify_combat.gd 独立覆盖。
	for actor_name in ["EggplantNPC", "PumpkinNPC", "CarrotNPC", "BlueberryNPC", "WatermelonNPC"]:
		arena.get_node(actor_name).melee_enabled = false
		arena.get_node(actor_name).set_physics_process(false)
		# 移动回归只测试摇杆、镜头和岩石；冻结的人机不能挡住测试路线。
		arena.get_node(actor_name).collision_layer = 0
		arena.get_node(actor_name).collision_mask = 0
	root.add_child(arena)
	await process_frame
	await process_frame
	await _frames(12)
	var player: CharacterBody3D = arena.get_node("StrawberryPlayer")
	var rig: Node3D = arena.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera3D")
	var stick: Control = arena.get_node("Interface/Root/VirtualJoystick")
	_check(player.is_on_floor(), "Strawberry rests on the ground")
	_check(player.get_node("BodyCollision").shape is CapsuleShape3D, "Player has a solid 3D collision shape")
	_check(player.get_node("Visual/Berry/StrawberryBody").mesh is ArrayMesh, "Strawberry is a real 3D mesh")
	_check(player.left_foot.mesh is SphereMesh and player.right_foot.mesh is SphereMesh, "Exactly two independent spherical feet")
	_check(player.get_node("Visual/Berry/LeafCrown").get_child_count() == 7, "3D leaf crown and stem")
	_check(arena.get_node("InteriorRocks").get_child_count() == 9, "Nine authored interior rocks retained")
	var collision_count: int = 0
	for rock in arena.get_node("InteriorRocks").get_children():
		if rock is StaticBody3D and rock.get_node("RockCollision").shape is ConvexPolygonShape3D:
			collision_count += 1
	_check(collision_count == 9, "All interior rocks have solid collisions")
	_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and rig.follow_target == player, "Orthographic camera follows the strawberry")
	var before: Vector3 = player.position
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_D, false)
	_check(player.position.x > before.x + 1.5, "D actually moves the player right")
	_check(rig.position.x > before.x + 0.5, "Camera follows player movement")
	_check(absf(player.left_foot.position.y - player.right_foot.position.y) > 0.01, "Two ball feet alternate while walking")
	await _frames(18)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Releasing keyboard stops the player")
	_check(player.left_foot.position.is_equal_approx(player.left_rest) and player.right_foot.position.is_equal_approx(player.right_rest), "Feet return to their rest positions")
	player.reset_player()
	await _frames(6)
	before = player.position
	_key(KEY_W, true)
	await _frames(24)
	_key(KEY_W, false)
	var forward := Vector3(-sin(rig.yaw), 0.0, -cos(rig.yaw))
	_check((player.position - before).dot(forward) > 1.0, "W moves toward the top of the screen")
	await _frames(12)
	player.reset_player()
	_key(KEY_W, true)
	_key(KEY_D, true)
	await _frames(24)
	_check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.walk_speed) < 0.05, "Diagonal keyboard input has the same speed")
	_key(KEY_W, false)
	_key(KEY_D, false)
	await _frames(12)
	player.reset_player()
	rig.yaw = PI * 0.5
	rig._apply_orientation()
	before = player.position
	_key(KEY_W, true)
	await _frames(24)
	_key(KEY_W, false)
	_check(player.position.x < before.x - 1.0, "Movement remains screen-relative after rotating the camera")
	await _frames(12)
	rig.reset_view()
	player.reset_player()
	await _frames(6)
	var center: Vector2 = stick.global_position + stick.size * 0.5
	_touch(2, true, center)
	_check(stick.active_touch == 2 and stick.movement.is_zero_approx(), "Touch at joystick center owns the control with zero movement")
	_drag(2, center + Vector2(stick.radius * 0.04, 0.0))
	_check(stick.movement.is_zero_approx(), "Joystick dead zone prevents accidental walking")
	_drag(2, center + Vector2(stick.radius * 0.20, 0.0))
	before = player.position
	await _frames(2)
	_check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.walk_speed) < 0.05, "Joystick movement starts at maximum speed without an acceleration ramp")
	await _frames(22)
	_check(player.position.x > before.x + 0.8, "Touch drag actually moves the 3D player")
	_check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.walk_speed) < 0.05, "A small joystick deflection moves the player at maximum walking speed")
	_drag(2, center + Vector2(stick.radius * 0.75, 0.0))
	await _frames(3)
	_check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.walk_speed) < 0.05, "A larger joystick deflection keeps the same maximum walking speed")
	_drag(2, center - Vector2(stick.radius * 0.75, 0.0))
	await _frames(2)
	_check(player.velocity.x < -8.0 and absf(Vector2(player.velocity.x, player.velocity.z).length() - player.walk_speed) < 0.05, "Reversing the joystick changes direction immediately at maximum speed")
	_drag(2, center + Vector2(stick.radius * 0.75, 0.0))
	_touch(3, true, center)
	_drag(3, center - Vector2(stick.radius, 0.0))
	_touch(3, false, center)
	_check(stick.active_touch == 2 and stick.movement.x > 0.6, "Second finger cannot steal or release the joystick")
	_drag(2, center + Vector2(stick.radius * 5.0, 0.0))
	_check(is_equal_approx(stick.movement.length(), 1.0), "Dragging outside joystick clamps its speed")
	_drag(2, center + Vector2(stick.radius * 0.5, -stick.radius * 0.5))
	_check(stick.movement.is_equal_approx(Vector2(1.0, -1.0).normalized()), "Diagonal joystick input changes direction without changing its speed")
	_touch(2, false, center + Vector2(stick.radius * 5.0, 0.0))
	await _frames(16)
	_check(stick.active_touch == -1 and stick.movement.is_zero_approx() and Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Releasing outside the joystick stops movement")
	_touch(5, true, center + Vector2(stick.radius, 0.0))
	_touch(5, false, center, true)
	_check(stick.movement.is_zero_approx() and stick.active_touch == -1, "Canceled touch releases the joystick")
	_touch(6, true, center + Vector2(stick.radius, 0.0))
	stick._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(stick.movement.is_zero_approx() and player.velocity.is_zero_approx() and player.movement_input().is_zero_approx(), "Losing focus clears all movement")
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	player.reset_player()
	rig.yaw = 0.0
	player.position = Vector3(1.8, 0.05, -0.49)
	await _frames(12)
	_key(KEY_D, true)
	await _frames(75)
	_key(KEY_D, false)
	_check(player.position.x > 2.0 and player.position.x < 3.8 and player.get_slide_collision_count() > 0, "Strawberry cannot walk through the eastern rock")
	await _frames(12)
	player.reset_player()
	player.position = Vector3(17.5, 0.05, 0.0)
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_D, false)
	_check(player.position.x <= 17.501 and player.position.y >= -0.05, "Map boundary prevents walking off the arena")
	player.reset_player()
	await _frames(12)
	_check(player.position.distance_to(Vector3(0.0, 0.01, 3.0)) < 0.06, "Respawn returns the strawberry to the clear starting area")
	rig.reset_view()
	var old_size: float = rig.desired_size
	rig.zoom_at(Vector2(720.0, 405.0), 0.8)
	_check(rig.desired_size < old_size, "Camera zoom is retained")
	_key(KEY_R, true)
	_key(KEY_R, false)
	_check(rig.following and is_equal_approx(rig.desired_size, rig.initial_size), "R restores the following camera")
	var old_yaw: float = rig.yaw
	_key(KEY_E, true)
	await _frames(12)
	_key(KEY_E, false)
	_check(rig.yaw > old_yaw, "E rotates the camera")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report := {"passed": checks.size(), "failed": failures.size(), "checks": checks, "failures": failures}
	var file := FileAccess.open("res://artifacts/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("VERIFICATION: %d passed, %d failed" % [checks.size(), failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

