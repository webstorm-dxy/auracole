extends RefCounted
class_name IndustryRuntimeStore

const LAYOUT_PATH := "user://placement_industry_layout.json"
const SNAPSHOT_PATH := "user://production_snapshot.json"
const MAP_VIEW_PATH := "user://industry_map_view.json"


static func load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func save_json_dictionary(path: String, payload: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true


static func stable_stringify(value: Variant) -> String:
	return JSON.stringify(value)
