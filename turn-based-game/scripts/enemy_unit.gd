extends Unit
class_name EnemyUnit

@export var behavior_type: String = "Aggressive" # "Aggressive" or "Tanker" or "Trickster"
var charge_count: int = 0

func choose_action(players: Array) -> Dictionary:
	var alive_players = []
	for p in players:
		if p.is_alive():
			alive_players.append(p)
	if alive_players.is_empty():
		return {}
	var target = alive_players[randi() % alive_players.size()]
	match behavior_type:
		"Aggressive":
			return {"id": "attack", "target": target}
		"Tanker":
			if hp < max_hp * 0.7 and not is_defending:
				return {"id": "defend", "target": self}
			if not is_defending and randf() < 0.20:
				return {"id": "defend", "target": self}
			if charge_count > 0 or randf() < 0.8:
				if charge_count < 3:
					charge_count += 1
					return {"id": "charge", "target": self}
				else:
					charge_count = 0 # Reset for next time
					return {"id": "ultimate", "target": null}
			return {"id": "attack", "target": target}
		"Trickster":
			# Charge and then unleash a strong attack
			if not is_charging and randf() < 0.4:
				return {"id": "charge", "target": self}
			return {"id": "attack", "target": target}
	#return {"id": "attack", "target": target}
	return {}
