extends Node3D

signal entry
signal exit

var current_camera_position: Vector3
var current_camera_rotation: Vector3
var camera_tween: Tween
var is_top_view: bool = false

func _ready() -> void:
	current_camera_position = $TopViewCamera.get_position()
	current_camera_rotation = $TopViewCamera.get_rotation()
	_apply_tps_demo_world_style()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("set_top_view"):
		if is_top_view:
			set_third_person_view()
			is_top_view = false
			
		else:
			current_camera_position = $TopViewCamera.get_position()
			current_camera_rotation = $TopViewCamera.get_rotation()
			set_top_view()
			is_top_view = true
			

func set_top_view():
	# 如果已有动画在运行，先停止
	if camera_tween:
		camera_tween.kill()

	# 创建新的 Tween
	camera_tween = create_tween()
	camera_tween.set_parallel(true)  # 位置和旋转同时进行
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)

	# 平滑过渡位置
	camera_tween.tween_property($TopViewCamera, "position", Vector3(0, 10, 0), 0.8)
	# 平滑过渡旋转（使用弧度）
	camera_tween.tween_property($TopViewCamera, "rotation", Vector3(deg_to_rad(-90), 0, 0), 0.8)
	camera_tween.finished.connect(func():emit_signal("entry"))
	
	
func set_third_person_view():
	# 如果已有动画在运行，先停止
	if camera_tween:
		camera_tween.kill()

	# 创建新的 Tween
	camera_tween = create_tween()
	camera_tween.set_parallel(true)
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)

	# 平滑过渡回原位置和旋转
	camera_tween.tween_property($TopViewCamera, "position", current_camera_position, 0.8)
	camera_tween.tween_property($TopViewCamera, "rotation", current_camera_rotation, 0.8)
	emit_signal("exit")


func _apply_tps_demo_world_style() -> void:
	var world_environment := _ensure_world_environment()
	var environment := world_environment.environment
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_color = Color(0.0, 0.5900909, 0.93618846, 1.0)
	environment.ambient_light_energy = 0.0
	environment.ssr_enabled = true
	environment.ssao_enabled = false
	environment.ssil_enabled = true
	environment.sdfgi_enabled = false
	environment.glow_enabled = false
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = true

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_horizon_color = Color(0.66224277, 0.6717428, 0.6867428, 1.0)
	sky_material.ground_horizon_color = Color(0.66224277, 0.6717428, 0.6867428, 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky

	var directional_light := _ensure_directional_light()
	directional_light.basis = Basis(
		Vector3(0.11493719, -0.8611516, 0.4951841),
		Vector3(0.0, 0.4984877, 0.86689675),
		Vector3(-0.99337274, -0.09963868, 0.05729478)
	)
	directional_light.light_energy = 0.408
	directional_light.light_indirect_energy = 0.259
	directional_light.shadow_enabled = true


func _ensure_world_environment() -> WorldEnvironment:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		add_child(world_environment)
		world_environment.owner = self

	if world_environment.environment == null:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_SKY
		world_environment.environment = environment

	return world_environment


func _ensure_directional_light() -> DirectionalLight3D:
	var directional_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional_light == null:
		directional_light = DirectionalLight3D.new()
		directional_light.name = "DirectionalLight3D"
		add_child(directional_light)
		directional_light.owner = self

	return directional_light
