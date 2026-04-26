extends Area3D
class_name PlayerInteractionArea

const INTERACT_ACTION := &"chat_01"

@export var talk_tip: Control

var can_talk := false
var player: CharacterBody3D


func _ready() -> void:
	set_process(false)
	_set_talk_tip_visible(false)
	if not body_entered.is_connected(_on_body_enter):
		body_entered.connect(_on_body_enter)
	if not body_exited.is_connected(_on_body_exit):
		body_exited.connect(_on_body_exit)


func _process(_delta: float) -> void:
	if can_talk and Input.is_action_just_pressed(INTERACT_ACTION):
		_interact(player)


func _on_body_enter(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character == null:
		return

	can_talk = true
	player = character
	set_process(true)
	_set_talk_tip_visible(true)
	_on_player_entered(character)


func _on_body_exit(body: Node3D) -> void:
	if body != player:
		return

	var leaving_player := player
	can_talk = false
	player = null
	set_process(false)
	_set_talk_tip_visible(false)
	_on_player_exited(leaving_player)


func _interact(_player: CharacterBody3D) -> void:
	pass


func _on_player_entered(_player: CharacterBody3D) -> void:
	print("靠近NPC，可以按F对话")


func _on_player_exited(_player: CharacterBody3D) -> void:
	print("离开NPC范围")


func _set_talk_tip_visible(visible_state: bool) -> void:
	if talk_tip != null:
		talk_tip.visible = visible_state
