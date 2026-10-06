extends Node

const REQUIRED := [
	"tracks/races.json",
	"tracks/names.json",
	"tracks/previews.json",
	"cars/car0/car.json",
	"cars/car0/mesh.bin",
	"cars/car0/atlas.png",
	"cars/bumper/car.json",
	"vehicles/venice/car0/car.json",
	"vehicles/swamp/car0/car.json",
	"vehicles/aqua/car0/car.json",
	"audio/sfx/vag_01.wav",
	"audio/sfx/vag_36.wav",
	"audio/music/track_2.ogg",
	"audio/music/track_9.ogg",
	"textures/particles_fire.png",
	"textures/particles_smoke.png",
	"textures/particles_ring.png",
	"textures/particles_streak.png",
	"textures/particles_arc.png",
	"textures/particles_respawn.png",
	"textures/particles_wake.png",
	"textures/items.png",
	"textures/menu/wild_west.png",
	"textures/menu/weather_0.png",
]

var folder := ""


func _ready() -> void:
	if _complete("res://"):
		folder = "res://"
		return
	var beside := content_folder()
	if _complete(beside):
		folder = beside


func content_folder() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("data")
	return OS.get_executable_path().get_base_dir().path_join("data")


func adopt(dir: String) -> bool:
	if not _complete(dir):
		return false
	folder = dir
	return true


func present() -> bool:
	return folder != ""


# A data folder left by an older version of the game, missing files this one needs.
func outdated() -> bool:
	return folder == "" and DirAccess.dir_exists_absolute(content_folder())


func path(res_path: String) -> String:
	if folder == "" or folder == "res://":
		return res_path
	return folder.path_join(res_path.trim_prefix("res://"))


func text(res_path: String) -> String:
	return FileAccess.get_file_as_string(path(res_path))


func bytes(res_path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path(res_path))


func exists(res_path: String) -> bool:
	return FileAccess.file_exists(path(res_path))


func texture(res_path: String) -> Texture2D:
	if folder == "res://":
		return load(res_path)
	var image := Image.new()
	image.load_png_from_buffer(bytes(res_path))
	return ImageTexture.create_from_image(image)


func _complete(base: String) -> bool:
	for rel in REQUIRED:
		if not _has(base, rel):
			return false
	return true


func _has(base: String, rel: String) -> bool:
	if FileAccess.file_exists(_file(base, rel)):
		return true
	if rel.ends_with(".ogg"):
		return FileAccess.file_exists(_file(base, rel.trim_suffix(".ogg") + ".wav"))
	return false


func _file(base: String, rel: String) -> String:
	if base == "res://":
		return "res://" + rel
	return base.path_join(rel)
