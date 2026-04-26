extends RefCounted
class_name BlueprintStore

var save_path: String = "user://blueprints.save"
var blueprints: Array[Dictionary] = []


func _init(p_save_path: String = "user://blueprints.save") -> void:
	save_path = p_save_path


func load() -> void:
	if not FileAccess.file_exists(save_path):
		blueprints.clear()
		save()
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open blueprint save file for reading.")
		blueprints.clear()
		return

	var raw_text := file.get_as_text().strip_edges()
	file.close()
	if raw_text.is_empty():
		blueprints.clear()
		save()
		return

	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_warning("Blueprint save file is invalid. Resetting blueprint data.")
		blueprints.clear()
		save()
		return

	blueprints.clear()
	var parsed_blueprints: Array = (parsed as Dictionary).get("blueprints", [])
	for blueprint_variant in parsed_blueprints:
		var blueprint := blueprint_variant as Dictionary
		if blueprint.is_empty():
			continue
		if not blueprint.has("name"):
			continue
		blueprint["items"] = blueprint.get("items", [])
		blueprint["conveyors"] = blueprint.get("conveyors", [])
		blueprints.append(blueprint)


func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open blueprint save file for writing.")
		return

	file.store_string(JSON.stringify({
		"blueprints": blueprints
	}, "\t"))
	file.close()


func add(blueprint: Dictionary) -> void:
	blueprints.append(blueprint)


func rename(old_name: String, new_name: String) -> bool:
	var blueprint_index := find_index(old_name)
	if blueprint_index == -1:
		return false

	var renamed_blueprint: Dictionary = (blueprints[blueprint_index] as Dictionary).duplicate(true)
	renamed_blueprint["name"] = new_name
	blueprints[blueprint_index] = renamed_blueprint
	return true


func remove(blueprint_name: String) -> bool:
	var blueprint_index := find_index(blueprint_name)
	if blueprint_index == -1:
		return false

	blueprints.remove_at(blueprint_index)
	return true


func has_name(blueprint_name: String) -> bool:
	return find_index(blueprint_name) != -1


func get_blueprint(blueprint_name: String) -> Dictionary:
	var blueprint_index := find_index(blueprint_name)
	if blueprint_index == -1:
		return {}
	return blueprints[blueprint_index]


func get_names() -> Array[String]:
	var blueprint_names: Array[String] = []
	for blueprint in blueprints:
		blueprint_names.append(str(blueprint.get("name", "")))
	return blueprint_names


func find_index(blueprint_name: String) -> int:
	for index in blueprints.size():
		var blueprint: Dictionary = blueprints[index]
		if str(blueprint.get("name", "")) == blueprint_name:
			return index
	return -1
