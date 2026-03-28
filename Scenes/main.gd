# Main.gd (скрипт для главной сцены)
extends Node3D

@onready var castle: Node3D = $PlayerCastle
@onready var edge_spawner: EdgeSpawner = $EdgeSpawner

var poison_ability: Node
var vacuum_ability: Node
var flamethrower_ability: Node

enum AbilityState { NONE, AWAITING_POSITION, AWAITING_DIRECTION }
var current_ability: String = ""  # "poison", "vacuum", "flamethrower"
var ability_state: AbilityState = AbilityState.NONE

var preview_node: Node3D = null
var direction_preview: Node3D = null
var temp_position: Vector3 = Vector3.ZERO

func _ready():
	# Настраиваем MapManager
	var map_manager = get_node("/root/Map_Manager")
	if map_manager:
		# Настраиваем границы карты в зависимости от визуального окружения
		map_manager.map_left = -25.0
		map_manager.map_right = 25.0
		map_manager.map_top = -25.0
		map_manager.map_bottom = 25.0
		map_manager.castle_position = castle.global_position
	
	# Подключаем сигналы GameManager
	GameManager.game_over.connect(_on_game_over)
	
	# Создаем визуальные границы (опционально)
	_create_visual_boundaries()
	_setup_abilities()

func _create_visual_boundaries():
	# Создаем прозрачные стены или маркеры на границах карты
	var map_manager = get_node("/root/Map_Manager")
	if not map_manager:
		return
	
	# Создаем простые маркеры по углам
	var corners = [
		Vector3(map_manager.map_left, 0, map_manager.map_top),
		Vector3(map_manager.map_left, 0, map_manager.map_bottom),
		Vector3(map_manager.map_right, 0, map_manager.map_top),
		Vector3(map_manager.map_right, 0, map_manager.map_bottom)
	]
	
	for corner in corners:
		var marker = MeshInstance3D.new()
		marker.mesh = BoxMesh.new()
		marker.mesh.size = Vector3(0.5, 0.5, 0.5)
		marker.material_override = StandardMaterial3D.new()
		marker.material_override.albedo_color = Color.YELLOW
		marker.position = corner
		add_child(marker)

func _on_game_over(victory: bool):
	if not victory:
		print("Game Over! You lost!")
		# Здесь можно добавить экран поражения


func _setup_abilities():
	poison_ability = preload("res://Scripts/Abilities/Abilities/holy_water.gd").new()
	add_child(poison_ability)
	
	# Вакуум
	vacuum_ability = preload("res://Scripts/Abilities/Abilities/vacuum_ability.gd").new()
	add_child(vacuum_ability)
	flamethrower_ability = preload("res://Scripts/Abilities/Abilities/flamethrower_ability.gd").new()
	add_child(flamethrower_ability)
	
	print("All three abilities loaded")

func _input(event):
	# Обработка выбора способности по клавишам
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_select_ability("vacuum")
			KEY_E:
				_select_ability("poison")
			KEY_R:
				_select_ability("flamethrower")
			KEY_ESCAPE:
				_cancel_ability_selection()
	
	# Обработка кликов мыши при активном выборе
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click()

func _select_ability(ability: String):
	# Сбрасываем предыдущий выбор
	_cancel_ability_selection()
	
	current_ability = ability
	ability_state = AbilityState.AWAITING_POSITION
	
	print("Selected ability: ", ability, ". Click to set position.")
	
	# Включаем визуальное превью позиции
	_show_position_preview()

func _cancel_ability_selection():
	current_ability = ""
	ability_state = AbilityState.NONE
	_remove_preview()
	_remove_direction_preview()
	print("Ability selection cancelled.")

func _handle_mouse_click():
	if ability_state == AbilityState.NONE:
		return
	
	var click_position = _get_mouse_ground_position()
	if click_position == Vector3.ZERO:
		print("No valid ground position.")
		return
	
	match ability_state:
		AbilityState.AWAITING_POSITION:
			if current_ability == "flamethrower":
				# Для огнемётчика запоминаем позицию и ждём направление
				temp_position = click_position
				ability_state = AbilityState.AWAITING_DIRECTION
				print("Position set. Now choose direction.")
				_show_direction_preview(temp_position)
				_remove_preview()  # убираем круг позиции
			else:
				# Для остальных способностей сразу используем
				_use_ability_at(click_position)
				_cancel_ability_selection()
		
		AbilityState.AWAITING_DIRECTION:
			# Для огнемётчика используем позицию и направление
			var direction = _get_direction_from_mouse(temp_position)
			_use_flamethrower_with_direction(temp_position, direction)
			_cancel_ability_selection()

func _use_ability_at(position: Vector3):
	match current_ability:
		"poison":
			poison_ability.use(position)
		"vacuum":
			vacuum_ability.use(position)
		_:
			print("Unknown ability: ", current_ability)

func _use_flamethrower_with_direction(position: Vector3, direction_angle: float):
	# Создаём турель с заданным направлением
	flamethrower_ability.use_with_direction(position, direction_angle)

func _get_mouse_ground_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	return result.position

func _get_direction_from_mouse(position: Vector3) -> float:
	# Получаем позицию мыши на земле и вычисляем угол от позиции турели
	var mouse_pos = _get_mouse_ground_position()
	if mouse_pos == Vector3.ZERO:
		return 0.0
	var dir_vec = mouse_pos - position
	return atan2(dir_vec.x, dir_vec.z)  # угол в радианах

# Визуальное превью
func _show_position_preview():
	_remove_preview()
	preview_node = Node3D.new()
	add_child(preview_node)
	
	# Круг на земле
	var circle = MeshInstance3D.new()
	circle.mesh = CylinderMesh.new()
	(circle.mesh as CylinderMesh).top_radius = 1.0
	(circle.mesh as CylinderMesh).bottom_radius = 1.0
	(circle.mesh as CylinderMesh).height = 0.05
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	circle.material_override = mat
	circle.position.y = 0.05
	preview_node.add_child(circle)
	
	# Обновляем позицию превью в _process
	set_process(true)

func _remove_preview():
	if preview_node:
		preview_node.queue_free()
		preview_node = null

# Замени метод _show_direction_preview на этот:

func _show_direction_preview(position: Vector3):
	_remove_direction_preview()
	direction_preview = Node3D.new()
	direction_preview.global_position = position
	add_child(direction_preview)
	
	# Стрелка направления (используем BoxMesh вместо ConeMesh)
	# Создаем треугольную стрелку из двух BoxMesh
	
	# Основание стрелки (длинный куб)
	var stem = MeshInstance3D.new()
	stem.mesh = BoxMesh.new()
	(stem.mesh as BoxMesh).size = Vector3(0.15, 0.1, 1.2)
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(1, 0.5, 0, 0.9)
	stem.material_override = stem_mat
	stem.position = Vector3(0, 0.2, 0)
	direction_preview.add_child(stem)
	
	# Наконечник стрелки (маленький куб, повернутый)
	var tip = MeshInstance3D.new()
	tip.mesh = BoxMesh.new()
	(tip.mesh as BoxMesh).size = Vector3(0.3, 0.15, 0.4)
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1, 0.3, 0, 0.9)
	tip.material_override = tip_mat
	tip.position = Vector3(0, 0.2, 0.7)
	direction_preview.add_child(tip)
	
	# Добавляем круг под турелью
	var base_circle = MeshInstance3D.new()
	base_circle.mesh = CylinderMesh.new()
	(base_circle.mesh as CylinderMesh).top_radius = 0.8
	(base_circle.mesh as CylinderMesh).bottom_radius = 0.8
	(base_circle.mesh as CylinderMesh).height = 0.05
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(1, 0.5, 0, 0.5)
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_circle.material_override = base_mat
	base_circle.position.y = 0.02
	direction_preview.add_child(base_circle)
	
	# Добавляем сектор (дуга) для визуализации угла
	var cone_angle = 120  # Полный угол сектора
	var range = 4.0
	var half_angle_rad = deg_to_rad(cone_angle / 2)
	var points = 25
	
	# Создаем точки по дуге
	for i in range(points + 1):
		var t = float(i) / points
		var angle = -half_angle_rad + t * (half_angle_rad * 2)
		var x = sin(angle) * range
		var z = cos(angle) * range
		
		var point = MeshInstance3D.new()
		point.mesh = SphereMesh.new()
		(point.mesh as SphereMesh).radius = 0.12
		var point_mat = StandardMaterial3D.new()
		point_mat.albedo_color = Color(1, 0.3, 0, 0.8)
		point_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		point.material_override = point_mat
		point.position = Vector3(x, 0.1, z)
		direction_preview.add_child(point)
	
	# Добавляем боковые линии
	for side_angle in [-half_angle_rad, half_angle_rad]:
		var end_x = sin(side_angle) * range
		var end_z = cos(side_angle) * range
		
		var segments = 12
		for j in range(segments + 1):
			var t2 = float(j) / segments
			var x = end_x * t2
			var z = end_z * t2
			
			var line_point = MeshInstance3D.new()
			line_point.mesh = SphereMesh.new()
			(line_point.mesh as SphereMesh).radius = 0.08
			var line_mat = StandardMaterial3D.new()
			line_mat.albedo_color = Color(1, 0.4, 0, 0.7)
			line_point.material_override = line_mat
			line_point.position = Vector3(x, 0.08, z)
			direction_preview.add_child(line_point)
	
	# Добавляем центральную линию
	var center_segments = 12
	for k in range(center_segments + 1):
		var t3 = float(k) / center_segments
		var z = range * t3
		
		var center_point = MeshInstance3D.new()
		center_point.mesh = SphereMesh.new()
		(center_point.mesh as SphereMesh).radius = 0.1
		var center_mat = StandardMaterial3D.new()
		center_mat.albedo_color = Color(1, 0.2, 0, 1.0)
		center_point.material_override = center_mat
		center_point.position = Vector3(0, 0.1, z)
		direction_preview.add_child(center_point)
	
	# Обновляем поворот стрелки в _process
	set_process(true)

func _remove_direction_preview():
	if direction_preview:
		direction_preview.queue_free()
		direction_preview = null

func _process(delta):
	if preview_node:
		var mouse_pos = _get_mouse_ground_position()
		if mouse_pos != Vector3.ZERO:
			preview_node.global_position = mouse_pos
	
	if direction_preview:
		var mouse_dir = _get_direction_from_mouse(direction_preview.global_position)
		direction_preview.rotation.y = mouse_dir
