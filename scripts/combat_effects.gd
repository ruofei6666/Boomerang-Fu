extends Node3D
## 保留原角色网格和配色，用切面裁出两半，并封住切口；碎块和圆点独立飞散。

const CUT_SHADER = preload("res://assets/effects/cut_half.gdshader")
const COLORS := {"StrawberryPlayer": Color("f34758"), "EggplantNPC": Color("7549ad"), "DonutNPC": Color("ff9dbb"), "CarrotNPC": Color("f99432")}
const ROLE_COLORS: Array[Color] = [Color("f34758"), Color("7549ad"), Color("ff9dbb"), Color("f99432")]
const PIVOT := Vector3(0.0, 1.25, 0.0)
var pieces: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var dot_mesh: SphereMesh


func _ready() -> void:
	random.randomize()
	dot_mesh = SphereMesh.new()
	dot_mesh.radius = 0.10
	dot_mesh.height = 0.20
	dot_mesh.radial_segments = 10
	dot_mesh.rings = 5


func slice(actor: CharacterBody3D, attack_direction: Vector3) -> void:
	var color: Color = COLORS.get(String(actor.name), Color("f34758"))
	if actor.has_meta("role"):
		color = ROLE_COLORS[clampi(int(actor.get_meta("role")), 0, 3)]
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(actor.visual, meshes)
	var local_inverse: Transform3D = actor.visual.global_transform.affine_inverse()
	var sideways: Vector3 = actor.visual.global_basis.x.normalized()
	for half in [-1.0, 1.0]:
		var fragment := Node3D.new()
		fragment.name = "FruitHalf"
		add_child(fragment, true)
		fragment.global_transform = actor.visual.global_transform
		fragment.global_position = actor.visual.to_global(PIVOT)
		for source in meshes:
			if source == actor.slash_visual:
				continue
			var relative: Transform3D = local_inverse * source.global_transform
			var clone := MeshInstance3D.new()
			clone.mesh = source.mesh
			clone.transform = relative
			clone.position -= PIVOT
			var material := ShaderMaterial.new()
			material.shader = CUT_SHADER
			var original: Material = source.get_active_material(0)
			material.set_shader_parameter("skin_color", original.albedo_color if original is StandardMaterial3D else color)
			material.set_shader_parameter("surface_roughness", original.roughness if original is StandardMaterial3D else 0.7)
			material.set_shader_parameter("slice_space", relative)
			material.set_shader_parameter("half_sign", half)
			clone.material_override = material
			fragment.add_child(clone)
			if String(source.name) in ["StrawberryBody", "EggplantBody", "CarrotBody", "DonutBody"]:
				_add_cut_face(fragment, source, relative, color, half, String(source.name) == "DonutBody")
		pieces.append({"node": fragment, "velocity": sideways * half * 3.4 + attack_direction * 0.65 + Vector3.UP * 3.6, "spin": Vector3(0.1, half * 0.45, half * 2.4), "age": 0.0, "floor": 0.52, "duration": 4.0, "half": true})
	var blood := StandardMaterial3D.new()
	blood.albedo_color = color
	blood.roughness = 0.95
	for index in range(26):
		var angle: float = random.randf_range(0.0, TAU)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var dot := MeshInstance3D.new()
		dot.name = "BloodDot"
		dot.mesh = dot_mesh
		dot.material_override = blood
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot, true)
		dot.global_position = actor.global_position + Vector3.UP * random.randf_range(0.8, 1.6)
		dot.scale = Vector3.ONE * random.randf_range(0.65, 1.35)
		pieces.append({"node": dot, "velocity": direction * random.randf_range(1.5, 4.0) + attack_direction * 0.7 + Vector3.UP * random.randf_range(1.4, 4.0), "spin": Vector3.ZERO, "age": 0.0, "floor": 0.07, "duration": 3.2, "half": false})


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.visible and node.mesh:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _add_cut_face(fragment: Node3D, source: MeshInstance3D, relative: Transform3D, color: Color, half: float, donut: bool) -> void:
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var groups: Array[PackedVector2Array] = []
	groups.append(PackedVector2Array())
	if donut:
		groups.append(PackedVector2Array())
	var unique: Dictionary = {}
	for triangle in range(0, indices.size(), 3):
		for edge in range(3):
			var a: Vector3 = relative * vertices[indices[triangle + edge]]
			var b: Vector3 = relative * vertices[indices[triangle + (edge + 1) % 3]]
			if a.x * b.x > 0.0 and absf(a.x) > 0.00001:
				continue
			var point: Vector3 = a if absf(a.x) < 0.00001 else a.lerp(b, a.x / (a.x - b.x))
			var key := Vector2i(roundi(point.y * 10000.0), roundi(point.z * 10000.0))
			if key in unique:
				continue
			unique[key] = true
			var group: int = 1 if donut and point.y > 1.49 else 0
			var outline: PackedVector2Array = groups[group]
			outline.append(Vector2(point.y, point.z))
			groups[group] = outline
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color("fff2cd"), 0.60)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for outline in groups:
		if outline.size() < 3:
			continue
		var polygon: PackedVector2Array = Geometry2D.convex_hull(outline)
		if polygon.size() > 3 and polygon[0].is_equal_approx(polygon[polygon.size() - 1]):
			polygon.remove_at(polygon.size() - 1)
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		if triangles.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in triangles:
			surface.set_normal(Vector3(-half, 0.0, 0.0))
			surface.add_vertex(Vector3(0.001 * half, polygon[index].x, polygon[index].y) - PIVOT)
		var cap := MeshInstance3D.new()
		cap.name = "CutFace"
		cap.mesh = surface.commit()
		cap.material_override = material
		fragment.add_child(cap, true)


func clash(at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffe487")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(10):
		var angle: float = TAU * float(index) / 10.0
		var spark := MeshInstance3D.new()
		spark.name = "ClashSpark"
		spark.mesh = dot_mesh
		spark.material_override = material
		spark.scale = Vector3.ONE * 0.6
		add_child(spark)
		spark.global_position = at
		pieces.append({"node": spark, "velocity": Vector3(cos(angle) * 3.0, 1.6, sin(angle) * 3.0), "spin": Vector3.ZERO, "age": 0.0, "floor": 0.04, "duration": 0.32, "half": false})


func _process(delta: float) -> void:
	for index in range(pieces.size() - 1, -1, -1):
		var item: Dictionary = pieces[index]
		var node: Node3D = item.node
		item.age += delta
		if not is_instance_valid(node) or item.age >= item.duration:
			if is_instance_valid(node):
				node.queue_free()
			pieces.remove_at(index)
			continue
		var velocity: Vector3 = item.velocity
		velocity.y -= 13.0 * delta
		node.position += velocity * delta
		if node.position.y < item.floor:
			node.position.y = item.floor
			velocity.y = absf(velocity.y) * 0.24 if velocity.y < -1.2 else 0.0
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			item.spin *= maxf(0.0, 1.0 - delta * 5.0)
		node.rotation += item.spin * delta
		item.velocity = velocity
		if item.age > item.duration - 0.55:
			node.scale = node.scale.lerp(Vector3.ZERO, minf(delta * 12.0, 1.0))


func clear() -> void:
	for item in pieces:
		if is_instance_valid(item.node):
			item.node.queue_free()
	pieces.clear()
