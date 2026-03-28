extends Node3D

var center_position: Vector3
var radius: float
var pull_strength: float
var duration: float

var elapsed_time: float = 0.0
var affected_enemies: Array = []
var is_initialized: bool = false

func setup(pos: Vector3, rad: float, strength: float, dur: float):
	center_position = pos
	radius = rad
	pull_strength = strength
	duration = dur
	
	print("=== VACUUM SETUP ===")
	print("Center: ", center_position)
	print("Radius: ", radius)
	print("Strength: ", pull_strength)
	print("Duration: ", duration)
	
	call_deferred("_delayed_init")

func _delayed_init():
	print("=== DELAYED INIT START ===")
	
	# Ждем один кадр
	await get_tree().process_frame
	
	print("Is in tree: ", is_inside_tree())
	
	# Находим всех врагов
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	print("Total enemies found: ", all_enemies.size())
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			print("Invalid enemy instance")
			continue
		
		var distance = center_position.distance_to(enemy.global_position)
		print("Enemy at: ", enemy.global_position, " distance: ", distance)
		
		if distance <= radius:
			affected_enemies.append(enemy)
			print("ENEMY ADDED to vacuum!")
			
			# Останавливаем врага
			if enemy.has_method("set_moving"):
				enemy.set_moving(false)
				print("Enemy movement stopped")
	
	print("Total affected enemies: ", affected_enemies.size())
	is_initialized = true
	
	# Запускаем таймер
	await get_tree().create_timer(duration).timeout
	_finish()

func _physics_process(delta):
	if not is_initialized:
		return
	
	elapsed_time += delta
	
	if elapsed_time >= duration:
		return
	
	if affected_enemies.size() == 0:
		return
	
	# Притягиваем каждого врага
	for enemy in affected_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var direction = center_position - enemy.global_position
		var distance = direction.length()
		
		if distance <= 0.5:
			continue
		
		var strength_multiplier = min(1.0, distance / radius)
		var force = direction.normalized() * pull_strength * strength_multiplier * delta
		
		enemy.global_position += force
		
		# Выводим отладку каждые 0.5 секунды
		if int(elapsed_time * 2) % 2 == 0:
			print("Pulling enemy, distance: ", distance)

func _finish():
	print("=== VACUUM FINISH ===")
	for enemy in affected_enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("set_moving"):
				enemy.set_moving(true)
			if enemy.has_method("update_navigation"):
				enemy.update_navigation()
	
	queue_free()
