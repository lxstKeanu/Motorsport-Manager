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
	_test_team_rules()
	_test_money_format()
	await _test_team_creation()
	_test_garage_layout()
	_test_clock()
	await _test_garage()
	_test_salary()
	_test_navigation()
	_test_task_board()
	await _test_crew()
	await _test_sound()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	Settings.config_path = real_settings_path
	Settings.load_settings()

	# Звуки отпускаем заранее: сервер звука освобождает их только через пару кадров.
	Sound.release_all()
	for i in 3:
		await get_tree().process_frame

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

	# Экран: валюта, кадры, масштаб интерфейса и текста.
	Settings.set_currency("eur")
	_check(Game.format_money(5000) == "€5,000", "the currency sign follows the setting")
	Settings.set_currency("rub")
	_check(Game.format_money(5000) == "5,000 ₽", "roubles go after the number")
	Settings.set_currency("usd")
	Settings.set_max_fps(30)
	_check(Engine.max_fps == 30, "the frame rate limit is applied")
	Settings.set_max_fps(60)
	var theme := ThemeDB.get_project_theme()
	var base_size := theme.default_font_size
	Settings.set_text_scale(1.5)
	_check(theme.default_font_size == roundi(base_size * 1.5), "text size scales the theme fonts")
	Settings.set_text_scale(1.0)
	_check(theme.default_font_size == base_size, "text size goes back to normal")

	# Звук: выключить всё.
	Settings.set_muted(true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.BUS_MASTER)), "mute silences the master bus")
	Settings.set_muted(false)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.BUS_MASTER)), "unmute brings the sound back")

	# Вид: режимы и слои 2.5D.
	Settings.set_view_mode("top_down")
	_check(not Settings.is_3d(GarageMap.Layer.WALLS) and GarageMap.lift(2.0) == Vector2.ZERO, "top-down draws walls flat")
	_check(GarageMap.raise(2.0) != Vector2.ZERO, "people stay in 2.5D in every view")
	Settings.set_view_mode("standard")
	_check(Settings.is_3d(GarageMap.Layer.WALLS) and not Settings.is_3d(GarageMap.Layer.VEHICLES), "standard raises walls but not cars")
	Settings.set_view_layer(GarageMap.Layer.MISC, true)
	_check(Settings.view_mode() == "", "a hand-picked set of layers is not a preset")
	Settings.set_view_mode("full")
	_check(Settings.view_mode() == "full", "2.5D raises every layer")
	Settings.set_view_mode("standard")
	_check(Settings.is_3d(GarageMap.Layer.EQUIPMENT), "standard raises equipment")
	Settings.set_view_mode("top_down")
	_check(not Settings.is_3d(GarageMap.Layer.EQUIPMENT), "top-down draws equipment flat")
	Settings.set_view_mode("full")

	# Размер текста доходит и до надписей со своим размером шрифта.
	var big_label := Label.new()
	big_label.add_theme_font_size_override("font_size", 20)
	add_child(big_label)
	Settings.set_text_scale(1.5)
	_check(big_label.get_theme_font_size("font_size") == 30, "text size scales labels with their own font size")
	Settings.set_text_scale(1.0)
	_check(big_label.get_theme_font_size("font_size") == 20, "their size goes back to normal")
	big_label.queue_free()

	Settings.set_currency("gbp")
	Settings.set_ui_scale("large")
	Settings.set_view_mode("standard")
	Settings.save()
	Settings.currency = "usd"
	Settings.ui_scale = "auto"
	Settings.load_settings()
	_check(Settings.currency == "gbp" and Settings.ui_scale == "large", "display settings are saved")
	_check(Settings.view_mode() == "standard", "view layers are saved")
	Settings.set_currency("usd")
	Settings.set_ui_scale("auto")
	Settings.set_view_mode("full")


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
	_check((menu.get_node("%SaveInfo") as Label).text == "MENU_CONTINUE_EMPTY", "the save card says there are no saves")
	_check(not (menu.get_node("%NewGameButton") as Button).disabled, "New game is available")
	for name in ["%TutorialButton", "%ScenariosButton", "%LoadButton"]:
		var row: Button = menu.get_node(name)
		_check(row.disabled and row.modulate.a < 1.0, "%s waits for its stage and looks dimmed" % name)
	_check(version.text == "Prototype 0.1 · working title", "version label is in English")
	_check(lang_en.button_pressed and not lang_ru.button_pressed, "EN is highlighted")
	_check(not panel.visible, "settings are hidden at start")

	var credits: ConfirmDialog = menu.get_node("%CreditsDialog")
	menu.get_node("%CreditsButton").pressed.emit()
	_check(credits.visible and not (credits.get_node("%ConfirmButton") as Button).visible, "Credits opens a window with only a close button")
	credits.close()

	# Масштаб интерфейса: меню растягивается обратно на всё окно.
	Settings.set_ui_scale("large")
	var factor := Settings.ui_scale_factor()
	_check(is_equal_approx(menu.scale.x, factor) and (menu.size * factor).is_equal_approx(menu.get_viewport_rect().size), "a larger interface still fills the window")
	Settings.set_ui_scale("auto")
	_check(is_equal_approx(menu.scale.x, 1.0), "auto scale is the normal size")

	settings_button.pressed.emit()
	_check(panel.visible, "Settings button opens the settings panel")
	_check(panel.get_node("%Tabs").get_child_count() == 3, "settings have three tabs")
	panel.show_tab(2)
	_check(panel.layer_checks.size() == 4 and panel.layer_checks.all(func(check: CheckButton) -> bool: return check.is_visible_in_tree()), "the view tab shows the 2.5D layers")
	panel.view_mode_buttons["top_down"].pressed.emit()
	_check(not Settings.is_3d(GarageMap.Layer.WALLS) and not panel.layer_checks[0].button_pressed, "picking top-down unticks the layers")
	panel.layer_checks[0].toggled.emit(true)
	_check(Settings.is_3d(GarageMap.Layer.WALLS) and not panel.view_mode_buttons["top_down"].button_pressed, "ticking a layer leaves the preset")
	Settings.set_view_mode("full")
	panel.currency_buttons["eur"].pressed.emit()
	_check(Settings.currency == "eur" and panel.currency_buttons["eur"].button_pressed, "currency buttons change the currency")
	Settings.set_currency("usd")
	panel.show_tab(0)

	lang_ru.pressed.emit()
	await get_tree().process_frame
	_check(Settings.language == "ru", "RU button switches the language")
	_check(version.text == "Прототип 0.1 · рабочее название", "version label follows the language")
	_check(lang_ru.button_pressed and not lang_en.button_pressed, "RU is highlighted")
	var language_option: OptionButton = panel.language_option
	_check(language_option.selected == Settings.LANGUAGES.find("ru"), "settings panel shows the new language")

	lang_ru.pressed.emit()
	_check(lang_ru.button_pressed, "clicking the selected language keeps it highlighted")

	panel.close()
	_check(not panel.visible, "settings panel closes")

	lang_en.pressed.emit()
	menu.queue_free()
	await get_tree().process_frame


func _test_team_rules() -> void:
	var hero := _member(true, TeamMember.Role.DRIVER, "Alex")
	var team: Array[TeamMember] = [hero]
	_check(TeamRules.difficulty_key(1) == "DIFFICULTY_1", "a lone founder has the hardest start")
	_check(TeamRules.difficulty_key(4) == "DIFFICULTY_4", "four founders have the easiest start")
	_check(TeamRules.difficulty_mark(1) > TeamRules.difficulty_mark(2) and TeamRules.difficulty_mark(3) > TeamRules.difficulty_mark(4), "more founders move the mark towards easy")
	_check(TeamRules.role_warnings(team) == ["TEAM_WARN_NO_MECHANIC"], "a lone driver is warned about the missing mechanic")
	_check(TeamRules.default_founder_role(team) == TeamMember.Role.MECHANIC, "a new founder fills the missing role")
	_check(TeamRules.name_errors(team).is_empty(), "a named hero can start")

	team.append(_member(false, TeamMember.Role.MECHANIC, "  alex "))
	_check(TeamRules.role_warnings(team).is_empty(), "driver and mechanic cover both roles")
	_check(TeamRules.name_errors(team) == ["TEAM_ERROR_NAME_DUPLICATE"], "names repeat regardless of case and spaces")
	team[1].display_name = "   "
	_check(TeamRules.name_errors(team) == ["TEAM_ERROR_NAME_EMPTY"], "a blank name is an error")

	# Возраст, навык, потенциал и основная работа.
	var founder := _member(false, TeamMember.Role.MECHANIC, "Kim")
	founder.potential = 87
	founder.age = 35
	_check(founder.skill() == 87, "in the prime years skill equals potential")
	_check(founder.weekly_income() == 750, "a skill of 87 earns $750 a week")
	founder.age = 20
	_check(founder.skill() == 87 - 8 * TeamMember.SKILL_LOSS_PER_YEAR, "a young founder has not reached the potential yet")
	founder.age = 50
	_check(founder.skill() < 87, "skill fades after forty")
	_check(founder.weekly_income() < 750, "lower skill earns less")
	_check(founder.job_end() == 20 * 60, "a mechanic works until 20:00")
	_check(GameClock.phase_at(19.0 * 60.0, true, founder.job_start(), founder.job_end()) == GameClock.Phase.DAY_JOB, "at 19:00 the mechanic is still at work")
	var driver := _member(false, TeamMember.Role.DRIVER, "Sam")
	_check(driver.phase_at(19.0 * 60.0) == GameClock.Phase.GARAGE, "at 19:00 the driver is already in the garage")
	_check(driver.phase_at(8.5 * 60.0) == GameClock.Phase.HOME, "before work the founder is at home")
	var shuffled := _member(false, TeamMember.Role.DESIGNER, "Ann")
	shuffled.shuffle()
	_check(shuffled.age >= TeamMember.AGE_MIN and shuffled.age <= TeamMember.AGE_MAX, "shuffle picks a sensible age")
	_check(shuffled.potential >= TeamMember.POTENTIAL_RANGE.x and shuffled.potential <= TeamMember.POTENTIAL_RANGE.y, "shuffle picks a founder-level potential")
	_check(shuffled.display_name == "Ann" and shuffled.role == TeamMember.Role.DESIGNER, "shuffle keeps the name and role")


func _test_money_format() -> void:
	Settings.language = "en"
	_check(Game.format_money(5000) == "$5,000", "money in English")
	_check(Game.format_money(1234567) == "$1,234,567", "large sums are grouped")
	_check(Game.format_money(-750) == "-$750", "debts keep the minus sign")
	Settings.language = "ru"
	_check(Game.format_money(5000) == "$5 000", "money in Russian")
	Settings.language = "en"


func _test_team_creation() -> void:
	var screen: Control = load("res://scenes/new_game/new_game.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame

	var slot_list: VBoxContainer = screen.get_node("%SlotList")
	var add_button: Button = screen.get_node("%AddFounderButton")
	var remove_button: Button = screen.get_node("%RemoveButton")
	var name_edit: LineEdit = screen.get_node("%NameEdit")
	var start_button: Button = screen.get_node("%StartButton")
	var difficulty: Label = screen.get_node("%DifficultyLabel")
	var warnings: Label = screen.get_node("%RoleWarnings")
	var role_row: HBoxContainer = screen.get_node("%RoleButtons")

	# Мастер: вступление → команда → основатели.
	_check(screen.step == screen.Step.INTRO and screen.get_node("%IntroPage").visible, "the wizard starts with the intro")
	_check(not screen.get_node("%Margin").visible, "the founders are not shown before their step")
	screen.get_node("%IntroNext").pressed.emit()
	_check(screen.step == screen.Step.TEAM and screen.get_node("%TeamPage").visible, "Next leads to the team step")
	var team_next: Button = screen.get_node("%TeamNext")
	_check(team_next.disabled, "the team needs a name before going on")
	var team_name_edit: LineEdit = screen.get_node("%TeamNameEdit")
	team_name_edit.text = "Night Shift"
	team_name_edit.text_changed.emit("Night Shift")
	_check(not team_next.disabled, "with a name the wizard goes on")
	_check(screen.get_node("%EmblemGrid").get_child_count() == TeamStyle.EMBLEMS.size(), "all emblems are offered")
	(screen.get_node("%EmblemGrid").get_child(3) as Button).pressed.emit()
	(screen.get_node("%ColorRow").get_child(2) as Button).pressed.emit()
	_check(screen.team_emblem == 3 and screen.team_color == 2, "emblem and colour are picked")
	team_next.pressed.emit()
	_check(screen.step == screen.Step.FOUNDERS and screen.get_node("%Margin").visible, "Next leads to the founders")
	var defaults: Array[TeamMember] = screen.default_team()
	_check(defaults.size() == 2 and defaults[0].is_hero and defaults[0].role == TeamMember.Role.MECHANIC and defaults[1].role == TeamMember.Role.DRIVER, "the default team is a mechanic and a driver")
	_check(defaults.all(func(member: TeamMember) -> bool: return not member.display_name.is_empty()), "the default founders have names")

	_check(screen.members.size() == 1 and screen.members[0].is_hero, "a new team starts with the hero")
	_check(slot_list.get_child_count() == 1, "the hero has a slot")
	_check(not remove_button.visible, "the hero cannot be removed")
	_check(_visible_children(role_row) == 4, "the hero picks from all four roles")
	_check(screen.members[0].role == TeamMember.Role.MECHANIC, "the hero starts as a mechanic")
	_check(start_button.disabled, "Start is disabled until the hero has a name")
	_check(difficulty.text == "DIFFICULTY_1", "difficulty shows a solo start")
	_check(add_button.text == "+ Add a founder  1 / 4", "the add button counts founders")
	_check(warnings.visible, "a lone mechanic sees a role warning")

	var age_slider: HSlider = screen.get_node("%AgeSlider")
	var skill_value: Label = screen.get_node("%SkillValue")
	var income: Label = screen.get_node("%JobIncome")
	screen.members[0].potential = 87
	age_slider.value = 34  # Сначала другой возраст: если случайно выпало 35, сигнала не будет.
	age_slider.value = 35
	_check(screen.members[0].age == 35 and skill_value.text == "87", "the age slider updates the skill")
	_check(income.text == "$750 / week", "the day job income follows the skill")
	_check((screen.get_node("%JobHours") as Label).text == "08:00–20:00, Mon–Fri", "the mechanic's hours are shown")
	age_slider.value = 20
	_check(skill_value.text == str(87 - 8 * TeamMember.SKILL_LOSS_PER_YEAR), "a younger age lowers the skill now")
	var hair_value: Label = screen.get_node("%HairStyleValue")
	_check(hair_value.text == Appearance.HAIR_STYLE_KEYS[screen.members[0].appearance.hair_style], "the hairstyle is shown by name")
	_check(screen.has_progress(), "a team with a name is worth asking about before leaving")

	name_edit.text = "Alex"
	name_edit.text_changed.emit("Alex")
	_check(not start_button.disabled, "Start is enabled once the hero has a name")

	var leave_dialog: Control = screen.get_node("%LeaveDialog")
	screen.get_node("%IntroBack").pressed.emit()
	_check(leave_dialog.visible, "leaving the wizard asks before dropping a started team")
	leave_dialog.get_node("%CancelButton").pressed.emit()
	_check(not leave_dialog.visible, "Keep editing closes the question")

	add_button.pressed.emit()
	await get_tree().process_frame
	_check(screen.members.size() == 2 and slot_list.get_child_count() == 2, "Add a founder adds a slot")
	_check(screen.members[1].role == TeamMember.Role.DRIVER, "the second founder fills the missing driver role")
	_check(not warnings.visible, "the warning is gone with a driver in the team")
	_check(remove_button.visible, "a founder can be removed")
	_check(name_edit.text.is_empty(), "the editor switches to the new founder")
	_check(start_button.disabled, "an unnamed founder blocks Start")

	name_edit.text = "alex"
	name_edit.text_changed.emit("alex")
	_check(start_button.disabled, "a repeated name blocks Start")
	name_edit.text = "Sam"
	name_edit.text_changed.emit("Sam")
	_check(not start_button.disabled, "different names allow Start")

	add_button.pressed.emit()
	add_button.pressed.emit()
	await get_tree().process_frame
	_check(screen.founder_count() == 4 and add_button.disabled, "no more than four founders")
	_check(difficulty.text == "DIFFICULTY_4", "four founders give the easiest difficulty")
	_check(is_equal_approx((screen.get_node("%DifficultyBar") as DifficultyBar).mark, TeamRules.difficulty_mark(4)), "the difficulty mark moves with the founders")
	remove_button.pressed.emit()
	remove_button.pressed.emit()
	await get_tree().process_frame
	_check(screen.founder_count() == 2 and not add_button.disabled, "removing founders frees slots")

	var roles: Array[TeamMember.Role] = []
	for member: TeamMember in screen.members:
		roles.append(member.role)
	Game.start_new_game(screen.members, team_name_edit.text, screen.team_emblem, screen.team_color)
	_check(Game.display_team_name() == "Night Shift" and Game.team_emblem == 3 and Game.team_color == 2, "the game keeps the team name, emblem and colour")
	_check(Game.team.size() == 2 and Game.money == Game.STARTING_MONEY, "a new game gets the team and $5,000")
	_check(Game.get_hero().display_name == "Alex", "the hero keeps the name")
	_check(Game.team[0] != screen.members[0], "the game keeps its own copy of the team")
	_check(Game.team[1].role == roles[1], "roles are kept")

	screen.queue_free()
	await get_tree().process_frame


func _test_garage_layout() -> void:
	var layout := GarageLayout.create_starting()
	_check(layout.size == GarageLayout.START_SIZE, "the plot has the starting size")
	_check(layout.get_terrain(Vector2i(10, 85)) == GarageLayout.Terrain.GRASS, "free land is lawn")
	_check(layout.get_terrain(Vector2i(62, 118)) == GarageLayout.Terrain.WALL, "our garage has walls")
	_check(layout.get_terrain(Vector2i(66, 125)) == GarageLayout.Terrain.GATE, "our garage has a door")
	_check(layout.get_terrain(Vector2i(layout.parking_spot.floor())) == GarageLayout.Terrain.FLOOR, "the car stands inside")
	_check(layout.get_terrain(Vector2i(66, 130)) == GarageLayout.Terrain.ASPHALT, "a driveway leads from the garage")
	_check(layout.get_terrain(Vector2i(40, 138)) == GarageLayout.Terrain.ASPHALT, "the main road runs along the bottom")
	_check(layout.get_terrain(Vector2i(114, 100)) == GarageLayout.Terrain.ASPHALT, "the road turns north in the east")
	_check(layout.get_terrain(Vector2i(90, 78)) == GarageLayout.Terrain.ASPHALT, "the road turns west by the fields")
	_check(layout.get_terrain(Vector2i(66, 10)) == GarageLayout.Terrain.ASPHALT, "a road goes north through the fields")
	_check(layout.get_terrain(Vector2i(150, 106)) == GarageLayout.Terrain.ASPHALT, "a road leads into the industrial estate")
	_check(layout.get_terrain(Vector2i(90, 143)) == GarageLayout.Terrain.ASPHALT, "the main road has a lay-by")
	_check(layout.get_terrain(Vector2i(10, 30)) == GarageLayout.Terrain.FIELD, "fields lie in the north")
	_check(layout.get_terrain(Vector2i(1, 30)) == GarageLayout.Terrain.HEDGE, "hedgerows surround the fields")
	_check(not layout.has_cell(Vector2i(-1, 0)) and not layout.has_cell(layout.size), "cells outside the plot do not exist")

	var ours := layout.parcel_at(Vector2i(layout.parking_spot.floor()))
	_check(ours != null and ours.owned and ours.name_key == "PARCEL_BOX", "the small garage with the sedan is ours")
	var yard := layout.parcel_at(Vector2i(66, 108))
	_check(yard != null and yard.owned and yard.kind == Parcel.Kind.LAND, "our yard behind the garage is ours to build on")
	var owned := 0
	var counts := {}
	for parcel in layout.parcels:
		owned += 1 if parcel.owned else 0
		counts[parcel.name_key] = int(counts.get(parcel.name_key, 0)) + 1
		_check(parcel.owned or parcel.price > 0, "%s %d has a price" % [parcel.name_key, parcel.number])
		for building in parcel.buildings:
			_check(parcel.rect.encloses(building), "%s %d keeps its buildings inside" % [parcel.name_key, parcel.number])
		for other in layout.parcels:
			_check(other == parcel or not other.rect.intersects(parcel.rect), "%s %d does not overlap others" % [parcel.name_key, parcel.number])
	_check(owned == 2, "only our garage and our yard are ours at the start")
	_check(counts.get("PARCEL_HOUSE", 0) == 3 and counts.get("PARCEL_UNIT", 0) == 3 and counts.get("PARCEL_FIELD", 0) == 7, "houses, industrial units and fields are for sale")
	_check(layout.parcel_at(Vector2i(170, 90)).roof == Parcel.Roof.METAL and layout.parcel_at(Vector2i(10, 105)).roof == Parcel.Roof.TILE, "industrial roofs are metal, houses have tiles")
	_check(not layout.is_open(Vector2i(95, 110)), "the house next door is closed")
	_check(not layout.is_open(Vector2i(10, 30)), "the fields are closed")
	_check(layout.is_open(Vector2i(40, 138)), "the road is open to everyone")
	_check(layout.trees.size() > 150 and layout.bushes.size() > 30, "trees and bushes are scattered over the grass")
	_check(GarageLayout.create_starting().trees == layout.trees, "trees stand in the same places every game")
	for spot in layout.trees + layout.bushes:
		var cell := Vector2i(spot.floor())
		_check(layout.get_terrain(cell) == GarageLayout.Terrain.GRASS and layout.parcel_at(cell) == null, "plants grow on free grass at %s" % spot)
	for spot in layout.lamps:
		var cell := Vector2i(spot.floor())
		var by_road := false
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			by_road = by_road or (layout.has_cell(cell + direction) and layout.get_terrain(cell + direction) == GarageLayout.Terrain.ASPHALT)
		_check(layout.get_terrain(cell) == GarageLayout.Terrain.GRASS and by_road, "lamps stand on the verge at %s" % spot)
	layout.fill(Rect2i(-5, -5, 7, 7), GarageLayout.Terrain.ASPHALT)
	_check(layout.get_terrain(Vector2i(1, 1)) == GarageLayout.Terrain.ASPHALT, "fill is clipped to the plot")


func _test_clock() -> void:
	var clock := GameClock.new()
	var hour := 60.0
	var day := float(GameClock.MINUTES_PER_DAY)
	_check(clock.weekday() == 0 and clock.time_text() == "18:00", "the game starts on Monday at 18:00")
	_check(clock.team_phase_key() == "PHASE_EVENING_GARAGE", "on Monday evening the team is in the garage")
	_check(clock.date_text() == "Mon 1 Jan" and clock.year() == 1, "the game starts on Monday 1 January, year 1")
	_check(GameClock.date_of(31.0 * day) == Vector2i(1, 1), "the 32nd day is 1 February")
	_check(GameClock.date_of(364.0 * day) == Vector2i(11, 31), "the last day of the year is 31 December")
	var next_year := GameClock.new()
	next_year.minutes = 365.0 * day
	_check(next_year.year() == 2 and GameClock.date_of(next_year.minutes) == Vector2i(0, 1), "a new year starts on 1 January")

	# Распорядок: будни, выходные, ночь, без основной работы.
	var monday_noon := 12.0 * hour
	var saturday := 5.0 * day
	_check(GameClock.phase_at(monday_noon, true) == GameClock.Phase.DAY_JOB, "on a weekday afternoon people are at their day jobs")
	_check(GameClock.phase_at(monday_noon, false) == GameClock.Phase.GARAGE, "without a day job the afternoon is spent in the garage")
	_check(GameClock.phase_at(19.0 * hour, true) == GameClock.Phase.GARAGE, "weekday evenings are spent in the garage")
	_check(GameClock.phase_at(23.5 * hour, true) == GameClock.Phase.GARAGE, "the garage stays busy until midnight")
	_check(GameClock.phase_at(day + 0.5 * hour, true) == GameClock.Phase.SLEEP, "after midnight everyone sleeps")
	_check(GameClock.phase_at(7.0 * hour, false) == GameClock.Phase.SLEEP, "early morning everyone sleeps")
	_check(GameClock.phase_at(saturday + 9.0 * hour, true) == GameClock.Phase.HOME, "on a weekend morning the team is at home")
	_check(GameClock.phase_at(saturday + 11.0 * hour, true) == GameClock.Phase.GARAGE, "on a weekend the team is in the garage from 10:00")
	_check(GameClock.weekday_of(6.0 * day + 1.0) == 6 and GameClock.weekday_of(7.0 * day) == 0, "the week wraps from Sunday to Monday")

	# Скорости, пауза и ночное ускорение.
	clock.speed = 0
	clock.advance(10.0)
	_check(is_equal_approx(clock.minutes, GameClock.START_MINUTE), "nothing moves on pause")
	clock.speed = 1
	clock.advance(10.0)
	_check(is_equal_approx(clock.minutes - GameClock.START_MINUTE, 60.0), "at x1 an hour takes ten seconds")
	var before := clock.minutes
	clock.speed = 3
	clock.advance(1.0)
	_check(is_equal_approx(clock.minutes - before, GameClock.MINUTES_PER_SECOND * 20.0), "x20 is twenty times faster")
	clock.minutes = 2.0 * hour
	clock.speed = 1
	clock.advance(1.0)
	_check(is_equal_approx(clock.minutes - 2.0 * hour, GameClock.MINUTES_PER_SECOND * GameClock.NIGHT_MULTIPLIER), "nights go faster")
	_check(clock.time_text() == "02:24", "time is shown as hours and minutes")

	var fridays := GameClock.occurrences(0.0, 3.0 * 7.0 * day, GameClock.FRIDAY, GameClock.PAYDAY_MINUTE)
	_check(fridays.size() == 3, "three Friday evenings fit into three weeks")
	_check(GameClock.occurrences(fridays[0], fridays[0] + 1.0, GameClock.FRIDAY, GameClock.PAYDAY_MINUTE).is_empty(), "an event is not counted twice")

	# Перемотка до утра: быстро, точно до 8:00, потом прежняя скорость.
	clock.minutes = 19.0 * hour
	clock.speed = 2
	clock.skip_to_morning()
	_check(clock.speed == GameClock.SKIP, "skipping uses the skip speed")
	var finished := [false]
	clock.skip_finished.connect(func() -> void: finished[0] = true)
	for i in 100:
		if clock.speed == GameClock.SKIP:
			clock.advance(0.1)
	_check(is_equal_approx(clock.minutes, day + GameClock.WAKE_UP), "skipping stops at 8:00 the next morning")
	_check(clock.speed == 2 and finished[0], "after skipping the previous speed is back")
	clock.minutes = 6.0 * hour
	clock.skip_to_morning()
	_check(is_equal_approx(clock.skip_until, GameClock.WAKE_UP), "before dawn the skip goes to the same morning")


func _test_salary() -> void:
	var hero := _member(true, TeamMember.Role.MECHANIC, "Alex")
	var driver := _member(false, TeamMember.Role.DRIVER, "Sam")
	for member in [hero, driver]:
		member.age = 35
	hero.potential = 87
	driver.potential = 70
	var team: Array[TeamMember] = [hero, driver]
	Game.start_new_game(team)
	var paid: Array[int] = []
	var record := func(amount: int) -> void: paid.append(amount)
	Game.salary_paid.connect(record)
	var weekly := 750 + 680
	_check(Game.weekly_income() == weekly, "every founder brings a weekly income")

	var day := float(GameClock.MINUTES_PER_DAY)
	Game.clock.advance_minutes(4.0 * day - 1.0)
	_check(paid.is_empty() and Game.money == Game.STARTING_MONEY, "no pay before Friday evening")
	Game.clock.advance_minutes(1.0)
	_check(paid == [weekly], "on Friday evening all founders' pay comes in at once")
	_check(Game.money == Game.STARTING_MONEY + weekly, "pay goes to the team money")
	Game.clock.advance_minutes(7.0 * day)
	_check(paid.size() == 2, "pay comes every week")

	_check(Game.members_in_garage() == team_of(Game.team[1]), "at 18:00 the driver is in the garage while the mechanic still works")
	Game.quit_day_job(Game.team[1])
	_check(not Game.team[1].has_day_job and Game.get_hero().has_day_job, "any founder can quit the day job on their own")
	var money_before := Game.money
	Game.clock.advance_minutes(7.0 * day)
	_check(Game.money == money_before + 750, "after quitting only the remaining day jobs pay")
	Game.salary_paid.disconnect(record)


func _test_garage() -> void:
	var garage: Node2D = load("res://scenes/garage/garage.tscn").instantiate()
	add_child(garage)
	await get_tree().process_frame

	var map: GarageMap = garage.get_node("%Map")
	var camera: GarageCamera = garage.get_node("%Camera")
	var money: Label = garage.get_node("%MoneyLabel")
	var leave_dialog: ConfirmDialog = garage.get_node("%LeaveDialog")

	_check(map.layout == Game.garage, "the map shows the game's plot")
	_check((garage.get_node("%TeamName") as Label).text == Game.display_team_name(), "the top bar shows the team name")
	_check((garage.get_node("%YearLabel") as Label).text == "YEAR 1", "the top bar shows the year")
	_check(money.text == "$5,000", "the top bar shows the money")
	_check((garage.get_node("%InboundLabel") as Label).text == "HUD_INBOUND_NONE", "nothing is on the way yet")

	# Колонка разделов справа и панель раздела.
	_check(garage.get_node("%SectionButtons").get_child_count() == garage.SECTIONS.size(), "every section has a button")
	_check(garage.open_section == "works" and garage.get_node("%WorksPage").visible, "the works queue is open at the start")
	garage.open_section_panel("staff")
	_check(garage.get_node("%StaffPage").visible and not garage.get_node("%WorksPage").visible, "the staff section shows the founders")
	garage.open_section_panel("money")
	_check((garage.get_node("%BalanceLabel") as Label).text == "$5,000", "the money section shows the balance")
	garage.open_section_panel("cars")
	_check(garage.get_node("%SoonPage").visible and (garage.get_node("%SoonLabel") as Label).text.contains("stage 5"), "a section that is not ready says when it comes")
	(garage.get_node("%BuildButton") as Button).toggled.emit(true)
	_check(garage.open_section == "build" and (garage.get_node("%SoonLabel") as Label).text.contains("stage 7"), "Build says it comes at stage 7")
	garage.open_section_panel("")
	_check(not garage.get_node("%SectionPanel").visible, "the section panel closes")
	garage.open_section_panel("staff")

	# Цели «С чего начать».
	var objectives: VBoxContainer = garage.get_node("%ObjectivesList")
	_check(objectives.get_child_count() == Game.objectives().size(), "the start goals are listed")
	garage.get_node("%ObjectivesHide").pressed.emit()
	_check(not garage.get_node("%ObjectivesPanel").visible and Game.objectives_hidden, "the goals panel can be hidden")
	_check(map.cell_at(map.cell_rect(Vector2i(5, 7)).get_center()) == Vector2i(5, 7), "cell lookup matches cell rects")

	# Камера: масштаб к курсору, пределы масштаба и границы участка.
	var view := camera.view_size()
	camera.position = map.world_bounds().get_center()
	camera.zoom_to(1.0, view * 0.5)
	var anchor := view * 0.5 + Vector2(240.0, 140.0)
	var before := camera.screen_to_world(anchor)
	camera.zoom_to(2.0, anchor)
	_check(is_equal_approx(camera.zoom.x, 2.0), "zoom changes")
	_check(camera.screen_to_world(anchor).distance_to(before) < 0.01, "zoom keeps the point under the cursor")
	camera.zoom_to(100.0, anchor)
	_check(is_equal_approx(camera.zoom.x, camera.max_zoom), "zoom in stops at the limit")
	camera.zoom_to(0.01, anchor)
	_check(is_equal_approx(camera.zoom.x, camera.min_zoom), "zoom out stops when the whole plot is visible")

	camera.zoom_to(1.0, view * 0.5)
	camera.position = Vector2(-100000.0, 100000.0)
	camera.clamp_to_bounds()
	var bounds := map.world_bounds().grow(0.01)
	_check(bounds.encloses(camera.visible_world_rect()), "the camera stays inside the plot")
	camera.view_inset_top = 100.0
	camera.position = Vector2(-100000.0, -100000.0)
	camera.clamp_to_bounds()
	_check(is_equal_approx(camera.visible_world_rect().position.y, map.world_bounds().position.y), "the top of the plot shows below the top bar")
	_check(is_equal_approx(camera.screen_to_world(Vector2(0.0, 100.0)).y, map.world_bounds().position.y), "the plot edge lines up with the bar")

	# При наведении ничего не появляется: ни квадрата, ни подписи.
	_check(not garage.has_node("%CellCursor") and not garage.has_node("%HoverPanel"), "hovering shows nothing")

	# Часы, скорость и распорядок.
	var time_label: Label = garage.get_node("%TimeLabel")
	var phase_label: Label = garage.get_node("%PhaseLabel")
	var speed_row: HBoxContainer = garage.get_node("%SpeedRow")
	_check(time_label.text.begins_with("18:"), "the clock shows Monday evening")
	_check((garage.get_node("%DateLabel") as Label).text == "Mon 1 Jan", "the top bar shows the date")
	var status: Label = garage.get_node("%StatusLabel")
	_check(status.text == "Open until 24:00" or status.text.begins_with("Closed · opens at"), "the top bar says whether the garage is open")
	garage.set_overtime(true)
	_check(Game.clock.overtime, "overtime can be switched on")
	_check(GameClock.phase_at(GameClock.MINUTES_PER_DAY + 60.0, true, 480, 1080, true) == GameClock.Phase.GARAGE, "with overtime the team stays until 02:00")
	garage.set_overtime(false)
	_check(phase_label.text == "PHASE_EVENING_GARAGE", "the schedule says the team is in the garage")
	_check(speed_row.get_child_count() == 5 and (speed_row.get_child(1) as Button).button_pressed, "speed x1 is on at the start")
	_check((speed_row.get_child(3) as Button).text == "×20" and (speed_row.get_child(4) as Button).text == "SPEED_SKIP_LABEL", "the speeds are x1, x5, x20 and skip to morning")
	garage.set_speed(0)
	var paused_at := Game.clock.minutes
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Game.clock.minutes, paused_at), "the pause button stops time")
	_check((speed_row.get_child(0) as Button).button_pressed, "the pause button is highlighted")
	var pause := InputEventAction.new()
	pause.action = "time_pause"
	pause.pressed = true
	garage._unhandled_input(pause)
	_check(Game.clock.speed == 1, "Space resumes at the previous speed")
	garage.set_speed(1)

	Game.clock.advance_minutes(GameClock.MINUTES_PER_DAY - 6.0 * 60.0)
	garage._refresh_clock()
	_check(phase_label.text == "PHASE_DAY_JOB", "on Tuesday at noon the team is at work")
	var founder_list: VBoxContainer = garage.get_node("%FounderList")
	_check(founder_list.get_child_count() == Game.team.size(), "every founder has a line in the schedule")
	var hero_row := founder_list.get_child(0)
	_check((hero_row.get_node("Texts/Status") as Label).text == "Alex: at the day job until 20:00", "the line says where the founder is")
	_check((hero_row.get_node("Texts/Job") as Label).text.begins_with("Day job: $"), "the line shows the day job income")

	# Увольнение основателя с основной работы.
	var quit_dialog: ConfirmDialog = garage.get_node("%QuitJobDialog")
	(hero_row.get_node("Quit") as Button).pressed.emit()
	_check(quit_dialog.visible and (quit_dialog.get_node("%Body") as Label).text.begins_with("Alex will work"), "quitting asks first and names the founder")
	quit_dialog.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	_check(not Game.get_hero().has_day_job, "confirming quits the job")
	hero_row = founder_list.get_child(0)
	_check(not hero_row.has_node("Quit"), "the quit button is gone after quitting")
	_check((hero_row.get_node("Texts/Job") as Label).text == "No day job: in the garage all day", "the line says there is no day job")
	_check((hero_row.get_node("Texts/Status") as Label).text == "Alex: in the garage", "after quitting the founder is in the garage during the day")
	_check(founder_list.get_child(1).has_node("Quit"), "other founders keep their jobs")

	Game.salary_paid.emit(742)
	_check(garage.get_node("%Toast").visible and (garage.get_node("%ToastLabel") as Label).text == "Weekly pay from day jobs: +$742", "pay day shows a notice")

	garage.get_node("%MenuButton").pressed.emit()
	_check(leave_dialog.visible, "Menu asks before leaving an unsaved game")
	leave_dialog.get_node("%CancelButton").pressed.emit()
	_check(not leave_dialog.visible, "Keep playing closes the question")

	garage.queue_free()
	await get_tree().process_frame


func _test_navigation() -> void:
	var layout := GarageLayout.create_starting()
	var car := layout.car_cells()
	var nav := GarageNav.new(layout, [car])
	_check(car.has_point(Vector2i(layout.parking_spot.floor())), "the car blocks its own cells")
	_check(not nav.is_walkable(Vector2i(layout.parking_spot.floor())), "nobody walks through the car")
	_check(not nav.is_walkable(Vector2i(62, 121)), "nobody walks through walls")
	_check(not nav.is_walkable(Vector2i(95, 110)), "nobody walks into a closed house plot")
	_check(not nav.is_walkable(Vector2i(10, 30)), "nobody walks onto closed fields")
	_check(nav.is_walkable(Vector2i(66, 125)), "the garage door is open")

	for target in layout.junk + layout.debris:
		var path := nav.find_path(Vector2(layout.entry) + Vector2(0.5, 0.5), target)
		_check(not path.is_empty() and Vector2i(path[path.size() - 1].floor()) == target, "the way from the driveway leads to %s" % target)
		var clean := true
		for point in path:
			clean = clean and nav.is_walkable(Vector2i(point.floor()))
		_check(clean, "the way to %s goes only over open cells" % target)
	var to_yard := nav.find_path(layout.parking_spot + Vector2(-3.0, 0.0), Vector2i(66, 108))
	_check(to_yard.size() > 12, "the yard is reached around the garage, not through its back wall")
	_check(nav.find_path(Vector2(66.5, 131.5), Vector2i(95, 126)).size() > 0, "a closed target leads to the nearest open cell")


func _test_task_board() -> void:
	var board := TaskBoard.new()
	var junk := GameTask.create("TASK_CLEAR_JUNK", TeamMember.Role.MECHANIC, Vector2i(1, 1), 60.0)
	var junk_2 := GameTask.create("TASK_CLEAR_JUNK", TeamMember.Role.MECHANIC, Vector2i(2, 2), 60.0)
	var yard := GameTask.create("TASK_INSPECT", TeamMember.Role.DESIGNER, Vector2i(3, 3), 60.0)
	for task in [junk, junk_2, yard]:
		board.add(task)
	var mechanic := _member(true, TeamMember.Role.MECHANIC, "Alex")
	var driver := _member(false, TeamMember.Role.DRIVER, "Sam")

	_check(board.take_for(driver) == null, "a driver takes no mechanic or designer work")
	board.move(junk_2, -1)
	_check(board.tasks[0] == junk_2, "a task can be moved up the queue")
	_check(board.take_for(mechanic) == junk_2 and junk_2.assignee == mechanic, "the first task of the role is taken first")
	_check(board.take_for(_member(false, TeamMember.Role.MECHANIC, "Kim")) == junk, "a second mechanic takes the next one")
	board.set_paused(junk_2, true)
	_check(junk_2.assignee == null, "pausing a task frees its worker")
	_check(board.take_for(mechanic) == null, "paused and taken tasks are not offered")
	board.set_paused(junk_2, false)

	var done: Array[GameTask] = []
	board.completed.connect(func(task: GameTask) -> void: done.append(task))
	_check(not board.work(junk, 30.0) and is_equal_approx(junk.fraction(), 0.5), "work adds progress")
	board.release(junk)
	_check(junk.assignee == null and is_equal_approx(junk.progress, 30.0), "a dropped task keeps its progress")
	_check(board.work(junk, 45.0) and done == [junk] and not board.tasks.has(junk), "a finished task leaves the queue")


func _test_crew() -> void:
	var hero := _member(true, TeamMember.Role.MECHANIC, "Alex")
	var helper := _member(false, TeamMember.Role.DRIVER, "Sam")
	var team: Array[TeamMember] = [hero, helper]
	Game.start_new_game(team)
	var garage: Node2D = load("res://scenes/garage/garage.tscn").instantiate()
	add_child(garage)
	await get_tree().process_frame
	garage.set_process(false)  # Время двигаем сами, ровными шагами.
	garage.set_speed(1)

	var figures: Array = garage.get_node("%Actors").get_children().filter(func(node: Node) -> bool: return node is CharacterFigure)
	_check(figures.size() == 2, "every team member has a figure")
	var task_list: VBoxContainer = garage.get_node("%TaskList")
	_check(task_list.get_child_count() == Game.tasks.tasks.size(), "the task panel lists every task")
	_check(Game.tasks.tasks.all(func(task: GameTask) -> bool: return task.role == TeamMember.Role.MECHANIC), "clearing junk and the yard is mechanic work")

	garage.tick(0.1)
	_check(figures[1].visible and not figures[0].visible, "at 18:00 the driver comes in while the mechanic is still at work")
	Game.clock.minutes = 20.0 * 60.0
	garage.tick(0.1)
	_check(figures.all(func(figure: CharacterFigure) -> bool: return figure.visible), "by 20:00 everyone is in the garage")
	var junk_before := Game.garage.junk.size()
	var hero_figure: CharacterFigure = figures[0]
	var took_task := false
	for i in 350:
		garage.tick(0.1)
		took_task = took_task or hero_figure.task != null
	_check(took_task, "the mechanic takes junk work")
	_check(Game.garage.junk.size() < junk_before, "the mechanic clears junk during the evening")
	_check(helper.role == TeamMember.Role.DRIVER and figures[1].task == null, "the driver does no junk work")
	_check(Game.garage.debris.size() == 3, "the yard waits until the junk higher in the queue is done")

	# После полуночи все уходят.
	Game.clock.minutes = 24.5 * 60.0
	for i in 200:
		garage.tick(0.1)
	_check(figures.all(func(figure: CharacterFigure) -> bool: return not figure.visible), "at night everyone goes home")
	_check(Game.tasks.tasks.all(func(task: GameTask) -> bool: return task.assignee == null), "nobody holds a task overnight")

	garage.queue_free()
	await get_tree().process_frame


func _test_sound() -> void:
	# Все звуки синтезируются и годятся для проигрывания.
	for sound_name in Sound.ALL_SOUNDS:
		var made := Sound.stream(sound_name) as AudioStreamWAV
		_check(made != null and made.data.size() > 1000, "the %s sound is made" % sound_name)
		if made == null:
			continue
		var looped := sound_name.begins_with("music_") or sound_name.begins_with("ambience_")
		_check((made.loop_mode == AudioStreamWAV.LOOP_FORWARD) == looped, "%s loops only if it is music or background" % sound_name)
		_check(made.get_length() < 1.0 or looped, "%s is short" % sound_name)
	var music := Sound.stream("music_menu") as AudioStreamWAV
	_check(music.get_length() > 8.0, "the menu music is a proper loop, not a jingle")
	_check(Sound.stream("music_menu").data != Sound.stream("music_garage").data, "the garage has its own music")
	_check(SoundSynth.make("click").data == SoundSynth.make("click").data, "sounds are the same every time")

	# Кнопки сами щёлкают.
	var button := Button.new()
	add_child(button)
	Sound.last_played = ""
	button.pressed.emit()
	_check(Sound.last_played == "click", "every button clicks when pressed")
	button.queue_free()

	# Меню и гараж включают свою музыку, гараж — фон по времени суток.
	var menu: Control = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(Sound.music_track == "music_menu" and Sound.current_ambience() == "", "the menu plays its music without background noise")
	menu.queue_free()
	var team: Array[TeamMember] = [_member(true, TeamMember.Role.MECHANIC, "Alex")]
	Game.start_new_game(team)
	var garage: Node2D = load("res://scenes/garage/garage.tscn").instantiate()
	add_child(garage)
	await get_tree().process_frame
	_check(Sound.music_track == "music_garage", "the garage plays its own music")
	_check(Sound.current_ambience() == "ambience_day", "on a Monday evening the garage hears birds and wind")
	Game.clock.minutes = 22.0 * 60.0
	garage._refresh_clock()
	_check(Sound.current_ambience() == "ambience_night", "late in the evening the crickets start")
	Game.salary_paid.emit(500)
	_check(Sound.last_played == "coin", "pay day sounds like coins")
	garage.queue_free()
	await get_tree().process_frame


func team_of(member: TeamMember) -> Array[TeamMember]:
	var result: Array[TeamMember] = [member]
	return result


func _member(hero: bool, role: TeamMember.Role, member_name: String) -> TeamMember:
	var member := TeamMember.create(hero, role)
	member.display_name = member_name
	return member


func _visible_children(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Control and child.visible:
			count += 1
	return count


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
