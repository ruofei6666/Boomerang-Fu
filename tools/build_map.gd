extends SceneTree

const BUILDER = preload("res://tools/map_builder.gd")


func _initialize() -> void:
	var builder = BUILDER.new()
	var arena: Node3D = builder.build_scene()
	var scene := PackedScene.new()
	var result: Error = scene.pack(arena)
	if result == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes")
		result = ResourceSaver.save(scene, "res://scenes/stone_arena.tscn")
	arena.free()
	if result != OK:
		push_error("Map generation failed: %s" % error_string(result))
		quit(1)
	else:
		print("SCENE_SAVED: res://scenes/stone_arena.tscn")
		quit()

