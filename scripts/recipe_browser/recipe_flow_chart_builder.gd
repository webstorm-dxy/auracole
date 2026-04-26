class_name RecipeFlowChartBuilder
extends RefCounted

const DEFAULT_SURFACE_LEFT_X := 90.0
const DEFAULT_SURFACE_DEVICE_X := 420.0
const DEFAULT_SURFACE_RIGHT_X := 820.0
const DEFAULT_SURFACE_MIN_Y := 120.0
const DEFAULT_SURFACE_MAX_Y := 540.0


static func build(recipe: RecipeData, custom_flow_charts: Dictionary) -> Dictionary:
	if custom_flow_charts.has(recipe.recipe_id):
		var raw_flow: Dictionary = custom_flow_charts.get(recipe.recipe_id, {})
		return _normalize_flow_chart(raw_flow)

	return _build_default_flow_chart(recipe)


static func _build_default_flow_chart(recipe: RecipeData) -> Dictionary:
	var steps: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var input_items: PackedStringArray = recipe.get_input_items()
	var output_items: PackedStringArray = recipe.get_output_items()
	var device_id: String = "device"

	var input_positions: Array[float] = _build_vertical_positions(max(input_items.size(), 1), DEFAULT_SURFACE_MIN_Y, DEFAULT_SURFACE_MAX_Y)
	var output_positions: Array[float] = _build_vertical_positions(max(output_items.size(), 1), DEFAULT_SURFACE_MIN_Y, DEFAULT_SURFACE_MAX_Y)

	if input_items.is_empty():
		input_items = PackedStringArray(["无输入"])
	if output_items.is_empty():
		output_items = PackedStringArray(["无输出"])

	for i in input_items.size():
		var step_id: String = "input_%d" % i
		steps.append({
			"id": step_id,
			"name": input_items[i],
			"kind": "input",
			"duration": 2.0,
			"pos": Vector2(DEFAULT_SURFACE_LEFT_X, input_positions[i]),
		})
		connections.append({"from": step_id, "to": device_id})

	steps.append({
		"id": device_id,
		"name": recipe.device_name,
		"kind": "device",
		"duration": 2.0,
		"pos": Vector2(DEFAULT_SURFACE_DEVICE_X, 250),
		"size": Vector2(200, 104),
	})

	for i in output_items.size():
		var step_id: String = "output_%d" % i
		steps.append({
			"id": step_id,
			"name": output_items[i],
			"kind": "output",
			"duration": 2.0,
			"pos": Vector2(DEFAULT_SURFACE_RIGHT_X, output_positions[i]),
		})
		connections.append({"from": device_id, "to": step_id})

	return {
		"steps": steps,
		"connections": connections,
	}


static func _build_vertical_positions(count: int, min_y: float, max_y: float) -> Array[float]:
	var positions: Array[float] = []

	if count <= 1:
		positions.append((min_y + max_y) * 0.5)
		return positions

	var step: float = (max_y - min_y) / float(count - 1)
	for index in count:
		positions.append(min_y + step * index)

	return positions


static func _normalize_flow_chart(raw_flow: Dictionary) -> Dictionary:
	var steps: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var raw_steps: Array = raw_flow.get("steps", [])
	var raw_connections: Array = raw_flow.get("connections", [])

	for raw_step_entry in raw_steps:
		if not (raw_step_entry is Dictionary):
			continue

		var raw_step: Dictionary = raw_step_entry
		var step: Dictionary = {
			"id": String(raw_step.get("id", "")),
			"name": String(raw_step.get("name", "")),
			"kind": String(raw_step.get("kind", "default")),
			"duration": float(raw_step.get("duration", 0.0)),
			"pos": _parse_vector2(raw_step.get("pos", [0, 0]), Vector2.ZERO),
		}

		if raw_step.has("size"):
			step["size"] = _parse_vector2(raw_step.get("size", [180, 92]), Vector2(180, 92))

		steps.append(step)

	for raw_connection_entry in raw_connections:
		if not (raw_connection_entry is Dictionary):
			continue

		var raw_connection: Dictionary = raw_connection_entry
		connections.append({
			"from": String(raw_connection.get("from", "")),
			"to": String(raw_connection.get("to", "")),
		})

	return {
		"steps": steps,
		"connections": connections,
	}


static func _parse_vector2(raw_value: Variant, default_value: Vector2) -> Vector2:
	if raw_value is Array:
		var values: Array = raw_value
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))

	if raw_value is Dictionary:
		var values_dict: Dictionary = raw_value
		return Vector2(
			float(values_dict.get("x", default_value.x)),
			float(values_dict.get("y", default_value.y))
		)

	return default_value
