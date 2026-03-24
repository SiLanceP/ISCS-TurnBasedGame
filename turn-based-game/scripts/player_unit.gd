extends Unit
class_name PlayerUnit

@export var role: String = "Fighter" # e.g. "Healer", "Mage", "Fighter", "Rogue"

func get_commands() -> Array:
	var cmds = [
		{"id": "attack", "name": "Attack", "target": "enemy"},
		{"id": "defend", "name": "Defend", "target": "self"},
		{"id": "charge", "name": "Charge", "target": "self"},
	]
	match role:
		"Healer":
			cmds.append({"id": "heal", "name": "Heal", "target": "ally"})
		"Mage":
			cmds.append({"id": "magic", "name": "Fireball", "target": "enemy"})
		"Rogue":
			cmds.append({"id": "item", "name": "Potion", "target": "ally"})
		"Fighter":
			cmds.append({"id": "power_strike", "name": "Power Strike", "target": "enemy"})
	if potion_count > 0:
		cmds.append({"id": "item", "name": "Potion", "target": "ally"}) # add potion at the end
	return cmds
