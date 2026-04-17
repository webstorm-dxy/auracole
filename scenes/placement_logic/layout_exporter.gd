extends Node

const STORE := preload("res://scenes/industry_runtime_store.gd")
const SAVE_INTERVAL_SECONDS := 0.25

@onready var map_manager: MapManager = $"../MapManager"

var _save_accumulator: float = SAVE_INTERVAL_SECONDS
var _last_signature: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_export_layout(true)


func _process(delta: float) -> void:
	_save_accumulator += delta
	if _save_accumulator < SAVE_INTERVAL_SECONDS:
		return

	_save_accumulator = 0.0
	_export_layout()


func _export_layout(force: bool = false) -> void:
	if map_manager == null:
		return

	var payload = _build_layout_payload()
	var signature = String(payload.get("signature", ""))
	if not force and signature == _last_signature:
		return

	_last_signature = signature
	STORE.save_json_dictionary(STORE.LAYOUT_PATH, payload)


func _build_layout_payload() -> Dictionary:
	var buildings = _collect_buildings()
	var conveyors = _collect_conveyors(buildings)
	var structure = {
		"version": 1,
		"grid_rows": map_manager.grid_rows,
		"grid_cols": map_manager.grid_cols,
		"cell_size": map_manager.CELL_SIZE,
		"buildings": buildings,
		"conveyors": conveyors,
	}
	var payload = structure.duplicate(true)
	payload["signature"] = STORE.stable_stringify(structure)
	payload["exported_at_unix"] = Time.get_unix_time_from_system()
	return payload


func _collect_buildings() -> Array:
	var buildings: Array = []
	for child in map_manager.get_children():
		if not child is Building:
			continue

		var building = child as Building
		buildings.append({
			"device_id": int(building.device_id),
			"item_id": String(building.item_id),
			"top_left_cell": {
				"x": int(building.top_left_cell.x),
				"y": int(building.top_left_cell.y),
			},
			"footprint": {
				"x": int(building.footprint.x),
				"y": int(building.footprint.y),
			},
			"rotation_steps": int(building.rotation_steps),
		})

	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("device_id", -1)) < int(b.get("device_id", -1))
	)
	return buildings


func _collect_conveyors(buildings: Array) -> Array:
	var conveyors: Array = []
	var conveyor_ids: Array = map_manager.directed_conveyors.keys()
	conveyor_ids.sort()

	for conveyor_id_variant in conveyor_ids:
		var conveyor_id = int(conveyor_id_variant)
		var directed_cells: Array = map_manager.directed_conveyors.get(conveyor_id, [])
		if directed_cells.is_empty():
			continue

		var first_cell = directed_cells[0].get("position", Vector2i.ZERO) as Vector2i
		var last_cell = directed_cells[directed_cells.size() - 1].get("position", Vector2i.ZERO) as Vector2i
		var source_device_id = _find_device_id_for_path_cell(first_cell, buildings)
		var target_device_id = _find_device_id_for_path_cell(last_cell, buildings, source_device_id)
		var serialized_cells: Array = []
		for cell_data_variant in directed_cells:
			var cell_data: Dictionary = cell_data_variant
			var position = cell_data.get("position", Vector2i.ZERO) as Vector2i
			serialized_cells.append({
				"x": int(position.x),
				"y": int(position.y),
				"arrow_direction": int(cell_data.get("arrow_direction", 0)),
			})

		conveyors.append({
			"conveyor_id": conveyor_id,
			"source_device_id": source_device_id,
			"target_device_id": target_device_id,
			"cells": serialized_cells,
		})

	conveyors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("conveyor_id", -1)) < int(b.get("conveyor_id", -1))
	)
	return conveyors


func _find_device_id_for_path_cell(path_cell: Vector2i, buildings: Array, excluded_device_id: int = -1) -> int:
	var candidates: Array[int] = []
	for building_data_variant in buildings:
		var building_data: Dictionary = building_data_variant
		var device_id = int(building_data.get("device_id", -1))
		if device_id == excluded_device_id:
			continue

		var building = _find_runtime_building(device_id)
		if building == null:
			continue

		for option_variant in map_manager.get_building_connection_options(building):
			var option: Dictionary = option_variant
			var option_path_cell = option.get("path_cell", Vector2i.ZERO) as Vector2i
			if option_path_cell == path_cell:
				candidates.append(device_id)
				break

	candidates.sort()
	return candidates[0] if not candidates.is_empty() else -1


func _find_runtime_building(device_id: int) -> Building:
	for child in map_manager.get_children():
		if child is Building and int((child as Building).device_id) == device_id:
			return child as Building
	return null
