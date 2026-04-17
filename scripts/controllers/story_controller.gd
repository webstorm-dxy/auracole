extends Node

const TARGET_PIPELINE: Array[String] = [
	"水坝接口",
	"矿石开采机",
	"沉淀池",
	"反应堆",
]

@onready var step = 1
@onready var map_manager: MapManager = $"../MapManager"

var is_dialog = true
var _pipeline_step_completed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.timeline_ended.connect(_continue_process)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Dialogic.current_timeline == null and step == 1 and is_dialog:
			Dialogic.start("res://story/beginner_1.dtl")
			get_viewport().set_input_as_handled()
		if Dialogic.current_timeline == null and step == 2 and is_dialog:
			Dialogic.start("res://story/beginner_2.dtl")
			get_viewport().set_input_as_handled()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not _should_check_target_pipeline():
		return

	if _has_target_pipeline():
		_pipeline_step_completed = true
		_goto_next_step()
	
func _continue_process():
	is_dialog = false
	#step+=1

func _goto_next_step():
	print("Over")
	is_dialog = true
	step += 1


func _should_check_target_pipeline() -> bool:
	return not is_dialog and step == 2 and not _pipeline_step_completed and map_manager != null


func _has_target_pipeline() -> bool:
	var buildings := _collect_buildings_by_id()
	if buildings.is_empty():
		return false

	var connections := _collect_connections_by_source(buildings)
	if connections.is_empty():
		return false

	return _matches_pipeline_chain(TARGET_PIPELINE, buildings, connections)


func _collect_buildings_by_id() -> Dictionary:
	var buildings := {}
	for child in map_manager.get_children():
		if not child is Building:
			continue

		var building := child as Building
		buildings[int(building.device_id)] = building

	return buildings


func _collect_connections_by_source(buildings: Dictionary) -> Dictionary:
	var connections := {}
	var conveyor_ids: Array = map_manager.directed_conveyors.keys()
	conveyor_ids.sort()

	for conveyor_id_variant in conveyor_ids:
		var conveyor_id := int(conveyor_id_variant)
		var directed_cells: Array = map_manager.directed_conveyors.get(conveyor_id, [])
		if directed_cells.is_empty():
			continue

		var first_cell := directed_cells[0].get("position", Vector2i.ZERO) as Vector2i
		var last_cell := directed_cells[directed_cells.size() - 1].get("position", Vector2i.ZERO) as Vector2i
		var source_device_id := _find_device_id_for_path_cell(first_cell, buildings)
		var target_device_id := _find_device_id_for_path_cell(last_cell, buildings, source_device_id)
		if source_device_id == -1 or target_device_id == -1:
			continue

		if not connections.has(source_device_id):
			connections[source_device_id] = []

		var targets: Array = connections[source_device_id]
		if not targets.has(target_device_id):
			targets.append(target_device_id)

	return connections


func _find_device_id_for_path_cell(path_cell: Vector2i, buildings: Dictionary, excluded_device_id: int = -1) -> int:
	var candidate_ids: Array[int] = []
	for building_variant in buildings.values():
		var building := building_variant as Building
		if building == null or building.device_id == excluded_device_id:
			continue

		for option_variant in map_manager.get_building_connection_options(building):
			var option: Dictionary = option_variant
			var option_path_cell := option.get("path_cell", Vector2i.ZERO) as Vector2i
			if option_path_cell == path_cell:
				candidate_ids.append(int(building.device_id))
				break

	candidate_ids.sort()
	return candidate_ids[0] if not candidate_ids.is_empty() else -1


func _matches_pipeline_chain(pipeline: Array[String], buildings: Dictionary, connections: Dictionary) -> bool:
	for building_variant in buildings.values():
		var building := building_variant as Building
		if building == null or building.item_id != pipeline[0]:
			continue

		if _match_pipeline_from_device(building.device_id, 0, pipeline, buildings, connections, {}):
			return true

	return false


func _match_pipeline_from_device(
	device_id: int,
	pipeline_index: int,
	pipeline: Array[String],
	buildings: Dictionary,
	connections: Dictionary,
	visited: Dictionary
) -> bool:
	if not buildings.has(device_id):
		return false

	var building := buildings[device_id] as Building
	if building == null or building.item_id != pipeline[pipeline_index]:
		return false

	if pipeline_index == pipeline.size() - 1:
		return true

	visited[device_id] = true
	var next_item_id := pipeline[pipeline_index + 1]
	var outgoing_connections: Array = connections.get(device_id, [])
	for next_device_variant in outgoing_connections:
		var next_device_id := int(next_device_variant)
		if visited.has(next_device_id) or not buildings.has(next_device_id):
			continue

		var next_building := buildings[next_device_id] as Building
		if next_building == null or next_building.item_id != next_item_id:
			continue

		if _match_pipeline_from_device(
			next_device_id,
			pipeline_index + 1,
			pipeline,
			buildings,
			connections,
			visited.duplicate()
		):
			return true

	return false
