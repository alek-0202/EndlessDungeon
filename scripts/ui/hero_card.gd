extends Button
class_name HeroCard

var hero: HeroCombatant
var title_label: Label
var health_label: Label
var passive_label: Label
var health_bar: ProgressBar
var highlighted := false


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(150, 72)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 1)
	margin.add_child(rows)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#f1e8d5"))
	rows.add_child(title_label)
	health_label = Label.new()
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.clip_text = true
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color("#c4d1db"))
	rows.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.show_percentage = false
	health_bar.custom_minimum_size.y = 5
	rows.add_child(health_bar)
	passive_label = Label.new()
	passive_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_label.clip_text = true
	passive_label.add_theme_font_size_override("font_size", 11)
	passive_label.add_theme_color_override("font_color", Color("#a8b8c7"))
	rows.add_child(passive_label)
	_set_style(false)


func update_state(member: HeroCombatant, index: int, selected: bool) -> void:
	hero = member
	title_label.text = "%d  %s%s" % [index + 1, member.display_name.to_upper(), "  ✦" if selected else ""]
	health_label.text = "HP %.0f / %.0f" % [member.current_health, member.stats.max_health]
	health_bar.max_value = maxf(1.0, member.stats.max_health)
	health_bar.value = member.current_health
	var state := member.passive_state
	match member.build.archetype:
		HeroBuildConfig.Archetype.TANK:
			passive_label.text = "Heal %.0fs" % state.heal_seconds
		HeroBuildConfig.Archetype.ASSASSIN:
			passive_label.text = "Stealth %.0fs  CD %.0fs" % [state.stealth_seconds, state.stealth_cooldown]
		HeroBuildConfig.Archetype.ARCHER:
			passive_label.text = "%d/%d  Buff %.0fs  CD %.0fs" % [state.basic_count, member.build.class_definition.archer_basic_trigger, state.active_seconds, state.cooldown_seconds]
		HeroBuildConfig.Archetype.MAGE:
			passive_label.text = "%d/%d basic  %d/%d cast" % [state.basic_count, member.build.class_definition.mage_basic_trigger, state.skill_count, member.build.class_definition.mage_skill_trigger]
	disabled = false
	if highlighted != selected:
		highlighted = selected
		_set_style(selected)


func _set_style(selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#263b50") if selected else Color("#1c2837")
	normal.border_color = Color("#e7bf74") if selected else Color("#425367")
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(5)
	add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#304b65")
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("disabled", normal)
