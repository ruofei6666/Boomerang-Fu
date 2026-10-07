extends SceneTree
## 用项目内的真实场景、灯光和网格保存四个角色的近景合照。


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1440, 720)
	var arena: Node3D = load("res://scenes/stone_arena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	arena.get_node("Interface").hide()
	var names: Array[String] = ["StrawberryPlayer", "EggplantNPC", "DonutNPC", "CarrotNPC"]
	for index in range(names.size()):
		var actor: CharacterBody3D = arena.get_node(names[index])
		actor.set_physics_process(false)
		actor.position = Vector3(-4.2 + float(index) * 2.8, 0.01, 7.0)
		actor.visual.rotation = Vector3.ZERO
	var rig: Node3D = arena.get_node("CameraRig")
	rig.set_process(false)
	rig.set_physics_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.global_position = Vector3(0.0, 7.8, 18.0)
	camera.look_at(Vector3(0.4, 1.4, 7.0))
	camera.size = 7.8
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var result: Error = screenshot.save_png("res://artifacts/food_characters.png")
	print("FOOD_CHARACTERS_CAPTURE: ", error_string(result))
	quit(0 if result == OK else 1)
