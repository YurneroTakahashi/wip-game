extends Node

# Параметры способности
var mana_cost: int = 35
var cooldown_seconds: float = 1.0
var vacuum_radius: float = 25.0
var pull_strength: float = 80.0
var duration: float = 0.5

# Внутреннее состояние
var current_cooldown: float = 0.0
var is_on_cooldown: bool = false

# Сцена эффекта
var vacuum_effect_scene: PackedScene

func _ready():
	# Загружаем сцену эффекта
	vacuum_effect_scene = preload("res://Scenes/vacuum_effect.tscn")
	print("Vacuum Ability loaded")

func _process(delta):
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0:
			is_on_cooldown = false
			print("Vacuum ready again")

func use(target_position: Vector3) -> bool:
	# Проверка кулдауна
	if is_on_cooldown:
		print("Vacuum on cooldown: ", round(current_cooldown), "s left")
		return false
	
	# Проверка маны
	if not GameManager.spend_mana(mana_cost):
		print("Not enough mana! Need ", mana_cost)
		return false
	
	# Создаем эффект вакуума
	_create_vacuum_effect(target_position)
	
	# Запускаем кулдаун
	is_on_cooldown = true
	current_cooldown = cooldown_seconds
	
	print("Vacuum used at: ", target_position)
	return true

func _create_vacuum_effect(position: Vector3):
	if not vacuum_effect_scene:
		print("ERROR: Vacuum effect scene not loaded!")
		return
	
	var vacuum = vacuum_effect_scene.instantiate()
	vacuum.setup(position, vacuum_radius, pull_strength, duration)
	get_tree().current_scene.add_child(vacuum)
	print("Vacuum effect created at: ", position)
