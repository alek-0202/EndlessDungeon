extends RefCounted
class_name HeroPassiveState

var basic_count := 0
var skill_count := 0
var active_seconds := 0.0
var cooldown_seconds := 0.0
var heal_seconds := 0.0
var incursion_seconds := 0.0
var incursion_cooldown := 0.0
var stealth_seconds := 0.0
var stealth_cooldown := 0.0


func advance(delta: float, definition: ClassDefinition) -> bool:
	if definition == null:
		return false
	var was_active := active_seconds > 0.0
	active_seconds = maxf(0.0, active_seconds - delta)
	if was_active and active_seconds <= 0.0:
		cooldown_seconds = definition.archer_cooldown_seconds
	else:
		cooldown_seconds = maxf(0.0, cooldown_seconds - delta)
	incursion_seconds = maxf(0.0, incursion_seconds - delta)
	incursion_cooldown = maxf(0.0, incursion_cooldown - delta)
	if stealth_seconds > 0.0:
		stealth_seconds = maxf(0.0, stealth_seconds - delta)
		if stealth_seconds <= 0.0:
			stealth_cooldown = definition.assassin_stealth_cooldown
	else:
		stealth_cooldown = maxf(0.0, stealth_cooldown - delta)
		if stealth_cooldown <= 0.0 and definition.archetype == HeroBuildConfig.Archetype.ASSASSIN:
			stealth_seconds = definition.assassin_stealth_seconds
	if definition.archetype == HeroBuildConfig.Archetype.TANK:
		heal_seconds -= delta
		if heal_seconds <= 0.0:
			heal_seconds = maxf(0.1, definition.tank_heal_interval)
			return true
	return false


func record_basic(definition: ClassDefinition) -> bool:
	if definition == null:
		return false
	match definition.archetype:
		HeroBuildConfig.Archetype.MAGE:
			basic_count += 1
			if basic_count >= maxi(1, definition.mage_basic_trigger):
				basic_count = 0
				skill_count = 0
				return true
		HeroBuildConfig.Archetype.ARCHER:
			if active_seconds <= 0.0 and cooldown_seconds <= 0.0:
				basic_count += 1
				if basic_count >= maxi(1, definition.archer_basic_trigger):
					basic_count = 0
					active_seconds = definition.archer_active_seconds
		HeroBuildConfig.Archetype.ASSASSIN:
			if stealth_seconds > 0.0:
				stealth_seconds = 0.0
				stealth_cooldown = definition.assassin_stealth_cooldown
	return false


func record_skill_cast(definition: ClassDefinition) -> bool:
	if definition == null or definition.archetype != HeroBuildConfig.Archetype.MAGE:
		return false
	skill_count += 1
	if skill_count >= maxi(1, definition.mage_skill_trigger):
		basic_count = 0
		skill_count = 0
		return true
	return false
