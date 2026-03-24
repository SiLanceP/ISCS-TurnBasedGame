extends CharacterBody2D
class_name Unit

@export var unit_name: String = "Unit"
@export var max_hp: int = 30
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10
@export var crit_chance: float = 0.1
@export var hit_chance: float = 0.9

@onready var health_bar = $healthbar
@onready var hp_label = $hplabel

var hp: int
var is_defending: bool = false
var is_charging: bool = false
var last_action: String = ""
var potion_count: int = 1

signal died
signal health_changed(new_hp)

func _ready() -> void:
	hp = max_hp
	update_health_bar()
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("idle")

func _process(delta):
	pass

func update_health_bar():
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp
	if hp_label:
		hp_label.text = "%d/%d" % [hp, max_hp]

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
	health_changed.emit(hp)
	update_health_bar()
	if dmg > 0:
		var effect_scene = load("res://scenes/effects.tscn")
		if effect_scene:
			var hit_effect = effect_scene.instantiate()
			get_parent().add_child(hit_effect) #add to the battle scene
			hit_effect.global_position = self.global_position #sets the hit onto the character
			var hit_scale = 1.0
			if dmg > 20:
				hit_scale = 4.5 #big boom
			elif dmg > 10:
				hit_scale = 3.0 #medium boom
			hit_effect.scale = Vector2(hit_scale,hit_scale)
			hit_effect.play("hit")
			await get_tree().create_timer(0.5).timeout
			hit_effect.queue_free()
	if hp == 0:
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("death") # Play death animation!
		else:
			visible = false
		emit_signal("died", self)
	else:
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("hurt")
			#back to idle
			await get_tree().create_timer(0.4).timeout
			if is_alive():
				$AnimatedSprite2D.play("idle")
	return dmg

func heal(amount):
	var h = max(amount, 0)
	hp = min(hp + h, max_hp)
	health_changed.emit(hp)
	update_health_bar()
	return h

func get_effective_attack():
	return attack + (int(attack * 0.8) if is_charging else 0)

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
		await attack_target(target, battle)
	elif cmd_id == "defend":
		await defend(battle)
	elif cmd_id == "charge":
		await charge(battle)
	elif cmd_id == "final_charge":
		await final_charge(battle)
	elif cmd_id == "power_strike":
		await power_strike(target, battle)
	elif cmd_id == "magic":
		await magic(target, battle)
	elif cmd_id == "heal":
		await heal_ally(target, battle)
	elif cmd_id == "item":
		use_item(target, battle)
	elif cmd_id == "ultimate":
		await ultimate_attack(battle)
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
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("attack")
			await get_tree().create_timer(1.0).timeout
			if is_alive():
				$AnimatedSprite2D.play("idle")
		return
	var crit = randf() < crit_chance
	if crit:
		dmg = int(dmg * 1.5)
	var dealt = await target.apply_damage(dmg, self)
	battle.log_message("%s attacked %s for %d damage%s." % [unit_name, target.unit_name, dealt, (" (CRIT)" if crit else "")])
	last_action = "attack"
	is_charging = false
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("attack")
		#back to idle
		await get_tree().create_timer(1.0).timeout
		if is_alive():
			$AnimatedSprite2D.play("idle")

func defend(battle):
	is_defending = true
	battle.log_message("%s is defending." % unit_name)
	last_action = "defend"
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("block")
		await get_tree().create_timer(0.5).timeout

func charge(battle):
	is_charging = true
	battle.log_message("%s is charging up their next attack!" % unit_name)
	last_action = "charge"
	
func final_charge(battle):
	is_charging = true
	battle.log_message("%s is at its final charge!" % unit_name)
	last_action = "final_charge"

func magic(target, battle):
	if not target or not target.is_alive():
		return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("magic")
		await get_tree().create_timer(0.4).timeout
	var effect_scene = load("res://scenes/effects.tscn")
	var fireball = null
	if effect_scene:
		fireball = effect_scene.instantiate()
		get_parent().add_child(fireball)
		# Set the starting position exactly where the Mage is standing
		fireball.global_position = self.global_position
		fireball.play("fireball")
		# Tween to slide the fireball over to the target
		var tween = get_tree().create_tween()
		# Move the fireball to the target over 1 second
		tween.tween_property(fireball, "global_position", target.global_position, 1.0)
		# Wait for the tween to finish moving before calculating damage
		await tween.finished
		# Fireball gets deleted after hit
		fireball.queue_free()
	var base = get_effective_attack()
	var dmg = max(1, base + 10 - target.defense)
	if randf() > hit_chance:
		battle.log_message("%s's magic missed %s." % [unit_name, target.unit_name])
		last_action = "miss"
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("idle")
		return
	var dealt = await target.apply_damage(dmg, self)
	battle.log_message("%s casts magic on %s for %d damage." % [unit_name, target.unit_name, dealt])
	last_action = "magic"
	is_charging = false
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("idle")

func heal_ally(target, battle):
	if not target or not target.is_alive():
		return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("heal")
		await get_tree().create_timer(1.0).timeout
	var effect_scene = load("res://scenes/effects.tscn") 
	var active_effect = null
	if effect_scene:
		active_effect = effect_scene.instantiate()
		target.add_child(active_effect)
		active_effect.position = Vector2(0, -2) 
		active_effect.play("heal")
	var base_heal = 15
	if is_charging:
		base_heal = int(base_heal * 1.5)
	var amount = base_heal + randi_range(-3, 3)
	var healed = target.heal(amount)
	battle.log_message("%s healed %s for %d HP." % [unit_name, target.unit_name, healed])
	last_action = "heal"
	await get_tree().create_timer(0.8).timeout
	is_charging = false
	if active_effect:
		active_effect.queue_free()
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("idle")

func use_item(target, battle):
	if potion_count <= 0:
		return
	if not target or not target.is_alive():
		return
	potion_count -= 1
	var effect_scene = load("res://scenes/effects.tscn")
	var active_effect = null
	if effect_scene:
		active_effect = effect_scene.instantiate()
		target.add_child(active_effect)
		active_effect.position = Vector2(0, -2) 
		active_effect.play("heal")
		active_effect.animation_finished.connect(active_effect.queue_free)
	var healed = target.heal(20)
	battle.log_message("%s used a Potion on %s for %d HP." % [unit_name, target.unit_name, healed])
	last_action = "item"

func power_strike(target, battle):
	if not target or not target.is_alive():
		return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("ultimate")
		await get_tree().create_timer(1.0).timeout
	var base = int(get_effective_attack() * 1.5)
	var rand = randi_range(-1, 1)
	var dmg = max(1, base + rand - target.defense)
	var hit_roll = randf()
	if hit_roll > hit_chance:
		battle.log_message("%s's Power Strike missed %s." % [unit_name, target.unit_name])
		last_action = "miss"
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play("idle")
		return
	var crit = randf() < crit_chance
	if crit:
		dmg = int(dmg * 2.0)  # Power Strike has higher crit multiplier
	var dealt = await target.apply_damage(dmg, self)
	battle.log_message("%s used Power Strike on %s for %d damage%s." % [unit_name, target.unit_name, dealt, (" (CRIT)" if crit else "")])
	last_action = "power_strike"
	is_charging = false
	if has_node("AnimatedSprite2D"):
		await get_tree().create_timer(0.7).timeout
		$AnimatedSprite2D.play("idle")

func ultimate_attack(battle): #aoe attack from the boss
	battle.log_message("%s unleashes a devastating Ultimate Attack on the whole party!" % unit_name)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("ultimate")
		await get_tree().create_timer(1.0).timeout
	var base = int(get_effective_attack() * 3.0)
	for player in battle.players:
		if player.is_alive():
			var rand = randi_range(-2, 2)
			var dmg = max(1, base + rand - player.defense)
			var hit_roll = randf()
			
			if hit_roll > hit_chance:
				battle.log_message("%s's Ultimate missed %s!" % [unit_name, player.unit_name])
				continue
				
			var crit = randf() < crit_chance
			if crit:
				dmg = int(dmg * 2.0)
			var actual_dmg = dmg
			if player.is_defending:
				actual_dmg = int(ceil(actual_dmg * 0.5))
			battle.log_message("%s took %d damage%s." % [player.unit_name, actual_dmg, (" (CRIT)" if crit else "")])
			player.apply_damage(dmg, self)
	await get_tree().create_timer(0.8).timeout
	last_action = "ultimate"
	is_charging = false
	if has_node("AnimatedSprite2D"):
		await get_tree().create_timer(0.7).timeout
		$AnimatedSprite2D.play("idle")
	
