extends Area2D
class_name Combatant

signal health_changed(combatant: Combatant)
signal died(combatant: Combatant)

var stats: CombatStats
var current_health: float = 0.0
var is_alive := true


func _ready() -> void:
	monitorable = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	collision.shape = circle
	add_child(collision)


func configure(new_stats: CombatStats) -> void:
	stats = new_stats
	current_health = stats.max_health
	is_alive = true
	queue_redraw()
	health_changed.emit(self)


func receive_hit(raw_damage: float, _source: Combatant = null) -> void:
	if not is_alive or stats == null:
		return
	current_health = maxf(0.0, current_health - CombatRules.damage_after_armor(raw_damage, stats.armor))
	health_changed.emit(self)
	queue_redraw()
	if current_health <= 0.0:
		is_alive = false
		died.emit(self)


func health_fraction() -> float:
	if stats == null or stats.max_health <= 0.0:
		return 0.0
	return current_health / stats.max_health


func heal(amount: float) -> void:
	if not is_alive or stats == null or amount <= 0.0:
		return
	current_health = minf(stats.max_health, current_health + amount)
	health_changed.emit(self)
	queue_redraw()
