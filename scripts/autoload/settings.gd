extends Node
## Настройки игрока: язык, полный экран, громкость.
## Хранятся в user://settings.cfg и применяются при запуске игры.

signal changed

const LANGUAGES := ["en", "ru"]
## Название языка всегда пишется на нём самом, чтобы его можно было найти при любом языке интерфейса.
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский"}

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const DEFAULT_VOLUMES := {BUS_MASTER: 0.8, BUS_MUSIC: 0.7, BUS_SFX: 0.8}

## Путь к файлу настроек. Тесты подменяют его, чтобы не трогать настройки игрока.
var config_path := "user://settings.cfg"
var language := "en"
var fullscreen := false
var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()


func _ready() -> void:
	load_settings()


## Читает настройки из файла и сразу применяет. При первом запуске язык берётся из системы.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(config_path)  # Если файла нет, ниже просто возьмутся значения по умолчанию.
	language = str(cfg.get_value("general", "language", ""))
	if not LANGUAGES.has(language):
		language = detect_system_language()
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	_volumes = DEFAULT_VOLUMES.duplicate()
	for bus: String in _volumes.keys():
		_volumes[bus] = clampf(float(cfg.get_value("audio", bus, _volumes[bus])), 0.0, 1.0)
	_apply_all()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("display", "fullscreen", fullscreen)
	for bus: String in _volumes.keys():
		cfg.set_value("audio", bus, _volumes[bus])
	var err := cfg.save(config_path)
	if err != OK:
		push_warning("Settings were not saved: %s" % error_string(err))


static func detect_system_language() -> String:
	var system_language := OS.get_locale_language()
	return system_language if LANGUAGES.has(system_language) else "en"


func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == language:
		return
	language = code
	TranslationServer.set_locale(language)
	save()
	changed.emit()


func set_fullscreen(enabled: bool) -> void:
	if enabled == fullscreen:
		return
	fullscreen = enabled
	_apply_window_mode()
	save()
	changed.emit()


func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)


## Громкость от 0 до 1. Файл здесь не пишется: окно настроек сохраняет всё при закрытии,
## чтобы не писать на диск при каждом движении ползунка.
func set_volume(bus: String, value: float) -> void:
	if not _volumes.has(bus):
		return
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	changed.emit()


func _apply_all() -> void:
	TranslationServer.set_locale(language)
	_apply_window_mode()
	for bus: String in _volumes.keys():
		_apply_volume(bus)


func _apply_window_mode() -> void:
	# Без окна (тесты) или внутри редактора режим окна менять нельзя.
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = _volumes[bus]
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
