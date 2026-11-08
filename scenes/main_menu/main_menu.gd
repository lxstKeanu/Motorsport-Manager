extends Control
## Главное меню: продолжить, новая игра, настройки, выход и быстрый выбор языка.

const VERSION := "0.1"
const NEW_GAME_SCENE := "res://scenes/new_game/new_game.tscn"

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel
@onready var _lang_en_button: Button = %LangEnButton
@onready var _lang_ru_button: Button = %LangRuButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	# Сохранений ещё нет: кнопка станет активной, когда появится система сохранений.
	_continue_button.disabled = true
	_continue_button.tooltip_text = "MENU_CONTINUE_EMPTY"

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_settings_panel.open)
	_quit_button.pressed.connect(_on_quit_pressed)
	# В браузере выйти из игры нельзя.
	_quit_button.visible = not OS.has_feature("web")
	_lang_en_button.pressed.connect(_on_language_pressed.bind("en"))
	_lang_ru_button.pressed.connect(_on_language_pressed.bind("ru"))
	_settings_panel.closed.connect(_settings_button.grab_focus)
	Settings.changed.connect(_refresh)

	_refresh()
	_new_game_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Обновляет то, что Godot не переводит сам: текст с подстановкой и выбранный язык.
func _refresh() -> void:
	_version_label.text = tr("MENU_VERSION") % VERSION
	_lang_en_button.set_pressed_no_signal(Settings.language == "en")
	_lang_ru_button.set_pressed_no_signal(Settings.language == "ru")


func _on_language_pressed(code: String) -> void:
	Settings.set_language(code)
	# Повторный клик по выбранному языку не должен снимать подсветку.
	_refresh()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(NEW_GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
