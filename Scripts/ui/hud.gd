extends Control

# Ссылки на элементы UI
@onready var wave_label: Label = $TopPanel/VBoxContainer/WaveLabel
@onready var civilians_label: Label = $TopPanel/VBoxContainer/CiviliansLabel
@onready var timer_label: Label = $TopPanel/VBoxContainer/TimerLabel


@onready var health_bar: ProgressBar = $BottomPanel/HBoxContainer2/HealthBar
@onready var mana_bar: ProgressBar = $BottomPanel/HBoxContainer2/ManaBar

@onready var health_label: Label = $BottomPanel/HBoxContainer/HealthLabel
@onready var mana_label: Label = $BottomPanel/HBoxContainer/ManaLabel

@onready var notification_label: Label = $CenterPanel/NotificationLabel
@onready var notification_panel: Panel = $CenterPanel
@onready var ability_panel: HBoxContainer = $AbilityPanel
@onready var ability1_button: Button = $AbilityPanel/Ability1
@onready var ability2_button: Button = $AbilityPanel/Ability2
@onready var ability3_button: Button = $AbilityPanel/Ability3


# Таймеры
var notification_timer: float = 0.0
var is_notification_active: bool = false
var wave_timer: float = 0.0
var is_trading_phase: bool = false

func _ready():
	_setup_signals()
	_setup_style()
	_setup_ability_buttons()
	
	# Скрываем панель уведомлений
	notification_panel.visible = false
	
	# Инициализируем отображение
	_update_mana(GameManager.current_mana, GameManager.max_mana)
	
	# Получаем здоровье замка
	var castle = get_tree().get_first_node_in_group("castle")
	if castle and castle.has_method("get_health"):
		_update_health(castle.get_health(), castle.get_max_health())
	
	print("HUD integrated with GameManager!")

func _setup_signals():
	# Сигналы GameManager
	GameManager.mana_changed.connect(_update_mana)
	GameManager.castle_damaged.connect(_update_health)
	GameManager.game_over.connect(_on_game_over)
	
	# Сигналы спавнера
	var spawner = get_tree().get_first_node_in_group("spawners")
	if spawner:
		if spawner.has_signal("wave_started"):
			spawner.wave_started.connect(_on_wave_started)
		if spawner.has_signal("trading_phase_started"):
			spawner.trading_phase_started.connect(_on_trading_phase_started)
		if spawner.has_signal("wave_ended"):
			spawner.wave_ended.connect(_on_wave_ended)

func _setup_style():
	# Настройка ProgressBar для здоровья
	health_bar.add_theme_color_override("bg_color", Color(0.2, 0.1, 0.1))
	health_bar.add_theme_color_override("fill_color", Color(0.9, 0.2, 0.2))
	
	# Настройка ProgressBar для маны
	mana_bar.add_theme_color_override("bg_color", Color(0.1, 0.1, 0.2))
	mana_bar.add_theme_color_override("fill_color", Color(0.3, 0.5, 0.9))
	
	# Фоновые панели
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	
	$TopPanel.add_theme_stylebox_override("panel", panel_style)
	$BottomPanel.add_theme_stylebox_override("panel", panel_style)

func _setup_ability_buttons():
	# Кнопка Q (Вакуум)
	ability1_button.text = "Q\nВАКУУМ"
	ability1_button.pressed.connect(_on_ability1_pressed)
	
	# Кнопка E (Ядовитая бутылка)
	ability2_button.text = "W\nЯД"
	ability2_button.pressed.connect(_on_ability2_pressed)
	
	# Кнопка R (Огнемётчик)
	ability3_button.text = "E\nОГОНЬ"
	ability3_button.pressed.connect(_on_ability3_pressed)
	
	# Стили кнопок
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.2, 0.4, 0.8)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	
	for button in [ability1_button, ability2_button, ability3_button]:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(90, 55)

func _process(delta):
	# Обновление таймера уведомлений
	if is_notification_active:
		notification_timer -= delta
		if notification_timer <= 0:
			_hide_notification()
	
	# Обновление таймера торговой фазы (если нужно)
	if is_trading_phase:
		wave_timer -= delta
		if wave_timer > 0:
			timer_label.text = "⏱ %.0f" % wave_timer

func _update_health(current: int, max: int):
	health_bar.max_value = max
	health_bar.value = current
	health_label.text = "❤️ %d/%d" % [current, max]


func _update_mana(current: int, max: int):
	mana_bar.max_value = max
	mana_bar.value = current
	mana_label.text = "✨ %d/%d" % [current, max]

func _update_civilians(saved: int, total: int = 0):
	if total > 0:
		civilians_label.text = "🙏 %d/%d" % [saved, total]
	else:
		civilians_label.text = "🙏 %d" % saved

func _on_wave_started(wave_number: int):
	wave_label.text = "🌊 ВОЛНА %d" % wave_number
	is_trading_phase = false
	_show_notification("⚔️ ВОЛНА %d НАЧАЛАСЬ! ⚔️" % wave_number, 2.0)
	
	# Обновляем радиус замка в UI (опционально)
	var castle_radius = GameManager.castle_radius
	print("Castle attack radius: ", castle_radius)

func _on_trading_phase_started(time_remaining: float):
	wave_label.text = "🛒 ТОРГОВЛЯ"
	is_trading_phase = true
	wave_timer = time_remaining
	timer_label.text = "⏱ %.0f" % time_remaining
	_show_notification("🛒 ТОРГУЙТЕСЬ! ТРАТЬТЕ ГРАЖДАНСКИХ! 🛒", 3.0)

func _on_wave_ended(wave_number: int, civilians_saved: int):
	_update_civilians(civilians_saved)
	_show_notification("✅ ВОЛНА %d ЗАВЕРШЕНА! Спасено: %d ✅" % [wave_number, civilians_saved], 2.0)

func _on_game_over(victory: bool):
	if victory:
		_show_notification("🎉 ПОБЕДА! ВЫ ВЫЖИЛИ! 🎉", 5.0)
		wave_label.text = "🏆 ПОБЕДА 🏆"
	else:
		_show_notification("💀 ПОРАЖЕНИЕ! ЗАМОК РАЗРУШЕН! 💀", 5.0)
		wave_label.text = "💀 ПОРАЖЕНИЕ 💀"
	
	# Отключаем кнопки способностей
	ability1_button.disabled = true
	ability2_button.disabled = true
	ability3_button.disabled = true
	
	# Ждём и возвращаемся в меню
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_ability1_pressed():
	var main = get_tree().current_scene
	if main and main.has_method("_try_use_vacuum"):
		main._try_use_vacuum()
		_show_ability_cooldown(ability1_button)

func _on_ability2_pressed():
	var main = get_tree().current_scene
	if main and main.has_method("_try_use_poison"):
		main._try_use_poison()
		_show_ability_cooldown(ability2_button)

func _on_ability3_pressed():
	var main = get_tree().current_scene
	if main and main.has_method("_try_use_flamethrower"):
		main._try_use_flamethrower()
		_show_ability_cooldown(ability3_button)

func _show_ability_cooldown(button: Button):
	button.disabled = true
	await get_tree().create_timer(1.5).timeout
	button.disabled = false

func _show_notification(text: String, duration: float = 2.0):
	notification_label.text = text
	notification_panel.visible = true
	is_notification_active = true
	notification_timer = duration
	
	# Анимация
	var tween = create_tween()
	tween.tween_property(notification_panel, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(notification_panel, "position", Vector2(0, 0), 0.1)

func _hide_notification():
	var tween = create_tween()
	tween.tween_property(notification_panel, "modulate", Color(1, 1, 1, 0), 0.2)
	await tween.finished
	notification_panel.visible = false
	is_notification_active = false

# Публичные методы для внешнего вызова
func update_civilians_display(saved: int, total: int = 0):
	_update_civilians(saved, total)

func update_wave_display(wave: int):
	wave_label.text = "🌊 ВОЛНА %d" % wave

func update_timer(seconds: float):
	timer_label.text = "⏱ %.0f" % seconds
