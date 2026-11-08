extends Control
## Главное меню: карточка «Продолжить» с последним сохранением, нумерованные пункты
## (новая игра, обучение, сценарии, загрузка), внизу настройки, титры и выход, в углу язык.
## Обучение, сценарии и загрузка пока неактивны: появятся на своих этапах.

const VERSION := "0.1"
const NEW_GAME_SCENE := "res://scenes/new_game/new_game.tscn"
## Неактивные пункты меню приглушены целиком, вместе с номером и подписью.
const DISABLED_ALPHA := 0.4

@onready var _continue_button: Button = %ContinueButton
@onready var _save_info: Label = %SaveInfo
@onready var _new_game_button: Button = %NewGameButton
@onready var _menu_rows: Array[Button] = [%NewGameButton, %TutorialButton, %ScenariosButton, %LoadButton]
@onready var _settings_button: Button = %SettingsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel
@onready var _lang_en_button: Button = %LangEnButton
@onready var _lang_ru_button: Button = %LangRuButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _credits_dialog: ConfirmDialog = %CreditsDialog


func _ready() -> void:
	Settings.fit_ui(self)
	Sound.play_music("music_menu")
	Sound.set_ambience("")
	# Сохранений ещё нет: кнопка станет активной, когда появится система сохранений.
	_continue_button.disabled = true
	_save_info.text = "MENU_CONTINUE_EMPTY"
	for row in _menu_rows:
		row.modulate.a = DISABLED_ALPHA if row.disabled else 1.0

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_settings_panel.open)
	_credits_button.pressed.connect(_credits_dialog.open)
	_quit_button.pressed.connect(_on_quit_pressed)
	# В браузере выйти из игры нельзя.
	_quit_button.visible = not OS.has_feature("web")
	_lang_en_button.pressed.connect(_on_language_pressed.bind("en"))
	_lang_ru_button.pressed.connect(_on_language_pressed.bind("ru"))
	_settings_panel.closed.connect(_settings_button.grab_focus)
	_credits_dialog.cancelled.connect(_credits_button.grab_focus)
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


## Enter — «Продолжить», если есть сохранение и не открыто окно поверх меню.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return
	if _continue_button.disabled or _settings_panel.visible or _credits_dialog.visible:
		return
	get_viewport().set_input_as_handled()
	_continue_button.pressed.emit()


func _on_quit_pressed() -> void:
	Settings.remember_window()
	get_tree().quit()
