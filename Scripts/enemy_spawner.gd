# EdgeSpawner.gd
extends Node
class_name EdgeSpawner
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0      # Интервал между спавнами
@export var spawn_burst_size: int = 1        # Сколько врагов спавнить за раз
@export var max_enemies_total: int = 30      # Максимум врагов на карте
@export var wave_size: int = 10              # Размер волны
@export var time_between_waves: float = 1.0  # Время между волнами

var current_wave: int = 0
var enemies_in_current_wave: int = 0
var is_wave_active: bool = false
var spawn_timer: float = 0.0
var wave_timer: float = 0.0

@onready var map_manager: MapManager = null

func _ready():
	add_to_group("spawners")
	
	if enemy_scene == null:
		enemy_scene = preload("res://Scenes/Enemy.tscn")
	
	# Находим MapManager
	map_manager = get_node("/root/Map_Manager")
	if map_manager == null:
		print("Warning: MapManager not found, creating default")
		map_manager = MapManager.new()
		add_child(map_manager)
	
	# Запускаем первую волну
	_start_next_wave()

func _process(delta):
	if not GameManager.is_game_active:
		return
	
	if not is_wave_active:
		wave_timer += delta
		if wave_timer >= time_between_waves:
			wave_timer = 0.0
			_start_next_wave()
		return
	
	# Активная волна - спавним врагов
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_try_spawn_enemies()

func _start_next_wave():
	current_wave += 1
	enemies_in_current_wave = 0
	is_wave_active = true
	
	# Увеличиваем сложность с каждой волной
	var wave_multiplier = 1.0 + (current_wave - 1) * 0.2
	spawn_burst_size = clamp(1 + current_wave / 3, 1, 8)
	#spawn_interval = max(0.5, 2.0 - current_wave * 0.1)
	
	print("Wave ", current_wave, " started! Spawning ", wave_size * wave_multiplier, " enemies")

func _try_spawn_enemies():
	# Проверяем, не слишком ли много врагов
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies_total:
		return
	
	# Определяем, сколько врагов нужно доспавнить в этой волне
	var enemies_to_spawn = spawn_burst_size
	var wave_limit = wave_size * (1.0 + (current_wave - 1) * 0.2)
	
	if enemies_in_current_wave + enemies_to_spawn > wave_limit:
		enemies_to_spawn = wave_limit - enemies_in_current_wave
	
	if enemies_to_spawn <= 0:
		# Волна закончилась
		is_wave_active = false
		print("Wave ", current_wave, " completed!")
		return
	
	# Спавним врагов
	for i in range(enemies_to_spawn):
		if current_enemies + i >= max_enemies_total:
			break
		_spawn_single_enemy()
		enemies_in_current_wave += 1

func _spawn_single_enemy():
	if enemy_scene == null:
		return
	
	var enemy_instance = enemy_scene.instantiate()
	var spawn_position = map_manager.get_random_edge_position()
	
	# Добавляем небольшой случайный сдвиг для разнообразия
	spawn_position.x += randf_range(-1.0, 1.0)
	spawn_position.z += randf_range(-1.0, 1.0)
	
	enemy_instance.global_position = spawn_position
	
	# Передаем врагу позицию замка
	if enemy_instance.has_method("set_target"):
		enemy_instance.set_target(map_manager.castle_position)
	
	get_tree().current_scene.add_child(enemy_instance)
