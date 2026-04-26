extends Area3D

# ------------------------------ 常量配置 ------------------------------
# 交互按键（在项目设置的 Input Map 中定义）
const INTERACT_ACTION := &"chat_01"
# UI 图层的节点名称，用于统一管理 UI
const UI_LAYER_NAME := &"BuildingTalkUiLayer"
const DIALOG_LAYER_NAME := &"BuildingTalkDialogLayer"
const DIALOG_HOST_NAME := &"DialogHost"
const UI_LAYER_ORDER := 100
const DIALOG_LAYER_ORDER := 200

# ------------------------------ 编辑器导出变量 ------------------------------
# 提示面板（如“按F对话”的文字面板）
@export var talk_tip: Control
@export var duihua: String
# 要弹出的 UI 场景文件（如背包/对话界面）
@export var inventory_scene: PackedScene

# ------------------------------ 运行时状态变量 ------------------------------
# 当前打开的 UI 实例
var inventory_instance: Node
# 承载 UI 的 CanvasLayer 图层
var ui_layer: CanvasLayer
# 承载 Dialogic 的最高层 CanvasLayer
var dialog_layer: CanvasLayer
# Dialogic 布局的宿主节点
var dialog_host: Control
# 进入交互范围的玩家节点
var player: CharacterBody3D
# 玩家是否在可交互范围内
var can_talk := false
# 打开 UI 前的鼠标模式（用于恢复）
var mouse_mode_before_inventory: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
# 鼠标是否因打开 UI 而显示
var mouse_visible_by_inventory := false
# 打开 UI 前玩家的输入/物理处理状态（用于恢复）
var player_input_process_before_inventory := false
var player_unhandled_input_before_inventory := false
var player_physics_process_before_inventory := true
# 玩家是否因打开 UI 而被锁定
var player_locked_by_inventory := false


# ------------------------------ 生命周期函数 ------------------------------
func _ready() -> void:
	# 默认不监听输入，只有玩家进入范围后才启用
	set_process_unhandled_input(false)
	# 隐藏交互提示
	_set_talk_tip_visible(false)
	_ensure_dialog_host()

	# 连接 Area3D 的“身体进入”信号
	if not body_entered.is_connected(_on_body_enter):
		body_entered.connect(_on_body_enter)
	# 连接 Area3D 的“身体离开”信号
	if not body_exited.is_connected(_on_body_exit):
		body_exited.connect(_on_body_exit)


func _exit_tree() -> void:
	# 节点销毁时的收尾工作，避免残留 UI 或错误状态
	can_talk = false
	_set_talk_tip_visible(false)
	close_inventory()
	player = null


# ------------------------------ 输入处理函数 ------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# 不在交互范围内时直接忽略输入
	if not can_talk:
		return

	# 过滤掉按键的重复触发（echo）
	var key_event := event as InputEventKey
	if key_event != null and key_event.echo:
		return

	# 当按下交互键时，切换 UI 的打开/关闭状态
	if event.is_action_pressed(INTERACT_ACTION, true):
		toggle_inventory()
		# 标记输入已处理，防止继续传递
		get_viewport().set_input_as_handled()


# ------------------------------ 信号处理函数 ------------------------------
func _on_body_enter(body: Node3D) -> void:
	# 检查进入的节点是否为 CharacterBody3D（玩家）
	var character := body as CharacterBody3D
	if character == null:
		return
	# 如果已经锁定了一个玩家，不切换引用
	if player != null and player != character:
		return

	# 记录玩家引用，启用交互
	player = character
	can_talk = true
	set_process_unhandled_input(true)
	_set_talk_tip_visible(true)
	print("靠近NPC，可以按F对话")


func _on_body_exit(body: Node3D) -> void:
	# 只响应当前交互玩家的离开事件
	if body != player:
		return

	# 清除玩家引用，禁用交互
	can_talk = false
	set_process_unhandled_input(false)
	_set_talk_tip_visible(false)
	close_inventory()
	player = null
	print("离开NPC范围")


# ------------------------------ UI 核心操作函数 ------------------------------
func toggle_inventory() -> void:
	# 切换 UI 状态：已打开则关闭，未打开则创建
	if _get_inventory_instance() == null:
		open_inventory()
		if not duihua.is_empty():
			await _play_dialog_timeline(duihua)
	else:
		close_inventory()


func open_inventory() -> void:
	# 检查是否配置了 UI 场景
	if inventory_scene == null:
		push_error("inventory_scene 未赋值，无法打开界面。")
		return
	if _get_inventory_instance() != null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_error("未找到当前场景根节点，无法打开界面。")
		return

	# 实例化 UI 场景
	var new_inventory := inventory_scene.instantiate()
	if new_inventory == null:
		push_error("inventory_scene 实例化失败。")
		return

	# 直接挂到当前场景根节点，避免破坏被实例化场景自己的 CanvasLayer 结构
	current_scene.add_child(new_inventory)
	inventory_instance = new_inventory
	# 锁定玩家并显示鼠标
	_lock_player_for_inventory()

	# 监听 UI 销毁信号，及时清理引用
	if not new_inventory.tree_exited.is_connected(_on_inventory_tree_exited):
		new_inventory.tree_exited.connect(_on_inventory_tree_exited, CONNECT_ONE_SHOT)


func close_inventory() -> void:
	# 获取当前有效的 UI 实例
	var current_inventory := _get_inventory_instance()
	if current_inventory == null:
		return

	# 销毁 UI 并解锁玩家
	inventory_instance = null
	current_inventory.queue_free()
	_unlock_player_from_inventory()


# ------------------------------ 辅助工具函数 ------------------------------
func _get_inventory_instance() -> Node:
	# 安全获取 UI 实例：防止引用已失效但变量未清空的情况
	if is_instance_valid(inventory_instance) and inventory_instance.is_inside_tree():
		return inventory_instance

	inventory_instance = null
	return null


func _ensure_ui_layer() -> CanvasLayer:
	# 优先复用已有的 UI 图层，避免重复创建
	if is_instance_valid(ui_layer) and ui_layer.is_inside_tree():
		return ui_layer

	# 在当前场景中查找或创建 UI 图层
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	# 尝试查找已存在的图层
	var existing_layer := current_scene.get_node_or_null(String(UI_LAYER_NAME)) as CanvasLayer
	if existing_layer != null:
		existing_layer.layer = UI_LAYER_ORDER
		ui_layer = existing_layer
		return ui_layer

	# 不存在则创建新图层
	var new_layer := CanvasLayer.new()
	new_layer.name = String(UI_LAYER_NAME)
	new_layer.layer = UI_LAYER_ORDER
	current_scene.add_child(new_layer)
	ui_layer = new_layer
	return ui_layer


func _ensure_dialog_host() -> Control:
	# 对话 UI 单独放到更高的 CanvasLayer，避免被其他 UI 遮挡
	if is_instance_valid(dialog_host) and dialog_host.is_inside_tree():
		return dialog_host

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	var existing_dialog_layer := current_scene.get_node_or_null(String(DIALOG_LAYER_NAME)) as CanvasLayer
	if existing_dialog_layer == null:
		existing_dialog_layer = CanvasLayer.new()
		existing_dialog_layer.name = String(DIALOG_LAYER_NAME)
		current_scene.add_child(existing_dialog_layer)
	existing_dialog_layer.layer = DIALOG_LAYER_ORDER
	dialog_layer = existing_dialog_layer

	var existing_host := dialog_layer.get_node_or_null(String(DIALOG_HOST_NAME)) as Control
	if existing_host == null:
		existing_host = Control.new()
		existing_host.name = String(DIALOG_HOST_NAME)
		existing_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		existing_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dialog_layer.add_child(existing_host)

	dialog_host = existing_host
	return dialog_host


func _play_dialog_timeline(timeline_name: String) -> void:
	if timeline_name.is_empty():
		return

	var host := _ensure_dialog_host()
	if host == null:
		push_error("未找到对话宿主节点，无法播放 Dialogic 时间线。")
		return

	var layout := Dialogic.Styles.get_layout_node()
	if layout != null:
		if layout.get_parent() != host:
			layout.reparent(host)
	else:
		layout = Dialogic.Styles.load_style("", host)
		await get_tree().process_frame

	_apply_dialog_layout_order(layout)
	layout.show()

	layout = Dialogic.start(timeline_name)
	_apply_dialog_layout_order(layout)
	await Dialogic.timeline_ended


func _apply_dialog_layout_order(layout: Node) -> void:
	if layout == null:
		return

	for property_info in layout.get_property_list():
		if property_info.get("name", "") == "layer":
			layout.set("layer", DIALOG_LAYER_ORDER)
			return


func _set_talk_tip_visible(vis: bool) -> void:
	# 安全设置提示面板可见性（允许不赋值）
	if talk_tip == null:
		return
	talk_tip.visible = vis


func _show_mouse_for_inventory() -> void:
	# 显示鼠标并记录之前的模式
	if mouse_visible_by_inventory:
		return

	mouse_mode_before_inventory = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_visible_by_inventory = true


func _lock_player_for_inventory() -> void:
	# 锁定玩家：停止移动、暂停输入与物理、显示鼠标
	if player_locked_by_inventory:
		return

	if is_instance_valid(player):
		# 清零玩家速度
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		# 只停用玩家脚本逻辑，避免 Area3D 因玩家节点被整体禁用而立刻触发离开
		player_input_process_before_inventory = player.is_processing_input()
		player_unhandled_input_before_inventory = player.is_processing_unhandled_input()
		player_physics_process_before_inventory = player.is_physics_processing()
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set_physics_process(false)

	# 显示鼠标
	_show_mouse_for_inventory()
	player_locked_by_inventory = true


func _restore_mouse_after_inventory() -> void:
	# 恢复鼠标到之前的模式
	if not mouse_visible_by_inventory:
		return

	Input.mouse_mode = mouse_mode_before_inventory
	mouse_visible_by_inventory = false


func _unlock_player_from_inventory() -> void:
	# 解锁玩家：恢复输入/物理、恢复鼠标
	if not player_locked_by_inventory:
		return

	if is_instance_valid(player):
		player.set_process_input(player_input_process_before_inventory)
		player.set_process_unhandled_input(player_unhandled_input_before_inventory)
		player.set_physics_process(player_physics_process_before_inventory)
		# 再次清零速度防止残留
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

	# 恢复鼠标
	_restore_mouse_after_inventory()
	player_locked_by_inventory = false


func _on_inventory_tree_exited() -> void:
	# UI 被销毁时的回调：清理引用并解锁玩家
	inventory_instance = null
	_unlock_player_from_inventory()
