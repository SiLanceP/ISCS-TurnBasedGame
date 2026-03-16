extends Node2D
class_name BattleManager

signal battle_ended(result: String)

var players_root: Node
var enemies_root: Node
var status_label: Label
var command_option: OptionButton
var target_option: OptionButton
var confirm_button: Button
var log_label: RichTextLabel

var players: Array = []
var enemies: Array = []
var _current_prompt_player: Node = null

func _ready() -> void:
	randomize()

	players_root = $Players
	enemies_root = $Enemies
	players = players_root.get_children()
	enemies = enemies_root.get_children()
	for unit in players + enemies:
		if unit.has_method("reset_state"):
			unit.reset_state()

	# Find UI elements
	status_label = $Control/StatusLabel
	confirm_button = $Control/ConfirmButton
	log_label = $Control/LogLabel
	
	# Find dropdowns by searching for OptionButton nodes
	command_option = get_node("CommandContainer#CommandOption")
	target_option = get_node("TargetContainer#TargetOption")

	# Initialize dropdowns as disabled
	if command_option:
		command_option.disabled = true
	if target_option:
		target_option.disabled = true

	start_battle()

var turn_queue: Array = []

func start_battle() -> void:
	log_message("A battle begins!")
	turn_queue = players + enemies
	_take_turn()

func _take_turn() -> void:
	print("Confirm button in _take_turn: ", confirm_button)
	if check_victory():
		log_message("Victory! All enemies defeated.")
		emit_signal("battle_ended", "win")
		return
	if check_defeat():
		log_message("Defeat... All party members have fallen.")
		emit_signal("battle_ended", "lose")
		return

	var unit = turn_queue.pop_front()
	if not unit.is_alive():
		turn_queue.append(unit)
		call_deferred("_take_turn")
		return

	if unit in players:
		# Enable dropdowns for player turn
		if command_option:
			command_option.disabled = false
		if target_option:
			target_option.disabled = false
			
		var selected = await prompt_player_action(unit)
		if selected:
			unit.perform_command(selected.id, selected.target, self)
			await get_tree().create_timer(0.2).timeout
	else: # an enemy
		if command_option:
			command_option.disabled = true
		if target_option:
			target_option.disabled = true
			
		if status_label:
			status_label.text = "%s is taking its turn..." % unit.unit_name
		
		await get_tree().create_timer(1.0).timeout # thinking delay

		var choice = unit.choose_action(players)
		if choice:
			unit.perform_command(choice.id, choice.target, self)
			await get_tree().create_timer(0.2).timeout
		
		if status_label:
			status_label.text = "Enemy turn is over. Press Continue to continue."
		
		if confirm_button:
			confirm_button.text = "Continue"
			await confirm_button.pressed
			confirm_button.text = "Confirm"

		if command_option:
			command_option.disabled = false
		if target_option:
			target_option.disabled = false

	turn_queue.append(unit)

	if check_victory():
		log_message("Victory! All enemies defeated.")
		emit_signal("battle_ended", "win")
		return
	if check_defeat():
		log_message("Defeat... All party members have fallen.")
		emit_signal("battle_ended", "lose")
		return
		
	call_deferred("_take_turn")



func check_victory() -> bool:
	for e in enemies:
		if e.is_alive():
			return false
	return true

func check_defeat() -> bool:
	for p in players:
		if p.is_alive():
			return false
	return true

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	else:
		print(text)

func prompt_player_action(player) -> Dictionary:
	# Show UI for selecting command + target
	_current_prompt_player = player
	if status_label:
		status_label.text = "%s (HP %d/%d) - Choose an action" % [player.unit_name, player.hp, player.max_hp]
	
	# Enable dropdowns for player turn
	if command_option:
		command_option.disabled = false
		command_option.clear()
		var commands = player.get_commands()
		
		for i in range(commands.size()):
			var cmd = commands[i]
			var idx = command_option.get_item_count()
			command_option.add_item(cmd.name)
			command_option.set_item_metadata(idx, cmd)
		
		# Select first command by default and update target list
		if commands.size() > 0:
			command_option.select(0)
			update_target_list(player, commands[0])

		# Handle command changes
		var handler = Callable(self, "_on_command_selected")
		if command_option.is_connected("item_selected", handler):
			command_option.disconnect("item_selected", handler)
		command_option.connect("item_selected", handler)

	if target_option:
		target_option.disabled = false

	# Wait for confirm
	if confirm_button:
		await confirm_button.pressed

	# Get selected command and target
	var cmd = null
	if command_option:
		var selected_idx = command_option.get_selected_id()
		cmd = command_option.get_item_metadata(selected_idx)
	
	var target = null
	if cmd:
		if cmd.target == "enemy":
			target = get_target_by_option(enemies)
		elif cmd.target == "ally":
			target = get_target_by_option(players)
		elif cmd.target == "self":
			target = player
	
	return {"id": cmd.id if cmd else "attack", "target": target if target else player}

func _on_command_selected(idx: int) -> void:
	var cmd = command_option.get_item_metadata(idx)
	if cmd and _current_prompt_player:
		update_target_list(_current_prompt_player, cmd)

func get_current_player() -> Node:
	return _current_prompt_player

func update_target_list(player, cmd) -> void:
	if not target_option:
		return
	target_option.clear()
	
	if cmd.target == "enemy":
		for enemy in enemies:
			if enemy.is_alive():
				var idx = target_option.get_item_count()
				target_option.add_item(enemy.unit_name)
				target_option.set_item_metadata(idx, enemy)
		if target_option.get_item_count() == 0:
			var idx = target_option.get_item_count()
			target_option.add_item("<No targets>")
			target_option.set_item_metadata(idx, null)
	elif cmd.target == "ally":
		for ally in players:
			if ally.is_alive():
				var idx = target_option.get_item_count()
				target_option.add_item(ally.unit_name)
				target_option.set_item_metadata(idx, ally)
	elif cmd.target == "self":
		var idx = target_option.get_item_count()
		target_option.add_item(player.unit_name)
		target_option.set_item_metadata(idx, player)
	
	# Select first target by default
	if target_option.get_item_count() > 0:
		target_option.select(0)

func get_target_by_option(group: Array) -> Unit:
	var selected_idx = target_option.get_selected_id()
	return target_option.get_item_metadata(selected_idx)
