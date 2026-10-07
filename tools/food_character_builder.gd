extends RefCounted
## 确定性生成独立 3D 食物场景，五官、圆手、圆脚和回旋镖与草莓保持同一风格。

const WANDER_SCRIPT = preload("res://scripts/wander_controller.gd")
const HELD_BOOMERANG_BUILDER = preload("res://tools/held_boomerang_builder.gd")
const SEGMENTS: int = 48
const RINGS: int = 32
const KINDS: Array[String] = ["eggplant", "pumpkin", "carrot", "blueberry", "watermelon"]
const PROFILES: Dictionary = {
	"eggplant": {"name": "EggplantNPC", "speed": 3.5, "radius": 0.57, "feet": 0.32, "skin": Color("7549ad"), "blush": Color("c394df"), "eye_y": 1.94, "cheek_y": 1.76, "smile_y": 1.60},
	"pumpkin": {"name": "PumpkinNPC", "speed": 3.8, "radius": 0.76, "feet": 0.39, "skin": Color("f29a38"), "blush": Color("ffb783"), "eye_y": 1.76, "cheek_y": 1.58, "smile_y": 1.42},
	"carrot": {"name": "CarrotNPC", "speed": 4.1, "radius": 0.57, "feet": 0.32, "skin": Color("f99432"), "blush": Color("ffb283"), "eye_y": 1.94, "cheek_y": 1.76, "smile_y": 1.60},
	"blueberry": {"name": "BlueberryNPC", "speed": 3.8, "radius": 0.69, "feet": 0.37, "skin": Color("637ed6"), "blush": Color("bba9ec"), "eye_y": 1.80, "cheek_y": 1.62, "smile_y": 1.46},
	"watermelon": {"name": "WatermelonNPC", "speed": 3.8, "radius": 0.72, "feet": 0.41, "skin": Color("f35b6c"), "blush": Color("ffacb1"), "eye_y": 1.85, "cheek_y": 1.66, "smile_y": 1.50},
}
const WATERMELON_TOP: float = 2.64
const WATERMELON_RADIUS: float = 2.10
const WATERMELON_ANGLE: float = 0.58
const WATERMELON_DEPTH: float = 0.30


func build(kind: String) -> CharacterBody3D:
	var profile: Dictionary = PROFILES[kind]
	var actor := CharacterBody3D.new()
	actor.name = profile["name"]
	actor.set_script(WANDER_SCRIPT)
	actor.body_path = ^"Visual/Body"
	actor.walk_speed = profile["speed"]
	actor.acceleration = 16.0
	actor.braking = 24.0
	actor.floor_snap_length = 0.25
	actor.floor_max_angle = deg_to_rad(42.0)
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = profile["radius"]
	capsule.height = 2.26
	collider.shape = capsule
	collider.position.y = 1.14
	actor.add_child(collider)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.rotation.y = deg_to_rad(8.0)
	actor.add_child(visual)
	var foot_color: Color = HELD_BOOMERANG_BUILDER.PALETTES[kind]["hand"]
	var foot_material: StandardMaterial3D = _material(foot_color, 0.65)
	var foot_spread: float = profile["feet"]
	_sphere(visual, "LeftFoot", Vector3(-foot_spread, 0.28, 0.16), Vector3.ONE * 0.28, foot_material)
	_sphere(visual, "RightFoot", Vector3(foot_spread, 0.28, 0.16), Vector3.ONE * 0.28, foot_material)
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	if kind == "watermelon":
		_build_watermelon(body)
	else:
		var body_name: String = {"eggplant": "EggplantBody", "pumpkin": "PumpkinBody", "carrot": "CarrotBody", "blueberry": "BlueberryBody"}[kind]
		_mesh(body, body_name, _vegetable_mesh(kind), _material(profile["skin"], 0.42 if kind == "eggplant" else 0.60))
		match kind:
			"eggplant", "carrot":
				_build_leaves(body, kind)
				if kind == "carrot":
					_build_carrot_lines(body)
			"pumpkin":
				_build_pumpkin_stem(body)
			"blueberry":
				_build_blueberry_calyx(body)
	_build_face(body, kind)
	HELD_BOOMERANG_BUILDER.new().attach(body, kind)
	_set_owner(actor, actor)
	return actor


func _radius_at(kind: String, t: float) -> float:
	var profile: float = maxf(sin(PI * clampf(t, 0.0, 1.0)), 0.0)
	if kind == "eggplant":
		return 0.78 * pow(profile, 0.70) * (1.08 - 0.37 * t)
	if kind == "pumpkin":
		return 0.88 * pow(profile, 0.56)
	if kind == "blueberry":
		return 0.85 * pow(profile, 0.60)
	return 0.76 * pow(profile, 0.48) * (0.22 + 0.87 * t)


func _height(kind: String) -> float:
	return {"eggplant": 2.02, "pumpkin": 1.78, "carrot": 1.87, "blueberry": 1.82}[kind]


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
			# 南瓜的分瓣来自真实表面起伏，光照和切开时仍然保留。
			var lobes: float = 1.0 + 0.095 * cos(angle * 10.0) if kind == "pumpkin" else 1.0
			var angular_slope: float = -0.95 * sin(angle * 10.0) / lobes if kind == "pumpkin" else 0.0
			vertices.append(Vector3(cos(angle) * radius * lobes, 0.55 + height * t, sin(angle) * radius * lobes))
			var normal := Vector3(cos(angle) + angular_slope * sin(angle), -slope * lobes, sin(angle) - angular_slope * cos(angle)).normalized()
			if ring == 0:
				normal = Vector3.DOWN
			elif ring == RINGS:
				normal = Vector3.UP
			normals.append(normal)
	_grid_indices(indices, RINGS, SEGMENTS)
	return _array_mesh(vertices, normals, indices)


func _front_z(kind: String, x: float, y: float) -> float:
	if kind == "watermelon":
		return WATERMELON_DEPTH
	var radius: float = _radius_at(kind, (y - 0.55) / _height(kind))
	if kind == "pumpkin":
		# 将五官贴在分瓣表面，避免落入凹槽或悬浮在身体前方。
		var low: float = 0.0
		var high: float = radius * 1.095
		for step in range(18):
			var z: float = (low + high) * 0.5
			var angle: float = atan2(z, x)
			if Vector2(x, z).length() > radius * (1.0 + 0.095 * cos(angle * 10.0)):
				high = z
			else:
				low = z
		return (low + high) * 0.5
	return sqrt(maxf(radius * radius - x * x, 0.0))


func _build_face(body: Node3D, kind: String) -> void:
	var dark: StandardMaterial3D = _material(Color("30242d"), 0.24)
	var white: StandardMaterial3D = _material(Color("fff9e8"), 0.30)
	var profile: Dictionary = PROFILES[kind]
	var blush: StandardMaterial3D = _material(profile["blush"], 0.76)
	var eye_x: float = 0.24 if kind == "watermelon" else 0.23
	var eye_y: float = profile["eye_y"]
	var cheek_x: float = 0.42 if kind == "watermelon" else 0.39
	var cheek_y: float = profile["cheek_y"]
	for side in [-1.0, 1.0]:
		var x: float = side * eye_x
		var z: float = _front_z(kind, x, eye_y)
		_sphere(body, "EyeLeft" if side < 0.0 else "EyeRight", Vector3(x, eye_y, z + 0.030), Vector3(0.102, 0.128, 0.055), dark)
		_sphere(body, "EyeGlintLeft" if side < 0.0 else "EyeGlintRight", Vector3(x - 0.025, eye_y + 0.043, z + 0.079), Vector3.ONE * 0.030, white)
		_sphere(body, "CheekLeft" if side < 0.0 else "CheekRight", Vector3(side * cheek_x, cheek_y, _front_z(kind, side * cheek_x, cheek_y) + 0.026), Vector3(0.105, 0.055, 0.029), blush)
	# 所有角色都沿用草莓的小弧形笑嘴。
	var smile_y: float = profile["smile_y"]
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


func _build_pumpkin_stem(body: Node3D) -> void:
	var crown := Node3D.new()
	crown.name = "PumpkinCrown"
	body.add_child(crown)
	var top: float = 0.55 + _height("pumpkin")
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.075
	stem_mesh.bottom_radius = 0.11
	stem_mesh.height = 0.34
	stem_mesh.radial_segments = 16
	var stem: MeshInstance3D = _mesh(crown, "Stem", stem_mesh, _material(Color("688b37"), 0.85))
	stem.position = Vector3(0.035, top + 0.12, 0.0)
	stem.rotation.z = -0.22
	var leaf: MeshInstance3D = _sphere(crown, "Leaf", Vector3(-0.26, top + 0.10, 0.02), Vector3(0.13, 0.050, 0.34), _material(Color("83b84c"), 0.8))
	leaf.rotation = Vector3(-0.12, -0.95, 0.18)


func _blueberry_top(radius: float) -> float:
	var low: float = 0.5
	var high: float = 1.0
	for step in range(18):
		var t: float = (low + high) * 0.5
		if _radius_at("blueberry", t) > radius:
			low = t
		else:
			high = t
	return 0.55 + _height("blueberry") * (low + high) * 0.5


func _build_blueberry_calyx(body: Node3D) -> void:
	var calyx := Node3D.new()
	calyx.name = "BlueberryCalyx"
	body.add_child(calyx)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var center := Vector3(0.0, _blueberry_top(0.0) + 0.012, 0.0)
	var outline: Array[Vector3] = []
	for index in range(10):
		var angle: float = TAU * float(index) / 10.0 - PI * 0.5
		var radius: float = 0.32 if index % 2 == 0 else 0.14
		outline.append(Vector3(cos(angle) * radius, _blueberry_top(radius) + 0.014, sin(angle) * radius))
	for index in range(outline.size()):
		_triangle(vertices, normals, indices, colors, center, outline[index], outline[(index + 1) % outline.size()], Vector3.UP, Color.WHITE)
	var material: StandardMaterial3D = _material(Color("43559c"), 0.85)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(calyx, "FivePointCalyx", _array_mesh(vertices, normals, indices), material)
	# 五个短花萼贴着顶部星形轮廓，仍然沿用圆润的低多边形质感。
	for index in range(5):
		var angle: float = TAU * float(index) / 5.0 - PI * 0.5
		var radius: float = 0.235
		var petal: MeshInstance3D = _sphere(calyx, "CalyxTip%d" % index, Vector3(cos(angle) * radius, _blueberry_top(radius) + 0.028, sin(angle) * radius), Vector3(0.066, 0.037, 0.125), _material(Color("7b8add"), 0.72))
		petal.rotation.y = PI * 0.5 - angle


func _watermelon_point(radius: float, angle: float, depth: float) -> Vector3:
	return Vector3(sin(angle) * radius, WATERMELON_TOP - cos(angle) * radius, depth)


func _build_watermelon(body: Node3D) -> void:
	var material: StandardMaterial3D = _material(Color.WHITE, 0.68)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	_mesh(body, "WatermelonBody", _watermelon_mesh(), material)
	var seeds := Node3D.new()
	seeds.name = "WatermelonSeeds"
	body.add_child(seeds)
	var dark: StandardMaterial3D = _material(Color("43302e"), 0.7)
	var positions: Array[Vector2] = [Vector2(0.0, 2.30), Vector2(-0.32, 2.02), Vector2(0.32, 2.02), Vector2(-0.64, 1.47), Vector2(0.64, 1.47), Vector2(-0.55, 1.11), Vector2(0.55, 1.11), Vector2(0.0, 1.04)]
	for side in [-1.0, 1.0]:
		for index in range(positions.size()):
			var at: Vector2 = positions[index]
			var seed_mesh: MeshInstance3D = _sphere(seeds, "Seed%s%02d" % ["Front" if side > 0.0 else "Back", index], Vector3(at.x, at.y, side * (WATERMELON_DEPTH + 0.009)), Vector3(0.033, 0.064, 0.012), dark)
			seed_mesh.rotation.z = -at.x * 0.35


func _watermelon_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var radii: Array[float] = [0.0, 1.83, 1.97, WATERMELON_RADIUS]
	var palette: Array[Color] = [Color("f35b6c"), Color("eff0b7"), Color("6bb54a")]
	var slices: int = 40
	# 红瓤、浅色内皮、绿色外皮属于同一个封闭实体，切开时不会留下空壳。
	for band in range(palette.size()):
		var color: Color = palette[band]
		for index in range(slices):
			var first: float = lerpf(-WATERMELON_ANGLE, WATERMELON_ANGLE, float(index) / slices)
			var second: float = lerpf(-WATERMELON_ANGLE, WATERMELON_ANGLE, float(index + 1) / slices)
			for side in [-1.0, 1.0]:
				var a: Vector3 = _watermelon_point(radii[band], first, side * WATERMELON_DEPTH)
				var b: Vector3 = _watermelon_point(radii[band + 1], first, side * WATERMELON_DEPTH)
				var c: Vector3 = _watermelon_point(radii[band], second, side * WATERMELON_DEPTH)
				var d: Vector3 = _watermelon_point(radii[band + 1], second, side * WATERMELON_DEPTH)
				var normal := Vector3(0.0, 0.0, side)
				_triangle(vertices, normals, indices, colors, a, b, c, normal, color)
				_triangle(vertices, normals, indices, colors, c, b, d, normal, color)
		# 两条平直切边也保留红瓤与内外瓜皮的真实厚度。
		for side in [-1.0, 1.0]:
			var angle: float = side * WATERMELON_ANGLE
			var a: Vector3 = _watermelon_point(radii[band], angle, -WATERMELON_DEPTH)
			var b: Vector3 = _watermelon_point(radii[band + 1], angle, -WATERMELON_DEPTH)
			var c: Vector3 = _watermelon_point(radii[band], angle, WATERMELON_DEPTH)
			var d: Vector3 = _watermelon_point(radii[band + 1], angle, WATERMELON_DEPTH)
			var normal := Vector3(cos(angle) * side, sin(angle) * side, 0.0)
			_triangle(vertices, normals, indices, colors, a, b, c, normal, color)
			_triangle(vertices, normals, indices, colors, c, b, d, normal, color)
	for index in range(slices):
		var first: float = lerpf(-WATERMELON_ANGLE, WATERMELON_ANGLE, float(index) / slices)
		var second: float = lerpf(-WATERMELON_ANGLE, WATERMELON_ANGLE, float(index + 1) / slices)
		var angle: float = (first + second) * 0.5
		var a: Vector3 = _watermelon_point(WATERMELON_RADIUS, first, -WATERMELON_DEPTH)
		var b: Vector3 = _watermelon_point(WATERMELON_RADIUS, second, -WATERMELON_DEPTH)
		var c: Vector3 = _watermelon_point(WATERMELON_RADIUS, first, WATERMELON_DEPTH)
		var d: Vector3 = _watermelon_point(WATERMELON_RADIUS, second, WATERMELON_DEPTH)
		var normal := Vector3(sin(angle), -cos(angle), 0.0)
		var green: Color = Color("53943d") if index % 8 < 2 else palette[2]
		_triangle(vertices, normals, indices, colors, a, b, c, normal, green)
		_triangle(vertices, normals, indices, colors, c, b, d, normal, green)
	return _array_mesh(vertices, normals, indices, colors)


func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	# Godot 使用顺时针绕序；让每一片实体表面的正面与给定法线一致。
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		points[1] = c
		points[2] = b
	for point in points:
		indices.append(vertices.size())
		vertices.append(point)
		normals.append(normal)
		colors.append(color)


func _grid_indices(indices: PackedInt32Array, rows: int, columns: int) -> void:
	for row in range(rows):
		for column in range(columns):
			var a: int = row * (columns + 1) + column
			var b: int = a + columns + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))


func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
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
