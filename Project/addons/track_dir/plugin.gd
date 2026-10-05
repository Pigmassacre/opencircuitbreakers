@tool
extends EditorPlugin

var inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	inspector = TrackDirInspector.new()
	add_inspector_plugin(inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector)


class TrackDirInspector extends EditorInspectorPlugin:
	func _can_handle(object: Object) -> bool:
		return object is Session

	func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
		if name != "track_dir":
			return false
		add_property_editor(name, TrackDirEditor.new())
		return true


class TrackDirEditor extends EditorProperty:
	var options := OptionButton.new()
	var updating := false

	func _init() -> void:
		options.clip_text = true
		options.item_selected.connect(_selected)
		add_child(options)
		add_focusable(options)

	func _update_property() -> void:
		var current: String = get_edited_object().track_dir
		updating = true
		options.clear()
		options.add_item("None")
		options.set_item_metadata(0, "")
		var selected := 0
		var found := current == ""
		for path in _dirs():
			options.add_item(Session.title(path))
			options.set_item_metadata(options.item_count - 1, path)
			if path == current:
				selected = options.item_count - 1
				found = true
		if not found:
			options.add_item(current)
			options.set_item_metadata(options.item_count - 1, current)
			selected = options.item_count - 1
		options.select(selected)
		updating = false

	func _selected(index: int) -> void:
		if updating:
			return
		get_edited_object().track_dir = options.get_item_metadata(index)

	func _dirs() -> PackedStringArray:
		var root := "res://tracks"
		if Data.folder != "res://":
			root = Data.content_folder().path_join("tracks")
		var present := {}
		for folder in DirAccess.get_directories_at(root):
			if FileAccess.file_exists(root.path_join(String(folder)).path_join("track.json")):
				present[folder] = true
		var ordered := PackedStringArray()
		for world in Session.WORLDS:
			for number in range(1, 5):
				for reverse in [false, true]:
					var path := Session.directory(world, number, reverse)
					var folder := path.get_file()
					if present.has(folder):
						ordered.append(path)
						present.erase(folder)
		var extra: Array = present.keys()
		extra.sort()
		for folder in extra:
			ordered.append("res://tracks/" + String(folder))
		return ordered
