extends Control
## 砍击图标直接拥有自己的触点，摇杆手指可以同时保持，不依赖模拟鼠标。

signal attack_pressed
var player: CharacterBody3D
var touch_id: int = -1
var mouse_held: bool = false
var action_label: String = "砍 J"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_id == -1 and _inside(event.position):
			touch_id = event.index
			_activate()
			get_viewport().set_input_as_handled()
		elif event.index == touch_id and (not event.pressed or event.canceled):
			touch_id = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _inside(event.position):
			mouse_held = true
			_activate()
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_held:
			mouse_held = false
			get_viewport().set_input_as_handled()


func _activate() -> void:
	attack_pressed.emit()


func _inside(at: Vector2) -> bool:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * at
	return local.distance_to(size * 0.5) <= size.x * 0.5


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		touch_id = -1
		mouse_held = false


func _process(_delta: float) -> void:
	queue_redraw()


func _action_ready() -> bool:
	return is_instance_valid(player) and player.alive and player.has_focus and not player.attack_requested and (player.attack_state == "idle" or (player.attack_state == "jump" and not player.attack_buffered))


func _draw() -> void:
	if size.x <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var unit: float = size.x / 100.0
	var ready: bool = _action_ready()
	var tint := Color("fff3d4") if ready else Color("9fb0a0")
	draw_circle(center + Vector2(0.0, 4.0) * unit, 46.0 * unit, Color(0.16, 0.26, 0.20, 0.25))
	draw_circle(center, 46.0 * unit, Color("41604a") if mouse_held or touch_id >= 0 else Color("2f493c"))
	draw_arc(center, 46.0 * unit, 0.0, TAU, 56, tint, 2.0 * unit, true)
	_draw_icon(center, unit, tint)
	var font: Font = get_theme_default_font()
	draw_string(font, center + Vector2(-18.0, 35.0) * unit, action_label, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13.0 * unit), tint)


func _draw_icon(center: Vector2, unit: float, tint: Color) -> void:
	# 两条弧线呈现挥砍轨迹，中间是圆角 V 形回旋镖。
	draw_arc(center + Vector2(-6.0, 2.0) * unit, 25.0 * unit, -1.45, 0.45, 32, tint, 5.0 * unit, true)
	draw_arc(center + Vector2(-6.0, 2.0) * unit, 33.0 * unit, -1.35, 0.20, 32, Color(tint, 0.42), 2.0 * unit, true)
	draw_polyline(PackedVector2Array([center + Vector2(-18.0, -12.0) * unit, center + Vector2(-6.0, 7.0) * unit, center + Vector2(12.0, 12.0) * unit]), tint, 7.0 * unit, true)
