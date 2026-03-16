extends Unit
class_name PlayerUnit

@export var role: String = "Fighter" # e.g. "Healer", "Mage", "Fighter", "Rogue"

func get_commands() -> Array:
	var cmds = [
		{"id": "attack", "name": "Attack", "target": "enemy"},
		{"id": "defend", "name": "Defend", "target": "self"},
		{"id": "charge", "name": "Charge", "target": "self"}
	]
	match role:
		"Healer":
			cmds.append({"id": "heal", "name": "Heal", "target": "ally"})
		"Mage":
			cmds.append({"id": "magic", "name": "Fireball", "target": "enemy"})
		"Rogue":
			cmds.append({"id": "item", "name": "Potion", "target": "ally"})
		"Fighter":
			# Fighter has only basic commands, but let's add a special ability
			cmds.append({"id": "power_strike", "name": "Power Strike", "target": "enemy"})
	return cmds
