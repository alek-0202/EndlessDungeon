extends VBoxContainer
class_name CombatSandbox

signal command_requested(action: String, data: Dictionary)

const SECTIONS := ["Heroes", "Attributes", "Passives", "Enemies", "Simulation"]
const HERO_FIELDS := {
	"max_health": Vector3(1, 1000, 1), "current_health": Vector3(0, 1000, 1),
	"armor": Vector3(0, 100, 0.5), "damage": Vector3(0, 100, 0.5),
	"skill_damage": Vector3(0, 500, 0.5), "damage_multiplier": Vector3(0, 10, 0.1),
	"attacks_per_second": Vector3(0.1, 10, 0.1), "movement_speed": Vector3(0, 300, 1),
	"attack_range": Vector3(1, 300, 1), "preferred_radius_percent": Vector3(0, 100, 1),
	"threat_multiplier": Vector3(0, 10, 0.1)
}
const ENEMY_FIELDS := {
	"max_health": Vector3(1, 1000, 1), "damage": Vector3(0, 100, 0.5),
	"armor": Vector3(0, 100, 0.5), "movement_speed": Vector3(0, 300, 1),
	"attacks_per_second": Vector3(0.1, 10, 0.1), "attack_range": Vector3(1, 300, 1)
}
const PASSIVE_FIELDS := [
	["tank_heal_interval", 0.1, 120.0], ["tank_heal_budget", 0.0, 1.0],
	["assassin_ranged_damage_multiplier", 1.0, 10.0], ["assassin_hunting_range", 1.0, 400.0],
	["assassin_incursion_distance", 0.0, 200.0], ["assassin_incursion_seconds", 0.1, 60.0],
	["assassin_incursion_cooldown", 0.0, 60.0], ["assassin_stealth_seconds", 0.1, 60.0],
	["assassin_stealth_cooldown", 0.0, 60.0], ["assassin_stealth_priority", 0.01, 1.0],
	["archer_basic_trigger", 1.0, 100.0], ["archer_speed_multiplier", 1.0, 5.0],
	["archer_active_seconds", 0.1, 60.0], ["archer_cooldown_seconds", 0.0, 60.0],
	["mage_basic_trigger", 1.0, 100.0], ["mage_skill_trigger", 1.0, 100.0],
	["mage_fireball_count", 1.0, 12.0], ["mage_fireball_damage_multiplier", 0.0, 10.0],
	["mage_fireball_speed", 1.0, 600.0]
]

var sections: Dictionary = {}
var section_buttons: Dictionary = {}
var active_section := "Heroes"
var selected_hero_id := 0
var last_arena: CombatArena
var syncing := false
var class_picker: OptionButton
var hero_heading: Label
var hero_summary: Label
var attribute_heading: Label
var passive_heading: Label
var state_label: Label
var hero_controls: Dictionary = {}
var enemy_controls: Dictionary = {}
var passive_controls: Dictionary = {}
var passive_rows: Dictionary = {}
var auto_spawn_check: CheckBox
var spawn_rate: SpinBox
var ranged_ratio: SpinBox
var ranged_slider: HSlider
var speed_control: SpinBox
var speed_slider: HSlider
var formation_control: SpinBox
var formation_slider: HSlider
var pause_resume_button: Button
var simulation_status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 8)
	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 6)
	quick.add_theme_constant_override("v_separation", 4)
	add_child(quick)
	pause_resume_button = _add_button(quick, "Pause", _toggle_pause)
	_add_button(quick, "Restart", func() -> void: command_requested.emit("restart", {}))
	_add_button(quick, "Clear enemies", func() -> void: command_requested.emit("clear_enemies", {}))
	var tab_scroll := ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(tab_scroll)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(tabs)
	for section_name in SECTIONS:
		var button := _add_button(tabs, section_name, _select_section.bind(section_name))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(88, 32)
		section_buttons[section_name] = button
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 6)
		add_child(section)
		sections[section_name] = section
	_select_section("Heroes")
	_build_heroes()
	_build_attributes()
	_build_passives()
	_build_enemies()
	_build_simulation()


func _build_heroes() -> void:
	var section: VBoxContainer = sections["Heroes"]
	hero_heading = _add_heading(section, "Selected hero")
	hero_summary = _add_heading(section, "")
	var actions := HFlowContainer.new()
	section.add_child(actions)
	class_picker = OptionButton.new()
	class_picker.custom_minimum_size = Vector2(120, 34)
	for class_label in ["Tank", "Assassin", "Archer", "Mage"]:
		class_picker.add_item(class_label)
	actions.add_child(class_picker)
	_add_button(actions, "Add class", func() -> void: command_requested.emit("add_hero", {"class_id": class_picker.selected}))
	_add_button(actions, "Duplicate selected", func() -> void: command_requested.emit("duplicate_hero", {"hero_id": selected_hero_id}))
	_add_button(actions, "Remove selected", func() -> void: command_requested.emit("remove_hero", {"hero_id": selected_hero_id}))
	_add_heading(section, "Select any hero from the persistent cards or the arena.")


func _build_attributes() -> void:
	var section: VBoxContainer = sections["Attributes"]
	attribute_heading = _add_heading(section, "Selected hero attributes")
	for field in HERO_FIELDS:
		hero_controls[field] = _add_spin(section, field, HERO_FIELDS[field], _emit_field.bind("hero_value", field))
	_add_button(section, "Reset selected hero", func() -> void: command_requested.emit("reset_hero", {"hero_id": selected_hero_id}))


func _build_passives() -> void:
	var section: VBoxContainer = sections["Passives"]
	passive_heading = _add_heading(section, "Selected hero passive")
	state_label = _add_heading(section, "")
	for spec in PASSIVE_FIELDS:
		var field: String = spec[0]
		var row := HBoxContainer.new()
		section.add_child(row)
		passive_rows[field] = row
		passive_controls[field] = _add_spin(row, field, Vector3(spec[1], spec[2], 0.01 if spec[2] <= 10.0 else 0.1), _emit_field.bind("passive_value", field))
	_add_button(section, "Reset selected passive", func() -> void: command_requested.emit("reset_passive", {"hero_id": selected_hero_id}))


func _build_enemies() -> void:
	var section: VBoxContainer = sections["Enemies"]
	_add_heading(section, "Global enemy settings")
	auto_spawn_check = CheckBox.new()
	auto_spawn_check.text = "Automatic spawning"
	auto_spawn_check.toggled.connect(func(value: bool) -> void:
		if not syncing: command_requested.emit("auto_spawn", {"value": value})
	)
	section.add_child(auto_spawn_check)
	spawn_rate = _add_spin(section, "Spawn interval (s)", Vector3(0.2, 20, 0.1), func(value: float) -> void: command_requested.emit("spawn_interval", {"value": value}))
	ranged_ratio = _add_spin(section, "Ranged ratio", Vector3(0, 1, 0.01), func(value: float) -> void: command_requested.emit("ranged_ratio", {"value": value}))
	ranged_slider = _add_slider(section, 0, 1, 0.01, func(value: float) -> void: command_requested.emit("ranged_ratio", {"value": value}))
	_add_heading(section, "Shared stat overrides for melee and ranged enemies")
	for field in ENEMY_FIELDS:
		enemy_controls[field] = _add_spin(section, field, ENEMY_FIELDS[field], _emit_field.bind("enemy_value", field))
	var actions := HFlowContainer.new()
	section.add_child(actions)
	_add_button(actions, "Spawn melee", func() -> void: command_requested.emit("spawn_melee", {}))
	_add_button(actions, "Spawn ranged", func() -> void: command_requested.emit("spawn_ranged", {}))
	_add_button(actions, "Clear enemies", func() -> void: command_requested.emit("clear_enemies", {}))
	_add_button(actions, "Reset enemies", func() -> void: command_requested.emit("reset_enemies", {}))


func _build_simulation() -> void:
	var section: VBoxContainer = sections["Simulation"]
	_add_heading(section, "Global simulation settings")
	simulation_status = _add_heading(section, "Running")
	var actions := HFlowContainer.new()
	section.add_child(actions)
	_add_button(actions, "Pause", func() -> void: command_requested.emit("pause", {}))
	_add_button(actions, "Resume", func() -> void: command_requested.emit("resume", {}))
	_add_button(actions, "Restart", func() -> void: command_requested.emit("restart", {}))
	speed_control = _add_spin(section, "Simulation speed", Vector3(0.1, 4, 0.1), func(value: float) -> void: command_requested.emit("simulation_speed", {"value": value}))
	speed_slider = _add_slider(section, 0.1, 4, 0.1, func(value: float) -> void: command_requested.emit("simulation_speed", {"value": value}))
	formation_control = _add_spin(section, "Formation radius", Vector3(30, 240, 1), func(value: float) -> void: command_requested.emit("formation_radius", {"value": value}))
	formation_slider = _add_slider(section, 30, 240, 1, func(value: float) -> void: command_requested.emit("formation_radius", {"value": value}))
	_add_button(section, "Restore all defaults", func() -> void: command_requested.emit("restore_defaults", {}))


func _add_heading(parent: Node, title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#d9e2e8"))
	parent.add_child(label)
	return label


func _add_button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_spin(parent: Node, title: String, limits: Vector3, callback: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := _add_heading(row, title.replace("_", " ").capitalize())
	label.custom_minimum_size.x = 156
	var spin := SpinBox.new()
	spin.min_value = limits.x
	spin.max_value = limits.y
	spin.step = limits.z
	spin.custom_minimum_size = Vector2(92, 30)
	spin.value_changed.connect(callback)
	row.add_child(spin)
	return spin


func _add_slider(parent: Node, minimum: float, maximum: float, increment: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.custom_minimum_size = Vector2(160, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider


func _emit_field(value: float, action: String, field: String) -> void:
	if syncing:
		return
	var payload := {"field": field, "value": value}
	if action in ["hero_value", "passive_value"]:
		payload["hero_id"] = selected_hero_id
	command_requested.emit(action, payload)


func _toggle_pause() -> void:
	if last_arena != null:
		command_requested.emit("resume" if last_arena.simulation_paused else "pause", {})


func _select_section(section_name: String) -> void:
	active_section = section_name
	for name_key in sections:
		(sections[name_key] as Control).visible = name_key == section_name
	for name_key in section_buttons:
		(section_buttons[name_key] as Button).set_pressed_no_signal(name_key == section_name)
	if is_instance_valid(last_arena):
		update_state(last_arena)


func _sync_spin(spin: SpinBox, value: float, force := false) -> void:
	if force or not spin.get_line_edit().has_focus():
		spin.set_value_no_signal(value)


func update_state(arena: CombatArena) -> void:
	if not is_instance_valid(arena):
		return
	last_arena = arena
	var hero: HeroCombatant = arena.heroes[arena.selected_hero_index] if not arena.heroes.is_empty() else null
	var next_id := hero.get_instance_id() if hero != null else 0
	var changed_hero := next_id != selected_hero_id
	if changed_hero:
		syncing = true
		for control in hero_controls.values() + passive_controls.values():
			(control as SpinBox).get_line_edit().release_focus()
		selected_hero_id = next_id
		syncing = false
	pause_resume_button.text = "Resume" if arena.simulation_paused else "Pause"
	if active_section == "Heroes":
		hero_heading.text = "Selected hero: %s" % (hero.display_name if hero != null else "none")
		hero_summary.text = "Party %d / %d   %s" % [arena.heroes.size(), arena.sandbox_max_heroes, "HP %.0f / %.0f" % [hero.current_health, hero.stats.max_health] if hero != null else "Add a hero to continue"]
	elif active_section == "Attributes":
		attribute_heading.text = "Selected hero attributes: %s" % (hero.display_name if hero != null else "none")
		(sections["Attributes"] as Control).modulate.a = 1.0 if hero != null else 0.5
		if hero != null:
			var definition := hero.build.class_definition
			for field in HERO_FIELDS:
				var value: float
				match field:
					"current_health": value = hero.current_health
					"attack_range": value = hero.active_attack_range()
					"skill_damage", "damage_multiplier": value = float(definition.get(field)) if definition != null else 0.0
					"preferred_radius_percent", "threat_multiplier": value = float(hero.build.get(field))
					_: value = float(hero.stats.get(field))
				_sync_spin(hero_controls[field] as SpinBox, value, changed_hero)
	elif active_section == "Passives":
		passive_heading.text = "Selected passive: %s" % (hero.display_name if hero != null else "none")
		if hero != null:
			var definition := hero.build.class_definition
			for spec in PASSIVE_FIELDS:
				var field: String = spec[0]
				var visible_for_class := (field.begins_with("tank_") and hero.build.archetype == HeroBuildConfig.Archetype.TANK) or (field.begins_with("assassin_") and hero.build.archetype == HeroBuildConfig.Archetype.ASSASSIN) or (field.begins_with("archer_") and hero.build.archetype == HeroBuildConfig.Archetype.ARCHER) or (field.begins_with("mage_") and hero.build.archetype == HeroBuildConfig.Archetype.MAGE)
				(passive_rows[field] as Control).visible = visible_for_class
				if visible_for_class and definition != null:
					_sync_spin(passive_controls[field] as SpinBox, float(definition.get(field)), changed_hero)
			var passive := hero.passive_state
			state_label.text = "Basic %d   Skill %d   Active %.1fs   Cooldown %.1fs\nHeal %.1fs   Incursion %.1fs / CD %.1fs   Stealth %.1fs / CD %.1fs" % [passive.basic_count, passive.skill_count, passive.active_seconds, passive.cooldown_seconds, passive.heal_seconds, passive.incursion_seconds, passive.incursion_cooldown, passive.stealth_seconds, passive.stealth_cooldown]
		else:
			state_label.text = "No hero selected"
	elif active_section == "Enemies":
		auto_spawn_check.set_pressed_no_signal(arena.auto_spawn)
		_sync_spin(spawn_rate, arena.spawn_interval)
		_sync_spin(ranged_ratio, arena.ranged_ratio)
		ranged_slider.set_value_no_signal(arena.ranged_ratio)
		for field in ENEMY_FIELDS:
			_sync_spin(enemy_controls[field] as SpinBox, float(arena.active_melee_stats.get(field)))
	elif active_section == "Simulation":
		simulation_status.text = "Paused" if arena.simulation_paused else "Running"
		_sync_spin(speed_control, arena.simulation_speed)
		speed_slider.set_value_no_signal(arena.simulation_speed)
		_sync_spin(formation_control, arena.formation_radius)
		formation_slider.set_value_no_signal(arena.formation_radius)
