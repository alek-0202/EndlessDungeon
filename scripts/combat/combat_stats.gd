extends Resource
class_name CombatStats

@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 100.0, 0.5) var damage: float = 12.0
@export_range(0.0, 100.0, 0.5) var armor: float = 2.0
@export_range(1.0, 300.0, 1.0) var attack_range: float = 100.0
@export_range(0.1, 10.0, 0.1) var attacks_per_second: float = 1.0
@export_range(0.0, 300.0, 1.0) var movement_speed: float = 75.0
