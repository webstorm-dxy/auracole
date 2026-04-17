extends Control

const STORE := preload("res://scenes/industry_runtime_store.gd")
const ITEM_DISPLAY_ORDER: Array[String] = [
	"高纯金属块",
	"高纯玄萤燃料块",
	"玄萤燃料块",
	"玄萤矿",
	"玄萤矿粉",
	"精炼玄萤矿粉",
	"金属块",
	"金属粉末",
]
const PROCESSING_STATE := "Processing"
const IDLE_STATE := "Idle"
const INPUT_BLOCKED_STATE := "InputBlocked"
const EPSILON := 0.0001
const TWENTY_FOUR_HOURS_SECONDS := 24.0 * 60.0 * 60.0
const RECIPES := {
	"矿石开采机": {
		"cycle_time": 6.0,
		"inputs": {},
		"outputs": {"玄萤矿": 4},
	},
	"沉淀池": {
		"cycle_time": 8.0,
		"inputs": {"玄萤矿": 4},
		"outputs": {"玄萤矿粉": 3},
	},
	"反应池": {
		"cycle_time": 10.0,
		"inputs": {"玄萤矿粉": 3},
		"outputs": {"精炼玄萤矿粉": 2},
	},
	"水坝接口": {
		"cycle_time": 7.0,
		"inputs": {},
		"outputs": {"金属块": 2},
	},
	"龙骨水车": {
		"cycle_time": 9.0,
		"inputs": {"金属块": 2},
		"outputs": {
			"金属粉末": 2,
			"高纯金属块": 1,
		},
	},
	"反应堆": {
		"cycle_time": 12.0,
		"inputs": {
			"精炼玄萤矿粉": 2,
			"金属粉末": 2,
		},
		"outputs": {
			"玄萤燃料块": 1,
			"高纯玄萤燃料块": 1,
		},
	},
}

@onready var input_inventory_label: Label = $TopBar/InputInventoryLabel
@onready var output_inventory_label: Label = $TopBar/OutputInventoryLabel
@onready var machine_state_label: Label = $TopBar/MachineStateLabel
@onready var offline_duration_label: Label = $TopBar/OfflineDurationLabel
@onready var log_label: Label = $LogLabel
@onready var simulate_button: Button = $ActionPanel/Simulate24HoursButton
@onready var reload_button: Button = $ActionPanel/ManualFeedButton
@onready var save_quit_button: Button = $ActionPanel/SaveAndQuitButton

var _layout_signature: String = ""
var _machines: Dictionary = {}
var _last_simulated_seconds: float = 0.0
var _last_total_produced: Dictionary = {}
var _last_total_consumed: Dictionary = {}


func _ready() -> void:
	_configure_buttons()
	_reload_layout_from_disk(true)


func _configure_buttons() -> void:
	simulate_button.text = "模拟离线 24 小时"
	reload_button.text = "重新读取布局"
	save_quit_button.text = "保存快照并退出"
	simulate_button.pressed.connect(_on_simulate_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	save_quit_button.pressed.connect(_on_save_quit_pressed)


func _on_simulate_pressed() -> void:
	if _machines.is_empty():
		_write_log("当前没有可计算的工业布局。")
		return

	var result = _simulate_offline(_machines, TWENTY_FOUR_HOURS_SECONDS)
	_machines = result.get("machines", {})
	_last_simulated_seconds = float(result.get("simulated_seconds", 0.0))
	_last_total_produced = result.get("total_produced", {}).duplicate(true)
	_last_total_consumed = result.get("total_consumed", {}).duplicate(true)
	_update_machine_states(_machines)
	_save_snapshot()
	_save_map_view()
	_update_ui()
	_write_log(
		"离线推演完成：%d 台机器，%.0f 秒，累计产出 %s"
		% [_machines.size(), _last_simulated_seconds, _format_inventory(_last_total_produced)]
	)


func _on_reload_pressed() -> void:
	_reload_layout_from_disk(false)


func _on_save_quit_pressed() -> void:
	_save_snapshot()
	get_tree().quit()


func _reload_layout_from_disk(use_snapshot: bool) -> void:
	var layout = STORE.load_json_dictionary(STORE.LAYOUT_PATH)
	if layout.is_empty():
		_layout_signature = ""
		_machines.clear()
		_last_simulated_seconds = 0.0
		_last_total_produced.clear()
		_last_total_consumed.clear()
		_save_map_view()
		_update_ui()
		_write_log("未找到 placement_logic 产线结构，请先在 main.tscn 中摆放设备。")
		return

	_layout_signature = String(layout.get("signature", ""))
	_machines = _build_machine_graph(layout)
	if use_snapshot:
		var snapshot = _load_snapshot_if_compatible()
		if not snapshot.is_empty():
			_machines = snapshot

	_last_simulated_seconds = 0.0
	_last_total_produced.clear()
	_last_total_consumed.clear()
	_update_machine_states(_machines)
	_save_map_view()
	_update_ui()
	_write_log("已加载布局：%d 台机器，%d 条传送带。" % [_machines.size(), _count_layout_conveyors(layout)])


func _build_machine_graph(layout: Dictionary) -> Dictionary:
	var machines: Dictionary = {}
	var buildings: Array = layout.get("buildings", [])
	var conveyors: Array = layout.get("conveyors", [])
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("device_id", -1)) < int(b.get("device_id", -1))
	)

	for building_variant in buildings:
		var building: Dictionary = building_variant
		var item_id = String(building.get("item_id", ""))
		if not RECIPES.has(item_id):
			continue

		var device_id = int(building.get("device_id", -1))
		var machine_id = _machine_id_from_device_id(device_id)
		machines[machine_id] = {
			"machine_id": machine_id,
			"display_name": "%s#%d" % [item_id, device_id],
			"building_type": item_id,
			"recipe": _duplicate_recipe(RECIPES[item_id]),
			"routes": [],
			"input_buffer": {},
			"output_buffer": {},
			"state": IDLE_STATE,
			"progress_seconds": 0.0,
			"sort_order": device_id,
		}

	conveyors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("conveyor_id", -1)) < int(b.get("conveyor_id", -1))
	)
	for conveyor_variant in conveyors:
		var conveyor: Dictionary = conveyor_variant
		var source_device_id = int(conveyor.get("source_device_id", -1))
		var target_device_id = int(conveyor.get("target_device_id", -1))
		var source_machine_id = _machine_id_from_device_id(source_device_id)
		var target_machine_id = _machine_id_from_device_id(target_device_id)
		if not machines.has(source_machine_id) or not machines.has(target_machine_id):
			continue

		var source_machine: Dictionary = machines[source_machine_id]
		var target_machine: Dictionary = machines[target_machine_id]
		var source_outputs: Dictionary = source_machine.get("recipe", {}).get("outputs", {})
		var target_inputs: Dictionary = target_machine.get("recipe", {}).get("inputs", {})
		var routable_items: Array[String] = []
		for item_name_variant in source_outputs.keys():
			var item_name = String(item_name_variant)
			if target_inputs.has(item_name):
				routable_items.append(item_name)

		routable_items.sort()
		for index in range(routable_items.size()):
			source_machine["routes"].append({
				"item_id": routable_items[index],
				"target_machine_id": target_machine_id,
				"target_input_item_id": routable_items[index],
				"priority": int(conveyor.get("conveyor_id", 0)) * 100 + index,
			})

	return _duplicate_machine_graph(machines)


func _load_snapshot_if_compatible() -> Dictionary:
	var snapshot = STORE.load_json_dictionary(STORE.SNAPSHOT_PATH)
	if snapshot.is_empty():
		return {}
	if String(snapshot.get("layout_signature", "")) != _layout_signature:
		return {}

	var restored: Dictionary = {}
	var machine_entries: Array = snapshot.get("machines", [])
	for entry_variant in machine_entries:
		var entry: Dictionary = entry_variant
		var machine_id = String(entry.get("machine_id", ""))
		if machine_id.is_empty() or not _machines.has(machine_id):
			continue

		var restored_machine = _duplicate_machine(_machines[machine_id])
		restored_machine["input_buffer"] = entry.get("input_buffer", {}).duplicate(true)
		restored_machine["output_buffer"] = entry.get("output_buffer", {}).duplicate(true)
		restored_machine["state"] = String(entry.get("state", IDLE_STATE))
		restored_machine["progress_seconds"] = float(entry.get("progress_seconds", 0.0))
		restored[machine_id] = restored_machine

	return restored if restored.size() == _machines.size() else {}


func _save_snapshot() -> void:
	var machine_entries: Array = []
	var machine_ids = _sorted_machine_ids(_machines)
	for machine_id in machine_ids:
		var machine: Dictionary = _machines[machine_id]
		machine_entries.append({
			"machine_id": machine_id,
			"state": String(machine.get("state", IDLE_STATE)),
			"progress_seconds": float(machine.get("progress_seconds", 0.0)),
			"input_buffer": machine.get("input_buffer", {}).duplicate(true),
			"output_buffer": machine.get("output_buffer", {}).duplicate(true),
		})

	STORE.save_json_dictionary(STORE.SNAPSHOT_PATH, {
		"layout_signature": _layout_signature,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"machines": machine_entries,
	})


func _simulate_offline(machine_graph: Dictionary, offline_seconds: float) -> Dictionary:
	var machines = _duplicate_machine_graph(machine_graph)
	var elapsed = 0.0
	var total_produced: Dictionary = {}
	var total_consumed: Dictionary = {}
	_update_machine_states(machines)

	while elapsed < offline_seconds - EPSILON:
		_process_immediate_transfers_and_starts(machines, total_consumed)
		var next_completion_dt = _get_next_completion_dt(machines)
		if is_inf(next_completion_dt):
			break

		var remaining = offline_seconds - elapsed
		var step = min(remaining, next_completion_dt)
		_advance_processing(machines, step)
		elapsed += step
		if step + EPSILON < next_completion_dt:
			break

		_resolve_completions(machines, total_produced)

	_process_immediate_transfers_and_starts(machines, total_consumed)
	return {
		"machines": machines,
		"simulated_seconds": elapsed,
		"total_produced": total_produced,
		"total_consumed": total_consumed,
	}


func _process_immediate_transfers_and_starts(machines: Dictionary, total_consumed: Dictionary) -> void:
	var changed = true
	var guard = 0
	while changed and guard < 2048:
		changed = false
		guard += 1
		for machine_id in _sorted_machine_ids(machines):
			var machine: Dictionary = machines[machine_id]
			if _flush_output_buffer(machine, machines):
				changed = true

			if String(machine.get("state", IDLE_STATE)) == PROCESSING_STATE:
				continue

			if _try_start_machine(machine, total_consumed):
				changed = true
			else:
				var blocked = _machine_is_input_blocked(machine)
				var next_state = INPUT_BLOCKED_STATE if blocked else IDLE_STATE
				if String(machine.get("state", IDLE_STATE)) != next_state:
					machine["state"] = next_state
					changed = true


func _flush_output_buffer(machine: Dictionary, machines: Dictionary) -> bool:
	var moved_any = false
	var output_buffer: Dictionary = machine.get("output_buffer", {})
	var keys = output_buffer.keys()
	keys.sort()
	for item_name_variant in keys:
		var item_name = String(item_name_variant)
		var amount = int(output_buffer.get(item_name, 0))
		if amount <= 0:
			_set_amount(output_buffer, item_name, 0)
			continue

		var remaining = _route_item(machine, item_name, amount, machines)
		if remaining != amount:
			moved_any = true
		_set_amount(output_buffer, item_name, remaining)

	return moved_any


func _try_start_machine(machine: Dictionary, total_consumed: Dictionary) -> bool:
	var recipe: Dictionary = machine.get("recipe", {})
	var input_buffer: Dictionary = machine.get("input_buffer", {})
	var inputs: Dictionary = recipe.get("inputs", {})
	if not _has_required_items(input_buffer, inputs):
		return false

	var sorted_input_names = inputs.keys()
	sorted_input_names.sort()
	for item_name_variant in sorted_input_names:
		var item_name = String(item_name_variant)
		var amount = int(inputs.get(item_name, 0))
		if amount <= 0:
			continue

		_add_amount(total_consumed, item_name, amount)
		_add_amount(input_buffer, item_name, -amount)

	machine["state"] = PROCESSING_STATE
	machine["progress_seconds"] = 0.0
	return true


func _get_next_completion_dt(machines: Dictionary) -> float:
	var next_dt = INF
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		if String(machine.get("state", IDLE_STATE)) != PROCESSING_STATE:
			continue

		var recipe: Dictionary = machine.get("recipe", {})
		var cycle_time = float(recipe.get("cycle_time", 0.0))
		var progress = float(machine.get("progress_seconds", 0.0))
		next_dt = min(next_dt, max(0.0, cycle_time - progress))

	return next_dt


func _advance_processing(machines: Dictionary, delta: float) -> void:
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		if String(machine.get("state", IDLE_STATE)) != PROCESSING_STATE:
			continue

		machine["progress_seconds"] = float(machine.get("progress_seconds", 0.0)) + delta


func _resolve_completions(machines: Dictionary, total_produced: Dictionary) -> void:
	var completed_ids: Array[String] = []
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		if String(machine.get("state", IDLE_STATE)) != PROCESSING_STATE:
			continue

		var recipe: Dictionary = machine.get("recipe", {})
		var cycle_time = float(recipe.get("cycle_time", 0.0))
		var progress = float(machine.get("progress_seconds", 0.0))
		if progress + EPSILON >= cycle_time:
			completed_ids.append(machine_id)

	for machine_id in completed_ids:
		var machine: Dictionary = machines[machine_id]
		var recipe: Dictionary = machine.get("recipe", {})
		var outputs: Dictionary = recipe.get("outputs", {})
		var output_names = outputs.keys()
		output_names.sort()
		machine["state"] = IDLE_STATE
		machine["progress_seconds"] = 0.0
		for item_name_variant in output_names:
			var item_name = String(item_name_variant)
			var amount = int(outputs.get(item_name, 0))
			if amount <= 0:
				continue

			_add_amount(total_produced, item_name, amount)
			var remaining = _route_item(machine, item_name, amount, machines)
			if remaining > 0:
				_add_amount(machine.get("output_buffer", {}), item_name, remaining)


func _route_item(machine: Dictionary, item_name: String, amount: int, machines: Dictionary) -> int:
	if amount <= 0:
		return 0

	var routes: Array = []
	for route_variant in machine.get("routes", []):
		var route: Dictionary = route_variant
		if String(route.get("item_id", "")) == item_name:
			routes.append(route)

	routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) < int(b.get("priority", 0))
	)

	var remaining = amount
	for route_variant in routes:
		if remaining <= 0:
			break

		var route: Dictionary = route_variant
		var target_machine_id = String(route.get("target_machine_id", ""))
		if target_machine_id.is_empty() or not machines.has(target_machine_id):
			continue

		var target_machine: Dictionary = machines[target_machine_id]
		var target_input_buffer: Dictionary = target_machine.get("input_buffer", {})
		var target_item_name = String(route.get("target_input_item_id", item_name))
		_add_amount(target_input_buffer, target_item_name, remaining)
		remaining = 0

	return remaining


func _machine_is_input_blocked(machine: Dictionary) -> bool:
	var recipe: Dictionary = machine.get("recipe", {})
	var inputs: Dictionary = recipe.get("inputs", {})
	return not inputs.is_empty() and not _has_required_items(machine.get("input_buffer", {}), inputs)


func _has_required_items(buffer: Dictionary, requirements: Dictionary) -> bool:
	for item_name_variant in requirements.keys():
		var item_name = String(item_name_variant)
		if int(buffer.get(item_name, 0)) < int(requirements.get(item_name, 0)):
			return false
	return true


func _add_amount(buffer: Dictionary, item_name: String, amount: int) -> void:
	_set_amount(buffer, item_name, int(buffer.get(item_name, 0)) + amount)


func _set_amount(buffer: Dictionary, item_name: String, amount: int) -> void:
	if amount <= 0:
		buffer.erase(item_name)
	else:
		buffer[item_name] = amount


func _save_map_view() -> void:
	var quantity_by_item = _collect_total_quantities(_machines)
	var theory_produce = _collect_theoretical_rates(_machines, "outputs")
	var theory_consume = _collect_theoretical_rates(_machines, "inputs")
	var current_produce = _convert_totals_to_rates(_last_total_produced, _last_simulated_seconds)
	var current_consume = _convert_totals_to_rates(_last_total_consumed, _last_simulated_seconds)
	var ordered_item_names = ITEM_DISPLAY_ORDER.duplicate()
	for item_name_variant in quantity_by_item.keys():
		var item_name = String(item_name_variant)
		if not ordered_item_names.has(item_name):
			ordered_item_names.append(item_name)

	var items: Array = []
	for item_name in ordered_item_names:
		items.append({
			"name": item_name,
			"quantity": int(quantity_by_item.get(item_name, 0)),
			"curr_produce": int(current_produce.get(item_name, 0)),
			"curr_consume": int(current_consume.get(item_name, 0)),
			"theory_produce": int(theory_produce.get(item_name, 0)),
			"theory_consume": int(theory_consume.get(item_name, 0)),
			"status": _compute_item_status(
				int(quantity_by_item.get(item_name, 0)),
				int(current_produce.get(item_name, 0)),
				int(current_consume.get(item_name, 0)),
				int(theory_produce.get(item_name, 0)),
				int(theory_consume.get(item_name, 0))
			),
		})

	STORE.save_json_dictionary(STORE.MAP_VIEW_PATH, {
		"layout_signature": _layout_signature,
		"simulated_seconds": _last_simulated_seconds,
		"exported_at_unix": Time.get_unix_time_from_system(),
		"items": items,
	})


func _collect_total_quantities(machines: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		_merge_inventory(totals, machine.get("input_buffer", {}))
		_merge_inventory(totals, machine.get("output_buffer", {}))
	return totals


func _collect_theoretical_rates(machines: Dictionary, field_name: String) -> Dictionary:
	var totals: Dictionary = {}
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		var recipe: Dictionary = machine.get("recipe", {})
		var cycle_time = float(recipe.get("cycle_time", 0.0))
		if cycle_time <= EPSILON:
			continue

		var scale = 60.0 / cycle_time
		var entries: Dictionary = recipe.get(field_name, {})
		for item_name_variant in entries.keys():
			var item_name = String(item_name_variant)
			var value = float(entries.get(item_name, 0)) * scale
			totals[item_name] = int(round(float(totals.get(item_name, 0)) + value))

	return totals


func _convert_totals_to_rates(totals: Dictionary, simulated_seconds: float) -> Dictionary:
	var rates: Dictionary = {}
	if simulated_seconds <= EPSILON:
		return rates

	for item_name_variant in totals.keys():
		var item_name = String(item_name_variant)
		var rate = float(totals.get(item_name, 0)) * 60.0 / simulated_seconds
		rates[item_name] = int(round(rate))

	return rates


func _merge_inventory(target: Dictionary, source: Dictionary) -> void:
	for item_name_variant in source.keys():
		var item_name = String(item_name_variant)
		_add_amount(target, item_name, int(source.get(item_name, 0)))


func _compute_item_status(quantity: int, curr_produce: int, curr_consume: int, theory_produce: int, theory_consume: int) -> int:
	var is_active = quantity > 0 or curr_produce > 0 or curr_consume > 0 or theory_produce > 0 or theory_consume > 0
	return 0 if is_active else 1


func _update_machine_states(machines: Dictionary) -> void:
	for machine_id in _sorted_machine_ids(machines):
		var machine: Dictionary = machines[machine_id]
		if String(machine.get("state", IDLE_STATE)) == PROCESSING_STATE:
			continue
		machine["state"] = INPUT_BLOCKED_STATE if _machine_is_input_blocked(machine) else IDLE_STATE


func _update_ui() -> void:
	if _machines.is_empty():
		input_inventory_label.text = "输入库存: 0"
		output_inventory_label.text = "输出库存: 0"
		machine_state_label.text = "机器状态: 无可用设备"
		offline_duration_label.text = "离线时长: 0s"
		return

	var total_input = {}
	var total_output = {}
	var processing_count = 0
	var blocked_count = 0
	var idle_count = 0
	for machine_id in _sorted_machine_ids(_machines):
		var machine: Dictionary = _machines[machine_id]
		_merge_inventory(total_input, machine.get("input_buffer", {}))
		_merge_inventory(total_output, machine.get("output_buffer", {}))
		match String(machine.get("state", IDLE_STATE)):
			PROCESSING_STATE:
				processing_count += 1
			INPUT_BLOCKED_STATE:
				blocked_count += 1
			_:
				idle_count += 1

	input_inventory_label.text = "输入库存: %s" % _format_inventory(total_input)
	output_inventory_label.text = "输出库存: %s" % _format_inventory(total_output)
	machine_state_label.text = "机器状态: 运行%d / 缺料%d / 空闲%d" % [processing_count, blocked_count, idle_count]
	offline_duration_label.text = "离线时长: %.0fs" % _last_simulated_seconds


func _format_inventory(inventory: Dictionary) -> String:
	if inventory.is_empty():
		return "0"

	var keys = inventory.keys()
	keys.sort()
	var parts: Array[String] = []
	for item_name_variant in keys:
		var item_name = String(item_name_variant)
		parts.append("%s x%d" % [item_name, int(inventory.get(item_name, 0))])
	return ", ".join(parts)


func _duplicate_recipe(recipe: Dictionary) -> Dictionary:
	return {
		"cycle_time": float(recipe.get("cycle_time", 0.0)),
		"inputs": recipe.get("inputs", {}).duplicate(true),
		"outputs": recipe.get("outputs", {}).duplicate(true),
	}


func _duplicate_machine_graph(machines: Dictionary) -> Dictionary:
	var duplicated: Dictionary = {}
	for machine_id in machines.keys():
		duplicated[machine_id] = _duplicate_machine(machines[machine_id])
	return duplicated


func _duplicate_machine(machine: Dictionary) -> Dictionary:
	return {
		"machine_id": String(machine.get("machine_id", "")),
		"display_name": String(machine.get("display_name", "")),
		"building_type": String(machine.get("building_type", "")),
		"recipe": _duplicate_recipe(machine.get("recipe", {})),
		"routes": machine.get("routes", []).duplicate(true),
		"input_buffer": machine.get("input_buffer", {}).duplicate(true),
		"output_buffer": machine.get("output_buffer", {}).duplicate(true),
		"state": String(machine.get("state", IDLE_STATE)),
		"progress_seconds": float(machine.get("progress_seconds", 0.0)),
		"sort_order": int(machine.get("sort_order", 0)),
	}


func _sorted_machine_ids(machines: Dictionary) -> Array[String]:
	var entries: Array[Dictionary] = []
	for machine_id_variant in machines.keys():
		var machine_id = String(machine_id_variant)
		var machine: Dictionary = machines[machine_id]
		entries.append({
			"machine_id": machine_id,
			"sort_order": int(machine.get("sort_order", 0)),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("sort_order", 0)) == int(b.get("sort_order", 0)):
			return String(a.get("machine_id", "")) < String(b.get("machine_id", ""))
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)

	var machine_ids: Array[String] = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		machine_ids.append(String(entry.get("machine_id", "")))
	return machine_ids


func _machine_id_from_device_id(device_id: int) -> String:
	return "machine_%d" % device_id


func _count_layout_conveyors(layout: Dictionary) -> int:
	return (layout.get("conveyors", []) as Array).size()


func _write_log(message: String) -> void:
	log_label.text = message
	print(message)
