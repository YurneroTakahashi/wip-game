extends RigidBody3D

var target_position: Vector3
var fall_speed: float = 8.0
var puddle_scene: PackedScene
var has_landed: bool = false

func _ready():
	# Настройка физики
	gravity_scale = 2.0
	
	# Добавляем визуал бутылки (твоя модель)
	var bottle_model = load("res://assets/models/bottle.glb")  # Укажи путь к твоей модели
	if bottle_model:
		var instance = bottle_model.instantiate()
		add_child(instance)
	
	# Добавляем свечение
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 1.0)
	light.omni_range = 3.0
	light.light_energy = 1.5
	add_child(light)
	
	# Автоудаление через 5 секунд
	await get_tree().create_timer(5.0).timeout
	if not has_landed:
		queue_free()

func _physics_process(delta):
	if has_landed:
		return
	
	# Падение вниз
	linear_velocity = Vector3(0, -fall_speed, 0)
	
	# Вращение бутылки
	angular_velocity = Vector3(2, 3, 1)
	
	# Проверка столкновения с землёй
	var current_y = global_position.y
	var target_y = target_position.y
	
	if current_y <= target_y + 0.5:
		_land()

func _land():
	if has_landed:
		return
	
	has_landed = true
	print("Bottle landed at: ", global_position)
	
	# Эффект разбивания
	_shatter_effect()
	
	# Создаём лужу
	if puddle_scene:
		var puddle = puddle_scene.instantiate()
		puddle.global_position = target_position
		get_tree().current_scene.add_child(puddle)
	
	# Удаляем бутылку
	queue_free()

func _shatter_effect():
	# Эффект разбивания - частицы
	var particles = GPUParticles3D.new()
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 5.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	
	particles.process_material = particle_material
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true
	
	add_child(particles)
	
	# Световая вспышка
	var flash = OmniLight3D.new()
	flash.light_color = Color(0.5, 0.7, 1.0)
	flash.omni_range = 2.0
	flash.light_energy = 3.0
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.5)
	await tween.finished
	flash.queue_free()
