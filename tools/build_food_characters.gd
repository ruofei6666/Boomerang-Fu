extends SceneTree

const BUILDER = preload("res://tools/food_character_builder.gd")


func _initialize() -> void:
	var builder = BUILDER.new()
	var kinds: PackedStringArray = OS.get_cmdline_user_args()
	if kinds.is_empty():
		kinds = PackedStringArray(BUILDER.KINDS)
	for kind in kinds:
		if kind not in BUILDER.KINDS:
			push_error("Unknown food character: %s" % kind)
			quit(1)
			return
		var actor: CharacterBody3D = builder.build(kind)
		var scene := PackedScene.new()
		var result: Error = scene.pack(actor)
		var path: String = "res://scenes/%s_npc.tscn" % kind
		if result == OK:
			result = ResourceSaver.save(scene, path)
		actor.free()
		if result != OK:
			push_error("Food character generation failed: %s" % error_string(result))
			quit(1)
			return
		print("CHARACTER_SAVED: ", path)
	quit()
