class_name SettingsPanel
extends Control
## Окно настроек с вкладками «Экран», «Звук», «Вид».
## Изменения применяются сразу, в файл сохраняются при закрытии окна.
## Строки вкладок собираются кодом: слева название и пояснение, справа выбор.

signal closed

const TAB_KEYS: Array[String] = ["SETTINGS_TAB_DISPLAY", "SETTINGS_TAB_SOUND", "SETTINGS_TAB_VIEW"]
const CURRENCY_KEYS := {"usd": "CURRENCY_USD", "eur": "CURRENCY_EUR", "gbp": "CURRENCY_GBP", "rub": "CURRENCY_RUB"}
const UI_SCALE_KEYS := {"auto": "UI_SCALE_AUTO", "small": "UI_SCALE_SMALL", "medium": "UI_SCALE_MEDIUM", "large": "UI_SCALE_LARGE"}
const VIEW_MODE_KEYS := {"top_down": "VIEW_TOP_DOWN", "standard": "VIEW_STANDARD", "full": "VIEW_FULL"}
const LAYER_HINT_KEYS := {"LAYER_WALLS": "LAYER_WALLS_HINT", "LAYER_VEHICLES": "LAYER_VEHICLES_HINT", "LAYER_MISC": "LAYER_MISC_HINT", "LAYER_EQUIPMENT": "LAYER_EQUIPMENT_HINT"}
const ACCENT := Color(0.941, 0.541, 0.141)
const LABEL_COLUMN_WIDTH := 400.0

var language_option: OptionButton
var currency_buttons := {}
var window_buttons := {}
var fps_buttons := {}
var ui_scale_buttons := {}
var text_scale_buttons := {}
var view_mode_buttons := {}
var mute_check: CheckButton
var layer_checks: Array[CheckButton] = []
## Громкость: шина → [ползунок, подпись с процентами].
var volume_controls := {}
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []

@onready var _tabs: HBoxContainer = %Tabs
@onready var _pages_root: MarginContainer = %Pages
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	hide()
	_build_tabs()
	_build_display_page()
	_build_sound_page()
	_build_view_page()
	_back_button.pressed.connect(close)
	Settings.changed.connect(_sync)
	show_tab(0)


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


func show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Вкладки ---

func _build_tabs() -> void:
	var group := ButtonGroup.new()
	for i in TAB_KEYS.size():
		var tab := Button.new()
		tab.text = TAB_KEYS[i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.theme_type_variation = &"TabButton"
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0.0, 52.0)
		tab.pressed.connect(show_tab.bind(i))
		_tabs.add_child(tab)
		_tab_buttons.append(tab)
		var page := ScrollContainer.new()
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 28)
		page.add_child(rows)
		_pages_root.add_child(page)
		_pages.append(page)


func _rows(page: int) -> VBoxContainer:
	return _pages[page].get_child(0)


func _build_display_page() -> void:
	language_option = OptionButton.new()
	language_option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_option.custom_minimum_size = Vector2(360.0, 44.0)
	language_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for code: String in Settings.LANGUAGES:
		language_option.add_item(Settings.LANGUAGE_NAMES[code])
	language_option.item_selected.connect(func(index: int) -> void: Settings.set_language(Settings.LANGUAGES[index]))
	_add_row(0, "SETTINGS_LANGUAGE", "", language_option)

	var currencies := []
	for code: String in Settings.CURRENCIES:
		currencies.append([code, CURRENCY_KEYS[code]])
	_add_row(0, "SETTINGS_CURRENCY", "SETTINGS_CURRENCY_HINT", _choices(currencies, currency_buttons, Settings.set_currency))

	_add_row(0, "SETTINGS_WINDOW", "SETTINGS_WINDOW_HINT", _choices(
		[[false, "SETTINGS_WINDOWED"], [true, "SETTINGS_FULLSCREEN"]], window_buttons, Settings.set_fullscreen))
	_add_row(0, "SETTINGS_FPS", "SETTINGS_FPS_HINT", _choices(
		[[30, "FPS_30"], [60, "FPS_60"], [0, "FPS_UNCAPPED"]], fps_buttons, Settings.set_max_fps))
	var scales := []
	for code: String in Settings.UI_SCALES:
		scales.append([code, UI_SCALE_KEYS[code]])
	_add_row(0, "SETTINGS_UI_SCALE", "SETTINGS_UI_SCALE_HINT", _choices(scales, ui_scale_buttons, Settings.set_ui_scale))
	var text_sizes := []
	for value: float in Settings.TEXT_SCALES:
		text_sizes.append([value, "%d%%" % roundi(value * 100.0)])
	_add_row(0, "SETTINGS_TEXT_SIZE", "SETTINGS_TEXT_SIZE_HINT", _choices(text_sizes, text_scale_buttons, Settings.set_text_scale))


func _build_sound_page() -> void:
	mute_check = CheckButton.new()
	mute_check.text = "SETTINGS_MUTE"
	mute_check.toggled.connect(Settings.set_muted)
	_add_row(1, "SETTINGS_TAB_SOUND", "", mute_check)
	var buses := [
		[Settings.BUS_MASTER, "SETTINGS_VOLUME_MASTER"],
		[Settings.BUS_MUSIC, "SETTINGS_VOLUME_MUSIC"],
		[Settings.BUS_SFX, "SETTINGS_VOLUME_SFX"],
	]
	for bus_info: Array in buses:
		var bus: String = bus_info[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var slider := HSlider.new()
		slider.step = 1.0
		slider.custom_minimum_size = Vector2(360.0, 0.0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value := Label.new()
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		value.custom_minimum_size = Vector2(56.0, 0.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.value_changed.connect(func(percent: float) -> void:
			Settings.set_volume(bus, percent / 100.0)
			value.text = "%d%%" % percent)
		row.add_child(slider)
		row.add_child(value)
		volume_controls[bus] = [slider, value]
		_add_row(1, bus_info[1], "", row)


func _build_view_page() -> void:
	var modes := []
	for mode: String in Settings.VIEW_MODES:
		modes.append([mode, VIEW_MODE_KEYS[mode]])
	_add_row(2, "SETTINGS_VIEW_MODE", "SETTINGS_VIEW_MODE_HINT", _choices(modes, view_mode_buttons, Settings.set_view_mode))
	var layers := VBoxContainer.new()
	layers.add_theme_constant_override("separation", 14)
	for key: String in ["LAYER_WALLS", "LAYER_VEHICLES", "LAYER_MISC", "LAYER_EQUIPMENT"]:
		var check := CheckButton.new()
		check.text = key
		check.toggled.connect(_on_layer_toggled.bind(layer_checks.size()))
		layers.add_child(check)
		var hint := Label.new()
		hint.text = LAYER_HINT_KEYS[key]
		hint.theme_type_variation = &"DimLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(480.0, 0.0)
		layers.add_child(hint)
		layer_checks.append(check)
	_add_row(2, "SETTINGS_LAYERS", "SETTINGS_LAYERS_HINT", layers)


func _on_layer_toggled(enabled: bool, layer: int) -> void:
	Settings.set_view_layer(layer, enabled)


# --- Строки ---

## Строка настройки: слева заголовок с чёрточкой и пояснение, справа то, что выбирают.
func _add_row(page: int, title_key: String, hint_key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LABEL_COLUMN_WIDTH, 0.0)
	left.add_theme_constant_override("separation", 8)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	var dash := ColorRect.new()
	dash.color = ACCENT
	dash.custom_minimum_size = Vector2(16.0, 2.0)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(dash)
	var title := Label.new()
	title.text = title_key
	title.uppercase = true
	title.theme_type_variation = &"SectionLabel"
	title_row.add_child(title)
	left.add_child(title_row)
	if not hint_key.is_empty():
		var hint := Label.new()
		hint.text = hint_key
		hint.theme_type_variation = &"DimLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(LABEL_COLUMN_WIDTH, 0.0)
		left.add_child(hint)
	row.add_child(left)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if control is Container else control.size_flags_horizontal
	control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	_rows(page).add_child(row)


## Ряд кнопок-вариантов, из которых нажата одна. options — [[значение, ключ или текст], ...].
## Кнопки складываются в buttons по значению, нажатие вызывает on_pick(значение).
func _choices(options: Array, buttons: Dictionary, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for option: Array in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = option[1]
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.pressed.connect(on_pick.bind(option[0]))
		row.add_child(button)
		buttons[option[0]] = button
	return row


## Подтягивает значения из Settings, не вызывая обработчики.
func _sync() -> void:
	language_option.select(Settings.LANGUAGES.find(Settings.language))
	_sync_choices(currency_buttons, Settings.currency)
	_sync_choices(window_buttons, Settings.fullscreen)
	_sync_choices(fps_buttons, Settings.max_fps)
	_sync_choices(ui_scale_buttons, Settings.ui_scale)
	_sync_choices(text_scale_buttons, Settings.text_scale)
	_sync_choices(view_mode_buttons, Settings.view_mode())
	mute_check.set_pressed_no_signal(Settings.muted)
	for i in layer_checks.size():
		layer_checks[i].set_pressed_no_signal(Settings.is_3d(i))
	for bus: String in volume_controls:
		var percent := roundf(Settings.get_volume(bus) * 100.0)
		(volume_controls[bus][0] as HSlider).set_value_no_signal(percent)
		(volume_controls[bus][1] as Label).text = "%d%%" % percent


## set_pressed_no_signal не отжимает остальные кнопки группы, поэтому выставляем все.
## Если значение не совпало ни с одной кнопкой (слои выбраны вручную), не нажата ни одна.
func _sync_choices(buttons: Dictionary, value: Variant) -> void:
	for key: Variant in buttons:
		(buttons[key] as Button).set_pressed_no_signal(key == value)
