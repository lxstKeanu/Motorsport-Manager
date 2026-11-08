extends Node
## Автопроверки без графики:
##   godot --headless --path . res://tests/test_runner.tscn
## Код выхода 0 — всё прошло, 1 — есть ошибки.

const TRANSLATIONS_CSV := "res://localization/translations.csv"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"
## Ключ перевода: заглавные буквы, цифры и хотя бы одно подчёркивание (MENU_NEW_GAME).
const KEY_REGEX := "\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\""

var _checks := 0
var _failures := 0


func _ready() -> void:
	var real_settings_path := Settings.config_path
	Settings.config_path = TEST_SETTINGS_PATH

	var table := _test_translation_table()
	_test_used_keys_exist(table)
	_test_translations_loaded(table)
	_test_settings()
	await _test_main_menu()
	await _test_new_game_stub()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	Settings.config_path = real_settings_path
	Settings.load_settings()

	print("Checks: %d, failed: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + what)


## Таблица переводов: у каждого ключа есть английский и русский текст, ключи не повторяются.
func _test_translation_table() -> Dictionary:
	var table := {}
	var file := FileAccess.open(TRANSLATIONS_CSV, FileAccess.READ)
	_check(file != null, "translations.csv opens")
	if file == null:
		return table
	var header := file.get_csv_line()
	_check(header == PackedStringArray(["keys", "en", "ru"]), "translations.csv columns are keys,en,ru")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		var key := row[0]
		_check(row.size() == header.size(), "%s has %d columns" % [key, header.size()])
		_check(not table.has(key), "%s is not duplicated" % key)
		for column in range(1, mini(row.size(), header.size())):
			_check(not row[column].strip_edges().is_empty(), "%s has a %s translation" % [key, header[column]])
		table[key] = row
	return table


## Каждый ключ, который встречается в сценах и скриптах, есть в таблице.
func _test_used_keys_exist(table: Dictionary) -> void:
	var files: Array[String] = []
	_collect_files("res://scenes", ["tscn", "gd"], files)
	_collect_files("res://scripts", ["gd"], files)
	var regex := RegEx.create_from_string(KEY_REGEX)
	var used := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for found in regex.search_all(text):
			used += 1
			_check(table.has(found.get_string(1)), "key %s from %s is in translations.csv" % [found.get_string(1), path])
	_check(used > 0, "scenes use translation keys")


## Импортированные переводы совпадают с таблицей (то есть импорт не устарел).
func _test_translations_loaded(table: Dictionary) -> void:
	var locales := ["en", "ru"]
	for i in locales.size():
		TranslationServer.set_locale(locales[i])
		for key: String in table.keys():
			_check(tr(key) == table[key][i + 1], "%s in %s matches translations.csv" % [key, locales[i]])
	TranslationServer.set_locale(Settings.language)


func _test_settings() -> void:
	Settings.set_language("ru")
	_check(TranslationServer.get_locale().begins_with("ru"), "setting the language switches the locale")
	Settings.set_volume(Settings.BUS_MUSIC, 0.25)
	var music_bus := AudioServer.get_bus_index(Settings.BUS_MUSIC)
	_check(music_bus >= 0, "Music bus exists")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.25)), "music volume reaches the bus")
	Settings.set_volume(Settings.BUS_SFX, 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.BUS_SFX)), "zero volume mutes the bus")
	Settings.save()

	# Меняем только в памяти: set_language сразу пишет файл.
	Settings.language = "en"
	Settings.set_volume(Settings.BUS_MUSIC, 1.0)
	Settings.load_settings()
	_check(Settings.language == "ru", "language is saved")
	_check(is_equal_approx(Settings.get_volume(Settings.BUS_MUSIC), 0.25), "music volume is saved")
	_check(is_equal_approx(Settings.get_volume(Settings.BUS_SFX), 0.0), "sfx volume is saved")
	Settings.set_volume(Settings.BUS_SFX, 0.8)
	Settings.set_language("en")


func _test_main_menu() -> void:
	var menu: Control = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame

	var continue_button: Button = menu.get_node("%ContinueButton")
	var settings_button: Button = menu.get_node("%SettingsButton")
	var lang_en: Button = menu.get_node("%LangEnButton")
	var lang_ru: Button = menu.get_node("%LangRuButton")
	var version: Label = menu.get_node("%VersionLabel")
	var panel: SettingsPanel = menu.get_node("%SettingsPanel")

	_check(continue_button.disabled, "Continue is disabled without saves")
	_check(version.text == "Prototype 0.1 · working title", "version label is in English")
	_check(lang_en.button_pressed and not lang_ru.button_pressed, "EN is highlighted")
	_check(not panel.visible, "settings are hidden at start")

	settings_button.pressed.emit()
	_check(panel.visible, "Settings button opens the settings panel")

	lang_ru.pressed.emit()
	await get_tree().process_frame
	_check(Settings.language == "ru", "RU button switches the language")
	_check(version.text == "Прототип 0.1 · рабочее название", "version label follows the language")
	_check(lang_ru.button_pressed and not lang_en.button_pressed, "RU is highlighted")
	var language_option: OptionButton = panel.get_node("%LanguageOption")
	_check(language_option.selected == Settings.LANGUAGES.find("ru"), "settings panel shows the new language")

	lang_ru.pressed.emit()
	_check(lang_ru.button_pressed, "clicking the selected language keeps it highlighted")

	panel.close()
	_check(not panel.visible, "settings panel closes")

	lang_en.pressed.emit()
	menu.queue_free()
	await get_tree().process_frame


func _test_new_game_stub() -> void:
	var screen: Control = load("res://scenes/new_game/new_game.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check(screen.get_node("%BackButton") is Button, "new game screen has a Back button")
	screen.queue_free()
	await get_tree().process_frame


func _collect_files(dir_path: String, extensions: Array, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_files(path, extensions, out)
		elif extensions.has(entry.get_extension()):
			out.append(path)
		entry = dir.get_next()
