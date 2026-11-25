extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rules()
	_test_hero_behavior()
	_test_kiting_mode(HeroBuildConfig.AttackMode.MELEE)
	_test_kiting_mode(HeroBuildConfig.AttackMode.PROJECTILE)
	_test_radial_preference()
	await _test_projectile_collision()
	await _test_arena_lifecycle()
	await _test_hud_layout()
	if failures.is_empty():
		print("COMBAT TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			print("COMBAT TEST FAILED: " + failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _test_rules() -> void:
	_expect(is_equal_approx(CombatRules.damage_after_armor(6.0, 2.0), 4.0), "armor reduces damage")
	_expect(is_equal_approx(CombatRules.damage_after_armor(1.0, 10.0), 1.0), "positive hits retain a minimum")
	_expect(is_zero_approx(CombatRules.damage_after_armor(0.0, 10.0)), "zero damage stays zero")
	var center := Vector2(100, 100)
	var threat := Vector2(200, 100)
	_expect(CombatRules.preferred_point(center, threat, 50.0, 0.0) == center, "zero percent stays at center")
	_expect(CombatRules.preferred_point(center, threat, 50.0, 50.0) == Vector2(125, 100), "half radius")
	_expect(CombatRules.preferred_point(center, threat, 50.0, 100.0) == Vector2(150, 100), "formation edge")


func _test_hero_behavior() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 100.0
	stats.damage = 10.0
	stats.armor = 3.0
	stats.movement_speed = 100.0
	stats.attacks_per_second = 1.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	build.attack_mode = HeroBuildConfig.AttackMode.MELEE
	build.melee_range = 22.0
	build.preferred_radius_percent = 100.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2(100, 100)
	hero.formation_radius = 50.0
	hero.global_position = hero.formation_center
	var nearby := EnemyCombatant.new()
	container.add_child(nearby)
	nearby.configure(stats)
	nearby.global_position = Vector2(150, 100)
	var distant := EnemyCombatant.new()
	container.add_child(distant)
	distant.configure(stats)
	distant.global_position = Vector2(100, 200)
	hero.enemies = [nearby, distant]
	hero.step_behavior(0.1)
	_expect(hero.current_target == nearby, "nearest target selected")
	_expect(hero.global_position == Vector2(110, 100), "hero approaches target automatically")
	build.preferred_radius_percent = 0.0
	hero.step_behavior(1.0)
	_expect(hero.global_position == Vector2(128, 100), "radial preference yields to attack range")
	build.preferred_radius_percent = 100.0
	hero.global_position = Vector2(130, 100)
	hero.attack_timer = 0.0
	var prior_health := nearby.current_health
	hero.step_behavior(0.1)
	_expect(nearby.current_health < prior_health, "melee attack applies damage in range")
	_expect(hero.global_position == Vector2(130, 100), "ready attack stops movement")
	prior_health = nearby.current_health
	hero.step_behavior(0.1)
	_expect(is_equal_approx(nearby.current_health, prior_health), "attack cooldown limits melee rate")
	hero.receive_hit(6.0)
	_expect(is_equal_approx(hero.current_health, 97.0), "hero armor remains relevant")
	build.attack_mode = HeroBuildConfig.AttackMode.PROJECTILE
	stats.attack_range = 200.0
	hero.attack_timer = 0.0
	var projectile_requests := [0]
	hero.projectile_requested.connect(func(_origin: Vector2, _destination: Vector2, _damage: float, _speed: float) -> void: projectile_requests[0] += 1)
	hero.step_behavior(0.1)
	_expect(projectile_requests[0] == 1, "projectile mode requests a physical projectile")
	var second_hero := HeroCombatant.new()
	container.add_child(second_hero)
	second_hero.configure_build(build)
	second_hero.global_position = Vector2(150, 100)
	hero.global_position = Vector2(100, 100)
	nearby.heroes = [hero, second_hero]
	nearby.global_position = Vector2(155, 100)
	var second_prior_health := second_hero.current_health
	nearby.step_behavior(0.1)
	_expect(second_hero.current_health < second_prior_health, "enemy chooses nearest living hero from a list")
	container.queue_free()


func _test_kiting_mode(mode: int) -> void:
	var label := "melee" if mode == HeroBuildConfig.AttackMode.MELEE else "projectile"
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 100.0
	stats.damage = 10.0
	stats.attack_range = 60.0
	stats.attacks_per_second = 1.0
	stats.movement_speed = 100.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	build.attack_mode = mode
	build.melee_range = 20.0
	build.preferred_radius_percent = 0.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2.ZERO
	hero.formation_radius = 70.0
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	var effective_range := hero.active_attack_range()
	enemy.global_position = Vector2(effective_range + 20.0, 0)
	hero.enemies = [enemy]
	var projectiles := [0]
	hero.projectile_requested.connect(func(_origin: Vector2, _destination: Vector2, _damage: float, _speed: float) -> void: projectiles[0] += 1)

	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(10, 0), label + " approaches only toward range")
	_expect(is_equal_approx(enemy.current_health, 100.0) and projectiles[0] == 0, label + " does not attack out of range")
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(20, 0), label + " stops at maximum effective range")
	_expect(hero.attack_timer > 0.0, label + " attacks upon entering range")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < 100.0, "melee hit occurs on entry")
	else:
		_expect(projectiles[0] == 1, "ranged shot occurs on entry")

	enemy.global_position = Vector2(hero.global_position.x + effective_range - 10.0, 0)
	var attacks_before: int = projectiles[0]
	var health_before := enemy.current_health
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(10, 0), label + " retreats to maximum range during cooldown")
	_expect(is_equal_approx(hero.attack_timer, 0.9), label + " movement does not reset cooldown")
	_expect(projectiles[0] == attacks_before and is_equal_approx(enemy.current_health, health_before), label + " cooldown prevents early attack")
	hero.step_behavior(0.4)
	_expect(hero.global_position == Vector2(10, 0), label + " does not retreat again at range")
	_expect(is_equal_approx(hero.attack_timer, 0.5), label + " cooldown continues while stationary")
	hero.step_behavior(0.5)
	_expect(hero.global_position == Vector2(10, 0), label + " ready attack does not move")
	_expect(hero.attack_timer > 0.0, label + " attacks immediately when cooldown ends")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < health_before, "melee repeats at cooldown end")
	else:
		_expect(projectiles[0] == attacks_before + 1, "ranged shot repeats at cooldown end")

	hero.global_position = Vector2(10, 0)
	enemy.global_position = Vector2(10.5 + effective_range, 0)
	hero.attack_timer = 0.0
	attacks_before = projectiles[0]
	health_before = enemy.current_health
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(10.5, 0), label + " closes a fractional range gap")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < health_before, "melee attacks without delay at range edge")
	else:
		_expect(projectiles[0] == attacks_before + 1, "ranged attack fires without delay at range edge")

	hero.global_position = Vector2(70, 0)
	enemy.global_position = Vector2(65, 0)
	hero.attack_timer = 0.5
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(70, 0), label + " retreat stops at formation boundary")
	_expect(hero.global_position.distance_to(hero.formation_center) <= hero.formation_radius, label + " remains inside formation")
	container.queue_free()


func _test_radial_preference() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.attack_range = 20.0
	stats.movement_speed = 100.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	build.attack_mode = HeroBuildConfig.AttackMode.PROJECTILE
	build.preferred_radius_percent = 100.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2.ZERO
	hero.formation_radius = 70.0
	hero.global_position = Vector2(40, 20)
	hero.attack_timer = 0.5
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	enemy.global_position = Vector2(40, 40)
	hero.enemies = [enemy]
	var preferred := CombatRules.preferred_point(Vector2.ZERO, enemy.global_position, 70.0, 100.0)
	var initial_preference_distance := hero.global_position.distance_to(preferred)
	hero.step_behavior(0.1)
	_expect(hero.global_position.distance_to(preferred) < initial_preference_distance, "radial preference guides safe cooldown movement")
	_expect(absf(hero.global_position.distance_to(enemy.global_position) - 20.0) <= 1.0, "preference preserves attack distance")
	_expect(hero.global_position.length() <= 70.0, "preference stays inside formation")
	var previous_preference_distance := hero.global_position.distance_to(preferred)
	for frame in range(6):
		hero.step_behavior(0.05)
		var preference_distance := hero.global_position.distance_to(preferred)
		_expect(preference_distance <= previous_preference_distance + 0.01, "radial adjustment does not oscillate")
		_expect(absf(hero.global_position.distance_to(enemy.global_position) - 20.0) <= 1.0, "radial adjustment retains attack distance")
		_expect(hero.global_position.length() <= 70.0, "radial adjustment remains within formation")
		previous_preference_distance = preference_distance
	container.queue_free()


func _test_projectile_collision() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 30.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure(stats)
	hero.global_position = Vector2(20, 40)
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	enemy.global_position = Vector2(50, 40)
	var behind := EnemyCombatant.new()
	container.add_child(behind)
	behind.configure(stats)
	behind.global_position = Vector2(80, 40)
	var projectile := PhysicalProjectile.new()
	container.add_child(projectile)
	projectile.launch(Vector2(0, 40), Vector2(100, 40), 300.0, 10.0)
	for frame in range(20):
		await physics_frame
	_expect(enemy.current_health < stats.max_health, "physical projectile hits enemy through Area2D collision")
	_expect(is_equal_approx(behind.current_health, stats.max_health), "front enemy intercepts projectile before rear enemy")
	_expect(is_equal_approx(hero.current_health, stats.max_health), "projectile ignores invalid friendly target")
	container.queue_free()
	await process_frame


func _test_arena_lifecycle() -> void:
	var arena := CombatArena.new()
	root.add_child(arena)
	await process_frame
	_expect(CombatArena.ARENA_SIZE == Vector2(960, 540), "combat world uses expanded logical area")
	_expect(CombatArena.FORMATION_CENTER == Vector2(480, 250), "formation reserves space above bottom panels")
	_expect(is_equal_approx(arena.formation_radius, 70.0), "formation radius preserves combat balance")
	_expect(arena.world_camera != null and arena.world_camera.zoom == Vector2.ONE, "camera has independent default zoom")
	_expect(is_equal_approx(arena.hero.stats.attack_range, 130.0), "hero attack range remains unchanged")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 960, "internal viewport width is 960")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 540, "internal viewport height is 540")
	_expect(int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1920, "desktop reference width is 1920")
	_expect(int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 1080, "desktop reference height is 1080")
	_expect(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "nearest texture filtering remains configured")
	_expect(arena.enemies.size() == 1, "arena starts with an enemy")
	_expect(arena.enemies[0].global_position.x == 252.0, "left spawn keeps original distance from center")
	var second := arena.spawn_enemy()
	var third := arena.spawn_enemy()
	var fourth := arena.spawn_enemy()
	_expect(second.global_position.y == 192.0, "top spawn keeps original distance from center")
	_expect(third.global_position.x == 708.0, "right spawn keeps original distance from center")
	_expect(fourth.global_position.y == 358.0, "bottom spawn keeps original distance from center")
	arena._on_radius_changed(25.0)
	_expect(is_equal_approx(arena.active_build.preferred_radius_percent, 25.0), "HUD radius updates active build")
	arena.hud.nav_buttons["Tactics"].pressed.emit()
	_expect(arena.hud.active_panel == "Tactics" and arena.hud.panel_host.visible, "tactics panel opens")
	await process_frame
	_expect(CombatArena.FORMATION_CENTER.y + arena.formation_radius <= arena.hud.panel_host.get_global_rect().position.y, "default formation stays above expanded panel")
	var timer_before_panel := arena.spawn_timer
	arena._physics_process(0.1)
	_expect(arena.spawn_timer < timer_before_panel, "open panel does not pause combat")
	arena.hud.radius_slider.value = 35.0
	_expect(is_equal_approx(arena.active_build.preferred_radius_percent, 35.0), "tactics slider controls build radius")
	var mode_before_panel := arena.active_build.attack_mode
	arena.hud.mode_button.pressed.emit()
	_expect(arena.active_build.attack_mode != mode_before_panel, "tactics button switches attack mode")
	arena.hud.nav_buttons["Stats"].pressed.emit()
	_expect(arena.hud.active_panel == "Stats" and not arena.hud.panels["Tactics"].visible, "panel switch closes previous panel")
	arena.hud.nav_buttons["Stats"].pressed.emit()
	_expect(arena.hud.active_panel == "" and not arena.hud.panel_host.visible, "active panel closes on second selection")
	arena._on_projectile_requested(arena.FORMATION_CENTER, Vector2.ZERO, 10.0, 100.0)
	var in_flight_projectile := arena.get_children().back() as PhysicalProjectile
	arena.hero.receive_hit(1000.0)
	_expect(arena.run_ended, "hero death ends run")
	_expect(in_flight_projectile.is_queued_for_deletion(), "run end clears in-flight projectiles")
	arena.restart_run()
	_expect(not arena.run_ended and arena.hero.is_alive, "restart creates a living hero")
	_expect(is_equal_approx(arena.active_build.preferred_radius_percent, 35.0), "restart retains positioning configuration")
	arena.queue_free()
	await process_frame
	var zoom_arena := CombatArena.new()
	zoom_arena.camera_zoom = 1.25
	root.add_child(zoom_arena)
	_expect(zoom_arena.world_camera.zoom == Vector2(1.25, 1.25), "camera zoom is configurable independently of combat")
	_expect(zoom_arena.formation_radius == 70.0, "camera zoom does not alter formation radius")
	zoom_arena.queue_free()
	await process_frame


func _test_hud_layout() -> void:
	var original_size := root.size
	var hud := CombatHud.new()
	root.add_child(hud)
	await process_frame
	_expect(hud.panels.size() == 6 and hud.nav_buttons.size() == 6, "six modular panels and navigation buttons exist")
	for panel_name in CombatHud.PANEL_NAMES:
		_expect(hud.panels[panel_name] is CombatPanel, panel_name + " uses modular panel foundation")
	for window_size in [Vector2i(960, 540), Vector2i(480, 270), Vector2i(320, 270), Vector2i(1280, 720)]:
		root.size = window_size
		await process_frame
		hud.select_panel("Character")
		await process_frame
		_expect(hud.root_control.size.x > 0.0 and hud.bottom_stack.size.x > 0.0, "HUD has usable width at " + str(window_size))
		var top_end := hud.status_bar.get_global_rect().end.y
		var bottom_start := hud.bottom_stack.get_global_rect().position.y
		_expect(bottom_start >= top_end, "expanded panel does not overlap status at " + str(window_size))
		_expect(hud.bottom_stack.get_global_rect().end.y <= hud.root_control.size.y, "bottom bar stays within viewport at " + str(window_size))
		_expect(hud.nav_bar.get_global_rect().end.y <= hud.root_control.size.y, "navigation remains visible at " + str(window_size))
		_expect(hud.panel_host.size.y <= hud.root_control.size.y * 0.30 + 1.0, "expanded panel uses at most 30 percent height at " + str(window_size))
		_expect(absf(hud.panel_host.size.y - hud.root_control.size.y * 0.30) <= 1.0, "expanded panel occupies about 30 percent height at " + str(window_size))
		for panel_name in CombatHud.PANEL_NAMES:
			var button_rect: Rect2 = hud.nav_buttons[panel_name].get_global_rect()
			var nav_rect := hud.nav_bar.get_global_rect()
			_expect(nav_rect.encloses(button_rect), panel_name + " navigation remains inside bar at " + str(window_size))
			if hud.active_panel != panel_name:
				hud.select_panel(panel_name)
				await process_frame
			var panel_rect: Rect2 = hud.panels[panel_name].get_global_rect()
			_expect(panel_rect.end.x <= hud.root_control.size.x and panel_rect.position.x >= 0.0, panel_name + " panel fits viewport width at " + str(window_size))
			_expect(panel_rect.end.y <= hud.nav_bar.get_global_rect().position.y, panel_name + " panel stays above navigation at " + str(window_size))
		hud.restart_button.visible = true
		hud._update_layout()
		await process_frame
		_expect(hud.bottom_stack.get_global_rect().position.y >= hud.status_bar.get_global_rect().end.y, "restart state does not overlap bottom panels at " + str(window_size))
		_expect(hud.status_bar.get_global_rect().encloses(hud.restart_button.get_global_rect()), "restart control stays within status bar at " + str(window_size))
		hud.restart_button.visible = false
		hud._update_layout()
		hud.select_panel(hud.active_panel)
		await process_frame
	_expect(hud.active_panel == "" and hud.nav_bar.visible, "navigation persists with panels closed")
	root.size = original_size
	hud.queue_free()
	await process_frame
