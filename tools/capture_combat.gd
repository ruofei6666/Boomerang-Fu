extends SceneTree
## 截取真实引擎渲染的跳斩、切开、对刀和手机图标布局。

var arena: Node3D
var player: CharacterBody3D
var target: CharacterBody3D
var failures: int = 0


func _initialize() -> void:
	_capture.call_deferred()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var result: Error = image.save_png("res://artifacts/combat_" + label + ".png")
	if result != OK:
		failures += 1
	print("COMBAT_CAPTURE: ", label, " ", error_string(result))


func _pair(opposite: bool = false) -> void:
	arena.combat.reset_round()
	for actor in arena.combat.actors:
		if actor.is_in_group("wanderers"):
			actor.melee_enabled = false
			actor.idle_time = 9999.0
			actor.walking = false
		if actor != player and actor != target:
			actor.position = Vector3(-4.5 if actor.name == "DonutNPC" else 4.5, 0.01, 7.8)
			actor.set_physics_process(false)
	player.position = Vector3(-1.3, 0.01, 6.0)
	player.visual.rotation.y = PI * 0.5
	target.position = Vector3(1.3, 0.01, 6.0)
	target.visual.rotation.y = -PI * 0.5 if opposite else 0.0


func _capture() -> void:
	root.size = Vector2i(1440, 810)
	arena = load("res://scenes/stone_arena.tscn").instantiate()
	arena.verification_mode = true
	for name in ["EggplantNPC", "DonutNPC", "CarrotNPC"]:
		arena.get_node(name).melee_enabled = false
	root.add_child(arena)
	await process_frame
	player = arena.get_node("StrawberryPlayer")
	target = arena.get_node("EggplantNPC")
	var rig: Node3D = arena.get_node("CameraRig")
	rig.set_process(false)
	rig.set_physics_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.global_position = Vector3(0.0, 12.0, 20.0)
	camera.look_at(Vector3(0.0, 1.1, 6.0))
	camera.size = 11.0
	_pair()
	await _frames(12)
	await _save("ready")
	player.request_attack()
	await _frames(6)
	await _save("hop")
	await _frames(7)
	await _save("slice")
	await _frames(9)
	await _save("halves")
	_pair(true)
	await _frames(4)
	player.request_attack()
	target.request_attack()
	await _frames(13)
	await _save("clash")
	await _frames(25)
	await _save("rebound")
	root.size = Vector2i(390, 844)
	await _frames(6)
	await _save("portrait")
	root.size = Vector2i(844, 390)
	await _frames(6)
	await _save("landscape")
	arena.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
