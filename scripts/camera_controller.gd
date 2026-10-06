extends Node3D
## 固定俯视倾角的正交相机。平移始终按屏幕方向计算。

@export var initial_size: float = 16.0
@export var min_size: float = 11.0
@export var max_size: float = 43.0
@export var move_speed: float = 12.0
@export var inclination_degrees: float = 48.0
@export var initial_yaw_degrees: float = 8.0
@export var pan_limits: Vector2 = Vector2(18.0, 14.0)

@onready var camera: Camera3D = $Camera3D

var desired_center := Vector3(0.0, 0.0, 0.7)
var desired_size: float = 24.0
var yaw: float = 0.0
var dragging: bool = false
var drag_button: int = MOUSE_BUTTON_NONE
var hud: CanvasLayer
var follow_target: Node3D
var following: bool = true


func _ready() -> void:
	desired_size = initial_size
	yaw = deg_to_rad(initial_yaw_degrees)
	position = desired_center
	camera.size = initial_size
	_apply_orientation()
	hud = get_parent().get_node_or_null("Interface") as CanvasLayer


func _process(delta: float) -> void:
	var step: float = minf(delta, 0.05)
	if following and is_instance_valid(follow_target):
		desired_center = Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)
	var turn: float = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	yaw += turn * step * 0.85
	_clamp_center()
	var smoothing: float = 1.0 - exp(-14.0 * delta)
	position = position.lerp(desired_center, smoothing)
	camera.size = lerpf(camera.size, desired_size, smoothing)
	_apply_orientation()


func _input(event: InputEvent) -> void:
	# 拖动后松开时，即使指针在界面按钮上也能结束拖动。
	if dragging and event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == drag_button and not button.pressed:
			_end_drag()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				following = false
				dragging = true
				drag_button = button.button_index
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			elif drag_button == button.button_index:
				_end_drag()
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(button.position, 1.0 / 1.12)
			get_viewport().set_input_as_handled()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(button.position, 1.12)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		var previous_hit: Vector3 = ground_position(motion.position - motion.relative)
		var current_hit: Vector3 = ground_position(motion.position)
		desired_center += previous_hit - current_hit
		_clamp_center()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_R or key.keycode == KEY_R:
			reset_view()
		elif key.physical_keycode == KEY_H or key.keycode == KEY_H:
			if hud:
				hud.visible = not hud.visible
		elif key.keycode == KEY_F11:
			var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_end_drag()


func _apply_orientation() -> void:
	var inclination: float = deg_to_rad(inclination_degrees)
	var offset := Vector3(sin(yaw) * cos(inclination), sin(inclination), cos(yaw) * cos(inclination)) * 45.0
	camera.position = offset
	camera.basis = Basis.looking_at(-offset, Vector3.UP)


func _clamp_center() -> void:
	desired_center.x = clampf(desired_center.x, -pan_limits.x, pan_limits.x)
	desired_center.z = clampf(desired_center.z, -pan_limits.y, pan_limits.y)
	desired_center.y = 0.0


func _end_drag() -> void:
	dragging = false
	drag_button = MOUSE_BUTTON_NONE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func ground_position(screen_position: Vector2) -> Vector3:
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	return hit as Vector3 if hit != null else position


func zoom_at(screen_position: Vector2, factor: float) -> void:
	# 同时平移相机，让鼠标指向的地面在缩放时留在同一位置。
	var before: Vector3 = ground_position(screen_position)
	var previous_size: float = camera.size
	var previous_position: Vector3 = position
	position = desired_center
	camera.size = clampf(desired_size * factor, min_size, max_size)
	var after: Vector3 = ground_position(screen_position)
	desired_size = camera.size
	camera.size = previous_size
	position = previous_position
	desired_center += before - after
	_clamp_center()


func reset_view() -> void:
	following = true
	desired_center = Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z) if is_instance_valid(follow_target) else Vector3(0.0, 0.0, 0.7)
	desired_size = initial_size
	yaw = deg_to_rad(initial_yaw_degrees)
	_end_drag()

