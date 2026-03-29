extends Node
class_name EdgeSpawner

# Параметры спавна
@export var enemy_scene: PackedScene
@export var civilian_scene: PackedScene

@export var spawn_burst_size: int = 2
@export var civ_spawn_burst_size: int = 1
@export var max_enemies_total: int = 30

# Интервалы спавна
@export var spawn_interval: float = 1.5
@export var civ_spawn_interval: float = 2.0

# Параметры волн
@export var time_between_waves: float = 5.0        # Время на торг между волнами (7-15 сек)
@export var wave_start_delay: float = 0.0          # Задержка перед началом волны после торга

# Паттерны спавна по волнам (максимально близко к старой логике, но без формул и экспоненциального разгона)
const TOTAL_WAVES: int = 5
const PHASE_TYPES: Array[String] = ["warmup", "battle", "break", "epicbattle"]

const ENEMY_PHASE_COUNTS := [
	[2, 5, 3, 7],
	[3, 5, 3, 8],
	[4, 7, 3, 8],
	[4, 8, 4, 10],
	[5, 9, 5, 11]
]

const ENEMY_PHASE_INTERVALS := [
	[1.8, 1.60, 1.60, 1.50],
	[1.6, 1.55, 1.40, 1.48],
	[1.5, 1.50, 1.20, 1.45],
	[1.4, 1.48, 1.10, 1.42],
	[1.3, 1.45, 1.00, 1.40]
]

const PHASE_SPEEDSTER_RATIOS := [
	[0.15, 0.25, 0.20, 0.35],
	[0.20, 0.30, 0.25, 0.40],
	[0.25, 0.35, 0.30, 0.45],
	[0.30, 0.40, 0.35, 0.50],
	[0.35, 0.45, 0.40, 0.55]
]

const CIVILIANS_PER_WAVE := [5, 6, 7, 8, 9]
const TIME_BETWEEN_WAVES := [5.0, 5.0, 5.0, 5.0, 5.0]   # можешь увеличить, если нужно
const WAVE_START_DELAYS := [2.0, 2.0, 2.0, 2.0, 2.0]


@onready var player_castle: CharacterBody3D = $"../PlayerCastle"

# Внутренние переменные
var current_wave: int = 0
var phases: Array = []
var current_phase_idx: int = 0
var enemies_to_spawn_in_phase: int = 0
var civilians_to_spawn_in_wave: int = 0
var civilians_spawned: int = 0
var civilians_saved: int = 0                       # Гражданские, дошедшие до замка
var current_speedster_ratio: float = 0.25

# Состояния спавнера
enum SpawnerState { BETWEEN_WAVES, WAVE_START_DELAY, WAVE_ACTIVE }
var current_state: SpawnerState = SpawnerState.BETWEEN_WAVES

var state_timer: float = 0.0
var spawn_timer: float = 0.0
var civ_timer: float = 0.0

@onready var map_manager: MapManager = null

# Сигналы для UI
signal wave_ended(wave_number: int, civilians_saved: int)
signal wave_started(wave_number: int)
signal trading_phase_started(time_remaining: float)

func _ready():
	add_to_group("spawners")
	
	if not enemy_scene:
		enemy_scene = preload("res://Scenes/enemy.tscn")
	if not civilian_scene:
		civilian_scene = preload("res://Scenes/civilian.tscn")
	
	map_manager = get_node("/root/Map_Manager")
	if map_manager == null:
		map_manager = MapManager.new()
		add_child(map_manager)
	
	# Начинаем с первой волны
	_start_next_wave()

func _process(delta):
	GameManager.change_wave(current_wave)
	if not GameManager.is_game_active:
		return
	
	match current_state:
		SpawnerState.BETWEEN_WAVES:
			state_timer += delta
			if state_timer >= time_between_waves:
				current_state = SpawnerState.WAVE_START_DELAY
				state_timer = 0.0
				print("Trading phase ended! Next wave starting in ", wave_start_delay, " seconds")
		
		SpawnerState.WAVE_START_DELAY:
			state_timer += delta
			if state_timer >= wave_start_delay:
				current_state = SpawnerState.WAVE_ACTIVE
				state_timer = 0.0
				_activate_wave()
		
		SpawnerState.WAVE_ACTIVE:
			_update_wave(delta)

func _update_wave(delta):
	# Обработка спавна врагов текущей фазы
	if enemies_to_spawn_in_phase > 0:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_try_spawn_enemy_batch()
	
	# Спавн гражданских (параллельно)
	if civilians_spawned < civilians_to_spawn_in_wave:
		civ_timer += delta
		if civ_timer >= civ_spawn_interval:
			civ_timer = 0.0
			_spawn_single_civ()
			civilians_spawned += 1
	
	# Проверка окончания волны
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if enemies_to_spawn_in_phase == 0 and current_phase_idx >= phases.size() and current_enemies == 0:
		_end_wave()

func _start_next_wave():
	if current_wave >= TOTAL_WAVES:
		GameManager.victory()
		return

	current_wave += 1
	civilians_spawned = 0
	civilians_saved = 0
	spawn_timer = 0.0
	civ_timer = 0.0

	var wave_idx = current_wave - 1
	time_between_waves = TIME_BETWEEN_WAVES[wave_idx]
	wave_start_delay = WAVE_START_DELAYS[wave_idx]
	civilians_to_spawn_in_wave = CIVILIANS_PER_WAVE[wave_idx]
	
	# Генерируем фазы
	_generate_phases()
	current_phase_idx = 0
	
	# Запускаем фазу торга
	current_state = SpawnerState.BETWEEN_WAVES
	state_timer = 0.0
	
	print("=== Trading Phase Started ===")
	print("Wave ", current_wave, " will start in ", time_between_waves, " seconds")
	print("Civilians to save this wave: ", civilians_to_spawn_in_wave)
	player_castle._upgrade()
	trading_phase_started.emit(time_between_waves)

func _activate_wave():
	_set_phase(current_phase_idx)
	
	print("=== Wave ", current_wave, " STARTED! ===")
	wave_started.emit(current_wave)

func _end_wave():
	current_state = SpawnerState.BETWEEN_WAVES
	state_timer = 0.0
	
	print("=== Wave ", current_wave, " ENDED! ===")
	print("Civilians saved: ", civilians_saved, "/", civilians_to_spawn_in_wave)
	
	wave_ended.emit(current_wave, civilians_saved)
	
	# Передаем сохраненных гражданских в GameManager для улучшений
	
	# Запускаем следующую волну
	_start_next_wave()

func _generate_phases():
	phases.clear()

	var wave_idx = current_wave - 1
	var phase_counts = ENEMY_PHASE_COUNTS[wave_idx]
	var phase_intervals = ENEMY_PHASE_INTERVALS[wave_idx]
	var phase_speedsters = PHASE_SPEEDSTER_RATIOS[wave_idx]

	for i in range(PHASE_TYPES.size()):
		var phase_count = int(phase_counts[i])
		if phase_count <= 0:
			continue

		phases.append({
			"type": PHASE_TYPES[i],
			"count": phase_count,
			"interval": float(phase_intervals[i]),
			"speedster_ratio": float(phase_speedsters[i])
		})

func _set_phase(idx: int):
	if idx >= phases.size():
		enemies_to_spawn_in_phase = 0
		return
	
	var phase = phases[idx]
	enemies_to_spawn_in_phase = int(phase["count"])
	spawn_interval = float(phase.get("interval", spawn_interval))
	current_speedster_ratio = float(phase.get("speedster_ratio", current_speedster_ratio))
	print("Phase ", idx + 1, "/", phases.size(), ": ", phase["type"], " (", enemies_to_spawn_in_phase, " enemies, interval=", spawn_interval, ", speedsters=", current_speedster_ratio, ")")

func _try_spawn_enemy_batch():
	if enemies_to_spawn_in_phase <= 0:
		return
	
	var to_spawn = min(spawn_burst_size, enemies_to_spawn_in_phase)
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	var max_spawn = max_enemies_total - current_enemies
	
	if max_spawn <= 0:
		return
	
	to_spawn = min(to_spawn, max_spawn)
	
	for i in range(to_spawn):
		_spawn_single_enemy()
		enemies_to_spawn_in_phase -= 1
	
	if enemies_to_spawn_in_phase == 0:
		current_phase_idx += 1
		_set_phase(current_phase_idx)

func _spawn_single_enemy():
	var enemy_instance = enemy_scene.instantiate()
	var spawn_position = map_manager.get_random_edge_position()
	
	spawn_position.x += randf_range(-1.0, 1.0)
	spawn_position.z += randf_range(-1.0, 1.0)
	
	enemy_instance.global_position = spawn_position
	
	# Тип врага зависит от текущей фазы, а не от случайного 50/50
	var enemy_type = 0
	if randf() < current_speedster_ratio:
		enemy_type = 1
	
	if enemy_instance.has_method("set_target"):
		enemy_instance.set_target(map_manager.castle_position)
	get_tree().current_scene.add_child(enemy_instance)
	enemy_instance.setup_type(enemy_type)
	
	print("[SPAWNER] Spawned enemy type: ", "SPEEDSTER" if enemy_type == 1 else "NORMAL")

func _spawn_single_civ():
	var civ = civilian_scene.instantiate()
	var spawn_pos = map_manager.get_random_edge_position()
	spawn_pos.x += randf_range(-1.0, 1.0)
	spawn_pos.z += randf_range(-1.0, 1.0)
	civ.global_position = spawn_pos
	
	# Подключаем сигнал сохранения гражданского
	civ.connect("reached_castle", _on_civilian_saved)
	
	if civ.has_method("set_target"):
		civ.set_target(map_manager.castle_position)
	get_tree().current_scene.add_child(civ)

func _on_civilian_saved():
	civilians_saved += 1
