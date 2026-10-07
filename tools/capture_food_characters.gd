extends SceneTree
## 用项目内的真实场景、灯光和网格保存六个角色的近景合照。


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1920, 720)
	var arena: Node3D = load("res://scenes/stone_arena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	arena.get_node("Interface").hide()
	# 合照隐藏遮住圆球脚的岩石，保留游戏原有地面、材质和灯光。
	for child in arena.get_children():
		if child is Node3D and String(child.name) in ["InteriorRocks", "PerimeterCliffs"]:
			child.hide()
	var names: Array[String] = ["StrawberryPlayer", "EggplantNPC", "CarrotNPC", "PumpkinNPC", "BlueberryNPC", "WatermelonNPC"]
	for index in range(names.size()):
		var actor: CharacterBody3D = arena.get_node(names[index])
		actor.set_physics_process(false)
		actor.position = Vector3(-7.1 + float(index) * 2.8, 0.01, 7.0)
		actor.visual.rotation = Vector3.ZERO
	var rig: Node3D = arena.get_node("CameraRig")
	rig.set_process(false)
	rig.set_physics_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.global_position = Vector3(0.0, 7.5, 20.0)
	camera.look_at(Vector3(0.2, 1.4, 7.0))
	camera.size = 7.8
	var sliced: bool = "--sliced" in OS.get_cmdline_user_args()
	if sliced:
		arena.combat.effects.set_process(false)
		for actor_name in names:
			var actor: CharacterBody3D = arena.get_node(actor_name)
			arena.combat.effects.slice(actor, Vector3.FORWARD)
			actor.visual.hide()
		for piece in arena.combat.effects.pieces:
			if piece.half:
				piece.node.position.x += piece.node.global_basis.x.x * piece.velocity.x / 3.4 * 0.18
			else:
				piece.node.hide()
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var output_path: String = "res://artifacts/food_characters_sliced.png" if sliced else "res://artifacts/food_characters.png"
	var result: Error = screenshot.save_png(output_path)
	print("FOOD_CHARACTERS_CAPTURE: ", error_string(result))
	quit(0 if result == OK else 1)
