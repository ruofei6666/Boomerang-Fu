extends RefCounted
## 四个角色共用的双圆手与圆角 V 形回旋镖；挂在身体下，自动跟随步态和转身。

const PALETTES: Dictionary = {
	"strawberry": {"hand": Color("ffb3c1"), "blade": Color("f34758"), "accent": Color("98cf4b"), "at": Vector3(0.86, 1.24, 0.30)},
	"eggplant": {"hand": Color("c9b2f0"), "blade": Color("7549ad"), "accent": Color("96ca4e"), "at": Vector3(0.80, 1.30, 0.27)},
	"donut": {"hand": Color("ffcfb1"), "blade": Color("ff9dbb"), "accent": Color("fff2b4"), "at": Vector3(1.00, 1.40, 0.20)},
	"carrot": {"hand": Color("ffc77d"), "blade": Color("f99432"), "accent": Color("96ca4e"), "at": Vector3(0.67, 1.26, 0.27)},
}
const LENGTH_SEGMENTS: int = 48
const RADIAL_SEGMENTS: int = 12
const HALF_WIDTH: float = 0.13
const HALF_THICKNESS: float = 0.055


func attach(body: Node3D, kind: String) -> void:
	var palette: Dictionary = PALETTES[kind]
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	sphere.radial_segments = 32
	sphere.rings = 16
	var palm_material: StandardMaterial3D = _material(palette["hand"], 0.65)
	var left_hand := Node3D.new()
	left_hand.name = "LeftHand"
	var hand_position: Vector3 = palette["at"]
	left_hand.position = Vector3(-hand_position.x, hand_position.y, hand_position.z)
	body.add_child(left_hand)
	_mesh(left_hand, "Palm", sphere, palm_material)
	var hand := Node3D.new()
	hand.name = "RightHand"
	hand.position = hand_position
	body.add_child(hand)
	_mesh(hand, "Palm", sphere, palm_material)
	var boomerang := Node3D.new()
	boomerang.name = "Boomerang"
	# 圆手覆盖回旋镖的弯折握持处，两翼朝身体外侧伸出，避开脸和甜甜圈的孔。
	boomerang.position = Vector3(0.0, 0.0, -0.075)
	boomerang.rotation = Vector3(-0.12, -0.16, 0.10)
	hand.add_child(boomerang)
	_mesh(boomerang, "Blade", _blade_mesh(0.0, 1.0), _material(palette["blade"], 0.48))
	var accent: StandardMaterial3D = _material(palette["accent"], 0.58)
	_mesh(boomerang, "UpperWingBand", _blade_mesh(0.13, 0.21, 0.003), accent)
	_mesh(boomerang, "LowerWingBand", _blade_mesh(0.79, 0.87, 0.003), accent)


func _center(t: float) -> Vector2:
	var upper := Vector2(0.14, 0.095)
	var lower := Vector2(0.14, -0.095)
	if t < 0.40:
		return Vector2(0.69, 0.46).lerp(upper, t / 0.40)
	if t > 0.60:
		return lower.lerp(Vector2(0.69, -0.46), (t - 0.60) / 0.40)
	var blend: float = (t - 0.40) / 0.20
	var corner := Vector2(-0.035, 0.0)
	return upper.lerp(corner, blend).lerp(corner.lerp(lower, blend), blend)


func _blade_mesh(start: float, end: float, offset: float = 0.0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments: int = LENGTH_SEGMENTS if start == 0.0 and end == 1.0 else 6
	for ring in range(segments + 1):
		var t: float = lerpf(start, end, float(ring) / segments)
		var center: Vector2 = _center(t)
		var tangent: Vector2 = (_center(minf(t + 0.001, 1.0)) - _center(maxf(t - 0.001, 0.0))).normalized()
		var sideways := Vector2(-tangent.y, tangent.x)
		# 两端缩成圆帽，截面为扁椭圆：有厚度和圆润边缘，仍能看清 V 形轮廓。
		var tip: float = clampf(minf(t, 1.0 - t) / 0.05, 0.0, 1.0)
		var cap: float = sqrt(maxf(1.0 - pow(1.0 - tip, 2.0), 0.0))
		var width: float = (HALF_WIDTH + offset) * cap
		var depth: float = (HALF_THICKNESS + offset) * cap
		for segment in range(RADIAL_SEGMENTS + 1):
			var angle: float = TAU * float(segment) / RADIAL_SEGMENTS
			var point: Vector2 = center + sideways * cos(angle) * width
			vertices.append(Vector3(point.x, point.y, sin(angle) * depth))
			var normal := Vector3(sideways.x * cos(angle) / HALF_WIDTH, sideways.y * cos(angle) / HALF_WIDTH, sin(angle) / HALF_THICKNESS).normalized()
			if tip < 1.0:
				var outward: Vector2 = -tangent if t < 0.5 else tangent
				normal = (normal * cap + Vector3(outward.x, outward.y, 0.0) * (1.0 - tip)).normalized()
			normals.append(normal)
	for ring in range(segments):
		for segment in range(RADIAL_SEGMENTS):
			var a: int = ring * (RADIAL_SEGMENTS + 1) + segment
			var b: int = a + RADIAL_SEGMENTS + 1
			# 沿中心线扫掠，使用 Godot 的顺时针正面绕序。
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
