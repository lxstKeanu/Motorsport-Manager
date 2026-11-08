extends Node
## Настройки игрока: экран (язык, валюта, окно, кадры, масштаб интерфейса и текста), звук и вид карты.
## Хранятся в user://settings.cfg и применяются при запуске игры.

signal changed

const LANGUAGES := ["en", "ru"]
## Название языка всегда пишется на нём самом, чтобы его можно было найти при любом языке интерфейса.
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский"}

## Валюта только для показа: суммы в игре те же, меняется значок.
const CURRENCIES := ["usd", "eur", "gbp", "rub"]
const CURRENCY_SYMBOLS := {"usd": "$", "eur": "€", "gbp": "£", "rub": "₽"}
## Ограничение кадров в секунду: 0 — без ограничения.
const FPS_OPTIONS := [30, 60, 0]
## Масштаб интерфейса. «Авто» — как есть: интерфейс и так растягивается под окно.
const UI_SCALES := ["auto", "small", "medium", "large"]
const UI_SCALE_FACTORS := {"auto": 1.0, "small": 0.85, "medium": 1.1, "large": 1.25}
const TEXT_SCALES := [1.0, 1.25, 1.5]
## Слои 2.5D на карте: здания и стены, машины, деревья и фонари, оборудование. Люди — всегда в 2.5D.
const LAYER_COUNT := 4
const VIEW_MODES := ["top_down", "standard", "full"]
const VIEW_PRESETS := {
	"top_down": [false, false, false, false],
	"standard": [true, false, false, true],
	"full": [true, true, true, true],
}

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const DEFAULT_VOLUMES := {BUS_MASTER: 0.8, BUS_MUSIC: 0.7, BUS_SFX: 0.8}

## Путь к файлу настроек. Тесты подменяют его, чтобы не трогать настройки игрока.
var config_path := "user://settings.cfg"
var language := "en"
var currency := "usd"
var fullscreen := false
var max_fps := 60
var ui_scale := "auto"
var text_scale := 1.0
var muted := false
var view_layers: Array[bool] = [true, true, true, true]
## Размер и положение окна между запусками. Нулевой размер — не запоминали, окно по умолчанию.
var window_size := Vector2i.ZERO
var window_position := Vector2i.ZERO
var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
## Экраны, которые масштабируются вместе с интерфейсом (см. fit_ui).
var _fitted: Array[Control] = []
## Исходные размеры шрифтов темы, от них считается размер текста.
var _base_font_sizes := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	load_settings()
	get_tree().root.size_changed.connect(_refit_all)
	_restore_window()


## Закрытие окна крестиком: запоминаем его размер и положение.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		remember_window()


## Запоминает размер и положение окна (если оно не на весь экран) и сохраняет настройки.
## Выход из игры кнопкой тоже вызывает это перед закрытием.
func remember_window() -> void:
	if _can_change_window() and not fullscreen:
		window_size = DisplayServer.window_get_size()
		window_position = DisplayServer.window_get_position()
	save()


## F11 переключает полный экран в любой момент.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		set_fullscreen(not fullscreen)
		save()


## Читает настройки из файла и сразу применяет. При первом запуске язык берётся из системы.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(config_path)  # Если файла нет, ниже просто возьмутся значения по умолчанию.
	language = str(cfg.get_value("general", "language", ""))
	if not LANGUAGES.has(language):
		language = detect_system_language()
	currency = str(cfg.get_value("general", "currency", "usd"))
	if not CURRENCIES.has(currency):
		currency = "usd"
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	max_fps = int(cfg.get_value("display", "max_fps", 60))
	if not FPS_OPTIONS.has(max_fps):
		max_fps = 60
	ui_scale = str(cfg.get_value("display", "ui_scale", "auto"))
	if not UI_SCALES.has(ui_scale):
		ui_scale = "auto"
	text_scale = float(cfg.get_value("display", "text_scale", 1.0))
	if not TEXT_SCALES.has(text_scale):
		text_scale = 1.0
	muted = bool(cfg.get_value("audio", "muted", false))
	_volumes = DEFAULT_VOLUMES.duplicate()
	for bus: String in _volumes.keys():
		_volumes[bus] = clampf(float(cfg.get_value("audio", bus, _volumes[bus])), 0.0, 1.0)
	var layers: Array = cfg.get_value("view", "layers", [true, true, true, true])
	for i in LAYER_COUNT:
		view_layers[i] = bool(layers[i]) if i < layers.size() else true
	window_size = cfg.get_value("window", "size", Vector2i.ZERO)
	window_position = cfg.get_value("window", "position", Vector2i.ZERO)
	_apply_all()
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "currency", currency)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "max_fps", max_fps)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "text_scale", text_scale)
	cfg.set_value("audio", "muted", muted)
	for bus: String in _volumes.keys():
		cfg.set_value("audio", bus, _volumes[bus])
	if window_size != Vector2i.ZERO:
		cfg.set_value("window", "size", window_size)
		cfg.set_value("window", "position", window_position)
	cfg.set_value("view", "layers", Array(view_layers))
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


func set_currency(code: String) -> void:
	if not CURRENCIES.has(code) or code == currency:
		return
	currency = code
	changed.emit()


func currency_symbol() -> String:
	return CURRENCY_SYMBOLS[currency]


func set_fullscreen(enabled: bool) -> void:
	if enabled == fullscreen:
		return
	fullscreen = enabled
	_apply_window_mode()
	save()
	changed.emit()


func set_max_fps(value: int) -> void:
	if not FPS_OPTIONS.has(value) or value == max_fps:
		return
	max_fps = value
	Engine.max_fps = max_fps
	changed.emit()


func set_ui_scale(value: String) -> void:
	if not UI_SCALES.has(value) or value == ui_scale:
		return
	ui_scale = value
	_refit_all()
	changed.emit()


func ui_scale_factor() -> float:
	return UI_SCALE_FACTORS[ui_scale]


func set_text_scale(value: float) -> void:
	if not TEXT_SCALES.has(value) or is_equal_approx(value, text_scale):
		return
	text_scale = value
	_apply_text_scale()
	changed.emit()


func set_muted(value: bool) -> void:
	if value == muted:
		return
	muted = value
	for bus: String in _volumes.keys():
		_apply_volume(bus)
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


## Рисовать ли слой карты в 2.5D (номер слоя — GarageMap.Layer).
func is_3d(layer: int) -> bool:
	return view_layers[layer] if layer >= 0 and layer < LAYER_COUNT else true


func set_view_layer(layer: int, enabled: bool) -> void:
	if layer < 0 or layer >= LAYER_COUNT or view_layers[layer] == enabled:
		return
	view_layers[layer] = enabled
	changed.emit()


func set_view_mode(mode: String) -> void:
	if not VIEW_PRESETS.has(mode):
		return
	var preset: Array = VIEW_PRESETS[mode]
	for i in LAYER_COUNT:
		view_layers[i] = preset[i]
	changed.emit()


## Какой готовый режим вида совпадает со слоями. Пустая строка — слои выбраны вручную.
func view_mode() -> String:
	for mode: String in VIEW_MODES:
		if Array(view_layers) == VIEW_PRESETS[mode]:
			return mode
	return ""


## Экран целиком масштабируется вместе с интерфейсом: корневой контрол получает размер окна,
## делённый на масштаб, и растягивается обратно. Карта гаража не масштабируется: она в своём слое.
func fit_ui(control: Control) -> void:
	if not _fitted.has(control):
		_fitted.append(control)
		control.tree_exiting.connect(func() -> void: _fitted.erase(control))
	_fit(control)


func _refit_all() -> void:
	for control in _fitted:
		_fit(control)


func _fit(control: Control) -> void:
	var factor := ui_scale_factor()
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = control.get_viewport_rect().size / factor
	control.scale = Vector2(factor, factor)


func _apply_all() -> void:
	TranslationServer.set_locale(language)
	_apply_window_mode()
	Engine.max_fps = max_fps
	for bus: String in _volumes.keys():
		_apply_volume(bus)
	_apply_text_scale()
	_refit_all()


## Без окна (тесты) или внутри редактора режим, размер и положение окна менять нельзя.
func _can_change_window() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


## Возвращает окну размер и положение с прошлого запуска, если оно целиком помещается на одном из экранов.
func _restore_window() -> void:
	if not _can_change_window() or fullscreen or window_size == Vector2i.ZERO:
		return
	var rect := Rect2i(window_position, window_size)
	for screen in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(screen).encloses(rect):
			DisplayServer.window_set_size(window_size)
			DisplayServer.window_set_position(window_position)
			return


func _apply_window_mode() -> void:
	if not _can_change_window():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = _volumes[bus]
	AudioServer.set_bus_mute(index, muted or value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


## Размер текста: шрифты темы от исходных размеров. Размеры, заданные прямо в сценах, не меняются.
func _apply_text_scale() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	if _base_font_sizes.is_empty():
		_base_font_sizes["default"] = theme.default_font_size
		for type in theme.get_font_size_type_list():
			for size_name in theme.get_font_size_list(type):
				_base_font_sizes[[type, size_name]] = theme.get_font_size(size_name, type)
	theme.default_font_size = roundi(_base_font_sizes["default"] * text_scale)
	for key in _base_font_sizes:
		if key is Array:
			theme.set_font_size(key[1], key[0], roundi(_base_font_sizes[key] * text_scale))
	# Надписи со своим размером шрифта (часы, деньги, заголовки) масштабируются тоже.
	if is_inside_tree():
		for node in get_tree().root.find_children("*", "Control", true, false):
			_scale_font_override(node)


## Новые надписи на экране сразу получают нужный размер текста.
func _on_node_added(node: Node) -> void:
	if node is Control:
		_scale_font_override(node)


## Размер шрифта, заданный прямо в надписи, запоминается как исходный и умножается на размер текста.
func _scale_font_override(control: Control) -> void:
	if not control.has_theme_font_size_override("font_size"):
		return
	if not control.has_meta(&"base_font_size"):
		control.set_meta(&"base_font_size", control.get_theme_font_size("font_size"))
	var scaled := roundi(int(control.get_meta(&"base_font_size")) * text_scale)
	if control.get_theme_font_size("font_size") != scaled:
		control.add_theme_font_size_override("font_size", scaled)
