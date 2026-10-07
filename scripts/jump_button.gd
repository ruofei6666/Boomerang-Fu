extends "res://scripts/melee_button.gd"
## 跳跃图标复用砍击按钮的独立触点和取消处理。

signal jump_pressed


func _ready() -> void:
	action_label = "跳 K"
	super._ready()


func _activate() -> void:
	jump_pressed.emit()


func _action_ready() -> bool:
	return is_instance_valid(player) and player.alive and player.has_focus and player.attack_state == "idle" and not player.attack_requested


func _draw_icon(center: Vector2, unit: float, tint: Color) -> void:
	# 向上箭头和离地的两只圆脚表示跳跃。
	draw_line(center + Vector2(0.0, 6.0) * unit, center + Vector2(0.0, -27.0) * unit, tint, 5.0 * unit, true)
	draw_polyline(PackedVector2Array([center + Vector2(-12.0, -15.0) * unit, center + Vector2(0.0, -27.0) * unit, center + Vector2(12.0, -15.0) * unit]), tint, 5.0 * unit, true)
	draw_circle(center + Vector2(-11.0, 12.0) * unit, 6.0 * unit, tint)
	draw_circle(center + Vector2(11.0, 16.0) * unit, 6.0 * unit, tint)
	draw_line(center + Vector2(-23.0, 6.0) * unit, center + Vector2(-23.0, 18.0) * unit, Color(tint, 0.5), 2.0 * unit, true)
	draw_line(center + Vector2(23.0, 10.0) * unit, center + Vector2(23.0, 22.0) * unit, Color(tint, 0.5), 2.0 * unit, true)
