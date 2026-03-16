extends SceneTree

func _init():
	var s = "Healer"
	match s:
		"Healer":
			print("ok")
		_:
			pass
	quit()
