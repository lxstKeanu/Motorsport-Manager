extends Control
## Мастер новой игры по шагам (GDD 3): вступление → название, эмблема и цвет команды →
## основатели (до четырёх, первый — сам игрок). На последнем шаге слева состав и сложность,
## справа редактор выбранного основателя: имя, роль, возраст, внешность.
## «Пропустить» сразу начинает игру со стандартной командой.

enum Step { INTRO, TEAM, FOUNDERS }

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const GARAGE_SCENE := "res://scenes/garage/garage.tscn"
const SWATCH_SIZE := Vector2(34, 34)
const EMBLEM_SIZE := Vector2(64, 64)
const SLOT_HEIGHT := 76.0
const ACCENT := Color(0.941, 0.541, 0.141)

## Состав по порядку слотов: первым всегда идёт сам игрок.
var members: Array[TeamMember] = []
var step := Step.INTRO
var team_emblem := 0
var team_color := 0
var _selected := 0
var _emblem_buttons: Array[Button] = []
var _team_color_buttons: Array[Button] = []

var _role_buttons := {}
var _skin_buttons: Array[Button] = []
var _hair_color_buttons: Array[Button] = []
var _shirt_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _slot_portraits: Array[CharacterPortrait] = []
var _slot_names: Array[Label] = []
var _slot_roles: Array[Label] = []

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _add_founder_button: Button = %AddFounderButton
@onready var _difficulty_label: Label = %DifficultyLabel
@onready var _difficulty_bar: DifficultyBar = %DifficultyBar
@onready var _difficulty_hint: Label = %DifficultyHint
@onready var _role_warnings: Label = %RoleWarnings
@onready var _editor_title: Label = %EditorTitle
@onready var _remove_button: Button = %RemoveButton
@onready var _portrait: CharacterPortrait = %Portrait
@onready var _randomize_button: Button = %RandomizeButton
@onready var _name_edit: LineEdit = %NameEdit
@onready var _role_row: HBoxContainer = %RoleButtons
@onready var _role_hint: Label = %RoleHint
@onready var _age_slider: HSlider = %AgeSlider
@onready var _age_value: Label = %AgeValue
@onready var _skill_value: Label = %SkillValue
@onready var _potential_value: Label = %PotentialValue
@onready var _job_income: Label = %JobIncome
@onready var _job_hours: Label = %JobHours
@onready var _skin_row: HBoxContainer = %SkinSwatches
@onready var _hair_prev_button: Button = %HairPrevButton
@onready var _hair_next_button: Button = %HairNextButton
@onready var _hair_style_value: Label = %HairStyleValue
@onready var _hair_color_row: HBoxContainer = %HairSwatches
@onready var _shirt_row: HBoxContainer = %ShirtSwatches
@onready var _name_error: Label = %NameError
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton
@onready var _leave_dialog: ConfirmDialog = %LeaveDialog
@onready var _skip_button: Button = %SkipButton
@onready var _pages: Array[Control] = [%IntroPage, %TeamPage, %Margin]
@onready var _intro_back: Button = %IntroBack
@onready var _intro_next: Button = %IntroNext
@onready var _team_name_edit: LineEdit = %TeamNameEdit
@onready var _emblem_grid: GridContainer = %EmblemGrid
@onready var _team_color_row: HBoxContainer = %ColorRow
@onready var _team_back: Button = %TeamBack
@onready var _team_next: Button = %TeamNext


func _ready() -> void:
	Settings.fit_ui(self)
	Sound.play_music("music_menu")
	Sound.set_ambience("")
	members.append(TeamMember.create(true, TeamMember.Role.MECHANIC))

	_build_role_buttons()
	_skin_buttons = _build_swatches(_skin_row, Appearance.SKIN_TONES, _on_skin_picked)
	_hair_color_buttons = _build_swatches(_hair_color_row, Appearance.HAIR_COLORS, _on_hair_color_picked)
	_shirt_buttons = _build_swatches(_shirt_row, Appearance.SHIRT_COLORS, _on_shirt_picked)
	_name_edit.max_length = TeamMember.NAME_MAX_LENGTH

	_add_founder_button.pressed.connect(add_founder)
	_remove_button.pressed.connect(remove_selected)
	_randomize_button.pressed.connect(_on_randomize_pressed)
	_name_edit.text_changed.connect(_on_name_changed)
	_age_slider.min_value = TeamMember.AGE_MIN
	_age_slider.max_value = TeamMember.AGE_MAX
	_age_slider.value_changed.connect(_on_age_changed)
	_hair_prev_button.pressed.connect(_step_hair_style.bind(-1))
	_hair_next_button.pressed.connect(_step_hair_style.bind(1))
	_back_button.pressed.connect(show_step.bind(Step.TEAM))
	_start_button.pressed.connect(_on_start_pressed)
	_skip_button.pressed.connect(start_with_default_team)
	_leave_dialog.confirmed.connect(_go_back)
	_leave_dialog.cancelled.connect(_intro_back.grab_focus)

	# Шаги мастера.
	_intro_back.pressed.connect(request_leave)
	_intro_next.pressed.connect(show_step.bind(Step.TEAM))
	_team_back.pressed.connect(show_step.bind(Step.INTRO))
	_team_next.pressed.connect(show_step.bind(Step.FOUNDERS))
	_team_name_edit.max_length = TeamStyle.NAME_MAX_LENGTH
	_team_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_team_step())
	var emblem_group := ButtonGroup.new()
	for i in TeamStyle.EMBLEMS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = emblem_group
		button.icon = TeamStyle.emblem(i)
		button.expand_icon = true
		button.custom_minimum_size = EMBLEM_SIZE
		button.pressed.connect(_on_emblem_picked.bind(i))
		_emblem_grid.add_child(button)
		_emblem_buttons.append(button)
	_team_color_buttons = _build_swatches(_team_color_row, TeamStyle.COLORS, _on_team_color_picked)
	for swatch in _team_color_buttons:
		swatch.custom_minimum_size = Vector2(48, 48)

	_rebuild_slots()
	select_member(0)
	_refresh_team_step()
	show_step(Step.INTRO)


## Показывает шаг мастера и ставит фокус туда, где удобно продолжать.
func show_step(new_step: Step) -> void:
	step = new_step
	for i in _pages.size():
		_pages[i].visible = i == step
	match step:
		Step.INTRO:
			_intro_next.grab_focus()
		Step.TEAM:
			_team_name_edit.grab_focus()
		Step.FOUNDERS:
			_name_edit.grab_focus()


## Начать сразу: стандартная команда из механика и гонщика, название и эмблема по умолчанию.
## Имена берутся из таблицы переводов, чтобы звучали на языке игры.
func start_with_default_team() -> void:
	Game.start_new_game(default_team(), tr("DEFAULT_TEAM_NAME"), 0, 0)
	get_tree().change_scene_to_file(GARAGE_SCENE)


func default_team() -> Array[TeamMember]:
	var mechanic := TeamMember.create(true, TeamMember.Role.MECHANIC)
	mechanic.display_name = tr("DEFAULT_FOUNDER_1")
	var driver := TeamMember.create(false, TeamMember.Role.DRIVER)
	driver.display_name = tr("DEFAULT_FOUNDER_2")
	var team: Array[TeamMember] = [mechanic, driver]
	return team


func _on_emblem_picked(index: int) -> void:
	team_emblem = index
	_refresh_team_step()


func _on_team_color_picked(index: int) -> void:
	team_color = index
	_refresh_team_step()


## Эмблемы окрашены в выбранный цвет команды. «Далее» доступна, когда у команды есть название.
func _refresh_team_step() -> void:
	_sync_group(_emblem_buttons, team_emblem)
	_sync_group(_team_color_buttons, team_color)
	for button in _emblem_buttons:
		button.add_theme_color_override("icon_normal_color", TeamStyle.color(team_color))
		button.add_theme_color_override("icon_pressed_color", TeamStyle.color(team_color))
		button.add_theme_color_override("icon_hover_color", TeamStyle.color(team_color))
		button.add_theme_color_override("icon_hover_pressed_color", TeamStyle.color(team_color))
	_team_next.disabled = _team_name_edit.text.strip_edges().is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_editor()
		for i in members.size():
			_refresh_slot(i)
		_refresh_status()


## Esc — на шаг назад, с первого шага — в меню. Открытое окно само закрывается по Esc.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _leave_dialog.visible:
		get_viewport().set_input_as_handled()
		if step == Step.INTRO:
			request_leave()
		else:
			show_step(step - 1 as Step)


## Выход в меню. Если команду уже начали собирать, сначала спрашиваем, чтобы случайный Esc её не стёр.
func request_leave() -> void:
	if not has_progress():
		_go_back()
		return
	_leave_dialog.open()


## Есть ли что терять: название команды, введённое имя или добавленный основатель.
## Внешность и возраст не считаются, они случайные.
func has_progress() -> bool:
	if members.size() > 1 or not _team_name_edit.text.strip_edges().is_empty():
		return true
	for member in members:
		if not member.display_name.strip_edges().is_empty():
			return true
	return false


func add_founder() -> void:
	if members.size() >= TeamRules.MAX_FOUNDERS:
		return
	members.append(TeamMember.create(false, TeamRules.default_founder_role(members)))
	_rebuild_slots()
	select_member(members.size() - 1)
	_name_edit.grab_focus()


func remove_selected() -> void:
	if members[_selected].is_hero:
		return
	members.remove_at(_selected)
	_rebuild_slots()
	select_member(mini(_selected, members.size() - 1))


func select_member(index: int) -> void:
	_selected = index
	for i in _slot_buttons.size():
		_slot_buttons[i].set_pressed_no_signal(i == _selected)
	_refresh_editor()
	_refresh_status()


func founder_count() -> int:
	return members.size()


func can_start() -> bool:
	return TeamRules.name_errors(members).is_empty()


func _selected_member() -> TeamMember:
	return members[_selected]


# --- Состав слева ---

func _rebuild_slots() -> void:
	for child in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	_slot_portraits.clear()
	_slot_names.clear()
	_slot_roles.clear()

	var group := ButtonGroup.new()
	for i in members.size():
		_slot_list.add_child(_make_slot(i, group))
		_refresh_slot(i)


func _make_slot(index: int, group: ButtonGroup) -> Button:
	var slot := Button.new()
	slot.toggle_mode = true
	slot.button_group = group
	slot.custom_minimum_size = Vector2(0.0, SLOT_HEIGHT)
	slot.pressed.connect(select_member.bind(index))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	slot.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.offset_left = 12.0

	var portrait := CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(52.0, 60.0)
	row.add_child(portrait)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)

	var name_label := Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	var role_label := Label.new()
	role_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	role_label.theme_type_variation = &"DimLabel"
	texts.add_child(role_label)

	_slot_buttons.append(slot)
	_slot_portraits.append(portrait)
	_slot_names.append(name_label)
	_slot_roles.append(role_label)
	return slot


func _refresh_slot(index: int) -> void:
	if index >= _slot_buttons.size():
		return
	var member := members[index]
	var shown_name := member.display_name.strip_edges()
	_slot_names[index].text = shown_name if not shown_name.is_empty() else tr("TEAM_UNNAMED")
	_slot_names[index].modulate.a = 1.0 if not shown_name.is_empty() else 0.5
	_slot_roles[index].text = "%s · %s" % [tr("TEAM_YOU"), member.role_name()] if member.is_hero else member.role_name()
	_slot_portraits[index].appearance = member.appearance
	_slot_portraits[index].queue_redraw()


func _refresh_status() -> void:
	_add_founder_button.disabled = founder_count() >= TeamRules.MAX_FOUNDERS
	_add_founder_button.text = tr("TEAM_ADD_FOUNDER") % [founder_count(), TeamRules.MAX_FOUNDERS]
	_difficulty_label.text = TeamRules.difficulty_key(founder_count())
	_difficulty_hint.text = TeamRules.difficulty_hint_key(founder_count())
	_difficulty_bar.mark = TeamRules.difficulty_mark(founder_count())

	var warnings := PackedStringArray()
	for key in TeamRules.role_warnings(members):
		warnings.append(tr(key))
	_role_warnings.text = "\n".join(warnings)
	_role_warnings.visible = not warnings.is_empty()

	var errors := TeamRules.name_errors(members)
	_name_error.text = errors[0] if not errors.is_empty() else ""
	_start_button.disabled = not errors.is_empty()


# --- Редактор справа ---

func _build_role_buttons() -> void:
	var group := ButtonGroup.new()
	for role in TeamMember.ROLES:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = TeamMember.ROLE_NAME_KEYS[role]
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.pressed.connect(_on_role_picked.bind(role))
		_role_row.add_child(button)
		_role_buttons[role] = button


func _build_swatches(row: HBoxContainer, colors: Array[Color], handler: Callable) -> Array[Button]:
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for i in colors.size():
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.add_theme_stylebox_override("normal", _swatch_style(colors[i], Color(1, 1, 1, 0.12), 1))
		swatch.add_theme_stylebox_override("hover", _swatch_style(colors[i], Color(1, 1, 1, 0.6), 2))
		swatch.add_theme_stylebox_override("pressed", _swatch_style(colors[i], ACCENT, 3))
		swatch.add_theme_stylebox_override("hover_pressed", _swatch_style(colors[i], ACCENT, 3))
		swatch.add_theme_stylebox_override("disabled", _swatch_style(Color(colors[i], 0.2), Color(1, 1, 1, 0.06), 1))
		swatch.pressed.connect(handler.bind(i))
		row.add_child(swatch)
		buttons.append(swatch)
	return buttons


func _swatch_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


func _refresh_editor() -> void:
	var member := _selected_member()
	_editor_title.text = tr("TEAM_HERO") if member.is_hero else tr("TEAM_FOUNDER_N") % (_selected + 1)
	_remove_button.visible = not member.is_hero
	if _name_edit.text != member.display_name:
		_name_edit.text = member.display_name

	for role: TeamMember.Role in _role_buttons:
		var button: Button = _role_buttons[role]
		button.set_pressed_no_signal(role == member.role)
	_role_hint.text = TeamMember.ROLE_HINT_KEYS[member.role]
	_refresh_numbers()

	var look := member.appearance
	_sync_group(_skin_buttons, look.skin)
	_sync_group(_hair_color_buttons, look.hair_color)
	_sync_group(_shirt_buttons, look.shirt)
	# Лысому цвет волос не нужен.
	for swatch in _hair_color_buttons:
		swatch.disabled = look.hair_style == Appearance.HairStyle.BALD
	_hair_style_value.text = Appearance.HAIR_STYLE_KEYS[look.hair_style]
	_portrait.appearance = look
	_portrait.queue_redraw()


## Возраст, навык, потенциал и основная работа: всё это зависит от возраста и роли.
func _refresh_numbers() -> void:
	var member := _selected_member()
	_age_slider.set_value_no_signal(member.age)
	_age_value.text = str(member.age)
	_skill_value.text = str(member.skill())
	_potential_value.text = str(member.potential)
	_job_income.text = tr("JOB_INCOME_WEEK") % Game.format_money(member.weekly_income())
	_job_hours.text = tr("JOB_HOURS") % [_clock_text(member.job_start()), _clock_text(member.job_end())]


static func _clock_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


## set_pressed_no_signal не отжимает остальные кнопки группы, поэтому выставляем все.
func _sync_group(buttons: Array[Button], selected: int) -> void:
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected)


func _appearance_changed() -> void:
	_refresh_editor()
	_refresh_slot(_selected)


func _on_name_changed(new_text: String) -> void:
	_selected_member().display_name = new_text
	_refresh_slot(_selected)
	_refresh_status()


func _on_age_changed(value: float) -> void:
	_selected_member().age = int(value)
	_refresh_numbers()


func _on_role_picked(role: TeamMember.Role) -> void:
	_selected_member().role = role
	_refresh_editor()
	_refresh_slot(_selected)
	_refresh_status()


func _on_skin_picked(index: int) -> void:
	_selected_member().appearance.skin = index
	_appearance_changed()


func _on_hair_color_picked(index: int) -> void:
	_selected_member().appearance.hair_color = index
	_appearance_changed()


func _on_shirt_picked(index: int) -> void:
	_selected_member().appearance.shirt = index
	_appearance_changed()


func _step_hair_style(step: int) -> void:
	var look := _selected_member().appearance
	look.hair_style = posmod(look.hair_style + step, Appearance.HairStyle.size()) as Appearance.HairStyle
	_appearance_changed()


## «Случайно»: новые внешность, возраст и потенциал. Имя и роль остаются.
func _on_randomize_pressed() -> void:
	_selected_member().shuffle()
	_appearance_changed()


func _on_start_pressed() -> void:
	if not can_start():
		return
	Game.start_new_game(members, _team_name_edit.text, team_emblem, team_color)
	get_tree().change_scene_to_file(GARAGE_SCENE)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
