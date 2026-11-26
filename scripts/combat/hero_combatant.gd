extends Combatant
class_name HeroCombatant

signal projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float)
signal fireball_requested(origin: Vector2, destination: Vector2, damage: float, speed: float)
signal tank_heal_requested
signal selection_requested(hero: HeroCombatant)

var build: HeroBuildConfig
var formation_center := Vector2.ZERO
var formation_radius := 70.0
var enemies: Array = []
var attack_timer := 0.0
var passive_state := HeroPassiveState.new()
var current_target: Combatant
var idle_direction := Vector2.ZERO
var display_name := "Hero"
var is_selected := false
var attack_block_reason := "No target"
const DISTANCE_TOLERANCE := 1.0


func _ready() -> void:
	super._ready()
	collision_layer = 1
	collision_mask = 0
	input_pickable = true


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selection_requested.emit(self)
		get_viewport().set_input_as_handled()


func configure_build(new_build: HeroBuildConfig) -> void:
	build = new_build
	configure(build.stats)
	attack_timer = 0.0
	current_target = null
	attack_block_reason = "No target"
	passive_state = HeroPassiveState.new()
	if build.class_definition != null:
		passive_state.heal_seconds = build.class_definition.tank_heal_interval
		if build.archetype == HeroBuildConfig.Archetype.ASSASSIN:
			passive_state.stealth_seconds = build.class_definition.assassin_stealth_seconds


func effective_attack_speed() -> float:
	var multiplier := 1.0
	if build != null and build.archetype == HeroBuildConfig.Archetype.ARCHER and passive_state.active_seconds > 0.0 and build.class_definition != null:
		multiplier = build.class_definition.archer_speed_multiplier
	return maxf(0.1, stats.attacks_per_second * multiplier)


func stealth_priority() -> float:
	if build != null and build.archetype == HeroBuildConfig.Archetype.ASSASSIN and passive_state.stealth_seconds > 0.0 and build.class_definition != null:
		return clampf(build.class_definition.assassin_stealth_priority, 0.01, 1.0)
	return 1.0


func record_skill_cast() -> void:
	if is_alive and build != null and passive_state.record_skill_cast(build.class_definition):
		_launch_mage_fireballs()


func active_attack_range() -> float:
	if build.attack_mode == HeroBuildConfig.AttackMode.MELEE:
		return build.melee_range
	return stats.attack_range


func step_behavior(delta: float) -> void:
	if not is_alive or build == null:
		attack_block_reason = "Defeated"
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if passive_state.advance(delta, build.class_definition):
		tank_heal_requested.emit()
	var normal_limit := minf(formation_radius, formation_radius * clampf(build.preferred_radius_percent / 100.0, 0.0, 1.0) + build.radial_tolerance)
	if build.archetype == HeroBuildConfig.Archetype.ASSASSIN and passive_state.incursion_seconds <= 0.0 and global_position.distance_to(formation_center) > normal_limit:
		current_target = null
		attack_block_reason = "Retreating from incursion"
		var retreat_direction := (global_position - formation_center).normalized()
		global_position = global_position.move_toward(formation_center + retreat_direction * normal_limit, stats.movement_speed * delta)
		return
	global_position = _inside_allowed_region(global_position)
	if build.archetype == HeroBuildConfig.Archetype.TANK:
		current_target = CombatRules.nearest_living(formation_center, enemies)
		if current_target == null:
			attack_block_reason = "No target"
			global_position = global_position.move_toward(formation_center, stats.movement_speed * delta)
		else:
			_step_tank(delta)
		return

	if idle_direction.is_zero_approx():
		var start_offset := global_position - formation_center
		idle_direction = start_offset.normalized() if not start_offset.is_zero_approx() else Vector2.RIGHT
	global_position = _inside_allowed_region(global_position)
	current_target = _select_non_tank_target()
	if current_target == null:
		if attack_block_reason != "No reachable target":
			attack_block_reason = "No target detected"
		var preferred := formation_center + idle_direction * formation_radius * clampf(build.preferred_radius_percent / 100.0, 0.0, 1.0)
		if global_position.distance_to(preferred) > build.radial_tolerance:
			global_position = _inside_allowed_region(global_position.move_toward(preferred, stats.movement_speed * delta))
		return

	var attack_range := active_attack_range()
	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()
		return
	attack_block_reason = "Cooldown" if attack_timer > 0.0 else "Closing distance"

	var away := global_position - current_target.global_position
	if away.is_zero_approx():
		away = formation_center - current_target.global_position
	if away.is_zero_approx():
		away = idle_direction
	var distance := global_position.distance_to(current_target.global_position)
	if distance > attack_range or (attack_timer > 0.0 and distance < attack_range - DISTANCE_TOLERANCE):
		var desired := current_target.global_position + away.normalized() * attack_range
		var limited := _inside_allowed_region(desired)
		global_position = _inside_allowed_region(global_position.move_toward(limited, stats.movement_speed * delta))

	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()
	elif attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) > attack_range and global_position.is_equal_approx(_inside_allowed_region(global_position)):
		attack_block_reason = "Out of range"


func _select_non_tank_target() -> Combatant:
	var detection_range := active_attack_range() * 1.1
	var release_range := detection_range + build.radial_tolerance
	var definition := build.class_definition
	var detected_unreachable := false
	if build.archetype == HeroBuildConfig.Archetype.ASSASSIN and definition != null:
		var hunting_target: EnemyCombatant = null
		var best_hunt := definition.assassin_hunting_range * definition.assassin_hunting_range
		for candidate in enemies:
			if is_instance_valid(candidate) and candidate is EnemyCombatant and candidate.is_alive and candidate.ranged:
				var distance: float = global_position.distance_squared_to(candidate.global_position)
				if distance <= best_hunt and (candidate.global_position.distance_to(formation_center) <= formation_radius or passive_state.incursion_cooldown <= 0.0 or candidate == current_target and passive_state.incursion_seconds > 0.0):
					hunting_target = candidate
					best_hunt = distance
		if hunting_target != null:
			if hunting_target.global_position.distance_to(formation_center) > formation_radius and passive_state.incursion_seconds <= 0.0:
				passive_state.incursion_seconds = definition.assassin_incursion_seconds
				passive_state.incursion_cooldown = definition.assassin_incursion_seconds + definition.assassin_incursion_cooldown
			return hunting_target
	if is_instance_valid(current_target) and current_target.is_alive:
		if global_position.distance_to(current_target.global_position) <= release_range and (not current_target is EnemyCombatant or not current_target.ranged or _target_is_reachable(current_target)) and (build.archetype != HeroBuildConfig.Archetype.ASSASSIN or passive_state.incursion_seconds > 0.0 or current_target.global_position.distance_to(formation_center) <= formation_radius):
			return current_target
	var nearest: Combatant = null
	var best_distance := detection_range * detection_range
	for candidate in enemies:
		if not is_instance_valid(candidate) or not candidate is Combatant or not candidate.is_alive:
			continue
		if build.archetype == HeroBuildConfig.Archetype.ASSASSIN and passive_state.incursion_cooldown > 0.0 and passive_state.incursion_seconds <= 0.0 and candidate.global_position.distance_to(formation_center) > formation_radius:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance <= best_distance and candidate is EnemyCombatant and candidate.ranged and not _target_is_reachable(candidate):
			detected_unreachable = true
			continue
		if distance <= best_distance:
			nearest = candidate
			best_distance = distance
	if nearest != null:
		var direction := nearest.global_position - formation_center
		if not direction.is_zero_approx():
			idle_direction = direction.normalized()
	elif detected_unreachable:
		attack_block_reason = "No reachable target"
	return nearest


func _target_is_reachable(candidate: Combatant) -> bool:
	if not is_instance_valid(candidate):
		return false
	if build.archetype == HeroBuildConfig.Archetype.ASSASSIN and passive_state.incursion_seconds > 0.0 and build.class_definition != null:
		return candidate.global_position.distance_to(formation_center) <= formation_radius + build.class_definition.assassin_incursion_distance + active_attack_range() + DISTANCE_TOLERANCE
	var radial_limit := minf(formation_radius, formation_radius * clampf(build.preferred_radius_percent / 100.0, 0.0, 1.0) + build.radial_tolerance)
	return candidate.global_position.distance_to(formation_center) <= radial_limit + active_attack_range() + DISTANCE_TOLERANCE


func _inside_radial_region(point: Vector2) -> Vector2:
	var limit := minf(formation_radius, formation_radius * clampf(build.preferred_radius_percent / 100.0, 0.0, 1.0) + build.radial_tolerance)
	var offset := point - formation_center
	if offset.length_squared() <= limit * limit:
		return point
	return formation_center + offset.normalized() * limit


func _inside_allowed_region(point: Vector2) -> Vector2:
	if build.archetype == HeroBuildConfig.Archetype.ASSASSIN and passive_state.incursion_seconds > 0.0 and build.class_definition != null:
		var limit := formation_radius + build.class_definition.assassin_incursion_distance
		var offset := point - formation_center
		return point if offset.length_squared() <= limit * limit else formation_center + offset.normalized() * limit
	return _inside_radial_region(point)

func _step_tank(delta: float) -> void:
	var attack_range := active_attack_range()
	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()
		return
	attack_block_reason = "Cooldown" if attack_timer > 0.0 else "Intercepting"
	# Intercept the enemy on the side facing the party, without crossing the formation edge.
	var intercept := current_target.global_position.move_toward(formation_center, attack_range * 0.8)
	var preferred := CombatRules.preferred_point(formation_center, current_target.global_position, formation_radius, build.preferred_radius_percent)
	var desired := _inside_formation(intercept.lerp(preferred, 0.25))
	global_position = _inside_formation(global_position.move_toward(desired, stats.movement_speed * delta))
	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()


func _attack_current_target() -> void:
	if not is_instance_valid(current_target) or not current_target.is_alive:
		attack_block_reason = "Target invalid"
		return
	var damage := stats.damage * (build.class_definition.damage_multiplier if build.class_definition != null else 1.0)
	if build.attack_mode == HeroBuildConfig.AttackMode.MELEE and build.archetype == HeroBuildConfig.Archetype.ASSASSIN and current_target is EnemyCombatant and current_target.ranged and build.class_definition != null:
		damage *= build.class_definition.assassin_ranged_damage_multiplier
	var trigger_fireballs := passive_state.record_basic(build.class_definition)
	attack_timer = 1.0 / effective_attack_speed()
	attack_block_reason = "Attacked"
	if build.attack_mode == HeroBuildConfig.AttackMode.MELEE:
		current_target.receive_hit(damage, self)
	else:
		projectile_requested.emit(global_position, current_target.global_position, damage, build.projectile_speed)
	if trigger_fireballs:
		_launch_mage_fireballs()


func _launch_mage_fireballs() -> void:
	if build.class_definition == null:
		return
	var targets: Array[EnemyCombatant] = []
	for candidate in enemies:
		if is_instance_valid(candidate) and candidate is EnemyCombatant and candidate.is_alive:
			targets.append(candidate)
	targets.sort_custom(func(a: EnemyCombatant, b: EnemyCombatant) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	if targets.is_empty():
		return
	for index in range(maxi(0, build.class_definition.mage_fireball_count)):
		var target := targets[index % targets.size()]
		fireball_requested.emit(global_position, target.global_position, build.class_definition.skill_damage * build.class_definition.mage_fireball_damage_multiplier, build.class_definition.mage_fireball_speed)


func _inside_formation(point: Vector2) -> Vector2:
	var offset := point - formation_center
	if offset.length_squared() <= formation_radius * formation_radius:
		return point
	return formation_center + offset.normalized() * maxf(0.0, formation_radius)



func _draw() -> void:
	var colors := [Color("#5dc8ca"), Color("#b58bee"), Color("#59a9ed"), Color("#f2aa68")]
	var color: Color = colors[build.archetype] if build != null else colors[2]
	draw_rect(Rect2(-6, -6, 12, 12), color)
	if is_selected:
		draw_rect(Rect2(-9, -9, 18, 18), Color("#f7dc7b"), false, 1.0)
	draw_rect(Rect2(-7, -11, 14, 3), Color("#1e2a3b"))
	draw_rect(Rect2(-7, -11, 14 * health_fraction(), 3), Color("#6de098"))
