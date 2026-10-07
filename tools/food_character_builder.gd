extends RefCounted
## 可重复生成三种独立 3D 食物场景，五官和球形脚与草莓保持同一风格。

const WANDER_SCRIPT = preload("res://scripts/wander_controller.gd")
const HELD_BOOMERANG_BUILDER = preload("res://tools/held_boomerang_builder.gd")
const SEGMENTS: int = 48
const RINGS: int = 32
const DONUT_CENTER: float = 1.49
const DONUT_MAJOR: float = 0.65
const DONUT_MINOR: float = 0.29


func build(kind: String) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.name = {"eggplant": "EggplantNPC", "donut": "DonutNPC", "carrot": "CarrotNPC"}[kind]
	actor.set_script(WANDER_SCRIPT)
	actor.body_path = ^"Visual/Body"
	actor.walk_speed = {"eggplant": 3.5, "donut": 3.8, "carrot": 4.1}[kind]
	actor.acceleration = 16.0
	actor.braking = 24.0
	actor.floor_snap_length = 0.25
	actor.floor_max_angle = deg_to_rad(42.0)
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.79 if kind == "donut" else 0.57
	capsule.height = 2.26
	collider.shape = capsule
	collider.position.y = 1.14
	actor.add_child(collider)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation.y = deg_to_rad(8.0)
	actor.add_child(visual)
	var foot_color: Color = {"eggplant": Color("c9b2f0"), "donut": Color("ffcfb1"), "carrot": Color("ffc77d")}[kind]
	var foot_material: StandardMaterial3D = _material(foot_color, 0.65)
	var foot_spread: float = 0.42 if kind == "donut" else 0.32
	_sphere(visual, "LeftFoot", Vector3(-foot_spread, 0.28, 0.16), Vector3.ONE * 0.28, foot_material)
	_sphere(visual, "RightFoot", Vector3(foot_spread, 0.28, 0.16), Vector3.ONE * 0.28, foot_material)
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	if kind == "donut":
		_build_donut(body)
	else:
		var skin: Color = Color("7549ad") if kind == "eggplant" else Color("f99432")
		_mesh(body, "EggplantBody" if kind == "eggplant" else "CarrotBody", _vegetable_mesh(kind), _material(skin, 0.42 if kind == "eggplant" else 0.60))
		_build_leaves(body, kind)
		if kind == "carrot":
			_build_carrot_lines(body)
	_build_face(body, kind)
	HELD_BOOMERANG_BUILDER.new().attach(body, kind)
	_set_owner(actor, actor)
	return actor


func _radius_at(kind: String, t: float) -> float:
	var profile: float = maxf(sin(PI * clampf(t, 0.0, 1.0)), 0.0)
	if kind == "eggplant":
		return 0.78 * pow(profile, 0.70) * (1.08 - 0.37 * t)
	return 0.76 * pow(profile, 0.48) * (0.22 + 0.87 * t)


func _height(kind: String) -> float:
	return 2.02 if kind == "eggplant" else 1.87


func _vegetable_mesh(kind: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var height: float = _height(kind)
	for ring in range(RINGS + 1):
		var t: float = float(ring) / RINGS
		var radius: float = _radius_at(kind, t)
		var slope: float = (_radius_at(kind, t + 0.001) - _radius_at(kind, t - 0.001)) / (height * 0.002)
		for segment in range(SEGMENTS + 1):
			var angle: float = TAU * float(segment) / SEGMENTS
			vertices.append(Vector3(cos(angle) * radius, 0.55 + height * t, sin(angle) * radius))
			var normal := Vector3(cos(angle), -slope, sin(angle)).normalized()
			if ring == 0:
				normal = Vector3.DOWN
			elif ring == RINGS:
				normal = Vector3.UP
			normals.append(normal)
	_grid_indices(indices, RINGS, SEGMENTS)
	return _array_mesh(vertices, normals, indices)


func _front_z(kind: String, x: float, y: float) -> float:
	if kind == "donut":
		var radius: float = Vector2(x, y - DONUT_CENTER).length()
		return sqrt(maxf(pow(DONUT_MINOR + 0.013, 2.0) - pow(radius - DONUT_MAJOR, 2.0), 0.0)) + 0.014
	var radius: float = _radius_at(kind, (y - 0.55) / _height(kind))
	return sqrt(maxf(radius * radius - x * x, 0.0))


func _build_face(body: Node3D, kind: String) -> void:
	var dark: StandardMaterial3D = _material(Color("30242d"), 0.24)
	var white: StandardMaterial3D = _material(Color("fff9e8"), 0.30)
	var blush: StandardMaterial3D = _material(Color("c394df") if kind == "eggplant" else Color("ffb283") if kind == "carrot" else Color("f473a0"), 0.76)
	var eye_x: float = 0.33 if kind == "donut" else 0.23
	var eye_y: float = 2.23 if kind == "donut" else 1.94
	var cheek_x: float = 0.50 if kind == "donut" else 0.39
	var cheek_y: float = 2.10 if kind == "donut" else 1.76
	for side in [-1.0, 1.0]:
		var x: float = side * eye_x
		var z: float = _front_z(kind, x, eye_y)
		_sphere(body, "EyeLeft" if side < 0.0 else "EyeRight", Vector3(x, eye_y, z + 0.030), Vector3(0.102, 0.128, 0.055), dark)
		_sphere(body, "EyeGlintLeft" if side < 0.0 else "EyeGlintRight", Vector3(x - 0.025, eye_y + 0.043, z + 0.079), Vector3.ONE * 0.030, white)
		_sphere(body, "CheekLeft" if side < 0.0 else "CheekRight", Vector3(side * cheek_x, cheek_y, _front_z(kind, side * cheek_x, cheek_y) + 0.026), Vector3(0.105, 0.055, 0.029), blush)
	# 与草莓完全相同的小弧形笑嘴。甜甜圈的脸放在上半圈，嘴紧接在眼睛下方。
	var smile_y: float = 2.01 if kind == "donut" else 1.60
	for index in range(17):
		var x: float = -0.115 + float(index) / 16.0 * 0.23
		var y: float = smile_y + 0.08 * pow(x / 0.115, 2.0)
		_sphere(body, "Smile%02d" % index, Vector3(x, y, _front_z(kind, x, y) + 0.022), Vector3.ONE * 0.020, dark)


func _build_leaves(body: Node3D, kind: String) -> void:
	var crown := Node3D.new()
	crown.name = "LeafCrown" if kind == "eggplant" else "CarrotGreens"
	body.add_child(crown)
	var top: float = 0.55 + _height(kind)
	for index in range(5):
		var green: StandardMaterial3D = _material(Color("72ae40") if index % 2 == 0 else Color("96ca4e"), 0.8)
		if kind == "eggplant":
			var angle: float = TAU * float(index) / 5.0
			var leaf: MeshInstance3D = _sphere(crown, "Leaf%d" % index, Vector3(sin(angle) * 0.21, top - 0.02, cos(angle) * 0.21), Vector3(0.15, 0.058, 0.34), green)
			leaf.rotation = Vector3(-0.32, angle, 0.0)
		else:
			var tilt: float = (float(index) - 2.0) * 0.26
			var leaf: MeshInstance3D = _sphere(crown, "Leaf%d" % index, Vector3(-sin(tilt) * 0.24, top + 0.34 + (0.10 if index == 2 else 0.0), -0.06 + float(index % 2) * 0.12), Vector3(0.10, 0.44, 0.068), green)
			leaf.rotation = Vector3(-0.08, float(index % 2) * 0.35, tilt)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.052
	cylinder.bottom_radius = 0.078
	cylinder.height = 0.26
	cylinder.radial_segments = 16
	var stem: MeshInstance3D = _mesh(crown, "Stem", cylinder, _material(Color("6b9d38"), 0.8))
	stem.position = Vector3(-0.025, top + 0.13, 0.0)
	stem.rotation.z = 0.20 if kind == "eggplant" else 0.0


func _build_carrot_lines(body: Node3D) -> void:
	var lines := Node3D.new()
	lines.name = "CarrotGrooves"
	body.add_child(lines)
	var orange: StandardMaterial3D = _material(Color("d87329"), 0.82)
	for row in range(4):
		var y: float = [0.91, 1.18, 2.16, 2.26][row]
		var center: float = [-0.03, 0.08, -0.24, 0.28][row]
		for index in range(7):
			var x: float = center - 0.105 + float(index) * 0.035
			_sphere(lines, "Groove%d_%d" % [row, index], Vector3(x, y, _front_z("carrot", x, y) + 0.006), Vector3(0.026, 0.013, 0.012), orange)


func _build_donut(body: Node3D) -> void:
	_mesh(body, "DonutBody", _torus_mesh(false), _material(Color("dca263"), 0.68))
	_mesh(body, "PinkIcing", _torus_mesh(true), _material(Color("ff9dbb"), 0.48))
	var sprinkles := Node3D.new()
	sprinkles.name = "Sprinkles"
	body.add_child(sprinkles)
	var colors: Array[Color] = [Color("fff2b4"), Color("84daca"), Color("a6bded"), Color("fff8ed"), Color("d26a9f")]
	var materials: Array[StandardMaterial3D] = []
	for color in colors:
		materials.append(_material(color, 0.60))
	var random := RandomNumberGenerator.new()
	random.seed = 68412
	for index in range(58):
		var u: float = TAU * float(index) / 58.0 + random.randf_range(-0.03, 0.03)
		var v: float = random.randf_range(0.27, 0.77) * PI
		var radius: float = DONUT_MAJOR + (DONUT_MINOR + 0.022) * cos(v)
		var at := Vector3(cos(u) * radius, DONUT_CENTER + sin(u) * radius, (DONUT_MINOR + 0.022) * sin(v) + 0.021)
		# 给五官留出空位，彩糖既贴在糖霜表面，也不会盖住眼睛和嘴。
		if absf(at.x) < 0.64 and at.y > 1.83 and at.y < 2.38:
			continue
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.024
		capsule.height = 0.125
		capsule.radial_segments = 8
		capsule.rings = 4
		var sprinkle: MeshInstance3D = _mesh(sprinkles, "Sprinkle%02d" % index, capsule, materials[index % materials.size()])
		sprinkle.position = at
		sprinkle.rotation.z = u + random.randf_range(-0.9, 0.9)


func _torus_mesh(icing: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var minor_segments: int = 20
	var tube: float = DONUT_MINOR + (0.013 if icing else 0.0)
	for ring in range(SEGMENTS + 1):
		var u: float = TAU * float(ring) / SEGMENTS
		for segment in range(minor_segments + 1):
			var t: float = float(segment) / minor_segments
			var start: float = 0.07 + 0.065 * sin(u * 7.0) + 0.028 * cos(u * 11.0)
			var end: float = PI - 0.07 + 0.07 * sin(u * 6.0 + 0.4)
			var v: float = lerpf(start, end, t) if icing else TAU * t
			var radius: float = DONUT_MAJOR + tube * cos(v)
			vertices.append(Vector3(cos(u) * radius, DONUT_CENTER + sin(u) * radius, tube * sin(v) + (0.014 if icing else 0.0)))
			normals.append(Vector3(cos(u) * cos(v), sin(u) * cos(v), sin(v)).normalized())
	# Godot 的正面使用顺时针绕序；糖霜只覆盖前半环面，保留中间的孔。
	for ring in range(SEGMENTS):
		for segment in range(minor_segments):
			var a: int = ring * (minor_segments + 1) + segment
			var b: int = a + minor_segments + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	return _array_mesh(vertices, normals, indices)


func _grid_indices(indices: PackedInt32Array, rows: int, columns: int) -> void:
	for row in range(rows):
		for column in range(columns):
			var a: int = row * (columns + 1) + column
			var b: int = a + columns + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))


func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, node_name: String, at: Vector3, radii: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var instance: MeshInstance3D = _mesh(parent, node_name, sphere, material)
	instance.position = at
	instance.scale = radii
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
