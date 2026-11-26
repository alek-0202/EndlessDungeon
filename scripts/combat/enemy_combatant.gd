extends Combatant
class_name EnemyCombatant

signal projectile_requested(origin: Vector2, destination: Vector2, damage: float, speed: float)

var heroes: Array = []
var attack_timer := 0.0
var ranged := false
var projectile_speed := 180.0
var threat: Dictionary = {}
var current_target: HeroCombatant


func _ready() -> void:
	super._ready()
	collision_layer = 2
	collision_mask = 0


func step_behavior(delta: float) -> void:
	if not is_alive:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	current_target = select_target()
	if current_target == null:
		return
	var separation := global_position.distance_to(current_target.global_position)
	if separation > stats.attack_range:
		global_position = global_position.move_toward(current_target.global_position, stats.movement_speed * delta)
	if global_position.distance_to(current_target.global_position) <= stats.attack_range and attack_timer <= 0.0:
		if ranged:
			projectile_requested.emit(global_position, current_target.global_position, stats.damage, projectile_speed)
		else:
			current_target.receive_hit(stats.damage, self)
		attack_timer = 1.0 / maxf(0.1, stats.attacks_per_second)


func receive_hit(raw_damage: float, source: Combatant = null) -> void:
	var previous_health := current_health
	super.receive_hit(raw_damage, source)
	if source is HeroCombatant and current_health < previous_health:
		var multiplier: float = source.build.threat_multiplier if source.build != null else 1.0
		threat[source] = float(threat.get(source, 0.0)) + (previous_health - current_health) * multiplier


func select_target() -> HeroCombatant:
	var chosen: HeroCombatant = null
	var best_threat := -INF
	var best_distance := INF
	for candidate in heroes:
		if not is_instance_valid(candidate) or not candidate is HeroCombatant or not candidate.is_alive:
			continue
		var candidate_threat: float = (float(threat.get(candidate, 0.0)) + 1.0) * candidate.stealth_priority()
		var distance := global_position.distance_squared_to(candidate.global_position)
		if chosen == null or candidate_threat > best_threat or (is_equal_approx(candidate_threat, best_threat) and distance < best_distance):
			chosen = candidate
			best_threat = candidate_threat
			best_distance = distance
	return chosen


func _draw() -> void:
	draw_rect(Rect2(-5, -5, 10, 10), Color("#db695e"))
	draw_rect(Rect2(-6, -10, 12, 2), Color("#35252b"))
	draw_rect(Rect2(-6, -10, 12 * health_fraction(), 2), Color("#e9b86b"))
