extends "res://scripts/melee_button.gd"
## 独立记录投掷手指；按住瞄准，正常松开才投掷，取消和失焦只退出瞄准。


func _ready() -> void:
	action_label = "投 L"
	super._ready()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_id == -1 and _inside(event.position):
			touch_id = event.index
			player.hold_throw("touch")
			get_viewport().set_input_as_handled()
		elif event.index == touch_id and (not event.pressed or event.canceled):
			touch_id = -1
			player.release_throw_control("touch", event.canceled)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _inside(event.position) and not mouse_held:
			mouse_held = true
			player.hold_throw("mouse")
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_held:
			mouse_held = false
			player.release_throw_control("mouse")
			get_viewport().set_input_as_handled()


func cancel() -> void:
	touch_id = -1
	mouse_held = false
	if is_instance_valid(player):
		player.cancel_throw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel()


func _action_ready() -> bool:
	return is_instance_valid(player) and player.alive and player.has_focus and player.has_boomerang and not player.attack_requested and player.attack_state in ["idle", "aim"]


func _draw_icon(center: Vector2, unit: float, tint: Color) -> void:
	# 朝右飞出的 V 形回旋镖和尾迹。
	draw_polyline(PackedVector2Array([center + Vector2(-8, -22) * unit, center + Vector2(9, -6) * unit, center + Vector2(-8, 10) * unit]), tint, 7.0 * unit, true)
	for row in [-16.0, -5.0, 6.0]:
		draw_line(center + Vector2(-29, row) * unit, center + Vector2(-16, row) * unit, Color(tint, 0.65), 2.5 * unit, true)
	draw_line(center + Vector2(15, -6) * unit, center + Vector2(29, -6) * unit, tint, 2.5 * unit, true)
	draw_polyline(PackedVector2Array([center + Vector2(23, -12) * unit, center + Vector2(29, -6) * unit, center + Vector2(23, 0) * unit]), tint, 2.5 * unit, true)
