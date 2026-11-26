extends CanvasLayer
class_name CombatHud

signal radius_changed(value: float)
signal mode_changed
signal restart_requested
signal hero_selected(index: int)
signal sandbox_command(action: String, data: Dictionary)
signal panel_changed
signal diagnostics_toggled

const PANEL_NAMES := ["Character", "Skills", "Inventory", "Loot", "Tactics", "Stats", "Sandbox"]

var visible_panel_names: Array[String] = []
var root_control: Control
var status_bar: PanelContainer
var status_rows: GridContainer
var status_label: Label
var restart_button: Button
var diagnostics_button: Button
var diagnostics_panel: PanelContainer
var diagnostics_label: Label
var bottom_stack: VBoxContainer
var panel_host: Control
var card_bar: PanelContainer
var card_scroll: ScrollContainer
var hero_selector: HBoxContainer
var nav_bar: PanelContainer
var nav_scroll: ScrollContainer
var nav_grid: GridContainer
var panels: Dictionary = {}
var nav_buttons: Dictionary = {}
var active_panel := ""
var hero_buttons: Array[HeroCard] = []
var current_heroes: Array[HeroCombatant] = []
var character_label: Label
var stats_label: Label
var radius_label: Label
var radius_slider: HSlider
var mode_button: Button
var sandbox: CombatSandbox


func _ready() -> void:
	layer = 10
	for panel_name in PANEL_NAMES:
		if panel_name != "Sandbox" or OS.is_debug_build() or OS.has_feature("editor"):
			visible_panel_names.append(panel_name)
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	_build_status()
	_build_bottom()
	_build_diagnostics()
	root_control.resized.connect(_update_layout)
	_update_layout()


func _bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#141d2a")
	style.border_color = Color("#33455b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _build_status() -> void:
	status_bar = PanelContainer.new()
	status_bar.anchor_right = 1.0
	status_bar.offset_left = 8.0
	status_bar.offset_top = 8.0
	status_bar.offset_right = -8.0
	status_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	status_bar.add_theme_stylebox_override("panel", _bar_style())
	root_control.add_child(status_bar)
	status_rows = GridContainer.new()
	status_rows.columns = 3
	status_rows.add_theme_constant_override("h_separation", 8)
	status_bar.add_child(status_rows)
	status_label = _make_label("Party --  Enemies --")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_rows.add_child(status_label)
	diagnostics_button = Button.new()
	diagnostics_button.text = "Debug"
	diagnostics_button.toggle_mode = true
	diagnostics_button.visible = OS.is_debug_build() or OS.has_feature("editor")
	diagnostics_button.toggled.connect(func(_enabled: bool) -> void:
		diagnostics_panel.visible = diagnostics_button.button_pressed
		diagnostics_toggled.emit()
	)
	status_rows.add_child(diagnostics_button)
	restart_button = Button.new()
	restart_button.text = "Restart (R)"
	restart_button.visible = false
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	status_rows.add_child(restart_button)


func _build_bottom() -> void:
	bottom_stack = VBoxContainer.new()
	bottom_stack.anchor_left = 0.0
	bottom_stack.anchor_right = 1.0
	bottom_stack.anchor_top = 1.0
	bottom_stack.anchor_bottom = 1.0
	bottom_stack.offset_left = 8.0
	bottom_stack.offset_right = -8.0
	bottom_stack.offset_bottom = -8.0
	bottom_stack.add_theme_constant_override("separation", 4)
	bottom_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(bottom_stack)

	panel_host = Control.new()
	panel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_host.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_host.visible = false
	bottom_stack.add_child(panel_host)
	_build_panels()

	card_bar = PanelContainer.new()
	card_bar.add_theme_stylebox_override("panel", _bar_style())
	card_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_stack.add_child(card_bar)
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_bar.add_child(card_scroll)
	hero_selector = HBoxContainer.new()
	hero_selector.add_theme_constant_override("separation", 6)
	card_scroll.add_child(hero_selector)

	nav_bar = PanelContainer.new()
	nav_bar.add_theme_stylebox_override("panel", _bar_style())
	nav_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_stack.add_child(nav_bar)
	nav_scroll = ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_bar.add_child(nav_scroll)
	nav_grid = GridContainer.new()
	nav_grid.columns = visible_panel_names.size()
	nav_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_grid.add_theme_constant_override("h_separation", 4)
	nav_scroll.add_child(nav_grid)
	for panel_name in visible_panel_names:
		var button := Button.new()
		button.text = panel_name
		button.custom_minimum_size = Vector2(105, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(select_panel.bind(panel_name))
		nav_grid.add_child(button)
		nav_buttons[panel_name] = button


func _build_panels() -> void:
	for panel_name in PANEL_NAMES:
		var panel := CombatPanel.new()
		panel.name = panel_name
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel_host.add_child(panel)
		panel.visible = false
		panels[panel_name] = panel

	character_label = _make_label("Select a hero card or click a hero in the arena.")
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
	radius_slider.custom_minimum_size = Vector2(120, 30)
	radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_slider.value_changed.connect(func(value: float) -> void: radius_changed.emit(value))
	tactics.add_child(radius_slider)
	mode_button = Button.new()
	mode_button.custom_minimum_size.y = 34
	mode_button.pressed.connect(func() -> void: mode_changed.emit())
	tactics.add_child(mode_button)
	stats_label = _make_label("")
	(panels["Stats"] as CombatPanel).body.add_child(stats_label)
	sandbox = CombatSandbox.new()
	sandbox.command_requested.connect(func(action: String, data: Dictionary) -> void: sandbox_command.emit(action, data))
	(panels["Sandbox"] as CombatPanel).body.add_child(sandbox)


func _build_diagnostics() -> void:
	diagnostics_panel = PanelContainer.new()
	diagnostics_panel.anchor_left = 1.0
	diagnostics_panel.anchor_right = 1.0
	diagnostics_panel.visible = false
	diagnostics_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostics_panel.add_theme_stylebox_override("panel", _bar_style())
	root_control.add_child(diagnostics_panel)
	diagnostics_label = _make_label("")
	diagnostics_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostics_panel.add_child(diagnostics_label)


func _add_placeholder(panel_name: String, message: String) -> void:
	(panels[panel_name] as CombatPanel).body.add_child(_make_label(message))


func _make_label(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#d9e2e8"))
	return label


func _on_card_pressed(card: HeroCard) -> void:
	if is_instance_valid(card.hero):
		var index := current_heroes.find(card.hero)
		if index >= 0:
			hero_selected.emit(index)


func _sync_cards(heroes: Array[HeroCombatant]) -> void:
	var roster_unchanged := hero_buttons.size() == heroes.size()
	if roster_unchanged:
		for index in range(heroes.size()):
			if hero_buttons[index].hero != heroes[index]:
				roster_unchanged = false
				break
	if roster_unchanged:
		return
	for card in hero_buttons.duplicate():
		if not is_instance_valid(card.hero) or not heroes.has(card.hero):
			hero_buttons.erase(card)
			hero_selector.remove_child(card)
			card.queue_free()
	for index in range(heroes.size()):
		var hero := heroes[index]
		var card: HeroCard = null
		for candidate in hero_buttons:
			if candidate.hero == hero:
				card = candidate
				break
		if card == null:
			card = HeroCard.new()
			card.hero = hero
			card.pressed.connect(_on_card_pressed.bind(card))
			hero_selector.add_child(card)
			hero_buttons.append(card)
		if card.get_index() != index:
			hero_selector.move_child(card, index)
	hero_buttons.clear()
	for child in hero_selector.get_children():
		hero_buttons.append(child as HeroCard)


func select_panel(panel_name: String) -> void:
	if not nav_buttons.has(panel_name):
		return
	active_panel = "" if active_panel == panel_name else panel_name
	panel_host.visible = active_panel != ""
	for name_key in visible_panel_names:
		var selected: bool = name_key == active_panel
		(panels[name_key] as CombatPanel).visible = selected
		(nav_buttons[name_key] as Button).set_pressed_no_signal(selected)
	_update_layout()
	panel_changed.emit()


func _update_layout() -> void:
	if root_control == null or nav_grid == null:
		return
	var viewport_size := root_control.size
	status_rows.columns = 2 if viewport_size.x < 520.0 else 3
	var status_height := 72.0 if status_rows.columns == 2 and restart_button.visible else 40.0
	status_bar.offset_bottom = 8.0 + status_height
	card_bar.custom_minimum_size.y = 82.0
	nav_bar.custom_minimum_size.y = 46.0
	var available := maxf(0.0, viewport_size.y - status_height - 82.0 - 46.0 - 24.0)
	var panel_ratio := 0.45 if active_panel == "Sandbox" else 0.30
	var panel_height := minf(viewport_size.y * panel_ratio, available)
	panel_host.custom_minimum_size.y = panel_height
	bottom_stack.offset_top = -8.0 - 82.0 - 46.0 - (panel_height + 4.0 if panel_host.visible else 0.0)
	diagnostics_panel.offset_left = -minf(380.0, viewport_size.x - 16.0)
	diagnostics_panel.offset_right = -8.0
	diagnostics_panel.offset_top = status_bar.offset_bottom + 4.0
	diagnostics_panel.offset_bottom = diagnostics_panel.offset_top + minf(160.0, viewport_size.y * 0.35)


func update_state(heroes: Array[HeroCombatant], selected_index: int, enemy_count: int, kills: int, ended: bool) -> void:
	current_heroes = heroes
	_sync_cards(heroes)
	var living := 0
	for index in range(heroes.size()):
		var member := heroes[index]
		if member.is_alive:
			living += 1
		hero_buttons[index].update_state(member, index, index == selected_index)
	status_label.text = "P %d/%d   E %d   K %d" % [living, heroes.size(), enemy_count, kills]
	if heroes.is_empty() or selected_index >= heroes.size():
		character_label.text = "No hero selected"
		stats_label.text = ""
		radius_label.text = ""
		mode_button.disabled = true
	else:
		var hero := heroes[selected_index]
		character_label.text = "%s   HP %.0f / %.0f   Armor %.1f%s" % [hero.display_name, hero.current_health, hero.stats.max_health, hero.stats.armor, "   Defeated" if not hero.is_alive else ""]
		stats_label.text = "Basic damage %.1f   Skill damage %.1f\nArmor %.1f   Damage multiplier %.2f\nAttack range %.1f   Effective rate %.2f/s\nMovement %.1f   Threat %.2f" % [hero.stats.damage, hero.build.class_definition.skill_damage, hero.stats.armor, hero.build.class_definition.damage_multiplier, hero.active_attack_range(), hero.effective_attack_speed(), hero.stats.movement_speed, hero.build.threat_multiplier]
		radius_label.text = "%s preferred radius: %.0f%%" % [hero.display_name, hero.build.preferred_radius_percent]
		radius_slider.set_value_no_signal(hero.build.preferred_radius_percent)
		mode_button.disabled = false
		mode_button.text = "Attack mode: Melee" if hero.build.attack_mode == HeroBuildConfig.AttackMode.MELEE else "Attack mode: Projectile"
	if restart_button.visible != ended:
		restart_button.visible = ended
		_update_layout()


func update_sandbox(arena: CombatArena) -> void:
	if active_panel == "Sandbox" and is_instance_valid(sandbox):
		sandbox.update_state(arena)


func update_diagnostics(arena: CombatArena) -> void:
	if not diagnostics_panel.visible:
		return
	var projectiles := 0
	for child in arena.get_children():
		if child is PhysicalProjectile:
			projectiles += 1
	var details := "FPS %d   Heroes %d   Enemies %d   Projectiles %d" % [Engine.get_frames_per_second(), arena.heroes.size(), arena.enemies.size(), projectiles]
	if not arena.heroes.is_empty():
		var hero := arena.heroes[arena.selected_hero_index]
		var target_name := "None"
		if is_instance_valid(hero.current_target) and hero.current_target.is_alive:
			target_name = "Ranged enemy" if hero.current_target is EnemyCombatant and hero.current_target.ranged else "Melee enemy"
		var passive := hero.passive_state
		details += "\n%s target: %s\nAttack %s   cooldown %.2fs   reason: %s" % [hero.display_name, target_name, "ready" if hero.attack_timer <= 0.0 else "waiting", hero.attack_timer, hero.attack_block_reason]
		details += "\nBasic %d  Skill %d  Active %.1fs  CD %.1fs  Heal %.1fs  Incursion %.1fs  Stealth %.1fs" % [passive.basic_count, passive.skill_count, passive.active_seconds, passive.cooldown_seconds, passive.heal_seconds, passive.incursion_seconds, passive.stealth_seconds]
		details += "\nDamage %.1f  Skill %.1f  Rate %.2f/s  Range %.1f  Move %.1f  Armor %.1f" % [hero.stats.damage * hero.build.class_definition.damage_multiplier, hero.build.class_definition.skill_damage, hero.effective_attack_speed(), hero.active_attack_range(), hero.stats.movement_speed, hero.stats.armor]
	diagnostics_label.text = details
