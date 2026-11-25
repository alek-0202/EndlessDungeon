extends Node2D
class_name CombatArena

const ARENA_SIZE := Vector2(960, 540)
const FORMATION_CENTER := Vector2(480, 250)
const LEGACY_CENTER := Vector2(240, 150)

@export var hero_build: HeroBuildConfig = preload("res://data/combat/prototype_hero_build.tres")
@export var enemy_stats: CombatStats = preload("res://data/combat/prototype_enemy_stats.tres")
@export_range(0.2, 20.0, 0.1) var spawn_interval := 2.0
@export_range(0.0, 120.0, 1.0) var formation_radius := 70.0
@export_range(0.5, 2.0, 0.05) var camera_zoom := 1.0

var active_build: HeroBuildConfig
var hero: HeroCombatant
var heroes: Array[HeroCombatant] = []
var enemies: Array[EnemyCombatant] = []
var hud: CombatHud
var world_camera: Camera2D
var rng := RandomNumberGenerator.new()
var spawn_timer := 0.0
var spawn_sequence := 0
var defeated := 0
var run_ended := false


func _ready() -> void:
	rng.randomize()
	active_build = hero_build.duplicate(true)
	world_camera = Camera2D.new()
	world_camera.position = ARENA_SIZE * 0.5
	world_camera.zoom = Vector2.ONE * camera_zoom
	add_child(world_camera)
	world_camera.make_current()
	hud = CombatHud.new()
	add_child(hud)
	hud.radius_changed.connect(_on_radius_changed)
	hud.mode_changed.connect(_on_mode_changed)
	hud.restart_requested.connect(restart_run)
	restart_run()


func _physics_process(delta: float) -> void:
	if run_ended:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_enemy()
		spawn_timer = spawn_interval
	hero.enemies = enemies
	hero.step_behavior(delta)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.step_behavior(delta)
	hud.update_state(hero, enemies.size(), defeated, run_ended)


func restart_run() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	for child in get_children():
		if child is PhysicalProjectile:
			remove_child(child)
			child.queue_free()
	if is_instance_valid(hero):
		remove_child(hero)
		hero.queue_free()
	heroes.clear()
	hero = HeroCombatant.new()
	add_child(hero)
	hero.global_position = FORMATION_CENTER
	hero.formation_center = FORMATION_CENTER
	hero.formation_radius = formation_radius
	hero.configure_build(active_build)
	heroes.append(hero)
	hero.projectile_requested.connect(_on_projectile_requested)
	hero.died.connect(_on_hero_died)
	defeated = 0
	spawn_sequence = 0
	spawn_timer = spawn_interval
	run_ended = false
	spawn_enemy()
	hud.update_state(hero, enemies.size(), defeated, run_ended)
	queue_redraw()


func spawn_enemy() -> EnemyCombatant:
	var enemy := EnemyCombatant.new()
	add_child(enemy)
	enemy.global_position = _next_spawn_position()
	enemy.configure(enemy_stats)
	enemy.heroes = heroes
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	return enemy


func _next_spawn_position() -> Vector2:
	var side := spawn_sequence % 4
	spawn_sequence += 1
	var legacy_position: Vector2
	match side:
		0:
			legacy_position = Vector2(12, rng.randf_range(95, 256))
		1:
			legacy_position = Vector2(rng.randf_range(15, 465), 92)
		2:
			legacy_position = Vector2(468, rng.randf_range(95, 256))
		_:
			legacy_position = Vector2(rng.randf_range(15, 465), 258)
	return FORMATION_CENTER + legacy_position - LEGACY_CENTER


func _on_projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float) -> void:
	var projectile := PhysicalProjectile.new()
	add_child(projectile)
	projectile.launch(origin, destination, speed, damage)


func _on_enemy_died(combatant: Combatant) -> void:
	enemies.erase(combatant)
	defeated += 1
	combatant.queue_free()


func _on_hero_died(_combatant: Combatant) -> void:
	run_ended = true
	for child in get_children():
		if child is PhysicalProjectile:
			child.set_physics_process(false)
			child.set_deferred("monitoring", false)
			child.queue_free()
	hud.update_state(hero, enemies.size(), defeated, run_ended)


func _on_radius_changed(value: float) -> void:
	active_build.preferred_radius_percent = value
	hud.update_state(hero, enemies.size(), defeated, run_ended)


func _on_mode_changed() -> void:
	if active_build.attack_mode == HeroBuildConfig.AttackMode.MELEE:
		active_build.attack_mode = HeroBuildConfig.AttackMode.PROJECTILE
	else:
		active_build.attack_mode = HeroBuildConfig.AttackMode.MELEE
	hud.update_state(hero, enemies.size(), defeated, run_ended)


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
