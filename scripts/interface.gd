extends CanvasLayer

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
const UI_FONT = preload("res://assets/fonts/noto_sans_sc_ui.ttf")

@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")
@onready var zoom_label: Label = $Root/TopRight/Zoom
@onready var root: Control = $Root

var joystick: Control
var respawn_button: Button
var touch_mode: bool = false


func _ready() -> void:
	root.theme = root.theme.duplicate() as Theme
	root.theme.default_font = UI_FONT
	$Root/TopRight/Reset.pressed.connect(camera_rig.reset_view)
	$Root/TopRight/Reset.focus_mode = Control.FOCUS_NONE
	$Root/TopRight/Reset.text = "跟随视角 R"
	$Root/MapTitle.text = "草莓散步  /  STRAWBERRY WALK"
	joystick = Control.new()
	joystick.name = "VirtualJoystick"
	joystick.set_script(JOYSTICK_SCRIPT)
	root.add_child(joystick)
	respawn_button = Button.new()
	respawn_button.name = "Respawn"
	respawn_button.text = "回到起点"
	respawn_button.focus_mode = Control.FOCUS_NONE
	respawn_button.pressed.connect(_respawn)
	var style: StyleBoxFlat = $Root/TopRight/Reset.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	respawn_button.add_theme_stylebox_override("normal", style)
	respawn_button.add_theme_color_override("font_color", Color("3a5948"))
	root.add_child(respawn_button)
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios")
	if OS.has_feature("web"):
		touch_mode = touch_mode or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0", true))
	get_viewport().size_changed.connect(_layout_controls)
	_layout_controls.call_deferred()


func _layout_controls() -> void:
	var pixels := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("web"):
		# Web 的 window_get_size 是渲染像素；触控尺寸要按 CSS 像素计算。
		var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		pixels = Vector2(float(browser_window.innerWidth), float(browser_window.innerHeight))
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var unit: float = minf(logical.x / maxf(pixels.x, 1.0), logical.y / maxf(pixels.y, 1.0))
	var mobile: bool = touch_mode or pixels.x < 760.0 or pixels.y < 520.0
	var stick_size: float = (170.0 if mobile else 188.0) * unit
	joystick.size = Vector2.ONE * stick_size
	joystick.position = Vector2(20.0 * unit, logical.y - stick_size - 24.0 * unit)
	joystick.radius = (66.0 if mobile else 74.0) * unit
	joystick.queue_redraw()
	var title: Label = $Root/MapTitle
	title.text = "草莓散步" if mobile else "草莓散步  /  STRAWBERRY WALK"
	title.position = Vector2(20.0, 18.0) * unit
	title.add_theme_font_size_override("font_size", roundi((19.0 if mobile else 17.0) * unit))
	var top: HBoxContainer = $Root/TopRight
	zoom_label.visible = not mobile
	zoom_label.custom_minimum_size = Vector2(46.0, 0.0) * unit
	zoom_label.add_theme_font_size_override("font_size", roundi(14.0 * unit))
	top.add_theme_constant_override("separation", roundi(14.0 * unit))
	$Root/TopRight/Reset.custom_minimum_size = Vector2(116.0, 42.0) * unit
	$Root/TopRight/Reset.add_theme_font_size_override("font_size", roundi(14.0 * unit))
	respawn_button.add_theme_font_size_override("font_size", roundi(15.0 * unit))
	var panel: PanelContainer = $Root/CameraHints
	var hints: Label = $Root/CameraHints/Hints
	hints.text = "拖动左下角摇杆 · 松手停下" if mobile else "WASD / 方向键 走动   ·   摇杆也可拖动   ·   滚轮缩放   ·   Q / E 转镜头"
	hints.add_theme_font_size_override("font_size", roundi(12.0 * unit))
	# 先更新字体和最小尺寸，再调整容器，横竖屏切换不会保留旧的高度。
	top.size = Vector2(116.0 if mobile else 200.0, 42.0) * unit
	top.position = Vector2(logical.x - (136.0 if mobile else 220.0) * unit, 16.0 * unit)
	respawn_button.size = Vector2(116.0, 44.0) * unit
	respawn_button.position = Vector2(logical.x - 136.0 * unit, logical.y - 68.0 * unit)
	panel.size = Vector2((210.0 if mobile else 578.0) * unit, 36.0 * unit)
	panel.position = Vector2(20.0 * unit, logical.y - (stick_size + 78.0 * unit))


func _process(_delta: float) -> void:
	var camera: Camera3D = camera_rig.get_node("Camera3D")
	zoom_label.text = "%d%%" % roundi(camera_rig.initial_size / camera.size * 100.0)


func _respawn() -> void:
	var player: CharacterBody3D = get_parent().get_node("StrawberryPlayer")
	player.reset_player()
	camera_rig.reset_view()

