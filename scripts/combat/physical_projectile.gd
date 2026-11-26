extends Area2D
class_name PhysicalProjectile

var velocity := Vector2.ZERO
var damage := 0.0
var remaining_life := 1.5
var spent := false
var target_heroes := false
var source_ref: WeakRef
var element := "physical"
var simulation_speed := 1.0
var simulation_paused := false
var ranged_bonus_multiplier := 1.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 if target_heroes else 2
	monitoring = true
	monitorable = false
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	collision.shape = circle
	add_child(collision)
	area_entered.connect(_on_area_entered)


func launch(origin: Vector2, destination: Vector2, speed: float, raw_damage: float, attacker: Combatant = null, hits_heroes := false, damage_element := "physical") -> void:
	global_position = origin
	velocity = (destination - origin).normalized() * speed
	damage = raw_damage
	source_ref = weakref(attacker) if is_instance_valid(attacker) else null
	target_heroes = hits_heroes
	element = damage_element
	collision_mask = 1 if target_heroes else 2


func _physics_process(delta: float) -> void:
	if simulation_paused:
		return
	delta *= simulation_speed
	global_position += velocity * delta
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not spent and area is Combatant and area.is_alive and ((target_heroes and area is HeroCombatant) or (not target_heroes and area is EnemyCombatant)):
		spent = true
		var attacker := source_ref.get_ref() as Combatant if source_ref != null else null
		var resolved_damage := damage * ranged_bonus_multiplier if area is EnemyCombatant and area.ranged else damage
		area.receive_hit(resolved_damage, attacker)
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-2, -2, 4, 4), Color("#f08c7b") if target_heroes else (Color("#ff7b36") if element == "fire" else Color("#f7dc7b")))
