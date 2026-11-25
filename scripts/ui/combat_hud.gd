extends CanvasLayer
class_name CombatHud

signal radius_changed(value: float)
signal mode_changed
signal restart_requested

const PANEL_NAMES := ["Character", "Skills", "Inventory", "Loot", "Tactics", "Stats"]

var root_control: Control
var status_bar: PanelContainer
var status_rows: GridContainer
var status_label: Label
var restart_button: Button
var bottom_stack: VBoxContainer
var panel_host: Control
var nav_bar: PanelContainer
var nav_grid: GridContainer
var panels: Dictionary = {}
var nav_buttons: Dictionary = {}
var active_panel := ""
var character_label: Label
var stats_label: Label
var radius_label: Label
var radius_slider: HSlider
var mode_button: Button


func _ready() -> void:
	layer = 10
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	status_bar = PanelContainer.new()
	status_bar.anchor_right = 1.0
	status_bar.offset_left = 8.0
	status_bar.offset_top = 8.0
	status_bar.offset_right = -8.0
	root_control.add_child(status_bar)
	status_rows = GridContainer.new()
	status_rows.columns = 2
	status_bar.add_child(status_rows)
	status_label = _make_label("HP --  Enemies --  Defeated --")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_rows.add_child(status_label)
	restart_button = Button.new()
	restart_button.text = "Run ended - Restart (R)"
	restart_button.visible = false
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	status_rows.add_child(restart_button)

	bottom_stack = VBoxContainer.new()
	bottom_stack.anchor_left = 0.0
	bottom_stack.anchor_right = 1.0
	bottom_stack.anchor_top = 1.0
	bottom_stack.anchor_bottom = 1.0
	bottom_stack.offset_left = 8.0
	bottom_stack.offset_right = -8.0
	bottom_stack.offset_bottom = -8.0
	bottom_stack.add_theme_constant_override("separation", 4)
	bottom_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bottom_stack)

	panel_host = Control.new()
	panel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_host.visible = false
	bottom_stack.add_child(panel_host)
	_build_panels()

	nav_bar = PanelContainer.new()
	bottom_stack.add_child(nav_bar)
	nav_grid = GridContainer.new()
	nav_grid.columns = 6
	nav_grid.add_theme_constant_override("h_separation", 4)
	nav_grid.add_theme_constant_override("v_separation", 4)
	nav_bar.add_child(nav_grid)
	for panel_name in PANEL_NAMES:
		var button := Button.new()
		button.text = panel_name
		button.custom_minimum_size.y = 36.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(select_panel.bind(panel_name))
		nav_grid.add_child(button)
		nav_buttons[panel_name] = button

	root_control.resized.connect(_update_layout)
	_update_layout()


func _build_panels() -> void:
	for panel_name in PANEL_NAMES:
		var panel := CombatPanel.new()
		panel.name = panel_name
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel_host.add_child(panel)
		panel.visible = false
		panels[panel_name] = panel

	character_label = _make_label("")
	(panels["Character"] as CombatPanel).body.add_child(character_label)
	_add_placeholder("Skills", "No skills available yet.")
	_add_placeholder("Inventory", "Inventory is not available yet.")
	_add_placeholder("Loot", "No loot available yet.")

	var tactics := (panels["Tactics"] as CombatPanel).body
	radius_label = _make_label("")
	tactics.add_child(radius_label)
	radius_slider = HSlider.new()
	radius_slider.min_value = 0.0
	radius_slider.max_value = 100.0
	radius_slider.step = 1.0
	radius_slider.custom_minimum_size = Vector2(120, 28)
	radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_slider.value_changed.connect(func(value: float) -> void: radius_changed.emit(value))
	tactics.add_child(radius_slider)
	mode_button = Button.new()
	mode_button.pressed.connect(func() -> void: mode_changed.emit())
	tactics.add_child(mode_button)

	stats_label = _make_label("")
	(panels["Stats"] as CombatPanel).body.add_child(stats_label)


func _add_placeholder(panel_name: String, message: String) -> void:
	(panels[panel_name] as CombatPanel).body.add_child(_make_label(message))


func _make_label(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func select_panel(panel_name: String) -> void:
	if not panels.has(panel_name):
		return
	active_panel = "" if active_panel == panel_name else panel_name
	panel_host.visible = active_panel != ""
	for name_key in PANEL_NAMES:
		var selected: bool = name_key == active_panel
		(panels[name_key] as CombatPanel).visible = selected
		(nav_buttons[name_key] as Button).set_pressed_no_signal(selected)
	_update_layout()


func _update_layout() -> void:
	if root_control == null or nav_grid == null:
		return
	var viewport_size := root_control.size
	nav_grid.columns = 6 if viewport_size.x >= 900.0 else (3 if viewport_size.x >= 450.0 else 2)
	var rows := ceili(float(PANEL_NAMES.size()) / float(nav_grid.columns))
	var nav_height := float(rows * 40 + 4)
	nav_bar.custom_minimum_size.y = nav_height
	status_rows.columns = 1 if viewport_size.x < 520.0 else 2
	var status_height := 76.0 if status_rows.columns == 1 and restart_button.visible else 44.0
	status_bar.offset_bottom = 8.0 + status_height
	var available_panel_height := maxf(0.0, viewport_size.y - status_height - nav_height - 24.0)
	var panel_height := minf(viewport_size.y * 0.30, available_panel_height)
	panel_host.custom_minimum_size.y = panel_height
	bottom_stack.offset_top = -8.0 - nav_height - (panel_height + 4.0 if panel_host.visible else 0.0)


func update_state(hero: HeroCombatant, enemy_count: int, kills: int, ended: bool) -> void:
	if hero == null:
		return
	status_label.text = "HP %.0f/%.0f  Enemies %d  Defeated %d" % [
		hero.current_health, hero.stats.max_health, enemy_count, kills
	]
	character_label.text = "Hero health: %.0f / %.0f\nArmor: %.0f" % [
		hero.current_health, hero.stats.max_health, hero.stats.armor
	]
	stats_label.text = "Damage: %.0f\nArmor: %.0f\nAttack range: %.0f\nAttack rate: %.1f/s\nMovement speed: %.0f" % [
		hero.stats.damage, hero.stats.armor, hero.active_attack_range(),
		hero.stats.attacks_per_second, hero.stats.movement_speed
	]
	radius_label.text = "Preferred formation radius: %.0f%%" % hero.build.preferred_radius_percent
	radius_slider.set_value_no_signal(hero.build.preferred_radius_percent)
	mode_button.text = "Attack mode: Melee" if hero.build.attack_mode == HeroBuildConfig.AttackMode.MELEE else "Attack mode: Projectile"
	if restart_button.visible != ended:
		restart_button.visible = ended
		_update_layout()
