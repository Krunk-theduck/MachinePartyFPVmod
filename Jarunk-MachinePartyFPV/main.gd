extends Node

const MOD_ID := "first_person_view"


func _mod_init(loader) -> void:
	loader.note("fpv mod init")



func _mod_ready(loader) -> void:
	var dir: String = loader.dir_of(MOD_ID)
	if dir.is_empty():
		loader.note("fpv mod: could not resolve mod dir")
		return

	var controller_script: GDScript = loader.compile(dir.path_join("fpv_controller.gd"))
	if controller_script == null:
		loader.note("fpv mod: failed to load controller script")
		return

	var controller := Node.new()
	controller.set_script(controller_script)
	controller.name = "FirstPersonViewController"
	get_tree().root.add_child.call_deferred(controller)

	loader.note("fpv mod ready")
