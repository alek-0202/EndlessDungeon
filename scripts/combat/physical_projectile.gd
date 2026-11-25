extends Area2D
class_name PhysicalProjectile

var velocity := Vector2.ZERO
var damage := 0.0
var remaining_life := 1.5
var spent := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = false
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	collision.shape = circle
	add_child(collision)
	area_entered.connect(_on_area_entered)


func launch(origin: Vector2, destination: Vector2, speed: float, raw_damage: float) -> void:
	global_position = origin
	velocity = (destination - origin).normalized() * speed
	damage = raw_damage


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not spent and area is EnemyCombatant and area.is_alive:
		spent = true
		area.receive_hit(damage)
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-2, -2, 4, 4), Color("#f7dc7b"))
