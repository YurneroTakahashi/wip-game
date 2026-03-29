# civilian.gd (оптимизированная версия)
extends CharacterBody3D

@export var speed: float = 5.0
@export var damage_to_castle: int = 10
@export var health: int = 5
@export var arrival_distance: float = 14  # Дистанция для атаки замка

var target_castle: Node3D
var navigation_agent: NavigationAgent3D
var debug_label: Label3D
var is_navigation_initialized: bool = false
var is_moving: bool = true

func _ready():
	add_to_group("civilians")
	_setup_visuals()
	call_deferred("_initialize_navigation")

func _setup_visuals():
	# Визуал врага
	
	add_child(debug_label)

func _initialize_navigation():
	target_castle = get_tree().get_first_node_in_group("castle")
	
	if not target_castle:
		print("ERROR: Castle not found!")
		return
	
	navigation_agent = $NavigationAgent3D
	
	if not navigation_agent:
		print("ERROR: NavigationAgent3D not found!")
		return
	
	# Настройка NavigationAgent
	navigation_agent.target_desired_distance = arrival_distance
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.max_speed = speed
	
	# Устанавливаем цель
	navigation_agent.target_position = target_castle.global_position
	
	# Даем время на инициализацию
	await get_tree().physics_frame
	
	is_navigation_initialized = true
	
	# Проверяем путь
	var path = navigation_agent.get_current_navigation_path()
	print("civilian initialized, path points: ", path.size())
	if path.size() > 0:
		print("First path point: ", path[0])
		print("Target position: ", target_castle.global_position)

func _physics_process(delta):
	if not is_moving:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not GameManager.is_game_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if not is_navigation_initialized or not target_castle:
		return
	
	# Проверяем, достигли ли замка
	var distance_to_castle = global_position.distance_to(target_castle.global_position)
	
	if distance_to_castle <= arrival_distance:
		# Достигли замка - атакуем
		_enter_castle()
		return
	
	# Если NavigationAgent готов и есть путь
	if not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		
		# Движение
		velocity = direction * speed
		move_and_slide()
		
		# Поворот
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = target_rotation
		
		# Обновляем отладку
	else:
		# Если нет пути, но враг еще не у замка - пробуем перестроить путь
		if distance_to_castle > arrival_distance * 2:
			navigation_agent.target_position = target_castle.global_position
			debug_label.text = "Rebuilding..."

func _enter_castle():
	if target_castle and target_castle.has_method("accept_civilian"):
		print("civilian entering the castle")
		target_castle.accept_civilian()
		#target_castle.take_damage(damage_to_castle)
	queue_free()

func take_damage(amount: int):
	health -= amount
	
	# Визуальный фидбек
	var mesh = get_child(0) as MeshInstance3D
	if mesh and mesh.material_override:
		var original_color = mesh.material_override.albedo_color
		mesh.material_override.albedo_color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(mesh):
			mesh.material_override.albedo_color = original_color
	
	if health <= 0:
		_die()

func _die():
	print("civilian died at: ", global_position)
	queue_free()
	
func set_moving(moving: bool):
	is_moving = moving
	if not moving:
		velocity = Vector3.ZERO
		move_and_slide()
		print("civilian movement stopped")

# Добавь метод обновления навигации
func update_navigation():
	if navigation_agent and target_castle:
		navigation_agent.target_position = target_castle.global_position
		print("civilian navigation updated")
	
