# PlayerCastle.gd
extends CharacterBody3D

@export var passive_damage: int = 15      # Урон пассивной атаки
@export var passive_cooldown: float = 4.0 # Раз в секунду бьем всех вокруг
@export var passive_range: float = 15.0    # Радиус поражения

@onready var health_component: HealthComponent = $HealthComponent
@onready var area_3d: Area3D = $PassiveAttackArea
@onready var animation_player: AnimationPlayer = $charch_anim/AnimationPlayer

@onready var animation_player_cam: AnimationPlayer = $"../Camera3D/AnimationPlayer"

@onready var stage_1: Node3D = $stage_1
@onready var stage_2: Node3D = $stage_2
@onready var stage_3: Node3D = $stage_3


var debug_label: Label3D
var passive_attack_timer: float = 0.0
var civs: int = 0
var stage: int = 0
func _ready():
	health_component.max_health = 100
	health_component.current_health = 100
	add_to_group("castle")
	
	stage_1.visible = true
	stage_2.visible = false
	stage_3.visible = false
	# Подключаем сигнал смерти
	health_component.died.connect(_on_castle_destroyed)
	# Настраиваем область для визуальной индикации (опционально)
	if area_3d:
		area_3d.body_entered.connect(_on_enemy_entered_attack_area)
	debug_label = Label3D.new()
	debug_label.visible = false
	debug_label.text = str("Хп церкви:",health_component.current_health)
	debug_label.pixel_size = 0.20
	debug_label.position = Vector3(0, 13, 0)
	add_child(debug_label)

func _process(delta):
	#print(civs)
	if not GameManager.is_game_active:
		return
	debug_label.text = str("Хп церкви:",health_component.current_health)
	# Пассивная атака по таймеру
	passive_attack_timer += delta
	if passive_attack_timer >= passive_cooldown:
		
		_perform_passive_attack()
	

func _perform_passive_attack():
	# Находим всех врагов в радиусе
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	var min_distance = 10000
	var best_enemy = null
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			best_enemy = enemy
	if best_enemy and min_distance <= passive_range:
		if best_enemy.has_method("take_damage"):
			best_enemy.take_damage(passive_damage)
			passive_attack_timer = 0.0
	
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
		
func take_damage(dmg: int):
	health_component.take_damage(dmg)

func accept_civilian():
	civs += 1

func get_health() -> int:
	return health_component.current_health

func get_max_health() -> int:
	return health_component.max_health


func _upgrade() -> void:
	if stage == 1:
		animation_player.play("charch_stady_1")
	elif stage == 2:
		stage_1.visible = false
		stage_2.visible = true
		animation_player_cam.play("stage_1")
	elif stage == 3:
		animation_player.play("charch_stady_2")
	elif stage == 4:
		stage_2.visible = false
		stage_3.visible = true
	elif stage == 5:
		print("win")
		animation_player.play("charch_stady_3")
		GameManager.victory()
	stage += 1
