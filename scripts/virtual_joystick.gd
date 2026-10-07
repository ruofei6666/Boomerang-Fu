extends Control
## 记录一根控制手指；其他手指不会抢走摇杆，松开、取消和失焦立即归零。

@export var radius: float = 74.0
@export var dead_zone: float = 0.12

var movement := Vector2.ZERO
var knob_offset := Vector2.ZERO
var active_touch: int = -1
var mouse_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _input(event: InputEvent) -> void:
	# GUI 按钮需要触摸模拟鼠标；摇杆只接受原始触摸，避免鼠标副本抢走手指。
	if event is InputEventMouse and event.device == -1:
		return
	if not is_visible_in_tree():
		release()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and active_touch == -1 and not mouse_active and _inside(touch.position):
			active_touch = touch.index
			_update_stick(touch.position)
			get_viewport().set_input_as_handled()
		elif touch.index == active_touch and (not touch.pressed or touch.canceled):
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch:
			_update_stick(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and active_touch == -1 and _inside(button.position):
				mouse_active = true
				_update_stick(button.position)
				get_viewport().set_input_as_handled()
			elif not button.pressed and mouse_active:
				release()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_active:
		_update_stick((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _inside(screen_position: Vector2) -> bool:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	return local.distance_to(size * 0.5) <= radius + 16.0


func _update_stick(screen_position: Vector2) -> void:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	knob_offset = (local - size * 0.5).limit_length(radius)
	var amount: float = knob_offset.length() / radius
	# 推动幅度只影响摇杆显示；越过死区后始终输出满速方向。
	movement = Vector2.ZERO if amount <= dead_zone else knob_offset.normalized()
	queue_redraw()


func release() -> void:
	active_touch = -1
	mouse_active = false
	movement = Vector2.ZERO
	knob_offset = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED:
		release()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var unit: float = radius / 74.0
	draw_circle(center, radius + 7.0 * unit, Color(0.16, 0.26, 0.20, 0.16))
	draw_circle(center, radius, Color(0.97, 1.0, 0.89, 0.30))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.97, 1.0, 0.9, 0.62), 2.0 * unit, true)
	for offset in [Vector2(0.0, -51.0), Vector2(51.0, 0.0), Vector2(0.0, 51.0), Vector2(-51.0, 0.0)]:
		draw_circle(center + offset * unit, 3.0 * unit, Color(0.2, 0.35, 0.26, 0.42))
	draw_circle(center + knob_offset + Vector2(0.0, 3.0) * unit, 29.0 * unit, Color(0.16, 0.28, 0.21, 0.18))
	draw_circle(center + knob_offset, 29.0 * unit, Color(0.96, 1.0, 0.86, 0.90))
	draw_arc(center + knob_offset, 29.0 * unit, 0.0, TAU, 48, Color(1.0, 1.0, 0.97, 0.90), 2.0 * unit, true)
