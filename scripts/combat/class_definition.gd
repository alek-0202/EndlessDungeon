extends Resource
class_name ClassDefinition

# These are prototype defaults. Runtime Sandbox edits use duplicated resources.
@export var display_name := "Archer"
@export var archetype: HeroBuildConfig.Archetype = HeroBuildConfig.Archetype.ARCHER
@export var skill_damage := 10.0
@export var damage_multiplier := 1.0
@export var mage_basic_trigger := 5
@export var mage_skill_trigger := 3
@export var mage_fireball_count := 3
@export var mage_fireball_damage_multiplier := 1.0
@export var mage_fireball_speed := 240.0
@export var archer_basic_trigger := 10
@export var archer_speed_multiplier := 1.5
@export var archer_active_seconds := 5.0
@export var archer_cooldown_seconds := 10.0
@export var assassin_ranged_damage_multiplier := 1.5
@export var assassin_hunting_range := 110.0
@export var assassin_incursion_distance := 45.0
@export var assassin_incursion_seconds := 3.0
@export var assassin_incursion_cooldown := 4.0
@export var assassin_stealth_seconds := 3.0
@export var assassin_stealth_cooldown := 8.0
@export var assassin_stealth_priority := 0.25
@export var tank_heal_interval := 30.0
@export var tank_heal_budget := 0.20
