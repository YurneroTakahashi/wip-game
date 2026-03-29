extends Node

# Параметры способности
var mana_cost: int = 30
var cooldown_seconds: float = 0.1
var bottle_scene: PackedScene
var puddle_scene: PackedScene

# Внутренние переменные
var current_cooldown: float = 0.0
var is_on_cooldown: bool = false

func _ready():
	# Загружаем сцены
	bottle_scene = preload("res://Scenes/holy_water_bottle.tscn")
	puddle_scene = preload("res://Scenes/holy_water.tscn")
	print("Holy Water ability ready!")

func _process(delta):
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0:
			is_on_cooldown = false
			print("Holy Water ready again!")

func use(target_position: Vector3) -> bool:
	if is_on_cooldown:
		print("Holy Water on cooldown!")
		return false
	
	if not GameManager.spend_mana(mana_cost):
		print("Not enough mana!")
		return false
	
	# Создаём падающую бутылку
	_create_falling_bottle(target_position)
	
	# Запускаем кулдаун
	is_on_cooldown = true
	current_cooldown = cooldown_seconds
	
	print("Holy Water used at: ", target_position)
	return true

func _create_falling_bottle(target_pos: Vector3):
	if not bottle_scene:
		print("ERROR: Bottle scene not loaded!")
		_create_puddle(target_pos)
		return
	
	var bottle = bottle_scene.instantiate()
	bottle.global_position = target_pos + Vector3(0, 8, 0)  # Появляется в небе
	bottle.target_position = target_pos
	bottle.puddle_scene = puddle_scene
	get_tree().current_scene.add_child(bottle)

func _create_puddle(position: Vector3):
	if puddle_scene:
		var puddle = puddle_scene.instantiate()
		puddle.global_position = position
		get_tree().current_scene.add_child(puddle)
