extends Control
## Заглушка экрана новой игры, чтобы кнопка «Новая игра» уже вела куда-то.
## Следующий шаг — создание персонажа и помощников.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_go_back)
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
