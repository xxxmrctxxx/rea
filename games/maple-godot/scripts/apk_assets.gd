extends RefCounted
## Loads images extracted from the APK (tools/extract_apk_assets.py) at run
## time. They live in res://assets/apk/, which is git-ignored; every caller
## must handle null and fall back to drawn shapes.

const DIR := "res://assets/apk/"

## Default look (full-body art) and HUD portrait for each job.
const JOB_ART := {
	"warrior": "art_02",
	"magician": "art_01",
	"bowman": "art_03",
	"thief": "art_10",
	"pirate": "art_06",
}
const LOOKS := ["art_01", "art_02", "art_03", "art_06", "art_07", "art_09", "art_10", "art_11", "art_12", "art_13"]

static var _cache := {}


static func tex(asset_name: String) -> Texture2D:
	if _cache.has(asset_name):
		return _cache[asset_name]
	var result: Texture2D = null
	var path := DIR + asset_name + ".png"
	var file := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(file) or FileAccess.file_exists(path):
		var image := Image.load_from_file(file)
		if image != null and not image.is_empty():
			result = ImageTexture.create_from_image(image)
	_cache[asset_name] = result
	return result


static func available() -> bool:
	return tex("title_bg") != null


static func portrait(job: String) -> Texture2D:
	return tex("job_" + job)


static func look_for(progress: Dictionary) -> Texture2D:
	return tex(progress.get("look", JOB_ART.get(progress.job, "")))
