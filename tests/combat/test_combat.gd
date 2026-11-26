extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rules()
	_test_hero_behavior()
	_test_kiting_mode(HeroBuildConfig.AttackMode.MELEE)
	_test_kiting_mode(HeroBuildConfig.AttackMode.PROJECTILE)
	_test_radial_preference(HeroBuildConfig.AttackMode.MELEE)
	_test_radial_preference(HeroBuildConfig.AttackMode.PROJECTILE)
	_test_threat_and_tank_interception()
	_test_class_passive_state()
	_test_assassin_hunting()
	_test_archer_reliability()
	await _test_projectile_collision()
	await _test_freed_projectile_sources()
	await _test_enemy_projectile_interception()
	await _test_arena_lifecycle()
	await _test_class_and_sandbox_integration()
	await _test_sandbox_selection_and_controls()
	await _test_party_stress()
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


func _test_class_passive_state() -> void:
	var mage := ClassDefinition.new()
	mage.archetype = HeroBuildConfig.Archetype.MAGE
	var mage_state := HeroPassiveState.new()
	for index in range(4):
		_expect(not mage_state.record_basic(mage), "mage basic counter waits for fifth attack")
	_expect(mage_state.record_basic(mage), "mage fifth basic triggers fireballs")
	_expect(mage_state.basic_count == 0 and mage_state.skill_count == 0, "mage activation resets both counters")
	mage_state.record_basic(mage)
	_expect(not mage_state.record_skill_cast(mage), "mage first skill cast waits")
	_expect(not mage_state.record_skill_cast(mage), "mage second skill cast waits")
	_expect(mage_state.record_skill_cast(mage), "mage third skill cast triggers fireballs")
	_expect(mage_state.basic_count == 0 and mage_state.skill_count == 0, "skill activation resets both counters")
	var archer := ClassDefinition.new()
	archer.archetype = HeroBuildConfig.Archetype.ARCHER
	var archer_state := HeroPassiveState.new()
	for index in range(10):
		archer_state.record_basic(archer)
	_expect(is_equal_approx(archer_state.active_seconds, 5.0), "archer activates after ten basic attacks")
	for index in range(10):
		archer_state.record_basic(archer)
	_expect(archer_state.basic_count == 0 and archer_state.active_seconds == 5.0, "archer does not count or refresh during activation")
	archer_state.advance(5.0, archer)
	_expect(archer_state.active_seconds == 0.0 and is_equal_approx(archer_state.cooldown_seconds, 10.0), "archer starts ten second cooldown after expiration")
	for index in range(10):
		archer_state.record_basic(archer)
	_expect(archer_state.basic_count == 0, "archer does not count during cooldown")
	archer_state.advance(10.0, archer)
	archer_state.record_basic(archer)
	_expect(archer_state.basic_count == 1, "archer counts again after cooldown")
	var archer_hero := HeroCombatant.new()
	var archer_build := HeroBuildConfig.new()
	archer_build.stats = CombatStats.new()
	archer_build.class_definition = archer
	archer_build.archetype = HeroBuildConfig.Archetype.ARCHER
	archer_hero.configure_build(archer_build)
	archer_hero.passive_state.active_seconds = 5.0
	_expect(is_equal_approx(archer_hero.effective_attack_speed(), archer_hero.stats.attacks_per_second * 1.5), "archer passive multiplies current attack speed")
	archer_hero.free()


func _test_assassin_hunting() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var build: HeroBuildConfig = preload("res://data/combat/assassin_build.tres").duplicate(true)
	build.stats = build.stats.duplicate(true)
	build.class_definition = build.class_definition.duplicate(true)
	build.stats.damage = 1.0
	build.class_definition.assassin_incursion_seconds = 0.5
	var assassin := HeroCombatant.new()
	container.add_child(assassin)
	assassin.configure_build(build)
	assassin.formation_center = Vector2.ZERO
	assassin.formation_radius = 70.0
	assassin.global_position = Vector2(45, 0)
	var ranged_enemy := EnemyCombatant.new()
	container.add_child(ranged_enemy)
	var enemy_stats := CombatStats.new()
	enemy_stats.max_health = 1000
	enemy_stats.armor = 0.0
	ranged_enemy.configure(enemy_stats)
	ranged_enemy.ranged = true
	ranged_enemy.global_position = Vector2(105, 0)
	var melee_enemy := EnemyCombatant.new()
	container.add_child(melee_enemy)
	melee_enemy.configure(enemy_stats)
	melee_enemy.global_position = Vector2(65, 0)
	assassin.enemies = [melee_enemy, ranged_enemy]
	assassin.step_behavior(0.1)
	_expect(assassin.current_target == ranged_enemy, "assassin prioritizes ranged enemy within hunting range")
	_expect(assassin.passive_state.incursion_seconds > 0.0, "assassin begins timed incursion")
	for index in range(3):
		assassin.step_behavior(0.1)
	_expect(assassin.global_position.distance_to(Vector2.ZERO) > 70.0, "assassin can temporarily leave formation")
	assassin.global_position = Vector2(85, 0)
	var outside_position := assassin.global_position
	assassin.step_behavior(0.6)
	_expect(assassin.current_target == null and assassin.global_position.x < outside_position.x, "expired incursion retreats toward formation")
	assassin.passive_state.stealth_seconds = 3.0
	_expect(assassin.stealth_priority() < 1.0, "assassin stealth lowers enemy targeting priority")
	assassin.current_target = melee_enemy
	assassin.attack_timer = 0.0
	assassin.global_position = melee_enemy.global_position - Vector2(10, 0)
	assassin._attack_current_target()
	_expect(is_zero_approx(assassin.passive_state.stealth_seconds) and assassin.passive_state.stealth_cooldown > 0.0, "attacking breaks stealth and starts cooldown")
	assassin.passive_state.stealth_seconds = 3.0
	var other := HeroCombatant.new()
	container.add_child(other)
	var other_build := HeroBuildConfig.new()
	other_build.stats = enemy_stats
	other.configure_build(other_build)
	ranged_enemy.heroes = [assassin, other]
	ranged_enemy.threat.clear()
	_expect(ranged_enemy.select_target() == other, "stealth reduces target priority when another hero is valid")
	other.is_alive = false
	_expect(ranged_enemy.select_target() == assassin, "stealthed assassin remains targetable alone")
	var stealth_projectile := PhysicalProjectile.new()
	container.add_child(stealth_projectile)
	stealth_projectile.launch(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, ranged_enemy, true)
	var health_before_collision := assassin.current_health
	stealth_projectile._on_area_entered(assassin)
	_expect(assassin.current_health < health_before_collision, "stealth does not prevent projectile collision")
	var intercepted := PhysicalProjectile.new()
	container.add_child(intercepted)
	intercepted.launch(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, assassin)
	intercepted.ranged_bonus_multiplier = 2.0
	var melee_before := melee_enemy.current_health
	intercepted._on_area_entered(melee_enemy)
	_expect(is_equal_approx(melee_before - melee_enemy.current_health, 10.0), "assassin projectile interception does not give ranged bonus to melee enemy")
	var ranged_hit := PhysicalProjectile.new()
	container.add_child(ranged_hit)
	ranged_hit.launch(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, assassin)
	ranged_hit.ranged_bonus_multiplier = 2.0
	var ranged_before := ranged_enemy.current_health
	ranged_hit._on_area_entered(ranged_enemy)
	_expect(is_equal_approx(ranged_before - ranged_enemy.current_health, 20.0), "assassin projectile bonus follows actual ranged target")
	container.queue_free()


func _test_archer_reliability() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var build: HeroBuildConfig = preload("res://data/combat/archer_build.tres").duplicate(true)
	build.stats = build.stats.duplicate(true)
	build.class_definition = build.class_definition.duplicate(true)
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2.ZERO
	hero.formation_radius = 110.0
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	var enemy_stats := CombatStats.new()
	enemy_stats.max_health = 100000.0
	enemy.configure(enemy_stats)
	enemy.global_position = Vector2(100, 0)
	hero.enemies = [enemy]
	var shots := [0]
	hero.projectile_requested.connect(func(_origin: Vector2, _destination: Vector2, _damage: float, _speed: float) -> void: shots[0] += 1)
	var saw_active := false
	var saw_cooldown := false
	var saw_recount := false
	var shots_after_cooldown := 0
	for frame in range(360):
		hero.step_behavior(0.1)
		saw_active = saw_active or hero.passive_state.active_seconds > 0.0
		saw_cooldown = saw_cooldown or hero.passive_state.cooldown_seconds > 0.0
		saw_recount = saw_recount or (saw_cooldown and hero.passive_state.cooldown_seconds <= 0.0 and hero.passive_state.basic_count > 0)
		if frame == 260:
			shots_after_cooldown = shots[0]
	_expect(shots[0] > 30 and shots[0] > shots_after_cooldown, "archer keeps attacking after passive activation and cooldown")
	_expect(saw_active and saw_cooldown and saw_recount, "archer passive transitions and resumes counting")
	hero.current_target = enemy
	enemy.free()
	var replacement := EnemyCombatant.new()
	container.add_child(replacement)
	replacement.configure(enemy_stats)
	replacement.global_position = Vector2(105, 0)
	hero.enemies = [enemy, replacement]
	hero.attack_timer = 0.0
	hero.step_behavior(0.1)
	_expect(hero.current_target == replacement and shots[0] > shots_after_cooldown, "archer reacquires after target is freed")
	var unreachable := EnemyCombatant.new()
	container.add_child(unreachable)
	unreachable.configure(enemy_stats)
	unreachable.ranged = true
	unreachable.global_position = Vector2(200, 0)
	hero.enemies = [unreachable, replacement]
	hero.current_target = unreachable
	hero.attack_timer = 0.0
	hero.step_behavior(0.1)
	_expect(hero.current_target == replacement, "archer releases stationary ranged target outside permitted attack region")
	replacement.free()
	hero.enemies = [unreachable]
	hero.step_behavior(0.1)
	_expect(hero.current_target == null and hero.attack_block_reason.contains("target"), "archer reports unreachable target instead of silently retaining it")
	container.queue_free()


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
	nearby.global_position = Vector2(120, 100)
	var distant := EnemyCombatant.new()
	container.add_child(distant)
	distant.configure(stats)
	distant.global_position = Vector2(100, 200)
	hero.enemies = [nearby, distant]
	hero.step_behavior(0.1)
	_expect(hero.current_target == nearby, "nearest detected target selected")
	_expect(hero.global_position == Vector2(100, 100), "ready melee attack stops movement")
	_expect(nearby.current_health < stats.max_health, "melee attack applies damage in range")
	var prior_health := nearby.current_health
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
	nearby.heroes = [hero, second_hero]
	nearby.threat.clear()
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
	build.preferred_radius_percent = 100.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2.ZERO
	hero.formation_radius = 70.0
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	var effective_range := hero.active_attack_range()
	enemy.global_position = Vector2(effective_range + 1.0, 0)
	hero.enemies = [enemy]
	var projectiles := [0]
	hero.projectile_requested.connect(func(_origin: Vector2, _destination: Vector2, _damage: float, _speed: float) -> void: projectiles[0] += 1)

	hero.step_behavior(0.1)
	_expect(hero.current_target == enemy and hero.global_position == Vector2(1, 0), label + " acquires within 110 percent and approaches only to range")
	_expect(hero.attack_timer > 0.0, label + " attacks immediately on entering range")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < stats.max_health, "melee hit occurs on entry")
	else:
		_expect(projectiles[0] == 1, "ranged shot occurs on entry")

	enemy.global_position = Vector2(hero.global_position.x + effective_range - 10.0, 0)
	var attacks_before: int = projectiles[0]
	var health_before := enemy.current_health
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(-9, 0), label + " retreats to maximum range during cooldown")
	_expect(is_equal_approx(hero.attack_timer, 0.9), label + " movement does not reset cooldown")
	_expect(projectiles[0] == attacks_before and is_equal_approx(enemy.current_health, health_before), label + " cooldown prevents early attack")
	hero.step_behavior(0.4)
	_expect(hero.global_position == Vector2(-9, 0), label + " does not oscillate at maximum range")
	_expect(is_equal_approx(hero.attack_timer, 0.5), label + " cooldown continues while stationary")
	hero.step_behavior(0.5)
	_expect(hero.global_position == Vector2(-9, 0), label + " ready attack does not move")
	_expect(hero.attack_timer > 0.0, label + " attacks immediately when cooldown ends")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < health_before, "melee repeats at cooldown end")
	else:
		_expect(projectiles[0] == attacks_before + 1, "ranged shot repeats at cooldown end")

	hero.global_position = Vector2.ZERO
	enemy.global_position = Vector2(effective_range + 0.5, 0)
	hero.attack_timer = 0.0
	attacks_before = projectiles[0]
	health_before = enemy.current_health
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(0.5, 0), label + " closes a fractional range gap")
	if mode == HeroBuildConfig.AttackMode.MELEE:
		_expect(enemy.current_health < health_before, "melee attacks without delay at range edge")
	else:
		_expect(projectiles[0] == attacks_before + 1, "ranged attack fires without delay at range edge")

	build.preferred_radius_percent = 0.0
	build.radial_tolerance = 6.0
	hero.global_position = Vector2(6, 0)
	enemy.global_position = Vector2.ZERO
	hero.attack_timer = 0.5
	hero.step_behavior(0.1)
	_expect(hero.global_position.length() <= 6.0, label + " kiting respects configured radial region")
	container.queue_free()

func _test_radial_preference(mode: int) -> void:
	var label := "melee" if mode == HeroBuildConfig.AttackMode.MELEE else "projectile"
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.attack_range = 20.0
	stats.movement_speed = 100.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	build.attack_mode = mode
	build.melee_range = 20.0
	build.preferred_radius_percent = 50.0
	build.radial_tolerance = 4.0
	var hero := HeroCombatant.new()
	container.add_child(hero)
	hero.configure_build(build)
	hero.formation_center = Vector2.ZERO
	hero.formation_radius = 70.0
	hero.global_position = Vector2(35, 0)
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	enemy.global_position = Vector2(80, 0)
	hero.enemies = [enemy]
	hero.step_behavior(0.1)
	_expect(hero.current_target == null and hero.global_position == Vector2(35, 0), label + " distant enemy is not acquired or chased")
	enemy.global_position = Vector2(57, 0)
	hero.step_behavior(0.1)
	_expect(hero.current_target == enemy and hero.global_position == Vector2(37, 0), label + " enemy at 110 percent detection enters attack range")
	_expect(hero.attack_timer > 0.0, "attack is immediate on entering range")
	stats.movement_speed = 0.0
	enemy.global_position = Vector2(61, 0)
	var closer_enemy := EnemyCombatant.new()
	container.add_child(closer_enemy)
	closer_enemy.configure(stats)
	closer_enemy.global_position = Vector2(38, 0)
	hero.enemies = [enemy, closer_enemy]
	hero.step_behavior(0.1)
	_expect(hero.current_target == enemy, label + " target persists despite a closer candidate")
	hero.enemies = [enemy]
	enemy.global_position = Vector2(65, 0)
	hero.step_behavior(0.1)
	_expect(hero.current_target == null, label + " target releases beyond engagement distance")
	stats.movement_speed = 100.0
	hero.global_position = Vector2(20, 0)
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(30, 0), "idle hero returns toward preferred radius")
	hero.step_behavior(0.1)
	_expect(hero.global_position == Vector2(35, 0), "idle hero reaches preferred radius")
	var idle_position := hero.global_position
	for frame in range(5):
		hero.step_behavior(0.05)
		_expect(hero.global_position == idle_position, "idle hero does not oscillate")
	build.preferred_radius_percent = 0.0
	hero.step_behavior(0.1)
	_expect(hero.global_position.length() <= build.radial_tolerance, label + " radial tolerance bounds center build")
	enemy.global_position = Vector2(25, 0)
	hero.attack_timer = 0.5
	hero.step_behavior(0.1)
	_expect(hero.current_target == enemy and hero.global_position.length() <= build.radial_tolerance, label + " detected enemy cannot pull hero beyond configured region")
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
	projectile.launch(Vector2(0, 40), Vector2(100, 40), 300.0, 10.0, hero)
	for frame in range(20):
		await physics_frame
	_expect(enemy.current_health < stats.max_health, "physical projectile hits enemy through Area2D collision")
	_expect(enemy.threat.get(hero, 0.0) > 0.0, "projectile damage generates threat for its source")
	_expect(is_equal_approx(behind.current_health, stats.max_health), "front enemy intercepts projectile before rear enemy")
	_expect(is_equal_approx(hero.current_health, stats.max_health), "projectile ignores invalid friendly target")
	container.queue_free()
	await process_frame


func _test_freed_projectile_sources() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 30.0
	stats.armor = 0.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	var hero_source := HeroCombatant.new()
	container.add_child(hero_source)
	hero_source.configure_build(build)
	var enemy_target := EnemyCombatant.new()
	container.add_child(enemy_target)
	enemy_target.configure(stats)
	enemy_target.global_position = Vector2(50, 40)
	var hero_projectile := PhysicalProjectile.new()
	container.add_child(hero_projectile)
	hero_projectile.launch(Vector2(0, 40), enemy_target.global_position, 300.0, 10.0, hero_source)
	hero_source.free()
	for frame in range(20):
		await physics_frame
	_expect(enemy_target.current_health < stats.max_health and enemy_target.threat.is_empty(), "hero projectile damages after source is freed without stale attribution")
	var enemy_source := EnemyCombatant.new()
	container.add_child(enemy_source)
	enemy_source.configure(stats)
	var hero_target := HeroCombatant.new()
	container.add_child(hero_target)
	hero_target.configure_build(build)
	hero_target.global_position = Vector2(50, 80)
	var enemy_projectile := PhysicalProjectile.new()
	container.add_child(enemy_projectile)
	enemy_projectile.launch(Vector2(0, 80), hero_target.global_position, 300.0, 10.0, enemy_source, true)
	enemy_source.free()
	for frame in range(20):
		await physics_frame
	_expect(hero_target.current_health < stats.max_health, "enemy projectile damages after source is freed")
	var dead_source := HeroCombatant.new()
	container.add_child(dead_source)
	dead_source.configure_build(build)
	var second_enemy_target := EnemyCombatant.new()
	container.add_child(second_enemy_target)
	second_enemy_target.configure(stats)
	second_enemy_target.global_position = Vector2(50, 120)
	var late_projectile := PhysicalProjectile.new()
	container.add_child(late_projectile)
	late_projectile.launch(Vector2(0, 120), second_enemy_target.global_position, 300.0, 10.0, dead_source)
	dead_source.receive_hit(1000.0)
	for frame in range(20):
		await physics_frame
	_expect(second_enemy_target.current_health < stats.max_health and second_enemy_target.threat.get(dead_source, 0.0) > 0.0, "projectile preserves attribution while defeated source still exists")
	container.queue_free()
	await process_frame


func _test_threat_and_tank_interception() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 100.0
	stats.armor = 0.0
	stats.movement_speed = 100.0
	var tank_build := HeroBuildConfig.new()
	tank_build.stats = stats
	tank_build.archetype = HeroBuildConfig.Archetype.TANK
	tank_build.threat_multiplier = 3.0
	tank_build.melee_range = 20.0
	var archer_build := HeroBuildConfig.new()
	archer_build.stats = stats
	archer_build.archetype = HeroBuildConfig.Archetype.ARCHER
	var tank := HeroCombatant.new()
	container.add_child(tank)
	tank.configure_build(tank_build)
	tank.formation_center = Vector2.ZERO
	tank.formation_radius = 70.0
	tank.global_position = Vector2(10, 0)
	var archer := HeroCombatant.new()
	container.add_child(archer)
	archer.configure_build(archer_build)
	archer.global_position = Vector2(40, 0)
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	enemy.global_position = Vector2(15, 0)
	enemy.heroes = [tank, archer]
	_expect(enemy.select_target() == tank, "enemy initially chooses nearest hero")
	enemy.receive_hit(10.0, archer)
	_expect(is_equal_approx(enemy.threat[archer], 10.0) and enemy.select_target() == archer, "damage threat overrides distance")
	enemy.receive_hit(5.0, tank)
	_expect(is_equal_approx(enemy.threat[tank], 15.0) and enemy.select_target() == tank, "configurable tank threat modifier applies")
	var other_enemy := EnemyCombatant.new()
	container.add_child(other_enemy)
	other_enemy.configure(stats)
	other_enemy.global_position = Vector2(39, 0)
	other_enemy.heroes = [tank, archer]
	_expect(other_enemy.select_target() == archer and other_enemy.threat.is_empty(), "each enemy has an independent threat table")
	other_enemy.ranged = true
	stats.attack_range = 100.0
	var enemy_shots := [0]
	other_enemy.projectile_requested.connect(func(_origin: Vector2, _destination: Vector2, _damage: float, _speed: float) -> void: enemy_shots[0] += 1)
	var archer_health := archer.current_health
	other_enemy.step_behavior(0.1)
	_expect(enemy_shots[0] == 1 and is_equal_approx(archer.current_health, archer_health), "ranged enemy fires a projectile instead of direct damage")
	archer.receive_hit(1000.0)
	_expect(other_enemy.select_target() == tank, "dead heroes are not targeted")
	enemy.global_position = Vector2(150, 0)
	tank.enemies = [enemy]
	tank.attack_timer = 0.5
	tank.step_behavior(0.5)
	_expect(tank.global_position == Vector2(60, 0), "tank approaches interception instead of retreating")
	tank.step_behavior(0.5)
	_expect(tank.global_position.length() <= tank.formation_radius, "tank remains inside formation boundary")
	enemy.global_position = Vector2(50, 0)
	tank.global_position = Vector2(70, 0)
	tank.attack_timer = 2.0
	tank_build.preferred_radius_percent = 0.0
	tank.step_behavior(1.0)
	var inner_intercept := tank.global_position.x
	tank.global_position = Vector2(70, 0)
	tank.attack_timer = 2.0
	tank_build.preferred_radius_percent = 100.0
	tank.step_behavior(1.0)
	_expect(tank.global_position.x > inner_intercept and tank.global_position.length() <= tank.formation_radius, "tank radial setting softly adjusts interception")
	container.queue_free()


func _test_enemy_projectile_interception() -> void:
	var container := Node2D.new()
	root.add_child(container)
	var stats := CombatStats.new()
	stats.max_health = 30.0
	stats.armor = 0.0
	var build := HeroBuildConfig.new()
	build.stats = stats
	var front := HeroCombatant.new()
	container.add_child(front)
	front.configure_build(build)
	front.global_position = Vector2(50, 40)
	var rear := HeroCombatant.new()
	container.add_child(rear)
	rear.configure_build(build)
	rear.global_position = Vector2(80, 40)
	var enemy := EnemyCombatant.new()
	container.add_child(enemy)
	enemy.configure(stats)
	enemy.global_position = Vector2(0, 40)
	var projectile := PhysicalProjectile.new()
	container.add_child(projectile)
	projectile.launch(enemy.global_position, rear.global_position, 300.0, 10.0, enemy, true)
	for frame in range(20):
		await physics_frame
	_expect(front.current_health < stats.max_health, "front hero intercepts enemy projectile")
	_expect(is_equal_approx(rear.current_health, stats.max_health), "rear hero is protected by collision")
	_expect(is_equal_approx(enemy.current_health, stats.max_health), "enemy shot ignores its own side")
	container.queue_free()
	await process_frame


func _test_arena_lifecycle() -> void:
	var arena := CombatArena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	_expect(CombatArena.ARENA_SIZE == Vector2(1280, 720), "party arena expands world space")
	_expect(is_equal_approx(arena.formation_radius, 110.0), "party formation expands")
	_expect(arena.world_camera.zoom == Vector2(0.8, 0.8), "camera zoom is separate from combat")
	_expect(arena.heroes.size() == 4 and arena.active_builds.size() == 4, "four independent heroes and builds")
	for index in range(4):
		_expect(arena.heroes[index].build == arena.active_builds[index], "hero uses its own active build")
		_expect(arena.heroes[index].formation_radius == arena.formation_radius, "hero shares formation boundary")
	_expect(arena.active_builds[0].preferred_radius_percent == 90.0, "tank radial default")
	_expect(arena.active_builds[1].preferred_radius_percent == 75.0, "assassin radial default")
	_expect(arena.active_builds[2].preferred_radius_percent == 30.0, "archer radial default")
	_expect(arena.active_builds[3].preferred_radius_percent == 15.0, "mage radial default")
	_expect(arena.heroes[0].stats != arena.heroes[1].stats, "heroes have independent stats resources")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 960, "internal viewport width remains 960")
	_expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 540, "internal viewport height remains 540")
	_expect(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "nearest texture filtering remains configured")
	_expect(arena.enemies.size() == 1, "arena starts with an enemy")
	_expect(arena.enemies[0].global_position.x == 40.0, "left spawn")
	var second := arena.spawn_enemy()
	var third := arena.spawn_enemy()
	var fourth := arena.spawn_enemy()
	_expect(second.global_position.y == 40.0, "top spawn")
	_expect(third.global_position.x == 1240.0, "right spawn")
	_expect(fourth.global_position.y == 600.0, "bottom spawn")
	_expect(third.ranged, "party arena includes ranged enemies")
	arena.hud.hero_buttons[2].pressed.emit()
	_expect(arena.selected_hero_index == 2 and arena.heroes[2].is_selected and not arena.heroes[0].is_selected, "character selector highlights archer")
	arena._on_radius_changed(25.0)
	_expect(is_equal_approx(arena.active_builds[2].preferred_radius_percent, 25.0), "HUD radius updates selected build")
	_expect(is_equal_approx(arena.active_builds[0].preferred_radius_percent, 90.0), "other build remains independent")
	arena.hud.nav_buttons["Tactics"].pressed.emit()
	_expect(arena.hud.active_panel == "Tactics" and arena.hud.panel_host.visible, "tactics panel opens")
	var timer_before_panel := arena.spawn_timer
	arena._physics_process(0.1)
	_expect(arena.spawn_timer < timer_before_panel, "open panel does not pause combat")
	arena.hud.radius_slider.value = 35.0
	_expect(is_equal_approx(arena.active_builds[2].preferred_radius_percent, 35.0), "tactics slider controls selected build")
	var mode_before_panel: int = arena.active_builds[2].attack_mode
	arena.hud.mode_button.pressed.emit()
	_expect(arena.active_builds[2].attack_mode != mode_before_panel, "tactics button switches selected attack mode")
	arena.hud.nav_buttons["Stats"].pressed.emit()
	_expect(arena.hud.active_panel == "Stats" and not arena.hud.panels["Tactics"].visible, "panel switch closes previous panel")
	arena.hud.nav_buttons["Stats"].pressed.emit()
	_expect(arena.hud.active_panel == "" and not arena.hud.panel_host.visible, "active panel closes on second selection")
	_expect(arena.hud.hero_buttons.size() == 4 and arena.hud.hero_buttons[0].health_label.text.contains("HP") and arena.hud.hero_buttons[3].title_label.text.contains("MAGE"), "persistent party cards show identity and health")
	arena._on_enemy_projectile_requested(Vector2.ZERO, Vector2.RIGHT, 10.0, 100.0, arena.enemies[0])
	var in_flight_projectile := arena.get_children().back() as PhysicalProjectile
	arena.heroes[2].receive_hit(1000.0)
	_expect(not arena.run_ended and not arena.heroes[2].is_alive, "individual death leaves run active")
	for index in [0, 1, 3]:
		arena.heroes[index].receive_hit(1000.0)
	_expect(arena.run_ended, "last hero death ends run")
	_expect(in_flight_projectile.is_queued_for_deletion(), "party defeat clears in-flight projectiles")
	arena.restart_run()
	_expect(not arena.run_ended and arena.heroes.all(func(hero: HeroCombatant) -> bool: return hero.is_alive), "restart creates living party")
	_expect(is_equal_approx(arena.active_builds[2].preferred_radius_percent, 35.0), "restart retains per-hero positioning")
	arena.queue_free()
	await process_frame
	var zoom_arena := CombatArena.new()
	zoom_arena.camera_zoom = 1.25
	root.add_child(zoom_arena)
	zoom_arena.set_physics_process(false)
	_expect(zoom_arena.world_camera.zoom == Vector2(1.25, 1.25), "camera zoom remains configurable")
	_expect(zoom_arena.formation_radius == 110.0, "camera zoom does not alter formation radius")
	zoom_arena.queue_free()
	await process_frame

func _test_class_and_sandbox_integration() -> void:
	var arena := CombatArena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	_expect(arena.heroes[0].build.class_definition != null and arena.heroes[0].passive_state != arena.heroes[1].passive_state, "class definitions exist with independent runtime state")
	_expect(arena.heroes[0].stats.max_health > arena.heroes[1].stats.max_health and arena.heroes[0].stats.movement_speed > arena.heroes[2].stats.movement_speed, "tank natural health and mobility advantages")
	_expect(arena.heroes[2].stats.damage > arena.heroes[3].stats.damage and arena.heroes[3].build.class_definition.skill_damage > arena.heroes[2].build.class_definition.skill_damage, "archer basic and mage skill advantages")
	var mage := arena.heroes[3]
	mage.enemies = arena.enemies
	var fireballs := [0]
	var elements := []
	mage.fireball_requested.connect(func(_origin: Vector2, _destination: Vector2, damage: float, _speed: float) -> void:
		fireballs[0] += 1
		elements.append(damage)
	)
	mage.record_skill_cast()
	mage.record_skill_cast()
	mage.record_skill_cast()
	_expect(fireballs[0] == 3 and elements.all(func(value: float) -> bool: return is_equal_approx(value, mage.build.class_definition.skill_damage)), "mage skill event launches three full skill damage fireballs with repeated target")
	arena._on_hero_fireball_requested(Vector2.ZERO, Vector2.RIGHT, 2.0, 100.0, mage)
	var projectile := arena.get_children().back() as PhysicalProjectile
	_expect(projectile.element == "fire", "fire projectile keeps element tag for future damage types")
	projectile.queue_free()
	arena._on_hero_projectile_requested(Vector2.ZERO, Vector2.RIGHT, 2.0, 100.0, arena.heroes[1])
	var assassin_projectile := arena.get_children().back() as PhysicalProjectile
	_expect(is_equal_approx(assassin_projectile.ranged_bonus_multiplier, arena.heroes[1].build.class_definition.assassin_ranged_damage_multiplier), "arena carries assassin ranged bonus to projectile collision")
	assassin_projectile.queue_free()
	for hero in arena.heroes:
		hero.current_health = hero.stats.max_health * 0.5
	arena._on_tank_heal_requested(arena.heroes[0])
	_expect(arena.heroes.all(func(hero: HeroCombatant) -> bool: return is_equal_approx(hero.health_fraction(), 0.55)), "tank divides twenty percentage points equally among four wounded heroes")
	for hero in arena.heroes:
		hero.current_health = hero.stats.max_health
	arena.heroes[1].current_health = arena.heroes[1].stats.max_health * 0.5
	arena._on_tank_heal_requested(arena.heroes[0])
	_expect(is_equal_approx(arena.heroes[1].health_fraction(), 0.7), "single wounded hero receives twenty percent of own maximum health")
	arena.heroes[1].current_health = arena.heroes[1].stats.max_health * 0.98
	arena.heroes[2].current_health = arena.heroes[2].stats.max_health * 0.2
	arena._on_tank_heal_requested(arena.heroes[0])
	_expect(is_equal_approx(arena.heroes[1].health_fraction(), 1.0) and is_equal_approx(arena.heroes[2].health_fraction(), 0.38), "unused tank healing is redistributed to lowest health percentage")
	arena._on_sandbox_command("add_hero", {"class_id": HeroBuildConfig.Archetype.MAGE})
	_expect(arena.heroes.size() == 5 and arena.heroes[4].build.archetype == HeroBuildConfig.Archetype.MAGE, "Sandbox adds duplicate class without restart")
	arena.sandbox_max_heroes = 5
	arena._on_sandbox_command("add_hero", {"class_id": HeroBuildConfig.Archetype.TANK})
	_expect(arena.heroes.size() == 5, "Sandbox enforces configurable hero limit")
	arena.hud.nav_buttons["Sandbox"].pressed.emit()
	_expect(arena.hud.active_panel == "Sandbox", "development Sandbox opens in existing HUD")
	arena.hud.sandbox.hero_controls["damage"].value = 41.0
	_expect(is_equal_approx(arena.heroes[4].stats.damage, 41.0), "Sandbox control applies selected hero edit live")
	arena._on_sandbox_command("hero_value", {"index": 4, "field": "damage", "value": 42.0})
	_expect(is_equal_approx(arena.heroes[4].stats.damage, 42.0) and not is_equal_approx(arena.heroes[3].stats.damage, 42.0) and not is_equal_approx(arena.mage_build.stats.damage, 42.0), "Sandbox hero override is isolated from peers and class template")
	arena._on_sandbox_command("passive_value", {"index": 4, "field": "mage_basic_trigger", "value": 2.0})
	_expect(arena.heroes[4].build.class_definition.mage_basic_trigger == 2 and arena.heroes[3].build.class_definition.mage_basic_trigger == 5, "passive override is isolated")
	arena._on_sandbox_command("hero_value", {"index": 0, "field": "attack_range", "value": 36.0})
	_expect(is_equal_approx(arena.heroes[0].active_attack_range(), 36.0), "Sandbox attack range edit affects active melee mode")
	arena._on_sandbox_command("hero_value", {"index": 4, "field": "damage", "value": -100.0})
	_expect(is_zero_approx(arena.heroes[4].stats.damage), "Sandbox clamps invalid negative damage")
	arena._on_sandbox_command("hero_value", {"index": 4, "field": "not_a_stat", "value": 100.0})
	_expect(is_zero_approx(arena.heroes[4].stats.damage), "Sandbox ignores unknown fields")
	arena._on_sandbox_command("auto_spawn", {"value": false})
	arena._on_sandbox_command("pause", {})
	arena._on_hero_projectile_requested(Vector2.ZERO, Vector2.RIGHT, 5.0, 100.0, arena.heroes[0])
	var paused_projectile := arena.get_children().back() as PhysicalProjectile
	var paused_position := paused_projectile.global_position
	paused_projectile._physics_process(1.0)
	_expect(paused_projectile.global_position == paused_position, "Sandbox pause also freezes projectiles")
	var prior_timer := arena.spawn_timer
	arena._physics_process(1.0)
	_expect(is_equal_approx(arena.spawn_timer, prior_timer), "paused Sandbox simulation does not advance")
	arena._on_sandbox_command("resume", {})
	arena._on_sandbox_command("simulation_speed", {"value": 2.0})
	arena._physics_process(0.1)
	_expect(is_equal_approx(arena.spawn_timer, prior_timer - 0.2), "Sandbox speed changes simulation time")
	arena._on_sandbox_command("enemy_value", {"field": "damage", "value": 17.0})
	arena._on_sandbox_command("spawn_ranged", {})
	_expect(arena.enemies.back().ranged and is_equal_approx(arena.enemies.back().stats.damage, 17.0), "manual ranged spawn uses live enemy override")
	arena._on_sandbox_command("clear_enemies", {})
	_expect(arena.enemies.is_empty(), "Sandbox clears enemies")
	arena._on_sandbox_command("formation_radius", {"value": 160.0})
	_expect(is_equal_approx(arena.heroes[0].formation_radius, 160.0), "formation radius updates living heroes")
	arena._on_sandbox_command("restore_defaults", {})
	_expect(is_equal_approx(arena.heroes[4].stats.damage, arena.mage_build.stats.damage) and arena.auto_spawn and is_equal_approx(arena.formation_radius, 110.0), "restore defaults clears runtime overrides without rebuilding party")
	for index in range(4, -1, -1):
		arena._on_sandbox_command("remove_hero", {"index": index})
	_expect(arena.heroes.is_empty() and arena.run_ended, "Sandbox safely removes entire party")
	arena.restart_run()
	_expect(arena.run_ended and arena.heroes.is_empty(), "restart with empty composition remains ended")
	arena._on_sandbox_command("add_hero", {"class_id": HeroBuildConfig.Archetype.TANK})
	_expect(arena.heroes.size() == 1 and not arena.run_ended, "Sandbox supports solo party after empty party")
	arena._on_sandbox_command("hero_value", {"index": 0, "field": "current_health", "value": 0.0})
	_expect(arena.run_ended and not arena.heroes[0].is_alive, "Sandbox health edit can end solo run")
	arena._on_sandbox_command("hero_value", {"index": 0, "field": "current_health", "value": 10.0})
	_expect(not arena.run_ended and arena.heroes[0].is_alive, "Sandbox health edit can resume solo run")
	arena.queue_free()
	await process_frame


func _test_sandbox_selection_and_controls() -> void:
	var arena := CombatArena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.hud.select_panel("Sandbox")
	_expect(arena.hud.hero_buttons.size() == 4 and arena.hud.hero_buttons[1].hero == arena.heroes[1], "persistent hero cards match party identities")
	var archer := arena.heroes[2]
	arena.hud.hero_buttons[2].pressed.emit()
	_expect(arena.heroes[arena.selected_hero_index] == archer and arena.hud.hero_buttons[2].highlighted, "hero card selects and highlights Archer")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arena.heroes[3]._input_event(root, click, 0)
	_expect(arena.selected_hero_index == 3 and arena.hud.hero_buttons[3].highlighted, "arena character click uses same selected hero state")
	arena.select_hero(2)
	arena._on_sandbox_command("remove_hero", {"index": 0})
	_expect(arena.heroes[arena.selected_hero_index] == archer and arena.hud.hero_buttons[arena.selected_hero_index].hero == archer, "removing earlier hero preserves selection by identity")
	var existing_card := arena.hud.hero_buttons[arena.selected_hero_index]
	arena._on_sandbox_command("duplicate_hero", {"hero_id": archer.get_instance_id()})
	_expect(arena.heroes.size() == 4 and arena.heroes.back().build.archetype == HeroBuildConfig.Archetype.ARCHER and arena.heroes.back().build != archer.build, "duplicate hero gets independent build")
	_expect(arena.hud.hero_buttons[1] == existing_card, "surviving card is retained when party changes")
	arena.hud.sandbox._select_section("Attributes")
	var damage_spin: SpinBox = arena.hud.sandbox.hero_controls["damage"]
	damage_spin.value = 33.0
	_expect(is_equal_approx(arena.heroes.back().stats.damage, 33.0), "selected hero attribute section edits runtime value")
	var old_speed: float = arena.heroes.back().effective_attack_speed()
	arena.heroes.back().attack_timer = 0.8
	arena._on_sandbox_command("hero_value", {"hero_id": arena.heroes.back().get_instance_id(), "field": "attacks_per_second", "value": 2.2})
	_expect(is_equal_approx(arena.heroes.back().attack_timer, 0.8 * old_speed / arena.heroes.back().effective_attack_speed()), "live attack speed edit rescales remaining cooldown")
	arena.hud.sandbox._select_section("Passives")
	arena._on_sandbox_command("passive_value", {"hero_id": arena.heroes.back().get_instance_id(), "field": "archer_basic_trigger", "value": 2.0})
	_expect(arena.heroes.back().build.class_definition.archer_basic_trigger == 2, "selected passive section edits runtime copy")
	arena._on_sandbox_command("reset_passive", {"hero_id": arena.heroes.back().get_instance_id()})
	_expect(arena.heroes.back().build.class_definition.archer_basic_trigger == 10, "passive reset restores selected class default")
	arena._on_sandbox_command("reset_hero", {"hero_id": arena.heroes.back().get_instance_id()})
	_expect(is_equal_approx(arena.heroes.back().stats.damage, arena.archer_build.stats.damage), "hero reset restores selected attributes")
	arena.hud.sandbox._select_section("Enemies")
	arena.hud.sandbox.ranged_slider.value = 0.6
	_expect(is_equal_approx(arena.ranged_ratio, 0.6), "enemy ratio slider applies global setting")
	arena._on_sandbox_command("enemy_value", {"field": "damage", "value": 25.0})
	arena._on_sandbox_command("reset_enemies", {})
	_expect(is_equal_approx(arena.active_melee_stats.damage, arena.melee_enemy_stats.damage), "enemy reset restores global defaults")
	arena.hud.sandbox._select_section("Simulation")
	arena.hud.sandbox.speed_slider.value = 1.5
	_expect(is_equal_approx(arena.simulation_speed, 1.5), "simulation slider applies speed")
	arena.hud.sandbox.pause_resume_button.pressed.emit()
	_expect(arena.simulation_paused and arena.hud.sandbox.pause_resume_button.text == "Resume", "quick pause remains responsive")
	arena.hud.sandbox.pause_resume_button.pressed.emit()
	_expect(not arena.simulation_paused, "quick resume works")
	arena._on_sandbox_command("pause", {})
	arena._on_sandbox_command("restart", {})
	_expect(not arena.simulation_paused and arena.heroes.size() == 4 and arena.heroes[arena.selected_hero_index].is_alive, "restart resumes paused simulation and keeps composition")
	var defeated := arena.heroes[0]
	arena._on_sandbox_command("hero_value", {"hero_id": defeated.get_instance_id(), "field": "current_health", "value": 0.0})
	_expect(not arena.hud.hero_buttons[0].disabled, "defeated hero card remains selectable for inspection")
	arena.hud.hero_buttons[0].pressed.emit()
	_expect(arena.heroes[arena.selected_hero_index] == defeated, "defeated hero selection stays synchronized")
	arena.hud.diagnostics_button.set_pressed_no_signal(true)
	arena.hud.diagnostics_panel.visible = true
	arena._update_diagnostics()
	_expect(arena.hud.diagnostics_label.text.contains("FPS") and arena.hud.diagnostics_label.text.contains("reason:"), "toggleable diagnostics show counts and attack reason")
	arena.queue_free()
	await process_frame


func _test_party_stress() -> void:
	for scenario in [[1, 20], [4, 60], [8, 100]]:
		var arena := CombatArena.new()
		root.add_child(arena)
		arena.set_physics_process(false)
		arena.auto_spawn = false
		arena._clear_enemies()
		arena.rng.seed = 4001
		while arena.heroes.size() > int(scenario[0]):
			arena._on_sandbox_command("remove_hero", {"index": arena.heroes.size() - 1})
		while arena.heroes.size() < int(scenario[0]):
			arena._on_sandbox_command("add_hero", {"class_id": HeroBuildConfig.Archetype.ARCHER})
		arena.active_melee_stats.damage = 0.0
		arena.active_ranged_stats.damage = 0.0
		for hero in arena.heroes:
			hero.stats.max_health = 100000.0
			hero.current_health = hero.stats.max_health
		for index in range(int(scenario[1])):
			arena.spawn_enemy(index % 2)
		for frame in range(60):
			arena._physics_process(1.0 / 60.0)
			await physics_frame
		_expect(arena.heroes.size() == int(scenario[0]) and arena.enemies.size() <= int(scenario[1]) and arena.selected_hero_index < arena.heroes.size(), "stress party composition remains valid: " + str(scenario))
		_expect(arena.heroes.all(func(hero: HeroCombatant) -> bool: return is_instance_valid(hero) and hero.is_alive and hero.global_position.distance_to(CombatArena.FORMATION_CENTER) <= arena.formation_radius + 1.0), "stress heroes stay valid and within approved boundary: " + str(scenario))
		arena.queue_free()
		await process_frame


func _test_hud_layout() -> void:
	var original_size := root.size
	var hud := CombatHud.new()
	root.add_child(hud)
	await process_frame
	_expect(hud.panels.size() == 7 and hud.nav_buttons.size() == 7, "seven modular panels and navigation buttons exist in development")
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
