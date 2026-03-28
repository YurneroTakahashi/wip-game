extends Node

# Параметры способности
var mana_cost: int = 40
var cooldown_seconds: float = 1.0
var turret_scene: PackedScene

# Внутреннее состояние
var current_cooldown: float = 0.0
var is_on_cooldown: bool = false

func _ready():
	# Загружаем сцену турели
	turret_scene = preload("res://Scenes/flamethrower_turret.tscn")
	print("Flamethrower Ability loaded")

func _process(delta):
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0:
			is_on_cooldown = false
			print("Flamethrower ready again")

func use(target_position: Vector3) -> bool:
	# Для совместимости (если вызывается без направления, используем угол 0)
	return use_with_direction(target_position, 0.0)

func use_with_direction(target_position: Vector3, direction_angle: float) -> bool:
	if is_on_cooldown:
		print("On cooldown: ", round(current_cooldown), "s")
		return false
	
	if not GameManager.spend_mana(mana_cost):
		print("Not enough mana!")
		return false
	
	var turret = turret_scene.instantiate()
	turret.global_position = target_position
	turret.rotation.y = direction_angle  # Устанавливаем направление
	get_tree().current_scene.add_child(turret)
	
	is_on_cooldown = true
	current_cooldown = cooldown_seconds
	
	print("Turret placed at: ", target_position, " with angle: ", rad_to_deg(direction_angle))
	return true

func _create_turret(position: Vector3):
	if not turret_scene:
		print("ERROR: Turret scene not loaded!")
		return
	
	var turret = turret_scene.instantiate()
	turret.global_position = position
	get_tree().current_scene.add_child(turret)
	print("Turret added to scene at: ", position)
	print("Turret is visible: ", turret.visible)
	print("Turret children count: ", turret.get_child_count())
