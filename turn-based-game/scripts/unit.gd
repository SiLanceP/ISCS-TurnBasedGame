extends CharacterBody2D
class_name Unit

@export var unit_name: String = "Unit"
@export var max_hp: int = 30
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10
@export var crit_chance: float = 0.1
@export var hit_chance: float = 0.9

var hp: int
var is_defending: bool = false
var is_charging: bool = false
var last_action: String = ""

signal died

func _ready() -> void:
	hp = max_hp
	update_health_bar()

func _process(delta):
	update_health_bar()

func update_health_bar():
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		var health_bar_fill = health_bar.get_node_or_null("HealthBarFill")
		var health_bar_background = health_bar.get_node_or_null("HealthBarBackground")
		if health_bar_fill and health_bar_background:
			var health_ratio = float(hp) / float(max_hp)
			health_bar_fill.size.x = health_bar_background.size.x * health_ratio

func reset_state() -> void:
	hp = max_hp
	is_defending = false
	is_charging = false
	last_action = ""
	visible = true

func is_alive() -> bool:
	return hp > 0

func apply_damage(amount, attacker = null):
	var dmg = max(amount, 0)
	if is_defending:
		dmg = int(ceil(dmg * 0.5))
	
	hp = max(hp - dmg, 0)
	if hp == 0:
		visible = false
		emit_signal("died", self)
	return dmg

func heal(amount):
	var h = max(amount, 0)
	hp = min(hp + h, max_hp)
	return h

func get_effective_attack():
	return attack + (int(attack * 0.5) if is_charging else 0)

func finalize_turn():
	# Defend only lasts one incoming attack; reset at end of round.
	is_defending = false

func get_commands():
	return [
		{"id": "attack", "name": "Attack", "target": "enemy"},
		{"id": "defend", "name": "Defend", "target": "self"},
		{"id": "charge", "name": "Charge", "target": "self"}
	]

func perform_command(cmd_id, target, battle):
	if cmd_id == "attack":
		attack_target(target, battle)
	elif cmd_id == "defend":
		defend(battle)
	elif cmd_id == "charge":
		charge(battle)
	elif cmd_id == "power_strike":
		power_strike(target, battle)
	elif cmd_id == "magic":
		magic(target, battle)
	elif cmd_id == "heal":
		heal_ally(target, battle)
	elif cmd_id == "item":
		use_item(target, battle)
	else:
		battle.log_message("%s does nothing." % unit_name)

func attack_target(target, battle):
	if not target or not target.is_alive():
		return
	var base = get_effective_attack()
	var rand = randi_range(-2, 2)
	var dmg = max(1, base + rand - target.defense)
	var hit_roll = randf()
	if hit_roll > hit_chance:
		battle.log_message("%s's attack missed %s." % [unit_name, target.unit_name])
		last_action = "miss"
		return
	var crit = randf() < crit_chance
	if crit:
		dmg = int(dmg * 1.5)
	var dealt = target.apply_damage(dmg, self)
	battle.log_message("%s attacked %s for %d damage%s." % [unit_name, target.unit_name, dealt, (" (CRIT)" if crit else "")])
	last_action = "attack"
	is_charging = false

func defend(battle):
	is_defending = true
	battle.log_message("%s is defending." % unit_name)
	last_action = "defend"

func charge(battle):
	is_charging = true
	battle.log_message("%s is charging up their next attack!" % unit_name)
	last_action = "charge"

func magic(target, battle):
	if not target or not target.is_alive():
		return
	var base = get_effective_attack()
	var dmg = max(1, base + 5 - target.defense)
	if randf() > hit_chance:
		battle.log_message("%s's magic missed %s." % [unit_name, target.unit_name])
		last_action = "miss"
		return
	var dealt = target.apply_damage(dmg, self)
	battle.log_message("%s casts magic on %s for %d damage." % [unit_name, target.unit_name, dealt])
	last_action = "magic"
	is_charging = false

func heal_ally(target, battle):
	if not target or not target.is_alive():
		return
	var amount = 15 + randi_range(-3, 3)
	var healed = target.heal(amount)
	battle.log_message("%s healed %s for %d HP." % [unit_name, target.unit_name, healed])
	last_action = "heal"

func use_item(target, battle):
	if not target or not target.is_alive():
		return
	var healed = target.heal(20)
	battle.log_message("%s used a Potion on %s for %d HP." % [unit_name, target.unit_name, healed])
	last_action = "item"

func power_strike(target, battle):
	if not target or not target.is_alive():
		return
	var base = get_effective_attack()
	var rand = randi_range(-1, 1)
	var dmg = max(1, base + rand - target.defense)
	var hit_roll = randf()
	if hit_roll > hit_chance:
		battle.log_message("%s's Power Strike missed %s." % [unit_name, target.unit_name])
		last_action = "miss"
		return
	var crit = randf() < crit_chance
	if crit:
		dmg = int(dmg * 2.0)  # Power Strike has higher crit multiplier
	var dealt = target.apply_damage(dmg, self)
	battle.log_message("%s used Power Strike on %s for %d damage%s." % [unit_name, target.unit_name, dealt, (" (CRIT)" if crit else "")])
	last_action = "power_strike"
	is_charging = false
