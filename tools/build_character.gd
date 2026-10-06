extends SceneTree
## 保存真实 3D 草莓网格、叶冠、立体五官、两颗独立圆球脚和碰撞体。

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const SEGMENTS: int = 48
const RINGS: int = 32


func _initialize() -> void:
	var player := CharacterBody3D.new()
	player.name = "StrawberryPlayer"
	player.set_script(PLAYER_SCRIPT)
	player.floor_snap_length = 0.25
	player.floor_max_angle = deg_to_rad(42.0)
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.62
	capsule.height = 1.94
	collider.shape = capsule
	collider.position.y = 0.98
	player.add_child(collider)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation.y = deg_to_rad(8.0)
	player.add_child(visual)
	var pink: StandardMaterial3D = _material(Color("ffb3c1"), 0.65)
	_sphere(visual, "LeftFoot", Vector3(-0.36, 0.28, 0.20), Vector3.ONE * 0.28, pink)
	_sphere(visual, "RightFoot", Vector3(0.36, 0.28, 0.20), Vector3.ONE * 0.28, pink)
	var berry := Node3D.new()
	berry.name = "Berry"
	visual.add_child(berry)
	var body := MeshInstance3D.new()
	body.name = "StrawberryBody"
	body.mesh = _berry_mesh()
	body.material_override = _material(Color("f34758"), 0.52)
	berry.add_child(body)
	_build_face(berry)
	_build_seeds(berry)
	_build_leaves(berry)
	_set_owner(player, player)
	var packed := PackedScene.new()
	var result: Error = packed.pack(player)
	if result == OK:
		result = ResourceSaver.save(packed, "res://scenes/strawberry_player.tscn")
	player.free()
	if result != OK:
		push_error("Character generation failed: " + error_string(result))
		quit(1)
	else:
		print("CHARACTER_SAVED: res://scenes/strawberry_player.tscn")
		quit()


func _radius_at(t: float) -> float:
	return 0.9 * pow(maxf(sin(PI * clampf(t, 0.0, 1.0)), 0.0), 0.65) * (0.73 + 0.34 * t)


func _normal_at(t: float, angle: float) -> Vector3:
	if t < 0.002:
		return Vector3.DOWN
	if t > 0.998:
		return Vector3.UP
	var slope: float = (_radius_at(t + 0.001) - _radius_at(t - 0.001)) / 0.0033
	return Vector3(cos(angle), -slope, sin(angle)).normalized()


func _berry_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring in range(RINGS + 1):
		var t: float = float(ring) / RINGS
		for segment in range(SEGMENTS + 1):
			var angle: float = TAU * float(segment) / SEGMENTS
			vertices.append(Vector3(cos(angle) * _radius_at(t), 0.55 + 1.65 * t, sin(angle) * _radius_at(t)))
			normals.append(_normal_at(t, angle))
	for ring in range(RINGS):
		for segment in range(SEGMENTS):
			var a: int = ring * (SEGMENTS + 1) + segment
			var b: int = a + SEGMENTS + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _front_z(x: float, y: float) -> float:
	var radius: float = _radius_at((y - 0.55) / 1.65)
	return sqrt(maxf(radius * radius - x * x, 0.0))


func _build_face(berry: Node3D) -> void:
	var dark: StandardMaterial3D = _material(Color("30242d"), 0.24)
	var white: StandardMaterial3D = _material(Color("fff9e8"), 0.30)
	var blush: StandardMaterial3D = _material(Color("ff879a"), 0.76)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.265
		var y: float = 1.77
		var z: float = _front_z(x, y)
		_sphere(berry, "EyeLeft" if side < 0.0 else "EyeRight", Vector3(x, y, z + 0.030), Vector3(0.105, 0.128, 0.055), dark)
		_sphere(berry, "EyeGlintLeft" if side < 0.0 else "EyeGlintRight", Vector3(x - 0.025, y + 0.043, z + 0.079), Vector3.ONE * 0.030, white)
		_sphere(berry, "CheekLeft" if side < 0.0 else "CheekRight", Vector3(side * 0.43, 1.60, _front_z(side * 0.43, 1.60) + 0.026), Vector3(0.108, 0.057, 0.028), blush)
	for index in range(17):
		var x: float = -0.115 + float(index) / 16.0 * 0.23
		var y: float = 1.49 + 0.08 * pow(x / 0.115, 2.0)
		_sphere(berry, "Smile%02d" % index, Vector3(x, y, _front_z(x, y) + 0.022), Vector3.ONE * 0.020, dark)


func _build_seeds(berry: Node3D) -> void:
	var seeds := Node3D.new()
	seeds.name = "Seeds"
	berry.add_child(seeds)
	var gold: StandardMaterial3D = _material(Color("ffe6a1"), 0.63)
	for row in range(5):
		var t: float = 0.19 + float(row) * 0.155
		var count: int = 9 if row == 0 or row == 4 else 12
		for index in range(count):
			var angle: float = TAU * (float(index) + float(row % 2) * 0.5) / count
			var point := Vector3(cos(angle) * _radius_at(t), 0.55 + 1.65 * t, sin(angle) * _radius_at(t))
			if point.z > 0.35 and absf(point.x) < 0.58 and point.y > 1.32 and point.y < 1.97:
				continue
			var normal: Vector3 = _normal_at(t, angle)
			var seed_mesh: MeshInstance3D = _sphere(seeds, "Seed%02d_%02d" % [row, index], point + normal * 0.010, Vector3(0.026, 0.058, 0.016), gold)
			seed_mesh.basis = Basis.looking_at(-normal, Vector3.UP) * Basis.from_scale(Vector3(0.026, 0.058, 0.016))


func _build_leaves(berry: Node3D) -> void:
	var crown := Node3D.new()
	crown.name = "LeafCrown"
	berry.add_child(crown)
	for index in range(6):
		var angle: float = TAU * float(index) / 6.0
		var green: StandardMaterial3D = _material(Color("7fb93d") if index % 2 == 0 else Color("98cf4b"), 0.8)
		var leaf: MeshInstance3D = _sphere(crown, "Leaf%d" % index, Vector3(sin(angle) * 0.32, 2.17, cos(angle) * 0.32), Vector3(0.20, 0.062, 0.46), green)
		leaf.rotation = Vector3(-0.22, angle, 0.0)
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.055
	cylinder.bottom_radius = 0.073
	cylinder.height = 0.28
	cylinder.radial_segments = 16
	stem.mesh = cylinder
	stem.material_override = _material(Color("74a83b"), 0.8)
	stem.position = Vector3(-0.04, 2.34, 0.0)
	stem.rotation.z = 0.26
	crown.add_child(stem)


func _sphere(parent: Node3D, node_name: String, at: Vector3, radii: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	instance.mesh = sphere
	instance.material_override = material
	instance.position = at
	instance.scale = radii
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)
