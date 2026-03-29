# Enemy.gd (полностью исправленный)
extends CharacterBody3D

@export var speed: float = 8.0
@export var damage_to_castle: int = 10
@export var health: int = 2
@export var arrival_distance: int = 1
@export var razmer: float = 3.0
var target_castle: Node3D
var debug_label: Label3D
var is_navigation_initialized: bool = false
var is_moving: bool = true
var enemy_type: int = 0

@onready var girl_run: Node3D = $girl_run
@onready var man_run: Node3D = $man_run
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

func _ready():
	
	arrival_distance = GameManager.castle_radius
	
	add_to_group("enemies")
	
	call_deferred("_initialize_navigation")

func setup_type(type: int) -> void:
	enemy_type = type
	if type == 0: # обычный
		speed = 8.0
		girl_run.visible = true
		man_run.visible = false
		print("[ENEMY] Type: NORMAL, speed: ", speed)
	elif type == 1: # speedster
		speed = 12.0
		girl_run.visible = false
		man_run.visible = true
		print("[ENEMY] Type: SPEEDSTER, speed: ", speed)
	girl_run.scale = Vector3(razmer,razmer,razmer)
	man_run.scale = Vector3(razmer,razmer,razmer)
	# Обновляем скорость в NavigationAgent
	if navigation_agent_3d and is_navigation_initialized:
		navigation_agent_3d.max_speed = speed

func _initialize_navigation():
	print("[ENEMY] Initializing navigation...")
	
	target_castle = get_tree().get_first_node_in_group("castle")
	
	if not target_castle:
		print("[ENEMY] ERROR: Castle not found!")
		return
	
	if not navigation_agent_3d:
		print("[ENEMY] ERROR: NavigationAgent3D not found!")
		return
	
	# Настройка NavigationAgent
	navigation_agent_3d.target_desired_distance = arrival_distance
	navigation_agent_3d.path_desired_distance = 0.5
	navigation_agent_3d.max_speed = speed
	
	# Устанавливаем цель
	navigation_agent_3d.target_position = target_castle.global_position
	
	# Ждем пару кадров для инициализации навигации
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	is_navigation_initialized = true
	
	# Проверяем путь
	var path = navigation_agent_3d.get_current_navigation_path()
	print("[ENEMY] Initialized! Speed: ", speed, " Path points: ", path.size())

func _physics_process(delta):
	if not is_moving:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if not GameManager or not GameManager.is_game_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if not target_castle:
		target_castle = get_tree().get_first_node_in_group("castle")
		return
	
	# ВРЕМЕННО: прямое движение к замку без навигации
	var direction = (target_castle.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	
	# Поворот
	if direction.length() > 0.1:
		rotation.y = atan2(direction.x, direction.z)
	
	# Атака при достижении
	var distance_to_castle = global_position.distance_to(target_castle.global_position)
	if distance_to_castle <= arrival_distance:
		_attack_castle()

func _attack_castle():
	if target_castle and target_castle.has_method("take_damage"):
		print("[ENEMY] Attacking castle! Damage: ", damage_to_castle)
		target_castle.take_damage(damage_to_castle)
	queue_free()

func take_damage(amount: int):
	health -= amount
	print("[ENEMY] Took damage: ", amount, " HP left: ", health)
	
	# Визуальный фидбек
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.05)
	
	if health <= 0:
		_die()

func _die():
	print("[ENEMY] Died at: ", global_position)
	queue_free()

func set_moving(moving: bool):
	is_moving = moving
	if not moving:
		velocity = Vector3.ZERO
		move_and_slide()

func update_navigation():
	if navigation_agent_3d and target_castle:
		navigation_agent_3d.target_position = target_castle.global_position
		navigation_agent_3d.max_speed = speed
