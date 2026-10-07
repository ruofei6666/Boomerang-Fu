extends RefCounted
## 生成真实的平面分层网格并保存到 .tscn，编辑器里可以单独移动每块石头。

const CAMERA_SCRIPT = preload("res://scripts/camera_controller.gd")
const ARENA_SCRIPT = preload("res://scripts/arena.gd")
const INTERFACE_SCRIPT = preload("res://scripts/interface.gd")
const PLAYER_SCENE = preload("res://scenes/strawberry_player.tscn")
const WANDER_SCENES = [preload("res://scenes/eggplant_npc.tscn"), preload("res://scenes/donut_npc.tscn"), preload("res://scenes/carrot_npc.tscn")]

const GROUND_COLOR := Color("d4f887")
const CAP_COLOR := Color("b5e89a")
const ROCK_COLORS: Array[Color] = [Color("626ca5"), Color("7b85bd"), Color("929dce"), Color("8a96c9")]

# Compatibility 的光照响应与 Forward+ 不同；以下材质补偿按旧版实际渲染画面校准。
const VERTEX_PALETTE_TINT := Color(0.70, 0.70, 0.716, 1.0)
const SOLID_PALETTE_TINT := Color(0.72, 0.74, 0.724, 1.0)

var vertex_material: StandardMaterial3D
var solid_materials: Dictionary = {}


func build_scene() -> Node3D:
	vertex_material = StandardMaterial3D.new()
	vertex_material.vertex_color_use_as_albedo = true
	vertex_material.vertex_color_is_srgb = true
	vertex_material.albedo_color = VERTEX_PALETTE_TINT
	vertex_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	vertex_material.roughness = 1.0
	vertex_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	vertex_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arena := Node3D.new()
	arena.name = "StoneArena"
	arena.set_script(ARENA_SCRIPT)
	_build_environment(arena)
	_build_ground(arena)
	_build_interior_rocks(arena)
	_build_perimeter(arena)
	_build_camera(arena)
	_build_interface(arena)
	var player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 0.08, 3.0)
	arena.add_child(player)
	var starts: Array[Vector3] = [Vector3(-2.9, 0.08, 1.25), Vector3(2.75, 0.08, 4.4), Vector3(0.75, 0.08, -0.55)]
	for index in range(WANDER_SCENES.size()):
		var actor: CharacterBody3D = WANDER_SCENES[index].instantiate() as CharacterBody3D
		actor.position = starts[index]
		actor.spawn_position = starts[index]
		arena.add_child(actor)
	_set_owners(arena, arena)
	return arena


func _build_environment(arena: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("95c989")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e2ff")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.name = "SoftDaylight"
	world.environment = environment
	arena.add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Sunlight"
	sunlight.rotation_degrees = Vector3(-55.0, -38.0, 0.0)
	sunlight.light_color = Color("fff7db")
	sunlight.light_energy = 0.64
	sunlight.light_angular_distance = 4.0
	sunlight.shadow_enabled = true
	sunlight.shadow_bias = 0.12
	sunlight.shadow_normal_bias = 0.7
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sunlight.directional_shadow_max_distance = 90.0
	arena.add_child(sunlight)


func _build_ground(arena: Node3D) -> void:
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	arena.add_child(terrain)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "SurroundingGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180.0, 180.0)
	backdrop.mesh = plane
	backdrop.material_override = _material(Color("98ce89"))
	backdrop.position.y = -1.55
	terrain.add_child(backdrop)
	var outline := PackedVector2Array([
		Vector2(-17.7, -14.4), Vector2(-9.1, -14.8), Vector2(-1.7, -14.3),
		Vector2(8.3, -14.5), Vector2(17.6, -13.7), Vector2(19.1, -11.0),
		Vector2(18.8, -3.0), Vector2(19.2, 4.6), Vector2(18.5, 11.9),
		Vector2(15.7, 14.1), Vector2(7.2, 14.7), Vector2(-0.8, 14.3),
		Vector2(-9.1, 14.6), Vector2(-17.9, 13.7), Vector2(-19.0, 10.3),
		Vector2(-18.8, 2.0), Vector2(-19.1, -7.9)
	])
	var floor_surface := MeshInstance3D.new()
	floor_surface.name = "LimeGround"
	floor_surface.mesh = _flat_polygon(outline, 0.0, GROUND_COLOR)
	floor_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.add_child(floor_surface)
	var collision := StaticBody3D.new()
	collision.name = "GroundCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(38.0, 0.4, 29.0)
	shape.shape = box
	shape.position.y = -0.2
	collision.add_child(shape)
	terrain.add_child(collision)
	var sides := MeshInstance3D.new()
	sides.name = "PlateauSides"
	sides.mesh = _extruded_outline(outline, -1.5, -0.005, Color("7581b4"))
	terrain.add_child(sides)
	_build_ground_patches(terrain)


func _build_ground_patches(terrain: Node3D) -> void:
	# 色斑只是地面材质几何，不是草、灌木或其他植物。
	var patches := Node3D.new()
	patches.name = "GroundColorPatches"
	terrain.add_child(patches)
	var positions: Array[Vector2] = [
		Vector2(-11.8, -4.5), Vector2(-5.2, -8.8), Vector2(5.6, -7.8),
		Vector2(11.2, -3.1), Vector2(-3.8, 3.2), Vector2(3.6, 5.9),
		Vector2(-10.6, 9.7), Vector2(11.8, 9.0), Vector2(0.4, -4.2),
		Vector2(6.4, 1.7), Vector2(-13.9, 0.9), Vector2(-0.3, 10.5)
	]
	var random := RandomNumberGenerator.new()
	random.seed = 43215
	for index in range(positions.size()):
		var patch := MeshInstance3D.new()
		patch.name = "GroundPatch%02d" % (index + 1)
		var points := PackedVector2Array()
		var width: float = random.randf_range(0.55, 1.2)
		var depth: float = random.randf_range(0.32, 0.75)
		for vertex in range(7):
			var angle: float = float(vertex) * TAU / 7.0
			var jitter: float = random.randf_range(0.75, 1.12)
			points.append(Vector2(cos(angle) * width, sin(angle) * depth) * jitter)
		var tint: Color = GROUND_COLOR.lerp(Color("f1ffb0"), 0.30 if index % 3 == 0 else 0.10)
		patch.mesh = _flat_polygon(points, 0.008, tint)
		patch.position = Vector3(positions[index].x, 0.0, positions[index].y)
		patch.rotation.y = random.randf_range(-PI, PI)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patches.add_child(patch)


func _build_interior_rocks(arena: Node3D) -> void:
	var rocks := Node3D.new()
	rocks.name = "InteriorRocks"
	arena.add_child(rocks)
	# 位置根据参考图安排，保留宽敞的中央地面和几组相接的石头。
	_add_rock(rocks, "NorthwestLarge", Vector2(-7.6, -5.2), Vector2(2.7, 2.1), 1.75, 31)
	_add_rock(rocks, "NorthwestLower", Vector2(-5.8, -3.9), Vector2(1.65, 1.4), 1.12, 42)
	_add_rock(rocks, "NorthernSingle", Vector2(1.4, -8.6), Vector2(1.65, 1.45), 1.42, 62)
	_add_rock(rocks, "EasternTall", Vector2(6.0, -0.49), Vector2(2.25, 2.2), 2.80, 82)
	_add_rock(rocks, "SouthwestLarge", Vector2(-6.5, 4.6), Vector2(2.8, 2.2), 1.24, 12)
	_add_rock(rocks, "SouthwestUpper", Vector2(-8.8, 3.55), Vector2(1.55, 1.4), 1.48, 28)
	_add_rock(rocks, "SoutheastLower", Vector2(12.0, 4.8), Vector2(2.85, 2.4), 1.08, 109)
	_add_rock(rocks, "SoutheastUpper", Vector2(12.3, 3.9), Vector2(2.18, 1.75), 1.85, 116)
	_add_rock(rocks, "FarNortheast", Vector2(12.8, -8.2), Vector2(2.0, 1.6), 1.35, 137)


func _build_perimeter(arena: Node3D) -> void:
	var cliffs := Node3D.new()
	cliffs.name = "PerimeterCliffs"
	arena.add_child(cliffs)
	var random := RandomNumberGenerator.new()
	random.seed = 94213
	for index in range(8):
		var horizontal: float = -17.0 + float(index) * 4.85
		var radii := Vector2(random.randf_range(2.6, 3.25), random.randf_range(1.8, 2.65))
		_add_rock(cliffs, "NorthCliff%02d" % (index + 1), Vector2(horizontal, -14.5), radii, random.randf_range(2.0, 3.4), 1000 + index)
		var near_radii := Vector2(random.randf_range(2.6, 3.5), random.randf_range(1.75, 2.5))
		_add_rock(cliffs, "SouthCliff%02d" % (index + 1), Vector2(horizontal + 0.3, 14.5), near_radii, random.randf_range(1.9, 3.25), 1100 + index, index % 4 == 1)
	# 左侧保留参考图里的矮石墙，中部不堆满大块岩石。
	_build_wall(cliffs, "WesternLowWall", Vector3(-18.35, 0.38, -0.2), Vector3(0.6, 0.76, 17.0))
	_add_rock(cliffs, "WestNorthernAnchor", Vector2(-18.2, -10.8), Vector2(2.7, 3.5), 3.1, 1198)
	_add_rock(cliffs, "WestSouthernAnchor", Vector2(-18.0, 10.4), Vector2(3.3, 3.1), 2.65, 1199, false)
	for index in range(5):
		var depth: float = -10.7 + float(index) * 5.2
		_add_rock(cliffs, "EastCliff%02d" % (index + 1), Vector2(19.0, depth), Vector2(random.randf_range(1.6, 2.3), random.randf_range(2.6, 3.3)), random.randf_range(1.7, 2.9), 1200 + index)


func _build_wall(parent: Node3D, wall_name: String, at: Vector3, dimensions: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.position = at
	parent.add_child(wall)
	var mesh := MeshInstance3D.new()
	mesh.name = "StoneWall"
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = _material(Color("8793c7"))
	wall.add_child(mesh)
	var cap := MeshInstance3D.new()
	cap.name = "LightStoneEdge"
	var top := BoxMesh.new()
	top.size = Vector3(dimensions.x + 0.045, 0.10, dimensions.z + 0.04)
	cap.mesh = top
	cap.material_override = _material(Color("a0acd7"))
	cap.position.y = dimensions.y * 0.5
	wall.add_child(cap)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.name = "WallCollision"
	collision.shape = shape
	wall.add_child(collision)


func _add_rock(parent: Node3D, rock_name: String, at: Vector2, radii: Vector2, height: float, rock_seed: int, green_top: bool = true) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = rock_seed
	var count: int = random.randi_range(7, 9)
	var outline := PackedVector2Array()
	for index in range(count):
		var angle: float = TAU * float(index) / float(count) + random.randf_range(-0.075, 0.075)
		var distortion: float = random.randf_range(0.88, 1.10)
		outline.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * distortion)
	var rock := StaticBody3D.new()
	rock.name = rock_name
	rock.position = Vector3(at.x, 0.02, at.y)
	rock.rotation.y = random.randf_range(-0.35, 0.35)
	rock.set_meta("seed", rock_seed)
	rock.set_meta("height", height)
	parent.add_child(rock)
	var arrays: Array = _empty_arrays()
	var ring_heights: Array[float] = [0.0, height * 0.12, height * 0.72, height * 0.90, height]
	var ring_scales: Array[float] = [0.86, 1.0, 1.025, 0.97, 0.87]
	var collision_points := PackedVector3Array()
	for ring in range(4):
		for index in range(count):
			var next: int = (index + 1) % count
			var a: Vector3 = _ring_point(outline[index], ring_scales[ring], ring_heights[ring])
			var b: Vector3 = _ring_point(outline[next], ring_scales[ring], ring_heights[ring])
			var c: Vector3 = _ring_point(outline[next], ring_scales[ring + 1], ring_heights[ring + 1])
			var d: Vector3 = _ring_point(outline[index], ring_scales[ring + 1], ring_heights[ring + 1])
			var outward: Vector3 = (d - a).cross(b - a).normalized()
			var color: Color = ROCK_COLORS[ring].lightened(random.randf_range(-0.035, 0.04))
			_triangle(arrays, a, b, c, outward, color)
			_triangle(arrays, a, c, d, outward, color)
			collision_points.append(a)
			collision_points.append(d)
	for index in range(count):
		var next: int = (index + 1) % count
		_triangle(arrays, Vector3(0.0, height, 0.0), _ring_point(outline[index], 0.87, height), _ring_point(outline[next], 0.87, height), Vector3.UP, Color("99a6d3"))
	var body := MeshInstance3D.new()
	body.name = "FacetedStone"
	body.mesh = _mesh_from_arrays(arrays)
	rock.add_child(body)
	if green_top:
		var top := MeshInstance3D.new()
		top.name = "FlatGreenSurface"
		var cap_outline := PackedVector2Array()
		for point in outline:
			cap_outline.append(point * 0.76)
		var cap_color: Color = CAP_COLOR.lightened(random.randf_range(-0.03, 0.05))
		top.mesh = _flat_polygon(cap_outline, height + 0.006, cap_color)
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rock.add_child(top)
	var collision := CollisionShape3D.new()
	collision.name = "RockCollision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = collision_points
	collision.shape = shape
	rock.add_child(collision)


func _build_camera(arena: Node3D) -> void:
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(CAMERA_SCRIPT)
	rig.position = Vector3(0.0, 0.0, 0.7)
	arena.add_child(rig)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40.0 / 1.23
	camera.near = 0.1
	camera.far = 180.0
	camera.current = true
	var angle: float = deg_to_rad(53.0)
	var yaw: float = deg_to_rad(8.0)
	var offset := Vector3(sin(yaw) * cos(angle), sin(angle), cos(yaw) * cos(angle)) * 45.0
	camera.position = offset
	camera.basis = Basis.looking_at(-offset, Vector3.UP)
	rig.add_child(camera)


func _build_interface(arena: Node3D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	layer.set_script(INTERFACE_SCRIPT)
	arena.add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	root.theme = theme
	var title := Label.new()
	title.name = "MapTitle"
	title.text = "岩石庭院  /  STONE ARENA"
	title.position = Vector2(25.0, 23.0)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("3a5948"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var hint_panel := PanelContainer.new()
	hint_panel.name = "CameraHints"
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 24.0
	hint_panel.offset_right = 832.0
	hint_panel.offset_top = -61.0
	hint_panel.offset_bottom = -24.0
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.23, 0.22, 0.84)
	style.set_corner_radius_all(9)
	style.content_margin_left = 15.0
	style.content_margin_right = 15.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	hint_panel.add_theme_stylebox_override("panel", style)
	root.add_child(hint_panel)
	var hints := Label.new()
	hints.name = "Hints"
	hints.text = "WASD / 方向键 移动    中键 / 右键 拖动    滚轮 缩放    Q / E 转向    R 复位    H 隐藏提示"
	hints.add_theme_color_override("font_color", Color("e4f2d7"))
	hints.add_theme_font_size_override("font_size", 13)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hints)
	var top_right := HBoxContainer.new()
	top_right.name = "TopRight"
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -70.0
	top_right.offset_right = -24.0
	top_right.offset_top = 22.0
	top_right.offset_bottom = 56.0
	top_right.add_theme_constant_override("separation", 14)
	root.add_child(top_right)
	var zoom := Label.new()
	zoom.name = "Zoom"
	zoom.text = "100%"
	zoom.add_theme_color_override("font_color", Color("3a5948"))
	zoom.custom_minimum_size.x = 46.0
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(zoom)


func _material(color: Color) -> StandardMaterial3D:
	if solid_materials.has(color):
		return solid_materials[color] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color * SOLID_PALETTE_TINT
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	solid_materials[color] = material
	return material


func _empty_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray()
	return arrays


func _triangle(arrays: Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	# Godot 正面绕序为顺时针；显式法线保留低多边形平面效果。
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for vertex in [a, b, c]:
		vertices.append(vertex)
		normals.append(normal)
		colors.append(color)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors


func _mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, vertex_material)
	return mesh


func _ring_point(point: Vector2, scale_factor: float, height: float) -> Vector3:
	return Vector3(point.x * scale_factor, height, point.y * scale_factor)


func _flat_polygon(outline: PackedVector2Array, height: float, color: Color) -> ArrayMesh:
	var arrays: Array = _empty_arrays()
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		var a: Vector3 = _ring_point(outline[indices[index]], 1.0, height)
		var b: Vector3 = _ring_point(outline[indices[index + 1]], 1.0, height)
		var c: Vector3 = _ring_point(outline[indices[index + 2]], 1.0, height)
		_triangle(arrays, a, b, c, Vector3.UP, color)
	return _mesh_from_arrays(arrays)


func _extruded_outline(outline: PackedVector2Array, bottom: float, top: float, color: Color) -> ArrayMesh:
	var arrays: Array = _empty_arrays()
	for index in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		var a: Vector3 = _ring_point(outline[index], 1.0, bottom)
		var b: Vector3 = _ring_point(outline[next], 1.0, bottom)
		var c: Vector3 = _ring_point(outline[next], 1.0, top)
		var d: Vector3 = _ring_point(outline[index], 1.0, top)
		var normal: Vector3 = (d - a).cross(b - a).normalized()
		_triangle(arrays, a, b, c, normal, color)
		_triangle(arrays, a, c, d, normal, color)
	return _mesh_from_arrays(arrays)


func _set_owners(node: Node, arena: Node) -> void:
	for child in node.get_children():
		child.owner = arena
		_set_owners(child, arena)

