extends Node2D

func _ready() -> void:
	var battle_scene = preload("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)
