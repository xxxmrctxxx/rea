extends RefCounted
## Local save in user://save.json.

const Data = preload("res://scripts/game_data.gd")
const PATH := "user://save.json"


static func load_progress():
	if not FileAccess.file_exists(PATH):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY or not Data.JOBS.has(data.get("job")) or not Data.MAPS.has(data.get("map")):
		return null
	# JSON numbers come back as floats.
	for key in ["level", "exp", "meso", "weaponLv"]:
		data[key] = int(data.get(key, 0))
	for key in data.potions:
		data.potions[key] = int(data.potions[key])
	return data


static func write(progress: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(progress))
