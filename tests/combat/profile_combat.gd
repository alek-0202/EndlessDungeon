extends SceneTree

const SCENARIOS := [[1, 20, "throttled"], [4, 60, "throttled"], [8, 100, "throttled"], [8, 100, "every_frame"]]
const SAMPLES := 180


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scenario in SCENARIOS:
		var arena := CombatArena.new()
		root.add_child(arena)
		arena.set_physics_process(false)
		arena.auto_spawn = false
		arena._clear_enemies()
		arena.rng.seed = 58421
		while arena.heroes.size() > int(scenario[0]):
			arena._on_sandbox_command("remove_hero", {"index": arena.heroes.size() - 1})
		while arena.heroes.size() < int(scenario[0]):
			arena._on_sandbox_command("add_hero", {"class_id": HeroBuildConfig.Archetype.ARCHER})
		for hero in arena.heroes:
			hero.stats.max_health = 100000.0
			hero.current_health = hero.stats.max_health
		for index in range(int(scenario[1])):
			var enemy := arena.spawn_enemy(index % 2)
			if enemy != null:
				enemy.stats.damage = 0.0
				enemy.stats.max_health = 100000.0
				enemy.current_health = enemy.stats.max_health
		var timings: Array[int] = []
		for frame in range(SAMPLES):
			if scenario[2] == "every_frame":
				arena.hud_refresh_timer = 0.0
			var started := Time.get_ticks_usec()
			arena._physics_process(1.0 / 60.0)
			timings.append(Time.get_ticks_usec() - started)
			await physics_frame
		timings.sort()
		var total := 0
		for timing in timings:
			total += timing
		var projectile_count := 0
		for child in arena.get_children():
			if child is PhysicalProjectile:
				projectile_count += 1
		print("PROFILE heroes=%d enemies=%d hud=%s mean_us=%.1f p95_us=%d projectiles=%d" % [arena.heroes.size(), arena.enemies.size(), scenario[2], float(total) / float(timings.size()), timings[int(timings.size() * 0.95)], projectile_count])
		arena.queue_free()
		await process_frame
	quit(0)
