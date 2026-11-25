extends Combatant
class_name HeroCombatant

signal projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float)

var build: HeroBuildConfig
var formation_center := Vector2.ZERO
var formation_radius := 70.0
var enemies: Array = []
var attack_timer := 0.0
var current_target: Combatant
const DISTANCE_TOLERANCE := 1.0


func _ready() -> void:
	super._ready()
	collision_layer = 1
	collision_mask = 0


func configure_build(new_build: HeroBuildConfig) -> void:
	build = new_build
	configure(build.stats)
	attack_timer = 0.0


func active_attack_range() -> float:
	if build.attack_mode == HeroBuildConfig.AttackMode.MELEE:
		return build.melee_range
	return stats.attack_range


func step_behavior(delta: float) -> void:
	if not is_alive or build == null:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	global_position = _inside_formation(global_position)
	current_target = CombatRules.nearest_living(global_position, enemies)
	if current_target == null:
		global_position = global_position.move_toward(formation_center, stats.movement_speed * delta)
		return

	var attack_range := active_attack_range()
	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()
		return

	var away := global_position - current_target.global_position
	if away.is_zero_approx():
		away = formation_center - current_target.global_position
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var distance := global_position.distance_to(current_target.global_position)
	if distance > attack_range or distance < attack_range - DISTANCE_TOLERANCE:
		var desired := current_target.global_position + away.normalized() * attack_range
		global_position = _inside_formation(global_position.move_toward(desired, stats.movement_speed * delta))
	elif attack_timer > 0.0:
		_move_toward_radial_preference(delta, away.normalized(), attack_range)

	if attack_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= attack_range:
		_attack_current_target()


func _attack_current_target() -> void:
	if not is_instance_valid(current_target) or not current_target.is_alive:
		return
	attack_timer = 1.0 / maxf(0.1, stats.attacks_per_second)
	if build.attack_mode == HeroBuildConfig.AttackMode.MELEE:
		current_target.receive_hit(stats.damage)
	else:
		projectile_requested.emit(global_position, current_target.global_position, stats.damage, build.projectile_speed)


func _inside_formation(point: Vector2) -> Vector2:
	var offset := point - formation_center
	if offset.length_squared() <= formation_radius * formation_radius:
		return point
	return formation_center + offset.normalized() * maxf(0.0, formation_radius)


func _move_toward_radial_preference(delta: float, away: Vector2, attack_range: float) -> void:
	var preferred := CombatRules.preferred_point(
		formation_center, current_target.global_position, formation_radius, build.preferred_radius_percent
	)
	var toward_preferred := preferred - global_position
	var tangent := toward_preferred - away * toward_preferred.dot(away)
	if tangent.length_squared() <= DISTANCE_TOLERANCE * DISTANCE_TOLERANCE:
		return
	var candidate := global_position + tangent.normalized() * minf(tangent.length(), stats.movement_speed * delta)
	candidate = current_target.global_position + (candidate - current_target.global_position).normalized() * attack_range
	candidate = _inside_formation(candidate)
	if absf(candidate.distance_to(current_target.global_position) - attack_range) > DISTANCE_TOLERANCE:
		return
	if candidate.distance_to(preferred) + DISTANCE_TOLERANCE >= global_position.distance_to(preferred):
		return
	global_position = global_position.move_toward(candidate, stats.movement_speed * delta)


func _draw() -> void:
	draw_rect(Rect2(-6, -6, 12, 12), Color("#59a9ed"))
	draw_rect(Rect2(-7, -11, 14, 3), Color("#1e2a3b"))
	draw_rect(Rect2(-7, -11, 14 * health_fraction(), 3), Color("#6de098"))
