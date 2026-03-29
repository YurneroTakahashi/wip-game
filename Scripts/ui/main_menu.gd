extends Control

# Ссылки на кнопки
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var authors_button: Button = $CenterContainer/VBoxContainer/AuthorsButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

# Звуки (опционально)
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

func _ready():
	# Подключаем сигналы
	_setup_buttons()
	
	# Настраиваем внешний вид
	_setup_visual()
	
	# Показываем курсор мыши
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	print("Main menu ready!")

func _setup_buttons():
	# ИГРАТЬ - запуск игры
	play_button.pressed.connect(_on_play_pressed)
	play_button.mouse_entered.connect(_on_button_hover.bind(play_button))
	
	# +1 БЛАГОСЛОВЕНИЯ - магазин улучшений
	
	# АВТОРЫ
	authors_button.pressed.connect(_on_authors_pressed)
	authors_button.mouse_entered.connect(_on_button_hover.bind(authors_button))
	
	# ОПЦИИ
	options_button.pressed.connect(_on_options_pressed)
	options_button.mouse_entered.connect(_on_button_hover.bind(options_button))
	
	# ВЫХОД
	exit_button.pressed.connect(_on_exit_pressed)
	exit_button.mouse_entered.connect(_on_button_hover.bind(exit_button))

func _setup_visual():
	# Настройка фона (если используешь TextureRect)
	var bg = $Background
	if bg and bg.texture:
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Настройка стилей кнопок
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	button_style.set_border_width_all(2)
	button_style.border_color = Color(0.8, 0.6, 0.2)
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.4, 0.3, 0.5, 0.9)
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(1, 0.8, 0.3)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.corner_radius_bottom_right = 10
	
	# Применяем стили ко всем кнопкам
	for button in [play_button, authors_button, options_button, exit_button]:
		if button:
			button.add_theme_stylebox_override("normal", button_style)
			button.add_theme_stylebox_override("hover", hover_style)
			button.add_theme_stylebox_override("pressed", hover_style)
			
			# Настройка шрифта
			button.add_theme_font_size_override("font_size", 24)
			button.add_theme_color_override("font_color", Color(1, 1, 1))
			button.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
			button.add_theme_constant_override("outline_size", 1)

func _on_button_hover(button: Button):
	# Звук наведения
	#if hover_sound:
		#AudioManager.play_sfx(hover_sound, -10)
	
	# Анимация увеличения
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func _on_play_pressed():
	print("Play button pressed")
	_play_click_sound()
	
	# Запускаем игру
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_blessings_pressed():
	print("Blessings button pressed")
	_play_click_sound()
	
	# TODO: Открыть магазин улучшений
	# _open_blessings_menu()
	_show_notification("Благословения - скоро!")

func _on_authors_pressed():
	print("Authors button pressed")
	_play_click_sound()
	
	# Показываем окно с авторами
	_show_authors_dialog()

func _on_options_pressed():
	print("Options button pressed")
	_play_click_sound()
	
	# TODO: Открыть настройки
	_show_notification("Настройки - скоро!")

func _on_exit_pressed():
	print("Exit button pressed")
	_play_click_sound()
	
	# Выход из игры
	get_tree().quit()

func _play_click_sound():
	pass
	#if click_sound:
		#AudioManager.play_sfx(click_sound, -5)

func _show_notification(text: String):
	# Простое всплывающее уведомление
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	label.position = get_viewport().get_visible_rect().size / 2 - Vector2(100, 0)
	add_child(label)
	
	await get_tree().create_timer(2.0).timeout
	label.queue_free()

func _show_authors_dialog():
	# Создаём диалоговое окно
	var dialog = AcceptDialog.new()
	dialog.title = "Авторы"
	dialog.dialog_text = "Игра создана в рамках хакатона\n\nРазработчики:\n- Твоё имя\n- Имя друга\n\nСпасибо за игру!"
	dialog.size = Vector2(400, 200)
	add_child(dialog)
	dialog.popup_centered()
