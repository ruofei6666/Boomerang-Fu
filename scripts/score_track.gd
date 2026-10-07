extends Control
## 十个果糖色记分点，清楚展示距离整场胜利还差几分。

var score: int = 0
var tint := Color("d94a66")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var step: float = size.x / 10.0
	var radius: float = minf(size.y * 0.38, step * 0.28)
	for index in range(10):
		var center := Vector2(step * (index + 0.5), size.y * 0.5)
		draw_circle(center, radius, tint if index < score else Color(tint, 0.14))
		if index < score:
			draw_circle(center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.22, Color(1.0, 1.0, 1.0, 0.70))
