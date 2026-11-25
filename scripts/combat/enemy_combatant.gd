extends Combatant
class_name EnemyCombatant

var heroes: Array = []
var attack_timer := 0.0


func _ready() -> void:
	super._ready()
	collision_layer = 2
	collision_mask = 0


func step_behavior(delta: float) -> void:
	if not is_alive:
		return
	var hero := CombatRules.nearest_living(global_position, heroes) as HeroCombatant
	if hero == null:
		return
	var separation := global_position.distance_to(hero.global_position)
	if separation > stats.attack_range:
		global_position = global_position.move_toward(hero.global_position, stats.movement_speed * delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	if global_position.distance_to(hero.global_position) <= stats.attack_range and attack_timer <= 0.0:
		hero.receive_hit(stats.damage)
		attack_timer = 1.0 / maxf(0.1, stats.attacks_per_second)


func _draw() -> void:
	draw_rect(Rect2(-5, -5, 10, 10), Color("#db695e"))
	draw_rect(Rect2(-6, -10, 12, 2), Color("#35252b"))
	draw_rect(Rect2(-6, -10, 12 * health_fraction(), 2), Color("#e9b86b"))
