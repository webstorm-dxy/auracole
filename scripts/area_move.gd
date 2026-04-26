# 这个脚本要挂在 NPC 的 Area3D 节点上
extends "res://scripts/interaction/player_interaction_area.gd"

@export var teleport_target: Marker3D


func _interact(active_player: CharacterBody3D) -> void:
	if not is_instance_valid(teleport_target):
		print("警告：未设置传送目标点（Marker3D），无法传送！")
		return
	if active_player == null:
		return

	active_player.global_position = teleport_target.global_position
	active_player.velocity = Vector3.ZERO
	_set_talk_tip_visible(false)
	print("对话触发！玩家已传送到指定坐标")
