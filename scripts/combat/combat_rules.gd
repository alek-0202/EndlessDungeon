extends RefCounted
class_name CombatRules

# Prototype-only mitigation. Final damage and armor formulas remain open.
static func damage_after_armor(raw_damage: float, armor: float) -> float:
	if raw_damage <= 0.0:
		return 0.0
	return maxf(1.0, raw_damage - maxf(0.0, armor))


static func preferred_point(center: Vector2, threat_position: Vector2, radius: float, percent: float) -> Vector2:
	var direction := threat_position - center
	if direction.is_zero_approx():
		return center
	return center + direction.normalized() * maxf(0.0, radius) * clampf(percent / 100.0, 0.0, 1.0)


static func nearest_living(origin: Vector2, candidates: Array) -> Combatant:
	var nearest: Combatant = null
	var best_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate is Combatant or not candidate.is_alive:
			continue
		var distance: float = origin.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest
