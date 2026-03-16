extends SceneTree

func _init():
	print("Loading Unit script...")
	var s = load("res://scripts/unit.gd")
	print(s)
	quit()
