extends Control

var level: PackedScene = preload("res://scenes/placement_logic/main.tscn")
var opening_timeline = preload("res://story/begin.dtl")
var _is_starting: bool = false

func _ready() -> void:
	print("start_game: ready")
	if not Dialogic.timeline_ended.is_connected(_on_dialog_ended):
		Dialogic.timeline_ended.connect(_on_dialog_ended)
	if not Dialogic.timeline_started.is_connected(_on_dialog_started):
		Dialogic.timeline_started.connect(_on_dialog_started)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var start_click_catcher := get_node_or_null("StartClickCatcher") as Button
	if start_click_catcher != null and not start_click_catcher.pressed.is_connected(_on_start_button_pressed):
		start_click_catcher.pressed.connect(_on_start_button_pressed)
		print("start_game: click catcher connected")

func _input(event: InputEvent) -> void:
	_try_start_dialog(event)

func _gui_input(event: InputEvent) -> void:
	_try_start_dialog(event)

func _try_start_dialog(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_start_dialog()

func _on_start_button_pressed() -> void:
	_start_dialog()

func _start_dialog() -> void:
	if _is_starting or Dialogic.current_timeline != null:
		return

	_is_starting = true
	print("start_game: click received, starting opening timeline")
	var dialog_layout: Node = Dialogic.start(opening_timeline)
	if dialog_layout != null:
		_hide_start_screen()
		get_viewport().set_input_as_handled()
	else:
		print("start_game: Dialogic.start returned null")
		_is_starting = false

func _on_dialog_started() -> void:
	print("start_game: dialog timeline started")
	_is_starting = false

func _on_dialog_ended():
	print("start_game: dialog timeline ended, changing scene")
	var level_instance: Node = level.instantiate()
	get_tree().change_scene_to_node(level_instance)

func _hide_start_screen() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = false
