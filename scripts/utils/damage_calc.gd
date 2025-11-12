extends Node

# Damage calculation helper per GDD:
# DMG = (6 * BASE_VALUE * (a.atk / b.def) * 0.02 + 2)
class_name DamageCalc

static func calculate_damage(base_value: float, attacker_atk: float, defender_def: float) -> int:
	# Guard against zero division
	var def = max(defender_def, 1.0)
	var atk = max(attacker_atk, 0.0)
	var dmg_f = (6.0 * base_value * (atk / def) * 0.02) + 2.0
	# Round to nearest integer, ensure at least 1 damage
	var final = int(round(dmg_f))
	return max(final, 1)
