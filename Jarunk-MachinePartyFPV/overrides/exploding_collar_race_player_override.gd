extends "res://minigames/exploding_collar_race/components/player/scripts/exploding_collar_race_player.gd"

var _fpv_missing_logged: bool = false

func _process(delta: float) -> void:
	super._process(delta)

	var fpv := get_tree().root.get_node_or_null("FirstPersonViewController")
	if fpv:
		movement_input = fpv.call("rotate_movement_if_active", self, movement_input)
	elif not _fpv_missing_logged:
		_fpv_missing_logged = true
		print("[fpv_mod][collar_race_override] FirstPersonViewController node not found under /root -- movement override is not running")
