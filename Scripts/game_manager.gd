# GameManager.gd (автозагрузка)
extends Node

# Сигналы для событий игры
signal game_over(victory: bool)
signal mana_changed(current_mana: int, max_mana: int)

# Балансные параметры (будем менять здесь для тюнинга)
@export var max_mana: int = 600
@export var mana_regen_rate: float = 10.0  # единиц в секунду
@export var starting_mana: int = 300
@onready var cur_wave:int = 0
@onready var castle_radius:int = 14
var current_mana: int:
	set(value):
		current_mana = clampi(value, 0, max_mana)
		mana_changed.emit(current_mana, max_mana)

var is_game_active: bool = true

func _ready():
	current_mana = starting_mana
	# Запускаем регенерацию маны
	var regen_timer = Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.timeout.connect(_on_mana_regen_tick)
	regen_timer.autostart = true
	add_child(regen_timer)

func _on_mana_regen_tick():
	if is_game_active and current_mana < max_mana:
		current_mana += mana_regen_rate
		# Округляем для красоты, но храним как float для точности
		current_mana = mini(current_mana, max_mana)

# Метод для траты маны (будем вызывать из способностей)
func spend_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		print("Used ", amount, "mana, left: ", current_mana)
		return true
	return false
func change_wave(wave: int):
	cur_wave = wave
	if cur_wave == 1:
		castle_radius = 14
	elif cur_wave == 3:
		castle_radius = 28
	elif cur_wave == 5:
		castle_radius = 40
		
func on_game_over(victory: bool):
	if victory:
		print("POBEDA URAAA")
	else:
		print("PROEBALI")
	GameManager.is_game_active = false

	
	# Останавливаем спавн врагов
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		spawner.queue_free()
