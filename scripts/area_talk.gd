# 这个脚本要挂在 NPC 的 Area3D 节点上
extends "res://scripts/interaction/player_interaction_area.gd"


func _interact(_active_player: CharacterBody3D) -> void:
	Dialogic.start("beginner")
