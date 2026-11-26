extends Node2D
class_name CombatArena

const ARENA_SIZE := Vector2(1280, 720)
const FORMATION_CENTER := Vector2(640, 310)
const PARTY_NAMES := ["Tank", "Assassin", "Archer", "Mage"]

@export var tank_build: HeroBuildConfig = preload("res://data/combat/tank_build.tres")
@export var assassin_build: HeroBuildConfig = preload("res://data/combat/assassin_build.tres")
@export var archer_build: HeroBuildConfig = preload("res://data/combat/archer_build.tres")
@export var mage_build: HeroBuildConfig = preload("res://data/combat/mage_build.tres")
@export var melee_enemy_stats: CombatStats = preload("res://data/combat/prototype_enemy_stats.tres")
@export var ranged_enemy_stats: CombatStats = preload("res://data/combat/ranged_enemy_stats.tres")
@export_range(0.2, 20.0, 0.1) var spawn_interval := 1.2
@export_range(0.0, 240.0, 1.0) var formation_radius := 110.0
@export_range(0.5, 2.0, 0.05) var camera_zoom := 0.8
@export_range(1, 32, 1) var sandbox_max_heroes := 8
@export_range(1, 500, 1) var sandbox_max_enemies := 100

var active_builds: Array[HeroBuildConfig] = []
var heroes: Array[HeroCombatant] = []
var enemies: Array[EnemyCombatant] = []
var selected_hero_index := 0
var hud: CombatHud
var world_camera: Camera2D
var rng := RandomNumberGenerator.new()
var spawn_timer := 0.0
var spawn_sequence := 0
var defeated := 0
var run_ended := false
var auto_spawn := true
var ranged_ratio := 0.33
var simulation_paused := false
var simulation_speed := 1.0
var active_melee_stats: CombatStats
var active_ranged_stats: CombatStats
var initial_settings: Dictionary = {}
var hud_refresh_timer := 0.0


func _ready() -> void:
	rng.randomize()
	initial_settings = {"spawn_interval": spawn_interval, "formation_radius": formation_radius, "ranged_ratio": ranged_ratio, "simulation_speed": simulation_speed, "auto_spawn": auto_spawn}
	for template in [tank_build, assassin_build, archer_build, mage_build]:
		active_builds.append(_copy_build(template))
	active_melee_stats = melee_enemy_stats.duplicate(true)
	active_ranged_stats = ranged_enemy_stats.duplicate(true)
	world_camera = Camera2D.new()
	world_camera.position = ARENA_SIZE * 0.5
	world_camera.zoom = Vector2.ONE * camera_zoom
	add_child(world_camera)
	world_camera.make_current()
	hud = CombatHud.new()
	add_child(hud)
	hud.radius_changed.connect(_on_radius_changed)
	hud.mode_changed.connect(_on_mode_changed)
	hud.hero_selected.connect(select_hero)
	hud.panel_changed.connect(_update_hud)
	hud.diagnostics_toggled.connect(_update_diagnostics)
	hud.restart_requested.connect(restart_run)
	hud.sandbox_command.connect(_on_sandbox_command)
	restart_run()


func _physics_process(delta: float) -> void:
	if run_ended or simulation_paused:
		return
	delta *= simulation_speed
	spawn_timer -= delta
	if auto_spawn and spawn_timer <= 0.0:
		spawn_enemy()
		spawn_timer = spawn_interval
	for hero in heroes:
		if is_instance_valid(hero) and hero.is_alive:
			hero.enemies = enemies
			hero.step_behavior(delta)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.step_behavior(delta)
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		_update_hud()
		hud_refresh_timer = 0.2


func restart_run() -> void:
	simulation_paused = false
	for enemy in enemies:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	for child in get_children():
		if child is PhysicalProjectile:
			remove_child(child)
			child.queue_free()
	for hero in heroes:
		if is_instance_valid(hero):
			remove_child(hero)
			hero.queue_free()
	heroes.clear()
	selected_hero_index = clampi(selected_hero_index, 0, maxi(0, active_builds.size() - 1))
	for index in range(active_builds.size()):
		_create_hero(active_builds[index], index)
	defeated = 0
	spawn_sequence = 0
	spawn_timer = spawn_interval
	run_ended = heroes.is_empty()
	if auto_spawn and not run_ended:
		spawn_enemy()
	_update_hud()
	queue_redraw()


func spawn_enemy(force_ranged := -1) -> EnemyCombatant:
	if enemies.size() >= sandbox_max_enemies:
		return null
	var enemy := EnemyCombatant.new()
	add_child(enemy)
	enemy.global_position = _next_spawn_position()
	enemy.ranged = (spawn_sequence % 3 == 0) if is_equal_approx(ranged_ratio, 0.33) else rng.randf() < ranged_ratio
	if force_ranged >= 0:
		enemy.ranged = force_ranged == 1
	enemy.configure(active_ranged_stats if enemy.ranged else active_melee_stats)
	enemy.heroes = heroes
	enemy.projectile_requested.connect(_on_enemy_projectile_requested.bind(enemy))
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	return enemy


func _copy_build(template: HeroBuildConfig) -> HeroBuildConfig:
	var copy: HeroBuildConfig = template.duplicate(true)
	copy.stats = template.stats.duplicate(true)
	copy.class_definition = template.class_definition.duplicate(true) if template.class_definition != null else null
	return copy


func _template_for_class(archetype: int) -> HeroBuildConfig:
	match archetype:
		HeroBuildConfig.Archetype.TANK: return tank_build
		HeroBuildConfig.Archetype.ASSASSIN: return assassin_build
		HeroBuildConfig.Archetype.ARCHER: return archer_build
		HeroBuildConfig.Archetype.MAGE: return mage_build
	return null


func _create_hero(build: HeroBuildConfig, index: int) -> HeroCombatant:
	var hero := HeroCombatant.new()
	hero.display_name = build.class_definition.display_name if build.class_definition != null else PARTY_NAMES[build.archetype]
	hero.is_selected = index == selected_hero_index
	add_child(hero)
	hero.global_position = FORMATION_CENTER + Vector2.RIGHT.rotated(float(index) * TAU / float(maxi(4, active_builds.size()))) * 12.0
	hero.formation_center = FORMATION_CENTER
	hero.formation_radius = formation_radius
	hero.configure_build(build)
	hero.projectile_requested.connect(_on_hero_projectile_requested.bind(hero))
	hero.fireball_requested.connect(_on_hero_fireball_requested.bind(hero))
	hero.tank_heal_requested.connect(_on_tank_heal_requested.bind(hero))
	hero.selection_requested.connect(select_hero_instance)
	hero.died.connect(_on_hero_died)
	heroes.append(hero)
	return hero


func _next_spawn_position() -> Vector2:
	var side := spawn_sequence % 4
	spawn_sequence += 1
	match side:
		0:
			return Vector2(40, rng.randf_range(100, 590))
		1:
			return Vector2(rng.randf_range(100, 1180), 40)
		2:
			return Vector2(1240, rng.randf_range(100, 590))
		_:
			return Vector2(rng.randf_range(100, 1180), 600)


func _on_hero_projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float, attacker: HeroCombatant) -> void:
	var projectile := PhysicalProjectile.new()
	add_child(projectile)
	projectile.launch(origin, destination, speed, damage, attacker)
	if is_instance_valid(attacker) and attacker.build != null and attacker.build.archetype == HeroBuildConfig.Archetype.ASSASSIN and attacker.build.class_definition != null:
		projectile.ranged_bonus_multiplier = attacker.build.class_definition.assassin_ranged_damage_multiplier
	_configure_projectile(projectile)


func _on_hero_fireball_requested(origin: Vector2, destination: Vector2, damage: float, speed: float, attacker: HeroCombatant) -> void:
	var projectile := PhysicalProjectile.new()
	add_child(projectile)
	projectile.launch(origin, destination, speed, damage, attacker, false, "fire")
	_configure_projectile(projectile)


func _on_enemy_projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float, attacker: EnemyCombatant) -> void:
	var projectile := PhysicalProjectile.new()
	add_child(projectile)
	projectile.launch(origin, destination, speed, damage, attacker, true)
	_configure_projectile(projectile)


func _configure_projectile(projectile: PhysicalProjectile) -> void:
	projectile.simulation_speed = simulation_speed
	projectile.simulation_paused = simulation_paused


func _on_tank_heal_requested(tank: HeroCombatant) -> void:
	if not is_instance_valid(tank) or not tank.is_alive or tank.build.class_definition == null:
		return
	var wounded: Array[HeroCombatant] = []
	for hero in heroes:
		if is_instance_valid(hero) and hero.is_alive and hero.current_health < hero.stats.max_health:
			wounded.append(hero)
	if wounded.is_empty():
		return
	wounded.sort_custom(func(a: HeroCombatant, b: HeroCombatant) -> bool: return a.health_fraction() < b.health_fraction())
	var budget := clampf(tank.build.class_definition.tank_heal_budget, 0.0, 1.0)
	var share := budget / float(wounded.size())
	var unused := 0.0
	for hero in wounded:
		var applied := minf(share, 1.0 - hero.health_fraction())
		hero.heal(hero.stats.max_health * applied)
		unused += share - applied
	for hero in wounded:
		if unused <= 0.00001:
			break
		var applied := minf(unused, 1.0 - hero.health_fraction())
		hero.heal(hero.stats.max_health * applied)
		unused -= applied


func _on_enemy_died(combatant: Combatant) -> void:
	enemies.erase(combatant)
	defeated += 1
	combatant.queue_free()


func _on_hero_died(_combatant: Combatant) -> void:
	for hero in heroes:
		if hero.is_alive:
			_update_hud()
			return
	_end_run()
	_update_hud()


func _end_run() -> void:
	run_ended = true
	for child in get_children():
		if child is PhysicalProjectile:
			child.set_physics_process(false)
			child.set_deferred("monitoring", false)
			child.queue_free()


func _on_sandbox_command(action: String, data: Dictionary) -> void:
	match action:
		"add_hero":
			var class_id := int(data.get("class_id", -1))
			var template := _template_for_class(class_id)
			if template != null and heroes.size() < sandbox_max_heroes:
				var build := _copy_build(template)
				active_builds.append(build)
				_create_hero(build, heroes.size())
				run_ended = false
				select_hero(heroes.size() - 1)
		"duplicate_hero":
			var source_index := _resolve_hero_index(data)
			if source_index >= 0 and source_index < heroes.size() and heroes.size() < sandbox_max_heroes:
				var build := _copy_build(active_builds[source_index])
				active_builds.append(build)
				_create_hero(build, heroes.size())
				run_ended = false
				select_hero(heroes.size() - 1)
		"remove_hero":
			var index := _resolve_hero_index(data)
			if index >= 0 and index < heroes.size():
				var hero := heroes[index]
				var selected := heroes[selected_hero_index] if selected_hero_index < heroes.size() else null
				heroes.remove_at(index)
				active_builds.remove_at(index)
				for enemy in enemies:
					enemy.threat.erase(hero)
				if hero.get_parent() == self:
					remove_child(hero)
				hero.queue_free()
				selected_hero_index = heroes.find(selected) if selected != hero and heroes.has(selected) else clampi(index, 0, maxi(0, heroes.size() - 1))
				if heroes.is_empty() or heroes.all(func(member: HeroCombatant) -> bool: return not member.is_alive):
					_end_run()
				else:
					select_hero(selected_hero_index)
		"hero_value":
			_set_hero_value(_resolve_hero_index(data), str(data.get("field", "")), float(data.get("value", 0.0)))
		"passive_value":
			_set_passive_value(_resolve_hero_index(data), str(data.get("field", "")), float(data.get("value", 0.0)))
		"reset_hero": _reset_hero(_resolve_hero_index(data))
		"reset_passive": _reset_passive(_resolve_hero_index(data))
		"auto_spawn": auto_spawn = bool(data.get("value", true))
		"spawn_interval": spawn_interval = clampf(float(data.get("value", 1.2)), 0.2, 20.0)
		"ranged_ratio": ranged_ratio = clampf(float(data.get("value", 0.33)), 0.0, 1.0)
		"enemy_value": _set_enemy_value(str(data.get("field", "")), float(data.get("value", 0.0)))
		"reset_enemies": _reset_enemies()
		"spawn_melee": spawn_enemy(0)
		"spawn_ranged": spawn_enemy(1)
		"clear_enemies": _clear_enemies()
		"pause": simulation_paused = true
		"resume": simulation_paused = false
		"restart": restart_run()
		"simulation_speed": simulation_speed = clampf(float(data.get("value", 1.0)), 0.1, 4.0)
		"formation_radius":
			formation_radius = clampf(float(data.get("value", 110.0)), 30.0, 240.0)
			for hero in heroes:
				hero.formation_radius = formation_radius
			queue_redraw()
		"restore_defaults": _restore_defaults()
	if action in ["pause", "resume", "simulation_speed", "restore_defaults"]:
		for child in get_children():
			if child is PhysicalProjectile:
				_configure_projectile(child)
	_update_hud()


func _resolve_hero_index(data: Dictionary) -> int:
	if data.has("hero_id"):
		for index in range(heroes.size()):
			if heroes[index].get_instance_id() == int(data["hero_id"]):
				return index
		return -1
	return int(data.get("index", selected_hero_index))


func _set_hero_value(index: int, field: String, value: float) -> void:
	if index < 0 or index >= heroes.size() or not is_finite(value):
		return
	var hero := heroes[index]
	var build := active_builds[index]
	match field:
		"max_health":
			build.stats.max_health = clampf(value, 1.0, 1000.0)
			hero.current_health = minf(hero.current_health, build.stats.max_health)
		"current_health":
			hero.current_health = clampf(value, 0.0, build.stats.max_health)
			hero.is_alive = hero.current_health > 0.0
			if hero.is_alive:
				run_ended = false
			elif heroes.all(func(member: HeroCombatant) -> bool: return not member.is_alive):
				_end_run()
		"armor": build.stats.armor = clampf(value, 0.0, 100.0)
		"damage": build.stats.damage = clampf(value, 0.0, 100.0)
		"skill_damage":
			if build.class_definition != null: build.class_definition.skill_damage = clampf(value, 0.0, 500.0)
		"damage_multiplier":
			if build.class_definition != null: build.class_definition.damage_multiplier = clampf(value, 0.0, 10.0)
		"attacks_per_second":
			var old_speed := hero.effective_attack_speed()
			build.stats.attacks_per_second = clampf(value, 0.1, 10.0)
			hero.attack_timer *= old_speed / hero.effective_attack_speed()
		"movement_speed": build.stats.movement_speed = clampf(value, 0.0, 300.0)
		"attack_range":
			build.stats.attack_range = clampf(value, 1.0, 300.0)
			build.melee_range = build.stats.attack_range
		"preferred_radius_percent": build.preferred_radius_percent = clampf(value, 0.0, 100.0)
		"threat_multiplier": build.threat_multiplier = clampf(value, 0.0, 10.0)
	hero.health_changed.emit(hero)
	hero.queue_redraw()


func _set_passive_value(index: int, field: String, value: float) -> void:
	if index < 0 or index >= heroes.size() or not is_finite(value):
		return
	var definition := active_builds[index].class_definition
	if definition == null:
		return
	var allowed := {
		"mage_basic_trigger": Vector2(1, 100), "mage_skill_trigger": Vector2(1, 100),
		"mage_fireball_count": Vector2(1, 12), "mage_fireball_damage_multiplier": Vector2(0, 10),
		"mage_fireball_speed": Vector2(1, 600), "archer_basic_trigger": Vector2(1, 100),
		"archer_speed_multiplier": Vector2(1, 5), "archer_active_seconds": Vector2(0.1, 60),
		"archer_cooldown_seconds": Vector2(0, 60), "assassin_ranged_damage_multiplier": Vector2(1, 10),
		"assassin_hunting_range": Vector2(1, 400), "assassin_incursion_distance": Vector2(0, 200),
		"assassin_incursion_seconds": Vector2(0.1, 60), "assassin_incursion_cooldown": Vector2(0, 60),
		"assassin_stealth_seconds": Vector2(0.1, 60), "assassin_stealth_cooldown": Vector2(0, 60),
		"assassin_stealth_priority": Vector2(0.01, 1), "tank_heal_interval": Vector2(0.1, 120),
		"tank_heal_budget": Vector2(0, 1)
	}
	if allowed.has(field):
		var bounds: Vector2 = allowed[field]
		var old_speed := heroes[index].effective_attack_speed()
		definition.set(field, clampf(value, bounds.x, bounds.y))
		if field == "archer_speed_multiplier":
			heroes[index].attack_timer *= old_speed / heroes[index].effective_attack_speed()


func _set_enemy_value(field: String, value: float) -> void:
	if not is_finite(value):
		return
	var bounds := {"max_health": Vector2(1, 1000), "damage": Vector2(0, 100), "armor": Vector2(0, 100), "movement_speed": Vector2(0, 300), "attacks_per_second": Vector2(0.1, 10), "attack_range": Vector2(1, 300)}
	if not bounds.has(field):
		return
	var limit: Vector2 = bounds[field]
	for stats_resource in [active_melee_stats, active_ranged_stats]:
		stats_resource.set(field, clampf(value, limit.x, limit.y))
	for enemy in enemies:
		if field == "max_health":
			enemy.current_health = minf(enemy.current_health, enemy.stats.max_health)


func _reset_hero(index: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	var hero := heroes[index]
	var health_fraction_before := hero.health_fraction()
	active_builds[index] = _copy_build(_template_for_class(hero.build.archetype))
	hero.configure_build(active_builds[index])
	hero.current_health = hero.stats.max_health * health_fraction_before
	hero.is_alive = hero.current_health > 0.0
	hero.health_changed.emit(hero)


func _reset_passive(index: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	var hero := heroes[index]
	var template := _template_for_class(hero.build.archetype)
	hero.build.class_definition = template.class_definition.duplicate(true)
	hero.passive_state = HeroPassiveState.new()
	hero.passive_state.heal_seconds = hero.build.class_definition.tank_heal_interval
	if hero.build.archetype == HeroBuildConfig.Archetype.ASSASSIN:
		hero.passive_state.stealth_seconds = hero.build.class_definition.assassin_stealth_seconds


func _reset_enemies() -> void:
	active_melee_stats = melee_enemy_stats.duplicate(true)
	active_ranged_stats = ranged_enemy_stats.duplicate(true)
	for enemy in enemies:
		var health_fraction_before := enemy.health_fraction()
		enemy.stats = active_ranged_stats if enemy.ranged else active_melee_stats
		enemy.current_health = enemy.stats.max_health * health_fraction_before
	auto_spawn = initial_settings["auto_spawn"]
	spawn_interval = initial_settings["spawn_interval"]
	ranged_ratio = initial_settings["ranged_ratio"]


func _clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.collision_layer = 0
			enemy.set_deferred("monitorable", false)
			enemy.queue_free()
	enemies.clear()
	for child in get_children():
		if child is PhysicalProjectile and child.target_heroes:
			child.set_deferred("monitoring", false)
			child.queue_free()


func _restore_defaults() -> void:
	for index in range(active_builds.size()):
		_reset_hero(index)
	_reset_enemies()
	simulation_speed = initial_settings["simulation_speed"]
	simulation_paused = false
	formation_radius = initial_settings["formation_radius"]
	for hero in heroes:
		hero.formation_radius = formation_radius
	queue_redraw()


func select_hero(index: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	selected_hero_index = index
	for hero_index in range(heroes.size()):
		heroes[hero_index].is_selected = hero_index == index
		heroes[hero_index].queue_redraw()
	_update_hud()


func select_hero_instance(hero: HeroCombatant) -> void:
	if is_instance_valid(hero):
		var index := heroes.find(hero)
		if index >= 0:
			select_hero(index)


func _on_radius_changed(value: float) -> void:
	if selected_hero_index >= active_builds.size(): return
	active_builds[selected_hero_index].preferred_radius_percent = value
	_update_hud()


func _on_mode_changed() -> void:
	if selected_hero_index >= active_builds.size(): return
	var build := active_builds[selected_hero_index]
	build.attack_mode = HeroBuildConfig.AttackMode.PROJECTILE if build.attack_mode == HeroBuildConfig.AttackMode.MELEE else HeroBuildConfig.AttackMode.MELEE
	_update_hud()


func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.update_state(heroes, selected_hero_index, enemies.size(), defeated, run_ended)
		hud.update_sandbox(self)
		_update_diagnostics()


func _update_diagnostics() -> void:
	if is_instance_valid(hud):
		hud.update_diagnostics(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and run_ended:
		restart_run()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("#181e29"))
	for x in range(0, int(ARENA_SIZE.x), 16):
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), Color("#222a37"))
	for y in range(0, int(ARENA_SIZE.y), 16):
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), Color("#222a37"))
	draw_arc(FORMATION_CENTER, formation_radius, 0.0, TAU, 64, Color("#466075"), 1.0)
	draw_rect(Rect2(FORMATION_CENTER - Vector2.ONE, Vector2(2, 2)), Color("#7293a5"))
