extends Node3D

# Параметры лужи (меняй здесь для баланса)
var duration: float = 5.0           # Сколько секунд существует
var damage_per_second: int = 1.5     # Урон в секунду
var radius: float = 12.0             # Радиус поражения
var tick_rate: float = 0.1          # Как часто наносить урон

# Внутренние переменные
var elapsed_time: float = 0.0
var tick_timer: float = 0.0

func _ready():
	# Добавляем простой визуал - просто небольшая сфера для отладки
	var simple_mesh = MeshInstance3D.new()
	simple_mesh.mesh = BoxMesh.new()
	simple_mesh.scale = Vector3(radius,0.3, radius)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.114, 0.784, 0.843, 0.788)  # Полупрозрачный зеленый
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	simple_mesh.material_override = material
	
	add_child(simple_mesh)
	
	print("Poison puddle ready! Duration: ", duration, "s, Damage: ", damage_per_second, "/s")

func _physics_process(delta):
	elapsed_time += delta
	
	# Проверяем, не пора ли исчезнуть
	if elapsed_time >= duration:
		queue_free()
		print("Poison puddle disappeared")
		return
	
	# Наносим урон с интервалами
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		_damage_enemies_in_radius()

func _damage_enemies_in_radius():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage_per_second)
				hit_count += 1
	
	if hit_count > 0:
		print("Poison puddle damaged ", hit_count, " enemies")
