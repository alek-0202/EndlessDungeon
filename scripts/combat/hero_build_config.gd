extends Resource
class_name HeroBuildConfig

enum AttackMode { MELEE, PROJECTILE }
enum Archetype { TANK, ASSASSIN, ARCHER, MAGE }

@export var stats: CombatStats
@export var class_definition: ClassDefinition
@export var archetype: Archetype = Archetype.ARCHER
@export_range(0.0, 100.0, 1.0) var preferred_radius_percent: float = 60.0
@export_range(0.0, 20.0, 0.5) var radial_tolerance: float = 6.0
@export_range(0.0, 10.0, 0.1) var threat_multiplier: float = 1.0
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
@export_range(1.0, 80.0, 1.0) var melee_range: float = 22.0
@export_range(1.0, 600.0, 1.0) var projectile_speed: float = 220.0
