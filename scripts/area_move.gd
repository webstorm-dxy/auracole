# 这个脚本要挂在 NPC 的 Area3D 节点上
extends Area3D
@export var talk_tip:Control
@export var teleport_target: Marker3D
# 变量：标记玩家是否在可对话范围内
var can_talk := false

# 变量：保存进入范围的玩家（CharacterBody3D）
var player: CharacterBody3D

# 节点准备好时执行一次
func _ready():
	# 连接信号：当物理物体进入区域时触发
	body_entered.connect(_on_body_enter)
	# 连接信号：当物理物体离开区域时触发
	body_exited.connect(_on_body_exit)

# 当有物体进入 Area3D 范围时
func _on_body_enter(body: Node3D):
	# 判断进入的物体是不是玩家（CharacterBody3D）
	if body is CharacterBody3D:
		can_talk = true       # 允许对话
		player = body         # 保存玩家引用
		talk_tip.visible=true
		print("靠近NPC，可以按F对话")

# 当有物体离开 Area3D 范围时
func _on_body_exit(body: Node3D):
	if body is CharacterBody3D:
		can_talk = false      # 禁止对话
		player = null
		talk_tip.visible=false         # 清空玩家引用
		print("离开NPC范围")

# 每帧检测按键
func _process(_delta):
	# 如果在范围内，并且刚按下 F 键（ui_accept 默认是 F）
	if can_talk and Input.is_action_just_pressed("chat_01"):
		if is_instance_valid(teleport_target):
			# 1. 直接设置玩家的世界坐标（瞬移）
			player.global_position = teleport_target.global_position
			# 2. 重置玩家速度（必加！防止传送后角色乱飞/滑动）
			player.velocity = Vector3.ZERO
			# 3. 隐藏提示文本
			talk_tip.visible = false
			# 4. 控制台提示
			print("对话触发！玩家已传送到指定坐标")
		else:
			print("警告：未设置传送目标点（Marker3D），无法传送！")
