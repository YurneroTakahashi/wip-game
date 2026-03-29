extends Node3D

# Параметры турели
var duration: float = 8.0
var damage_per_second: int = 1
var fire_rate: float = 0.1
@export var range: float = 20.0
@export var cone_angle: float = 70.0  # Полный угол сектора

# Внутренние переменные
var elapsed_time: float = 0.0
var fire_timer: float = 0.0

# Визуальные компоненты
var turret_body: MeshInstance3D
var turret_head: MeshInstance3D
var nozzle: MeshInstance3D

func _ready():
	_setup_visuals()
	_draw_cone_visual()
	
	print("=== FLAMETHROWER TURRET ===")
	print("Position: ", global_position)
	print("Range: ", range, " | Cone angle: ", cone_angle)
	print("Forward direction: ", -global_transform.basis.z)
	
	await get_tree().create_timer(duration).timeout
	_destroy()

func _setup_visuals():
	
	# Маркер направления (стрелка)
	var arrow = MeshInstance3D.new()
	arrow.mesh = CylinderMesh.new()
	(arrow.mesh as CylinderMesh).top_radius = 0.05
	(arrow.mesh as CylinderMesh).bottom_radius = 0.15
	(arrow.mesh as CylinderMesh).height = 0.5
	
	var arrow_material = StandardMaterial3D.new()
	arrow_material.albedo_color = Color(1, 1, 0)
	arrow.material_override = arrow_material
	arrow.position = Vector3(0, 0.8, 0.8)
	add_child(arrow)
	var direction = (arrow.global_position - global_position).normalized()
	rotation.y = atan2(direction.x, direction.z)

func _draw_cone_visual():
	# Удаляем старые визуальные элементы если есть
	for child in get_children():
		if child.has_meta("cone_visual"):
			child.queue_free()
	
	# Рисуем сектор в ЛОКАЛЬНЫХ координатах турели
	# Это гарантирует, что визуал и логика совпадают
	
	var half_angle_rad = deg_to_rad(cone_angle / 2)
	
	# 1. Круг радиуса
	var radius_circle = MeshInstance3D.new()
	radius_circle.mesh = CylinderMesh.new()
	(radius_circle.mesh as CylinderMesh).top_radius = range
	(radius_circle.mesh as CylinderMesh).bottom_radius = range
	(radius_circle.mesh as CylinderMesh).height = 0.05
	
	var circle_material = StandardMaterial3D.new()
	circle_material.albedo_color = Color(1, 0.3, 0, 0.3)
	circle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	radius_circle.material_override = circle_material
	radius_circle.position.y = 0.05
	radius_circle.set_meta("cone_visual", true)
	#add_child(radius_circle)
	
	# 2. Создаем точки границы сектора
	var points_count = 30
	
	for i in range(points_count + 1):
		# Угол от -half_angle до +half_angle
		var t = float(i) / points_count
		var angle = -half_angle_rad + t * (half_angle_rad * 2)
		
		# Координаты в локальной системе турели
		# X - вправо/влево, Z - вперед
		var x = sin(angle) * range
		var z = cos(angle) * range
		
		var point = MeshInstance3D.new()
		point.mesh = SphereMesh.new()
		(point.mesh as SphereMesh).radius = 0.12
		
		var point_material = StandardMaterial3D.new()
		point_material.albedo_color = Color(0.561, 0.476, 1.0, 0.9)
		point_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		point.material_override = point_material
		
		point.position = Vector3(x, 0.1, z)
		point.set_meta("cone_visual", true)
		add_child(point)
	
	# 3. Боковые линии (от турели до границ сектора)
	for side_angle in [-half_angle_rad, half_angle_rad]:
		var end_x = sin(side_angle) * range
		var end_z = cos(side_angle) * range
		
		var segments = 15
		for j in range(segments + 1):
			var t2 = float(j) / segments
			var x = end_x * t2
			var z = end_z * t2
			
			var line_point = MeshInstance3D.new()
			line_point.mesh = SphereMesh.new()
			(line_point.mesh as SphereMesh).radius = 0.08
			
			var line_material = StandardMaterial3D.new()
			line_material.albedo_color = Color(1, 0.3, 0, 0.7)
			line_point.material_override = line_material
			
			line_point.position = Vector3(x, 0.08, z)
			line_point.set_meta("cone_visual", true)
			add_child(line_point)
	
	# 4. Центральная линия
	var center_segments = 15
	for k in range(center_segments + 1):
		var t3 = float(k) / center_segments
		var z = range * t3
		
		var center_point = MeshInstance3D.new()
		center_point.mesh = SphereMesh.new()
		(center_point.mesh as SphereMesh).radius = 0.1
		
		var center_material = StandardMaterial3D.new()
		center_material.albedo_color = Color(1, 0.2, 0, 1.0)
		center_point.material_override = center_material
		
		center_point.position = Vector3(0, 0.1, z)
		center_point.set_meta("cone_visual", true)
		add_child(center_point)
	
	# 5. Добавляем полоски на земле внутри сектора (для наглядности)
	var stripes_count = 8
	for s in range(stripes_count):
		var angle = -half_angle_rad + (float(s) / stripes_count) * (half_angle_rad * 2)
		var distance_step = range / 5
		
		for d in range(1, 6):
			var dist = distance_step * d
			var x = sin(angle) * dist
			var z = cos(angle) * dist
			
			var stripe = MeshInstance3D.new()
			stripe.mesh = SphereMesh.new()
			(stripe.mesh as SphereMesh).radius = 0.06
			
			var stripe_material = StandardMaterial3D.new()
			stripe_material.albedo_color = Color(1, 0.5, 0, 0.5)
			stripe.material_override = stripe_material
			
			stripe.position = Vector3(x, 0.05, z)
			stripe.set_meta("cone_visual", true)
			add_child(stripe)

func _process(delta):
	elapsed_time += delta
	
	if elapsed_time >= duration:
		return
	
	# Атака
	fire_timer += delta
	if fire_timer >= fire_rate:
		fire_timer = 0.0
		_attack()

func _attack():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	print("=== FLAMETHROWER ATTACK ===")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		if _is_enemy_in_cone(enemy):
			hit_count += 1
			enemy.take_damage(damage_per_second)
			_add_hit_effect(enemy.global_position)
			print("HIT: ", enemy.name)
	
	if hit_count > 0:
		print("Hit ", hit_count, " enemies")
		_show_flame()
	else:
		print("No enemies in cone")

func _is_enemy_in_cone(enemy: Node3D) -> bool:
	# Получаем позицию врага в ЛОКАЛЬНЫХ координатах турели
	var local_pos = to_local(enemy.global_position)
	
	# Проверяем Z (вперед) - должен быть положительным (враг перед турелью)
	if local_pos.z <= 0:
		return false
	
	# Проверяем дистанцию
	var distance = local_pos.length()
	if distance > range:
		return false
	
	# Проверяем угол
	# Угол в радианах от оси Z (вперед)
	var angle_to_enemy = atan2(local_pos.x, local_pos.z)
	var half_angle_rad = deg_to_rad(cone_angle / 2)
	
	var in_cone = abs(angle_to_enemy) <= half_angle_rad
	
	# Отладка (каждую секунду)
	if int(Time.get_ticks_msec() / 1000) % 2 == 0:
		print("Enemy local pos: ", local_pos)
		print("Distance: ", distance, " Angle: ", rad_to_deg(angle_to_enemy), " In cone: ", in_cone)
	
	return in_cone

func _show_flame():
	# Эффект пламени
	var flame = MeshInstance3D.new()
	flame.mesh = SphereMesh.new()
	(flame.mesh as SphereMesh).radius = 0.35
	
	var flame_material = StandardMaterial3D.new()
	flame_material.albedo_color = Color(1, 0.5, 0, 0.9)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1, 0.3, 0)
	flame_material.emission_energy_multiplier = 2.0
	flame.material_override = flame_material
	
	flame.position = Vector3(0, 0.6, 0.9)
	add_child(flame)
	
	await get_tree().create_timer(0.2).timeout
	flame.queue_free()

func _add_hit_effect(position: Vector3):
	var hit = MeshInstance3D.new()
	hit.mesh = SphereMesh.new()
	(hit.mesh as SphereMesh).radius = 0.25
	
	var hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color(1, 0, 0, 0.9)
	hit_material.emission_enabled = true
	hit_material.emission = Color(1, 0, 0)
	hit.material_override = hit_material
	
	hit.global_position = position
	get_tree().current_scene.add_child(hit)
	
	await get_tree().create_timer(0.3).timeout
	hit.queue_free()

func _destroy():
	print("Flamethrower turret destroyed")
	queue_free()
