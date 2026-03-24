extends TextureProgressBar
@export var unit: Unit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not unit and get_parent() is Unit:
		unit = get_parent()
	if unit:
		await unit.ready 
		
		max_value = unit.max_hp
		value = unit.hp
		if not unit.health_changed.is_connected(_on_health_changed):
			unit.health_changed.connect(_on_health_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_health_changed(new_hp:int) -> void:
	value = new_hp
