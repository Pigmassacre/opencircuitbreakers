extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var source := ""
	var addon := ""
	var out := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("data")
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		if arg == "--addon":
			i += 1
			addon = args[i]
		elif arg == "--out":
			i += 1
			out = args[i]
		else:
			source = arg
		i += 1
	if source == "":
		print("Usage: godot --headless --path Project -s res://scripts/export_cli.gd -- <cue|bin|iso|folder> [--addon path] [--out path]")
		print("Writes tracks, cars, audio, and editor tilesets. The default output folder is data next to the project.")
		quit(1)
		return
	var exporter = load("res://scripts/content_export.gd").new()
	exporter.echo = true
	var message: String = exporter.extract(source, addon, out)
	if message != "":
		print(message)
		quit(1)
		return
	print("wrote " + out)
	quit()
