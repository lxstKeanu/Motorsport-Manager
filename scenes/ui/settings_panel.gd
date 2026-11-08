class_name SettingsPanel
extends Control
## Окно настроек: язык, полный экран, громкость.
## Изменения применяются сразу, в файл сохраняются при закрытии окна.

signal closed

@onready var _language_option: OptionButton = %LanguageOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	hide()
	for code: String in Settings.LANGUAGES:
		_language_option.add_item(Settings.LANGUAGE_NAMES[code])
	_language_option.item_selected.connect(_on_language_selected)
	_fullscreen_check.toggled.connect(Settings.set_fullscreen)
	_master_slider.value_changed.connect(_on_volume_changed.bind(Settings.BUS_MASTER, _master_value))
	_music_slider.value_changed.connect(_on_volume_changed.bind(Settings.BUS_MUSIC, _music_value))
	_sfx_slider.value_changed.connect(_on_volume_changed.bind(Settings.BUS_SFX, _sfx_value))
	_back_button.pressed.connect(close)
	Settings.changed.connect(_sync)


func open() -> void:
	_sync()
	show()
	_back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	Settings.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Подтягивает значения из Settings, не вызывая обработчики.
func _sync() -> void:
	_language_option.select(Settings.LANGUAGES.find(Settings.language))
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_sync_slider(_master_slider, _master_value, Settings.BUS_MASTER)
	_sync_slider(_music_slider, _music_value, Settings.BUS_MUSIC)
	_sync_slider(_sfx_slider, _sfx_value, Settings.BUS_SFX)


func _sync_slider(slider: HSlider, value_label: Label, bus: String) -> void:
	var percent := roundf(Settings.get_volume(bus) * 100.0)
	slider.set_value_no_signal(percent)
	value_label.text = "%d%%" % percent


func _on_language_selected(index: int) -> void:
	Settings.set_language(Settings.LANGUAGES[index])


func _on_volume_changed(percent: float, bus: String, value_label: Label) -> void:
	Settings.set_volume(bus, percent / 100.0)
	value_label.text = "%d%%" % percent
