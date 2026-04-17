extends Node

@onready var step = 1
var is_dialog = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.timeline_ended.connect(_continue_process)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Dialogic.current_timeline == null and step == 1 and is_dialog:
			Dialogic.start("res://story/beginner_1.dtl")
			get_viewport().set_input_as_handled()
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _continue_process():
	is_dialog = false
	step+=1

func _goto_next_step():
	pass
