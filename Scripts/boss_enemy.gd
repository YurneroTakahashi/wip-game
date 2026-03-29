extends CharacterBody3D

# Основные параметры
@export var health: int = 100
@export var damage_to_castle: int = 25

# Параметры спирального движения
@export var orbit_radius_start: float = 52.0   # Начальный радиус
@export var orbit_radius_end: float = 2.5      # Радиус для перехода к атаке
@export var angular_speed: float = 0.5         # Радиан в секунду (скорость кружения)
@export var radial_speed: float = 0.1        # Скорость приближения к центру

# Внутренние переменные
var target_castle: Node3D
var current_angle: float = 0.0
var current_radius: float
var is_moving: bool = true
var is_orbiting: bool = true
var debug_label: Label3D

# Атака
var attack_cooldown: float = 2.0
var attack_timer: float = 0.0

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	orbit_radius_end = GameManager.castle_radius
	target_castle = get_tree().get_first_node_in_group("castle")
	if not target_castle:
		print("ERROR: Boss cannot find castle!")
		queue_free()
		return
	
	current_radius = orbit_radius_start
	current_angle = randf_range(0, TAU)
	
	# Отладочная метка
	debug_label = Label3D.new()
	debug_label.text = str(health)
	debug_label.pixel_size = 0.3
	debug_label.position = Vector3(0, 2.0, 0)
	add_child(debug_label)
	
	print("Boss spawned! Start radius: ", current_radius)

func _physics_process(delta):
	if not GameManager.is_game_active or not is_moving:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	if not target_castle:
		return
	
	if debug_label:
		debug_label.text = str(health) + "\nR:" + str(int(current_radius))
	
	_update_spiral(delta)
	
	move_and_slide()
	
	# Поворот в сторону движения
	if velocity.length() > 0.1:
		var direction = velocity.normalized()
		rotation.y = atan2(direction.x, direction.z)

func _update_spiral(delta):
	# 1. Увеличиваем угол (продолжаем кружение)
	current_angle += angular_speed * delta
	
	# 2. Уменьшаем радиус (приближаемся к центру)
	current_radius -= radial_speed * delta
	
	# 3. ВЫЧИСЛЯЕМ КАСАТЕЛЬНУЮ (направление движения по окружности)
	# Вектор от замка к боссу
	var to_boss = global_position - target_castle.global_position
	to_boss.y = 0
	if to_boss.length() <= orbit_radius_end:
		radial_speed = 0
		angular_speed = 0
		GameManager.on_game_over(0)
		#print(to_boss.length())
	# Касательный вектор (перпендикуляр) - направление по окружности
	var tangent = Vector3(-to_boss.z, 0, to_boss.x)
	
	# Радиальный вектор (к центру)
	var radial = -to_boss
	
	# Смешиваем касательное и радиальное движение
	# Касательное - для кружения, радиальное - для приближения
	var move_dir = tangent * angular_speed + radial * radial_speed
	move_dir = move_dir.normalized()
	
	# Скорость движения
	var current_speed = (angular_speed * current_radius) + radial_speed
	velocity = move_dir * current_speed
	
	# Отладка
	if Engine.get_process_frames() % 60 == 0:
		print("Angle: ", rad_to_deg(current_angle), " Radius: ", current_radius)
	
	# Проверяем, достигли ли минимального радиуса
	if current_radius <= orbit_radius_end:
		is_orbiting = false
		print("Boss reached min radius! Switching to attack!")

func _update_attack(delta):
	# Идём прямо к замку
	var direction = (target_castle.global_position - global_position).normalized()
	velocity = direction * 8.0
	
	# Проверяем дистанцию до замка
	var distance = global_position.distance_to(target_castle.global_position)
	
	if distance <= 2.0:
		velocity = Vector3.ZERO
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_attack_castle()

func _attack_castle():
	if target_castle and target_castle.has_method("take_damage"):
		print("BOSS attacking castle! Damage: ", damage_to_castle)
		target_castle.take_damage(damage_to_castle)

func take_damage(amount: int):
	health -= amount
	print("Boss took damage: ", amount, " HP left: ", health)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.05)
	
	if health <= 0:
		_die()

func _die():
	print("Boss defeated!")
	
	# Эффект взрыва
	var explosion = MeshInstance3D.new()
	explosion.mesh = SphereMesh.new()
	(explosion.mesh as SphereMesh).radius = 1.5
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.3, 0)
	material.emission_enabled = true
	material.emission = Color(1, 0.2, 0)
	explosion.material_override = material
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	
	await get_tree().create_timer(0.5).timeout
	explosion.queue_free()
	queue_free()

func set_moving(moving: bool):
	is_moving = moving
	if not moving:
		velocity = Vector3.ZERO
		move_and_slide()
