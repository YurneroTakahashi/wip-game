# PlayerCastle.gd
extends CharacterBody3D

@export var passive_damage: int = 15      # Урон пассивной атаки
@export var passive_cooldown: float = 1.0 # Раз в секунду бьем всех вокруг
@export var passive_range: float = 8.0    # Радиус поражения

@onready var health_component: HealthComponent = $HealthComponent
@onready var area_3d: Area3D = $PassiveAttackArea
var debug_label: Label3D
var passive_attack_timer: float = 0.0

func _ready():
	add_to_group("castle")
	# Подключаем сигнал смерти
	health_component.died.connect(_on_castle_destroyed)
	# Настраиваем область для визуальной индикации (опционально)
	if area_3d:
		area_3d.body_entered.connect(_on_enemy_entered_attack_area)
	debug_label = Label3D.new()
	debug_label.text = str("Хп церкви:",health_component.current_health)
	debug_label.pixel_size = 0.20
	debug_label.position = Vector3(0, 13, 0)
	add_child(debug_label)

func _process(delta):
	if not GameManager.is_game_active:
		return
	
	# Пассивная атака по таймеру
	passive_attack_timer += delta
	if passive_attack_timer >= passive_cooldown:
		passive_attack_timer = 0.0
		_perform_passive_attack()
	

func _perform_passive_attack():
	# Находим всех врагов в радиусе
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= passive_range:
			# Наносим урон врагу
			if enemy.has_method("take_damage"):
				enemy.take_damage(passive_damage)
				hit_count += 1
	
	if hit_count > 0:
		print("Passive attack hit ", hit_count, " enemies")

# Проверка входа врага в зону (можно использовать для визуальных эффектов)
func _on_enemy_entered_attack_area(body: Node):
	if body.is_in_group("enemies"):
		pass  # Здесь можно добавить визуальный фидбек или звук

func _on_castle_destroyed():
	print("Game Over! Castle destroyed.")
	GameManager.is_game_active = false
	GameManager.game_over.emit(false)
	
	# Останавливаем спавн врагов
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		spawner.queue_free()
