extends PopupPanel

const STEP_NODE_SCENE: PackedScene = preload("res://scenes/recipe_browser/step_node.tscn")
const POPUP_SIZE: Vector2i = Vector2i(1080, 720)
const SURFACE_SIZE: Vector2 = Vector2(1240, 720)
const FLOW_CHARTS_JSON_PATH: String = "res://data/recipe_browser/flow_charts.json"
const NARROW_POPUP_WIDTH: float = 900.0
const COMPACT_POPUP_WIDTH: float = 640.0

@onready var root_margin: MarginContainer = %MarginContainer
@onready var popup_layout: VBoxContainer = %VBoxContainer
@onready var header_container: BoxContainer = %Header
@onready var title_block: VBoxContainer = %TitleBlock
@onready var title_label: Label = %DeviceName
@onready var info_label: Label = %RecipeInfo
@onready var close_button: Button = %CloseButton
@onready var flow_panel: PanelContainer = %FlowPanel
@onready var flow_surface: Control = %FlowSurface
@onready var connection_layer: FlowChartConnectionLayer = %ConnectionLayer
@onready var nodes_layer: Control = %NodesLayer

var _current_recipe: RecipeData
var _step_nodes: Dictionary = {}
var _custom_flow_charts: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(hide)
	exclusive = true
	flow_surface.custom_minimum_size = SURFACE_SIZE
	_load_flow_charts()
	_apply_styles()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)


func show_recipe(recipe: RecipeData) -> void:
	_current_recipe = recipe
	title_label.text = recipe.device_name
	info_label.text = "输入：%s\n输出：%s" % [
		RecipeTextFormatter.format_optional(recipe.input_items),
		RecipeTextFormatter.format_optional(recipe.output_items),
	]
	_display_flow_chart(RecipeFlowChartBuilder.build(recipe, _custom_flow_charts))
	_apply_responsive_layout()
	popup_centered(_get_popup_size())


func _display_flow_chart(flow_data: Dictionary) -> void:
	_clear_flow_chart()

	for step in flow_data.get("steps", []):
		_create_step_node(step)

	call_deferred("_apply_connections", flow_data.get("connections", []))


func _create_step_node(step_data: Dictionary) -> void:
	var step_node: StepNode = STEP_NODE_SCENE.instantiate() as StepNode
	nodes_layer.add_child(step_node)
	step_node.setup_step(step_data)
	_step_nodes[String(step_data.get("id", ""))] = step_node


func _apply_connections(connection_defs: Array) -> void:
	var resolved: Array[Dictionary] = []

	for connection in connection_defs:
		var from_id: String = String(connection.get("from", ""))
		var to_id: String = String(connection.get("to", ""))
		if _step_nodes.has(from_id) and _step_nodes.has(to_id):
			resolved.append({
				"from": _step_nodes[from_id],
				"to": _step_nodes[to_id],
			})

	connection_layer.set_connections(resolved)


func _clear_flow_chart() -> void:
	connection_layer.clear_connections()

	for child in nodes_layer.get_children():
		child.free()

	_step_nodes.clear()


func _apply_styles() -> void:
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color("0d1524")
	popup_style.border_color = Color("3f5f8d")
	popup_style.border_width_left = 1
	popup_style.border_width_top = 1
	popup_style.border_width_right = 1
	popup_style.border_width_bottom = 1
	popup_style.corner_radius_top_left = 18
	popup_style.corner_radius_top_right = 18
	popup_style.corner_radius_bottom_left = 18
	popup_style.corner_radius_bottom_right = 18
	add_theme_stylebox_override("panel", popup_style)

	var flow_style: StyleBoxFlat = StyleBoxFlat.new()
	flow_style.bg_color = Color("101b2d")
	flow_style.border_color = Color("2c4468")
	flow_style.border_width_left = 1
	flow_style.border_width_top = 1
	flow_style.border_width_right = 1
	flow_style.border_width_bottom = 1
	flow_style.corner_radius_top_left = 16
	flow_style.corner_radius_top_right = 16
	flow_style.corner_radius_bottom_left = 16
	flow_style.corner_radius_bottom_right = 16
	flow_panel.add_theme_stylebox_override("panel", flow_style)


func _load_flow_charts() -> void:
	_custom_flow_charts = JsonFileLoader.load_json_dictionary(FLOW_CHARTS_JSON_PATH)


func _on_viewport_resized() -> void:
	_apply_responsive_layout()
	if visible:
		popup_centered(_get_popup_size())


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = _get_viewport_size()
	var viewport_width: float = viewport_size.x
	var viewport_height: float = viewport_size.y
	var is_narrow: bool = viewport_width < NARROW_POPUP_WIDTH
	var is_compact: bool = viewport_width < COMPACT_POPUP_WIDTH

	header_container.vertical = is_narrow
	header_container.add_theme_constant_override("separation", 12 if is_compact else 16)
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_narrow else Control.SIZE_FILL
	close_button.custom_minimum_size = Vector2(0 if is_narrow else 112, 42 if is_compact else 46)

	root_margin.add_theme_constant_override("margin_left", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_right", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_top", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_bottom", 14 if is_compact else 22)
	popup_layout.add_theme_constant_override("separation", 14 if is_compact else 18)

	title_label.add_theme_font_size_override("font_size", 22 if is_compact else 28)
	info_label.add_theme_font_size_override("font_size", 14 if is_compact else 15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var surface_width: float = clampf(viewport_width * 0.88, 760.0, SURFACE_SIZE.x)
	var surface_height: float = clampf(viewport_height * 0.62, 420.0, SURFACE_SIZE.y)
	flow_surface.custom_minimum_size = Vector2(surface_width, surface_height)


func _get_popup_size() -> Vector2i:
	var viewport_size: Vector2 = _get_viewport_size()
	var width: int = int(clampf(viewport_size.x * 0.92, 360.0, POPUP_SIZE.x))
	var height: int = int(clampf(viewport_size.y * 0.88, 320.0, POPUP_SIZE.y))
	return Vector2i(width, height)


func _get_viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size
