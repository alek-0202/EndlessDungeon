extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var requested_width := 960 if OS.get_cmdline_user_args().has("--small") else 1920
	var requested_height := 540 if requested_width == 960 else 1080
	DisplayServer.window_set_size(Vector2i(requested_width, requested_height))
	var arena := load("res://scenes/main/combat_arena.tscn").instantiate() as CombatArena
	root.add_child(arena)
	arena.hud.select_panel("Sandbox")
	arena.hud.sandbox._select_section("Attributes")
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("HUD capture unavailable")
		quit(1)
		return
	var destination := "user://hud_capture_%d.png" % requested_width
	var result := image.save_png(destination)
	print("HUD_CAPTURE path=%s size=%s result=%d" % [ProjectSettings.globalize_path(destination), image.get_size(), result])
	quit(0 if result == OK else 1)
