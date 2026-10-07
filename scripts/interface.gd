extends CanvasLayer

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
const UI_FONT = preload("res://assets/fonts/noto_sans_sc_ui.ttf")
const MELEE_BUTTON_SCRIPT = preload("res://scripts/melee_button.gd")
const JUMP_BUTTON_SCRIPT = preload("res://scripts/jump_button.gd")
const THROW_BUTTON_SCRIPT = preload("res://scripts/throw_button.gd")
const SCORE_TRACK_SCRIPT = preload("res://scripts/score_track.gd")
const MATCH_SCRIPT = preload("res://scripts/match_controller.gd")

const INK := Color("21483b")
const PAPER := Color("eaf4de")
const SUN := Color("f7c866")

@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")
@onready var zoom_label: Label = $Root/TopRight/Zoom
@onready var root: Control = $Root

var joystick: Control
var respawn_button: Button
var roles_label: Label
var touch_mode: bool = false
var melee_button: Control
var jump_button: Control
var throw_button: Control
var match_controller: Node
var overlay: Control
var lobby_panel: PanelContainer
var score_panel: PanelContainer
var bot_count_label: Label
var minus_button: Button
var plus_button: Button
var difficulty_choice: OptionButton
var scoring_choice: OptionButton
var rules_label: Label
var settings_grid: GridContainer
var role_selectors: Array[OptionButton] = []
var seat_rows: Array[PanelContainer] = []
var seat_badges: Array[Label] = []
var start_button: Button
var next_button: Button
var lobby_button: Button
var score_title: Label
var score_result: Label
var score_caption: Label
var score_list: GridContainer
var seat_grid: GridContainer
var participants_scroll: ScrollContainer
var scores_scroll: ScrollContainer
var menu_styles: Array[StyleBoxFlat] = []
var score_styles: Array[StyleBoxFlat] = []


func _ready() -> void:
	root.theme = root.theme.duplicate() as Theme
	root.theme.default_font = UI_FONT
	$Root/MapTitle.text = "水果乱斗  /  BOOMERANG ARENA"
	roles_label = Label.new()
	roles_label.name = "CharacterRoles"
	roles_label.text = "你控制草莓 · 跳斩命中即淘汰"
	roles_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roles_label.add_theme_color_override("font_color", Color("3a5948"))
	root.add_child(roles_label)
	joystick = Control.new()
	joystick.name = "VirtualJoystick"
	joystick.set_script(JOYSTICK_SCRIPT)
	root.add_child(joystick)
	respawn_button = Button.new()
	respawn_button.name = "Respawn"
	respawn_button.text = "重新开始"
	respawn_button.focus_mode = Control.FOCUS_NONE
	respawn_button.pressed.connect(_respawn)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 1.0, 0.88, 0.84)
	style.set_corner_radius_all(8)
	respawn_button.add_theme_stylebox_override("normal", style)
	respawn_button.add_theme_color_override("font_color", Color("3a5948"))
	root.add_child(respawn_button)
	melee_button = Control.new()
	melee_button.name = "MeleeButton"
	melee_button.set_script(MELEE_BUTTON_SCRIPT)
	melee_button.player = get_parent().get_node("StrawberryPlayer")
	melee_button.attack_pressed.connect(_attack)
	root.add_child(melee_button)
	jump_button = Control.new()
	jump_button.name = "JumpButton"
	jump_button.set_script(JUMP_BUTTON_SCRIPT)
	jump_button.player = melee_button.player
	jump_button.jump_pressed.connect(_jump)
	root.add_child(jump_button)
	throw_button = Control.new()
	throw_button.name = "ThrowButton"
	throw_button.set_script(THROW_BUTTON_SCRIPT)
	throw_button.player = melee_button.player
	root.add_child(throw_button)
	_build_menus()
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
	title.text = "水果乱斗" if mobile else "水果乱斗  /  BOOMERANG ARENA"
	title.position = Vector2(20.0, 18.0) * unit
	title.add_theme_font_size_override("font_size", roundi((19.0 if mobile else 17.0) * unit))
	roles_label.position = Vector2(20.0, 68.0 if pixels.x < 360.0 else 51.0) * unit
	roles_label.add_theme_font_size_override("font_size", roundi((11.0 if mobile else 13.0) * unit))
	var top: HBoxContainer = $Root/TopRight
	zoom_label.visible = not mobile
	zoom_label.custom_minimum_size = Vector2(46.0, 0.0) * unit
	zoom_label.add_theme_font_size_override("font_size", roundi(14.0 * unit))
	top.add_theme_constant_override("separation", roundi(14.0 * unit))
	respawn_button.add_theme_font_size_override("font_size", roundi(15.0 * unit))
	# 先更新字体和最小尺寸，再调整容器，横竖屏切换不会保留旧的高度。
	top.size = Vector2(46.0, 42.0) * unit
	top.position = Vector2(logical.x - 198.0 * unit, 16.0 * unit)
	respawn_button.size = Vector2(116.0, 44.0) * unit
	respawn_button.position = Vector2(logical.x - 136.0 * unit, 16.0 * unit)
	var attack_size: float = (100.0 if mobile else 106.0) * unit
	if pixels.x < 560.0:
		attack_size = minf(attack_size, maxf(64.0, (pixels.y - 126.0) / 3.0 - 14.0) * unit)
	melee_button.size = Vector2.ONE * attack_size
	melee_button.position = Vector2(logical.x - attack_size - 26.0 * unit, logical.y - attack_size - 24.0 * unit)
	jump_button.size = Vector2.ONE * attack_size
	# 窄屏上下排列，避免跳跃图标与左下角摇杆的触控区域重叠。
	jump_button.position = melee_button.position - (Vector2(0.0, attack_size + 14.0 * unit) if pixels.x < 560.0 else Vector2(attack_size + 14.0 * unit, 0.0))
	throw_button.size = Vector2.ONE * attack_size
	if pixels.x < 560.0:
		throw_button.position = jump_button.position - Vector2(0.0, attack_size + 14.0 * unit)
	elif pixels.x < 760.0:
		throw_button.position = melee_button.position - Vector2(0.0, attack_size + 14.0 * unit)
	else:
		throw_button.position = jump_button.position - Vector2(attack_size + 14.0 * unit, 0.0)
	_layout_menus(pixels, logical, unit)


func _process(_delta: float) -> void:
	var camera: Camera3D = camera_rig.get_node("Camera3D")
	zoom_label.text = "%d%%" % roundi(camera_rig.view_size(camera_rig.initial_size) / camera.size * 100.0)
	if not is_instance_valid(match_controller) or match_controller.phase == "practice":
		roles_label.text = "你控制草莓 · 跳斩命中即淘汰" if melee_button.player.alive else "草莓已被切开 · 点重新开始再来"
	elif match_controller.phase == "playing":
		var living: int = 0
		for actor in get_parent().combat.actors:
			living += int(actor.alive)
		var role: String = MATCH_SCRIPT.ROLE_NAMES[match_controller.role_choices[0]]
		roles_label.text = "第 %d 小局 · 你是%s · 存活 %d / %d" % [match_controller.round_number, role, living, match_controller.scores.size()]
		if match_controller.scoring_mode == MATCH_SCRIPT.ScoringMode.KILLS:
			roles_label.text = "第 %d 小局 · 击杀计分 · 你 %d / 10 分" % [match_controller.round_number, match_controller.scores[0]]
		if not melee_button.player.alive:
			roles_label.text = "第 %d 小局 · 你已淘汰 · 等待人机决出胜者" % match_controller.round_number
			if match_controller.scoring_mode == MATCH_SCRIPT.ScoringMode.KILLS:
				roles_label.text = "第 %d 小局 · 你已淘汰 · 击杀得分 %d / 10" % [match_controller.round_number, match_controller.scores[0]]
		elif living == 1:
			var countdown: String = "小局即将结束" if match_controller.scoring_mode == MATCH_SCRIPT.ScoringMode.KILLS else "保持存活"
			roles_label.text = "%s · %.1f 秒" % [countdown, maxf(0.0, MATCH_SCRIPT.SURVIVOR_HOLD - match_controller.survivor_time)]
	if melee_button.player.alive:
		if melee_button.player.attack_state == "aim":
			roles_label.text += " · 瞄准中"
		elif not melee_button.player.has_boomerang:
			roles_label.text += " · 空手：拾回镖"


func _respawn() -> void:
	if is_instance_valid(match_controller) and match_controller.phase != "practice":
		match_controller.return_to_lobby()
	else:
		get_parent().combat.reset_round()
		camera_rig.reset_view()


func _attack() -> void:
	var player: CharacterBody3D = melee_button.player
	if player.has_focus:
		player.request_attack()


func _jump() -> void:
	jump_button.player.request_jump()


func bind_player(actor: CharacterBody3D) -> void:
	melee_button.player = actor
	jump_button.player = actor
	throw_button.player = actor


func release_actions() -> void:
	joystick.release()
	melee_button.touch_id = -1
	melee_button.mouse_held = false
	jump_button.touch_id = -1
	jump_button.mouse_held = false
	throw_button.cancel()


func bind_match(controller: Node) -> void:
	match_controller = controller
	match_controller.phase_changed.connect(_refresh_phase)
	_refresh_lobby()
	_refresh_phase()


func _build_menus() -> void:
	overlay = Control.new()
	overlay.name = "MatchOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.17, 0.14, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	lobby_panel = _menu_panel("LobbyPanel")
	var content: VBoxContainer = _panel_content(lobby_panel)
	content.add_child(_label("水果乱斗", 30))
	var introduction := _label("选好角色，进入岩石庭院。", 13)
	introduction.set_meta("compact_hide", true)
	content.add_child(introduction)
	var settings := GridContainer.new()
	settings_grid = settings
	settings.columns = 3
	content.add_child(settings)
	var count_column := VBoxContainer.new()
	count_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(count_column)
	count_column.add_child(_label("人机数量", 13))
	var count_row := HBoxContainer.new()
	count_column.add_child(count_row)
	minus_button = _button("−", _change_count.bind(-1))
	minus_button.set_meta("css_width", 42.0)
	count_row.add_child(minus_button)
	bot_count_label = _label("3", 22)
	bot_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(bot_count_label)
	plus_button = _button("+", _change_count.bind(1))
	plus_button.set_meta("css_width", 42.0)
	count_row.add_child(plus_button)
	var level_column := VBoxContainer.new()
	level_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(level_column)
	level_column.add_child(_label("人机难度", 13))
	difficulty_choice = _choice()
	for text in ["简单", "普通", "困难"]:
		difficulty_choice.add_item(text)
	difficulty_choice.item_selected.connect(_change_difficulty)
	level_column.add_child(difficulty_choice)
	var scoring_column := VBoxContainer.new()
	scoring_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(scoring_column)
	scoring_column.add_child(_label("计分方式", 13))
	scoring_choice = _choice()
	scoring_choice.name = "ScoringMode"
	for text in MATCH_SCRIPT.SCORING_NAMES:
		scoring_choice.add_item(text)
	scoring_choice.item_selected.connect(_change_scoring)
	scoring_column.add_child(scoring_choice)
	content.add_child(_label("参赛角色 · 可以选择相同角色", 13))
	var scroll := ScrollContainer.new()
	participants_scroll = scroll
	scroll.name = "ParticipantsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var seats := GridContainer.new()
	seat_grid = seats
	seats.columns = 1
	seats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(seats)
	for index in range(MATCH_SCRIPT.MAX_BOTS + 1):
		var row := PanelContainer.new()
		row.name = "Seat%d" % index
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.set_meta("css_height", 52.0)
		row.set_meta("css_compact_height", 48.0)
		row.add_theme_stylebox_override("panel", _style(Color("f7fbf1"), 10, 10))
		seats.add_child(row)
		seat_rows.append(row)
		var line := HBoxContainer.new()
		row.add_child(line)
		var badge := _label("莓", 21)
		badge.set_meta("css_width", 27.0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(badge)
		seat_badges.append(badge)
		var name_label := _label("你" if index == 0 else "人机 %d" % index, 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var selector := _choice()
		selector.set_meta("css_width", 132.0)
		for role_name in MATCH_SCRIPT.ROLE_NAMES:
			selector.add_item(role_name)
		selector.item_selected.connect(_change_role.bind(index))
		line.add_child(selector)
		role_selectors.append(selector)
	rules_label = _label("", 12)
	rules_label.set_meta("compact_hide", true)
	content.add_child(rules_label)
	start_button = _button("开始游戏", _start_match, true)
	start_button.name = "StartMatch"
	start_button.set_meta("css_height", 48.0)
	start_button.set_meta("css_compact_height", 42.0)
	content.add_child(start_button)
	score_panel = _menu_panel("ScorePanel")
	var score_content: VBoxContainer = _panel_content(score_panel)
	score_title = _label("小局结束", 28)
	score_content.add_child(score_title)
	score_result = _label("最后存活者 +1 分", 14)
	score_content.add_child(score_result)
	var score_scroll := ScrollContainer.new()
	scores_scroll = score_scroll
	score_scroll.name = "ScoresScroll"
	score_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	score_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	score_content.add_child(score_scroll)
	score_list = GridContainer.new()
	score_list.columns = 1
	score_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_scroll.add_child(score_list)
	score_caption = _label("当前累计分数 · 先到 10 分获胜", 12)
	score_content.add_child(score_caption)
	var actions := HBoxContainer.new()
	score_content.add_child(actions)
	lobby_button = _button("返回设置", _return_to_lobby)
	lobby_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(lobby_button)
	next_button = _button("下一小局", _next_round, true)
	next_button.name = "NextRound"
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(next_button)
	start_button.focus_mode = Control.FOCUS_ALL
	next_button.focus_mode = Control.FOCUS_ALL


func _menu_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _style(PAPER, 22, 0))
	overlay.add_child(panel)
	return panel


func _panel_content(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	return content


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("css_font", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", INK)
	return label


func _style(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.set_meta("css_radius", radius)
	style.set_meta("css_margin", margin)
	menu_styles.append(style)
	return style


func _decorate_button(button: Button, primary: bool = false) -> void:
	var color: Color = SUN if primary else Color("dbe8d0")
	button.add_theme_stylebox_override("normal", _style(color, 10, 10))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12), 10, 10))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.08), 10, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("e3ebdb"), 10, 10))
	var focus := _style(Color(0, 0, 0, 0), 10, 0)
	focus.border_color = INK
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", Color("9aa78f"))
	button.set_meta("css_font", 14)
	button.set_meta("css_height", 42.0)
	button.set_meta("css_compact_height", 36.0)


func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	_decorate_button(button, primary)
	if primary:
		button.set_meta("css_font", 16)
	button.pressed.connect(action)
	return button


func _choice() -> OptionButton:
	var choice := OptionButton.new()
	_decorate_button(choice)
	choice.get_popup().add_theme_color_override("font_color", INK)
	choice.get_popup().add_theme_color_override("font_hover_color", INK)
	choice.get_popup().add_theme_stylebox_override("panel", _style(PAPER, 10, 6))
	choice.get_popup().add_theme_stylebox_override("hover", _style(SUN, 5, 4))
	return choice


func _change_count(amount: int) -> void:
	if not is_instance_valid(match_controller):
		return
	match_controller.configure(match_controller.bot_count + amount, match_controller.difficulty, match_controller.role_choices)
	_refresh_lobby()


func _change_difficulty(index: int) -> void:
	match_controller.configure(match_controller.bot_count, index, match_controller.role_choices)


func _change_scoring(index: int) -> void:
	match_controller.configure(match_controller.bot_count, match_controller.difficulty, match_controller.role_choices, index)
	_refresh_lobby()


func _change_role(role: int, seat: int) -> void:
	var choices: Array[int] = match_controller.role_choices.duplicate()
	choices[seat] = role
	match_controller.configure(match_controller.bot_count, match_controller.difficulty, choices)
	_refresh_lobby()


func _refresh_lobby() -> void:
	bot_count_label.text = str(match_controller.bot_count)
	minus_button.disabled = match_controller.bot_count <= 1
	plus_button.disabled = match_controller.bot_count >= MATCH_SCRIPT.MAX_BOTS
	difficulty_choice.select(match_controller.difficulty)
	scoring_choice.select(match_controller.scoring_mode)
	rules_label.text = "每击杀一名对手 +1 分，存活不额外加分。" if match_controller.scoring_mode == MATCH_SCRIPT.ScoringMode.KILLS else "每局最后存活者 +1 分，全灭不加分。"
	rules_label.text += "\n先到 10 分获胜，计分页点击进入下一局。"
	rules_label.text += "\n按住 L / 投掷瞄准，松开飞出；空手时先拾回镖。"
	for index in range(role_selectors.size()):
		seat_rows[index].visible = index <= match_controller.bot_count
		var role: int = match_controller.role_choices[index]
		role_selectors[index].select(role)
		seat_badges[index].text = MATCH_SCRIPT.ROLE_BADGES[role]
		seat_badges[index].add_theme_color_override("font_color", MATCH_SCRIPT.ROLE_COLORS[role])
	_layout_controls.call_deferred()


func _start_match() -> void:
	match_controller.start_match()


func _next_round() -> void:
	if match_controller.phase == "match_over":
		match_controller.return_to_lobby()
	else:
		match_controller.next_round()


func _return_to_lobby() -> void:
	match_controller.return_to_lobby()


func _refresh_phase() -> void:
	# 即使玩家在战斗中按 H 隐藏过 HUD，结算和设置仍然必须能操作。
	show()
	var phase: String = match_controller.phase
	if OS.has_feature("web"):
		get_parent().web_canvas.setAttribute("data-match-phase", phase)
	var playing: bool = phase in ["playing", "practice"]
	for control in [$Root/MapTitle, $Root/TopRight, roles_label, joystick, melee_button, jump_button, throw_button, respawn_button]:
		control.visible = playing
	overlay.visible = not playing
	lobby_panel.visible = phase == "lobby"
	score_panel.visible = phase in ["scores", "match_over"]
	respawn_button.text = "重新开始" if phase == "practice" else "返回设置"
	if phase == "lobby":
		_refresh_lobby()
		camera_rig._end_drag()
		camera_rig.following = false
		camera_rig.desired_center = Vector3(0.0, 0.0, 0.7)
	elif score_panel.visible:
		_show_scores()
	_layout_controls.call_deferred()


func _show_scores() -> void:
	for style in score_styles:
		menu_styles.erase(style)
	score_styles.clear()
	for child in score_list.get_children():
		score_list.remove_child(child)
		child.queue_free()
	var winner: int = match_controller.round_winner
	var kill_scoring: bool = match_controller.scoring_mode == MATCH_SCRIPT.ScoringMode.KILLS
	score_title.text = "第 %d 小局结束" % match_controller.round_number
	score_result.text = "全员淘汰 · 本局不加分" if winner < 0 else "%s · %s存活，+1 分" % [match_controller.seat_name(winner), MATCH_SCRIPT.ROLE_NAMES[match_controller.role_choices[winner]]]
	if kill_scoring:
		score_result.text = "全员淘汰 · 已获击杀分保留" if winner < 0 else "击杀计分 · 存活者不额外加分"
	score_caption.text = "%s · 当前累计分数 · 先到 10 分获胜" % MATCH_SCRIPT.SCORING_NAMES[match_controller.scoring_mode]
	if match_controller.phase == "match_over":
		score_title.text = "%s · %s获胜" % [match_controller.seat_name(match_controller.champion), MATCH_SCRIPT.ROLE_NAMES[match_controller.role_choices[match_controller.champion]]]
		score_result.text = "%s · 率先得到 10 分" % MATCH_SCRIPT.SCORING_NAMES[match_controller.scoring_mode]
	next_button.text = "再玩一场" if match_controller.phase == "match_over" else "下一小局"
	for index in range(match_controller.scores.size()):
		var role: int = match_controller.role_choices[index]
		var color: Color = MATCH_SCRIPT.ROLE_COLORS[role]
		var gained: int = match_controller.round_points[index]
		var highlighted: bool = gained > 0 if kill_scoring else index == winner
		var row := PanelContainer.new()
		row.name = "ScoreSeat%d" % index
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.set_meta("css_height", 72.0)
		row.set_meta("css_compact_height", 58.0)
		var style: StyleBoxFlat = _style(Color("f7fbf1").lerp(color, 0.12 if highlighted else 0.035), 10, 10)
		score_styles.append(style)
		if highlighted:
			style.border_color = color
			style.set_border_width_all(2)
		row.add_theme_stylebox_override("panel", style)
		score_list.add_child(row)
		var column := VBoxContainer.new()
		column.set_meta("css_gap", 2.0)
		row.add_child(column)
		var line := HBoxContainer.new()
		column.add_child(line)
		var seat := _label("%s · %s" % [match_controller.seat_name(index), MATCH_SCRIPT.ROLE_NAMES[role]], 14)
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(seat)
		if gained > 0:
			var added := _label("+%d" % gained, 14)
			added.name = "RoundGain"
			added.add_theme_color_override("font_color", color)
			line.add_child(added)
		line.add_child(_label("%d / 10" % match_controller.scores[index], 20))
		var track := Control.new()
		track.set_script(SCORE_TRACK_SCRIPT)
		track.score = match_controller.scores[index]
		track.tint = color
		track.set_meta("css_height", 18.0)
		track.set_meta("css_compact_height", 12.0)
		column.add_child(track)


func _layout_menus(pixels: Vector2, logical: Vector2, unit: float) -> void:
	var compact: bool = pixels.y < 520.0
	settings_grid.columns = 2 if pixels.x < 560.0 else 3
	seat_grid.columns = 2 if compact and pixels.x > 640.0 else 1
	score_list.columns = seat_grid.columns
	root.theme.default_font_size = roundi(14.0 * unit)
	for style in menu_styles:
		style.set_corner_radius_all(roundi(float(style.get_meta("css_radius")) * unit))
		var margin: float = float(style.get_meta("css_margin")) * (0.6 if compact else 1.0) * unit
		style.content_margin_left = margin
		style.content_margin_right = margin
		style.content_margin_top = margin
		style.content_margin_bottom = margin
	_scale_menu(overlay, unit, compact)
	var width: float = minf(680.0, pixels.x - 28.0) * unit
	var lobby_height: float = minf(660.0, pixels.y - 28.0) * unit
	var score_height: float = minf(680.0, pixels.y - 28.0) * unit
	lobby_panel.size = Vector2(width, lobby_height)
	lobby_panel.position = (logical - lobby_panel.size) * 0.5
	score_panel.size = Vector2(width, score_height)
	score_panel.position = (logical - score_panel.size) * 0.5


func _scale_menu(node: Node, unit: float, compact: bool) -> void:
	if node is Control:
		if node.has_meta("compact_hide"):
			node.visible = not compact
		var height: float = float(node.get_meta("css_compact_height", node.get_meta("css_height", 0.0))) if compact else float(node.get_meta("css_height", 0.0))
		node.custom_minimum_size = Vector2(float(node.get_meta("css_width", 0.0)), height) * unit
		if node.has_meta("css_font"):
			var font_size: float = float(node.get_meta("css_font"))
			node.add_theme_font_size_override("font_size", roundi(minf(font_size, 24.0) * unit if compact else font_size * unit))
		if node is BoxContainer:
			node.add_theme_constant_override("separation", roundi(float(node.get_meta("css_gap", 6.0 if compact else 8.0)) * unit))
		if node is GridContainer:
			for separation in ["h_separation", "v_separation"]:
				node.add_theme_constant_override(separation, roundi((4.0 if compact else 8.0) * unit))
		if node is MarginContainer:
			for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
				node.add_theme_constant_override(side, roundi((12.0 if compact else 20.0) * unit))
		if node is OptionButton:
			node.get_popup().add_theme_font_size_override("font_size", roundi(14.0 * unit))
	for child in node.get_children():
		_scale_menu(child, unit, compact)


func verification_state() -> Dictionary:
	if not is_instance_valid(match_controller):
		return {}
	var pixels := Vector2(float(web_window_size().x), float(web_window_size().y))
	var ratio: Vector2 = pixels / get_viewport().get_visible_rect().size
	var selectors: Array = []
	for selector in role_selectors:
		selectors.append(_screen_rect(selector, ratio))
	var actors: Array = []
	for index in range(get_parent().combat.actors.size()):
		var actor: CharacterBody3D = get_parent().combat.actors[index]
		actors.append({"seat": index, "role": actor.get_meta("role", index), "alive": actor.alive, "position": [actor.position.x, actor.position.y, actor.position.z], "attack_state": actor.attack_state, "round_active": actor.round_active, "has_boomerang": actor.has_boomerang, "throw_id": actor.throw_id})
	return {"phase": match_controller.phase, "bot_count": match_controller.bot_count, "difficulty": match_controller.difficulty, "scoring_mode": match_controller.scoring_mode, "round_points": match_controller.round_points, "roles": match_controller.role_choices, "scores": match_controller.scores, "round": match_controller.round_number, "winner": match_controller.round_winner, "champion": match_controller.champion, "survivor_time": match_controller.survivor_time, "actors": actors,
		"controls": {"minus": _screen_rect(minus_button, ratio), "plus": _screen_rect(plus_button, ratio), "difficulty": _screen_rect(difficulty_choice, ratio), "scoring": _screen_rect(scoring_choice, ratio), "roles": selectors, "start": _screen_rect(start_button, ratio), "next": _screen_rect(next_button, ratio), "lobby": _screen_rect(lobby_button, ratio), "settings": _screen_rect(respawn_button, ratio), "joystick": _screen_rect(joystick, ratio), "attack": _screen_rect(melee_button, ratio), "jump": _screen_rect(jump_button, ratio), "panel": _screen_rect(lobby_panel if match_controller.phase == "lobby" else score_panel, ratio), "participants": _screen_rect(participants_scroll, ratio), "scores_scroll": _screen_rect(scores_scroll, ratio), "popup": _popup_state(ratio)}, "title": score_title.text, "result": score_result.text, "rules": rules_label.text}


func _popup_state(ratio: Vector2) -> Dictionary:
	var choices: Array[OptionButton] = [difficulty_choice, scoring_choice]
	choices.append_array(role_selectors)
	for choice in choices:
		var popup: PopupMenu = choice.get_popup()
		if not popup.visible:
			continue
		var style: StyleBoxFlat = popup.get_theme_stylebox("panel") as StyleBoxFlat
		var row_height: float = (popup.size.y - style.content_margin_top - style.content_margin_bottom) / popup.item_count
		var centers: Array = []
		for index in range(popup.item_count):
			var center: Vector2 = (Vector2(popup.position) + Vector2(popup.size.x * 0.5, style.content_margin_top + row_height * (index + 0.5))) * ratio
			centers.append([center.x, center.y])
		return {"visible": true, "focused": popup.get_focused_item(), "items": centers}
	return {"visible": false}


func web_window_size() -> Vector2:
	if OS.has_feature("web"):
		var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
		return Vector2(float(browser_window.innerWidth), float(browser_window.innerHeight))
	return Vector2(DisplayServer.window_get_size())


func _screen_rect(control: Control, ratio: Vector2) -> Array:
	var at: Vector2 = control.global_position * ratio
	var extent: Vector2 = control.size * ratio
	return [at.x, at.y, extent.x, extent.y]

