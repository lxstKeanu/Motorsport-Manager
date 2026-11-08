extends Node2D
## Гараж: участок на сетке, камера, время, команда и игровой интерфейс.
## Сверху: команда и год, часы с датой, открыт ли гараж и сверхурочные, скорость, меню;
## под ней деньги и поставки. Слева цели «С чего начать». Справа колонка разделов:
## «Работы» (очередь задач), «Персонал» (основатели и распорядок), «Деньги»; остальные
## разделы пишут, на каком этапе появятся. Внизу колонки — «Строить» (этап 7).

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
## Масштаб на старте: седан и бокс видны крупно.
const START_ZOOM := 1.4
## Зазор между верхней панелью и картой, в пикселях.
const TOP_BAR_GAP := 8.0
## Подписи кнопок скорости. Это значки, а не слова, поэтому без перевода.
## У последней кнопки, перемотки до утра, подпись — ключ перевода.
const SPEED_LABELS: Array[String] = ["II", "×1", "×5", "×20", "SPEED_SKIP_LABEL"]
const TOAST_SECONDS := 4.0
const ICONS := "res://ui/icons/sidebar/%s.svg"
## Разделы справа: id, ключ названия и где он появится. Пустой этап — раздел уже работает.
const SECTIONS: Array[Array] = [
	["series", "SECTION_SERIES", "STAGE_8"],
	["sponsors", "SECTION_SPONSORS", "STAGE_LATER"],
	["suppliers", "SECTION_SUPPLIERS", "STAGE_6"],
	["fleet", "SECTION_FLEET", "STAGE_8"],
	["cars", "SECTION_CARS", "STAGE_5"],
	["parts", "SECTION_PARTS", "STAGE_5"],
	["staff", "SECTION_STAFF", ""],
	["design", "SECTION_DESIGN", "STAGE_LATER"],
	["works", "SECTION_WORKS", ""],
	["production", "SECTION_PRODUCTION", "STAGE_LATER"],
	["money", "SECTION_MONEY", ""],
	["company", "SECTION_COMPANY", "STAGE_LATER"],
	["testing", "SECTION_TESTING", "STAGE_LATER"],
	["analysis", "SECTION_ANALYSIS", "STAGE_LATER"],
]
const OPEN_COLOR := Color(0.36, 0.78, 0.48)
const CLOSED_COLOR := Color(0.86, 0.3, 0.26)
const MONEY_POSITIVE := Color(0.45, 0.82, 0.52)
const MONEY_NEGATIVE := Color(0.92, 0.38, 0.32)
const ACCENT := Color(0.941, 0.541, 0.141)
## Через сколько минут проверять, когда гараж откроется, и как далеко вперёд.
const OPENING_STEP := 15
const OPENING_LOOKAHEAD := 3 * GameClock.MINUTES_PER_DAY

## Скорость, к которой вернёт Пробел после паузы.
var _resume_speed := 1
var _speed_buttons: Array[Button] = []
var _section_buttons := {}
## Открытый раздел справа, пустая строка — панель закрыта.
var open_section := ""
## Кто собрался увольняться: окно с вопросом открыто для него.
var _quitting: TeamMember
var _toast_tween: Tween
var _nav: GarageNav
var _figures: Array[CharacterFigure] = []
## Строки панели задач: задача → её виджеты, чтобы каждый кадр обновлять только прогресс и статус.
var _task_rows := {}

@onready var _map: GarageMap = %Map
@onready var _actors: Node2D = %Actors
@onready var _sedan: Node2D = %Sedan
@onready var _camera: GarageCamera = %Camera
@onready var _hud_root: Control = $Hud/Root
@onready var _top_bar: Control = %TopBar
@onready var _emblem: TextureRect = %Emblem
@onready var _team_name: Label = %TeamName
@onready var _year_label: Label = %YearLabel
@onready var _time_label: Label = %TimeLabel
@onready var _date_label: Label = %DateLabel
@onready var _status_dot: ColorRect = %StatusDot
@onready var _status_label: Label = %StatusLabel
@onready var _overtime_button: Button = %OvertimeButton
@onready var _speed_row: HBoxContainer = %SpeedRow
@onready var _menu_button: Button = %MenuButton
@onready var _money_label: Label = %MoneyLabel
@onready var _objectives_panel: Control = %ObjectivesPanel
@onready var _objectives_list: VBoxContainer = %ObjectivesList
@onready var _objectives_toggle: Button = %ObjectivesToggle
@onready var _objectives_hide: Button = %ObjectivesHide
@onready var _section_list: VBoxContainer = %SectionButtons
@onready var _build_button: Button = %BuildButton
@onready var _section_panel: Control = %SectionPanel
@onready var _section_title: Label = %SectionTitle
@onready var _section_close: Button = %SectionClose
@onready var _pages := {"works": %WorksPage, "staff": %StaffPage, "money": %MoneyPage}
@onready var _soon_page: Control = %SoonPage
@onready var _soon_label: Label = %SoonLabel
@onready var _balance_label: Label = %BalanceLabel
@onready var _income_label: Label = %IncomeLabel
@onready var _next_pay_label: Label = %NextPayLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _founder_list: VBoxContainer = %FounderList
@onready var _task_list: VBoxContainer = %TaskList
@onready var _tasks_empty: Label = %TasksEmpty
@onready var _toast: Control = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _leave_dialog: ConfirmDialog = %LeaveDialog
@onready var _quit_job_dialog: ConfirmDialog = %QuitJobDialog


func _ready() -> void:
	# Сцену можно запустить отдельно (F6): тогда начинаем игру без команды.
	if Game.garage == null:
		Game.start_new_game([])
	_map.layout = Game.garage
	_sedan.position = Game.garage.parking_spot * GarageMap.CELL_SIZE
	_camera.setup(_map.world_bounds(), _sedan.position, START_ZOOM)
	Settings.fit_ui(_hud_root)
	Sound.play_music("music_garage")
	_camera.view_inset_top = _top_bar_bottom()
	_top_bar.resized.connect(_update_camera_inset)
	Settings.changed.connect(_on_settings_changed)

	_menu_button.pressed.connect(_leave_dialog.open)
	_leave_dialog.confirmed.connect(_go_to_menu)
	_quit_job_dialog.confirmed.connect(func() -> void: Game.quit_day_job(_quitting))
	_overtime_button.toggled.connect(set_overtime)
	_objectives_toggle.pressed.connect(_toggle_objectives)
	_objectives_hide.pressed.connect(func() -> void:
		Game.objectives_hidden = true
		_objectives_panel.hide())
	_section_close.pressed.connect(open_section_panel.bind(""))
	_build_button.icon = load(ICONS % "build")
	_build_button.toggled.connect(func(on: bool) -> void: open_section_panel("build" if on else ""))
	Game.money_changed.connect(_refresh_money)
	Game.salary_paid.connect(_on_salary_paid)
	Game.day_job_quit.connect(func(_member: TeamMember) -> void:
		_rebuild_founder_rows()
		_refresh_money())
	Game.clock.skip_finished.connect(_sync_speed_buttons)
	Game.garage_changed.connect(_on_garage_changed)
	Game.tasks.changed.connect(_rebuild_task_rows)

	_nav = GarageNav.new(Game.garage, [Game.garage.car_cells()])
	for member in Game.team:
		var figure := CharacterFigure.new()
		figure.setup(member, _nav, Game.garage, Game.tasks)
		figure.task_finished.connect(_on_task_finished)
		_actors.add_child(figure)
		_figures.append(figure)

	_build_speed_buttons()
	_build_section_buttons()
	_rebuild_task_rows()
	_rebuild_founder_rows()
	_rebuild_objectives()
	_objectives_panel.visible = not Game.objectives_hidden
	_overtime_button.set_pressed_no_signal(Game.clock.overtime)
	_refresh_hud()
	# Очередь задач открыта сразу: с неё начинается работа в гараже.
	open_section_panel("works")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_hud()
		_rebuild_task_rows()
		_rebuild_founder_rows()
		_rebuild_objectives()
		open_section_panel(open_section)


func _process(delta: float) -> void:
	tick(delta)


## Шаг игры на delta реальных секунд: время, команда, панели. Пока открыто окно с вопросом, всё стоит.
func tick(delta: float) -> void:
	if _leave_dialog.visible or _quit_job_dialog.visible:
		return
	var before := Game.clock.minutes
	Game.clock.advance(delta)
	var minutes := Game.clock.minutes - before
	var walk := delta * GameClock.SPEEDS[Game.clock.speed]
	for figure in _figures:
		figure.step(walk, minutes, Game.clock.minutes)
	if int(Game.clock.minutes) != int(before):
		_refresh_clock()
	_refresh_task_rows()


func _unhandled_input(event: InputEvent) -> void:
	if _leave_dialog.visible or _quit_job_dialog.visible:
		return  # Открытое окно само закрывается по Esc.
	if event.is_action_pressed("ui_cancel"):
		if open_section.is_empty():
			_leave_dialog.open()
		else:
			open_section_panel("")
	elif event.is_action_pressed("time_pause"):
		set_speed(_resume_speed if Game.clock.speed == 0 else 0)
	elif event.is_action_pressed("time_speed_1"):
		set_speed(1)
	elif event.is_action_pressed("time_speed_2"):
		set_speed(2)
	elif event.is_action_pressed("time_speed_3"):
		set_speed(3)
	elif event.is_action_pressed("time_skip_day"):
		set_speed(GameClock.SKIP)
	else:
		return
	get_viewport().set_input_as_handled()


## Скорость по номеру в GameClock.SPEEDS: 0 — пауза, GameClock.SKIP — перемотка до утра.
func set_speed(index: int) -> void:
	index = clampi(index, 0, GameClock.SPEEDS.size() - 1)
	if index == GameClock.SKIP:
		Game.clock.skip_to_morning()
	else:
		Game.clock.speed = index
		Game.clock.skip_until = -1.0
		if index > 0:
			_resume_speed = index
			Game.clock.resume_speed = index
	_sync_speed_buttons()


## Сверхурочные: команда остаётся в гараже до 02:00.
func set_overtime(enabled: bool) -> void:
	Game.clock.overtime = enabled
	_overtime_button.set_pressed_no_signal(enabled)
	_refresh_clock()


## Открывает раздел справа по id. Пустая строка или повторный выбор того же раздела — закрыть.
func open_section_panel(id: String) -> void:
	open_section = id
	_section_panel.visible = not id.is_empty()
	for key: String in _section_buttons:
		(_section_buttons[key] as Button).set_pressed_no_signal(key == id)
	_build_button.set_pressed_no_signal(id == "build")
	if id.is_empty():
		return
	for key: String in _pages:
		(_pages[key] as Control).visible = key == id
	var section := _section(id)
	_section_title.text = tr(section[1])
	_soon_page.visible = not _pages.has(id)
	if _soon_page.visible:
		_soon_label.text = tr("SECTION_SOON").format({"section": tr(section[1]), "when": tr(section[2])})
	if id == "money":
		_refresh_money()


func _section(id: String) -> Array:
	if id == "build":
		return ["build", "SECTION_BUILD", "STAGE_7"]
	for section in SECTIONS:
		if section[0] == id:
			return section
	return ["", "", ""]


## Уведомление вверху экрана со своим звуком: по умолчанию «динь», у зарплаты — монеты, у работы — стук металла.
func show_toast(text: String, sound_name: String = "chime") -> void:
	Sound.play(sound_name)
	_toast_label.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_toast.hide)


## Низ верхней панели на экране, с учётом масштаба интерфейса.
func _top_bar_bottom() -> float:
	return (_top_bar.get_global_transform() * _top_bar.size).y + TOP_BAR_GAP


func _update_camera_inset() -> void:
	_camera.view_inset_top = _top_bar_bottom()


## Масштаб интерфейса меняет высоту панели, валюта — подписи денег.
func _on_settings_changed() -> void:
	_update_camera_inset()
	_refresh_money()
	_rebuild_founder_rows()


func _on_garage_changed() -> void:
	_map.queue_redraw()
	_rebuild_objectives()


func _refresh_hud() -> void:
	_emblem.texture = TeamStyle.emblem(Game.team_emblem)
	_emblem.modulate = TeamStyle.color(Game.team_color)
	_team_name.text = Game.display_team_name()
	_refresh_money()
	_refresh_clock()
	for i in _speed_buttons.size():
		if i == 0:
			_speed_buttons[i].tooltip_text = tr("SPEED_PAUSE")
		elif i == GameClock.SKIP:
			_speed_buttons[i].tooltip_text = tr("SPEED_SKIP")
		else:
			_speed_buttons[i].tooltip_text = tr("SPEED_N") % [int(GameClock.SPEEDS[i]), i]


## Деньги сверху и раздел «Деньги»: баланс, недельный доход с основных работ, ближайшая зарплата.
func _refresh_money() -> void:
	_money_label.text = Game.format_money(Game.money)
	_money_label.add_theme_color_override("font_color", MONEY_POSITIVE if Game.money >= 0 else MONEY_NEGATIVE)
	_balance_label.text = _money_label.text
	_income_label.text = tr("MONEY_WEEKLY_INCOME") % Game.format_money(Game.weekly_income())
	_next_pay_label.text = tr("MONEY_NEXT_PAY") if Game.weekly_income() > 0 else tr("MONEY_NO_INCOME")


func _refresh_clock() -> void:
	var clock := Game.clock
	_time_label.text = clock.time_text()
	_date_label.text = clock.date_text()
	_year_label.text = tr("HUD_YEAR") % clock.year()
	_refresh_status()
	_refresh_schedule()
	# Фон: ночью сверчки, днём ветер и птицы. Смена плавная, без щелчка.
	Sound.set_ambience("ambience_night" if GameClock.is_night(clock.minutes) or clock.minute_of_day() >= 21 * 60 else "ambience_day")


## «Открыто до 24:00», пока в гараже кто-то есть, иначе «Закрыто · откроется в 18:00».
func _refresh_status() -> void:
	var open := not Game.members_in_garage().is_empty()
	_status_dot.color = OPEN_COLOR if open else CLOSED_COLOR
	if open:
		_status_label.text = tr("HUD_OPEN_UNTIL") % _clock_text(Game.clock.closing_minute())
		return
	var opening := next_opening()
	_status_label.text = tr("HUD_CLOSED_UNTIL") % _clock_text(int(opening) % GameClock.MINUTES_PER_DAY) if opening >= 0.0 else tr("HUD_CLOSED")


## Когда в гараже кто-нибудь появится. -1 — в ближайшие дни никого (или команды нет).
func next_opening() -> float:
	var start := floorf(Game.clock.minutes / OPENING_STEP) * OPENING_STEP
	var at := start + OPENING_STEP
	while at <= start + OPENING_LOOKAHEAD:
		for member in Game.team:
			if member.phase_at(at, Game.clock.overtime) == GameClock.Phase.GARAGE:
				return at
		at += OPENING_STEP
	return -1.0


# --- Цели «С чего начать» ---

func _rebuild_objectives() -> void:
	for child in _objectives_list.get_children():
		_objectives_list.remove_child(child)
		child.queue_free()
	for objective in Game.objectives():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var mark := Panel.new()
		mark.custom_minimum_size = Vector2(14.0, 14.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.border_color = ACCENT
		style.bg_color = ACCENT if objective["done"] else Color(0, 0, 0, 0)
		mark.add_theme_stylebox_override("panel", style)
		row.add_child(mark)
		var text := Label.new()
		text.text = objective["key"]
		text.modulate.a = 0.5 if objective["done"] else 1.0
		row.add_child(text)
		_objectives_list.add_child(row)


func _toggle_objectives() -> void:
	_objectives_list.visible = not _objectives_list.visible
	_objectives_hide.visible = _objectives_list.visible
	_objectives_toggle.text = "−" if _objectives_list.visible else "+"


# --- Разделы справа ---

func _build_section_buttons() -> void:
	for section in SECTIONS:
		var id: String = section[0]
		var button := Button.new()
		button.theme_type_variation = &"SideButton"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = section[1]
		button.icon = load(ICONS % id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(0.0, 50.0)
		button.toggled.connect(func(on: bool) -> void: open_section_panel(id if on else ""))
		_section_list.add_child(button)
		_section_buttons[id] = button


# --- Персонал ---

## Общая строка о времени суток и по строке на каждого основателя.
func _refresh_schedule() -> void:
	_phase_label.text = Game.clock.team_phase_key()
	for i in mini(Game.team.size(), _founder_list.get_child_count()):
		var status: Label = _founder_list.get_child(i).get_node("Texts/Status")
		status.text = _founder_status(Game.team[i])


func _rebuild_founder_rows() -> void:
	for child in _founder_list.get_children():
		_founder_list.remove_child(child)
		child.queue_free()
	for member in Game.team:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		var texts := VBoxContainer.new()
		texts.name = "Texts"
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		var status := Label.new()
		status.name = "Status"
		status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		texts.add_child(status)
		var job := Label.new()
		job.name = "Job"
		job.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		job.theme_type_variation = &"DimLabel"
		job.text = _founder_job(member)
		texts.add_child(job)
		if member.has_day_job:
			var quit := Button.new()
			quit.name = "Quit"
			quit.text = "QUIT_JOB_BUTTON"
			quit.focus_mode = Control.FOCUS_NONE
			quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			quit.pressed.connect(_ask_quit_job.bind(member))
			row.add_child(quit)
		_founder_list.add_child(row)
	_refresh_schedule()


func _founder_status(member: TeamMember) -> String:
	var values := {"name": member.display_name, "time": _clock_text(member.job_end())}
	match member.phase_at(Game.clock.minutes, Game.clock.overtime):
		GameClock.Phase.SLEEP:
			return tr("STATUS_SLEEP").format(values)
		GameClock.Phase.DAY_JOB:
			return tr("STATUS_AT_JOB").format(values)
		GameClock.Phase.HOME:
			return tr("STATUS_HOME").format(values)
	return tr("STATUS_IN_GARAGE").format(values)


func _founder_job(member: TeamMember) -> String:
	if not member.has_day_job:
		return tr("JOB_NONE")
	return tr("JOB_HAS").format({
		"income": Game.format_money(member.weekly_income()),
		"start": _clock_text(member.job_start()),
		"end": _clock_text(member.job_end()),
	})


static func _clock_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _ask_quit_job(member: TeamMember) -> void:
	_quitting = member
	_quit_job_dialog.open({"name": member.display_name, "income": Game.format_money(member.weekly_income())})


func _on_salary_paid(amount: int) -> void:
	show_toast(tr("TOAST_SALARY") % Game.format_money(amount), "coin")


func _on_task_finished(member: TeamMember, task: GameTask) -> void:
	show_toast(tr("TOAST_TASK_DONE").format({"name": member.display_name, "task": tr(task.title_key)}), "clank")


# --- Очередь задач ---

## Пересобирает строки панели: состав или порядок задач поменялся.
func _rebuild_task_rows() -> void:
	for child in _task_list.get_children():
		_task_list.remove_child(child)
		child.queue_free()
	_task_rows.clear()
	for task in Game.tasks.tasks:
		_task_list.add_child(_make_task_row(task))
	_tasks_empty.visible = Game.tasks.tasks.is_empty()
	_refresh_task_rows()


func _make_task_row(task: GameTask) -> Control:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 4)
	row.add_child(head)
	var title := Label.new()
	title.text = task.title_key
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var up := _task_button("↑", "TASK_UP", func() -> void: Game.tasks.move(task, -1))
	var down := _task_button("↓", "TASK_DOWN", func() -> void: Game.tasks.move(task, 1))
	var pause := _task_button("II", "TASK_PAUSE", func() -> void: Game.tasks.set_paused(task, not task.paused))
	pause.toggle_mode = true
	pause.set_pressed_no_signal(task.paused)
	var index := Game.tasks.tasks.find(task)
	up.disabled = index == 0
	down.disabled = index == Game.tasks.tasks.size() - 1
	for button in [up, down, pause]:
		head.add_child(button)

	var status := Label.new()
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.theme_type_variation = &"DimLabel"
	row.add_child(status)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 6.0)
	bar.max_value = 1.0
	bar.step = 0.0
	row.add_child(bar)
	_task_rows[task] = {"status": status, "bar": bar}
	return row


func _task_button(text: String, tooltip_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.tooltip_text = tr(tooltip_key)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(34.0, 30.0)
	button.add_theme_constant_override("h_separation", 0)
	button.pressed.connect(action)
	return button


## Статус и прогресс каждой задачи: кто делает, кто нужен, на паузе ли.
func _refresh_task_rows() -> void:
	for task: GameTask in _task_rows:
		var widgets: Dictionary = _task_rows[task]
		(widgets["bar"] as ProgressBar).value = task.fraction()
		(widgets["status"] as Label).text = _task_status(task)


func _task_status(task: GameTask) -> String:
	var role_name := tr(TeamMember.ROLE_NAME_KEYS[task.role])
	var text := ""
	if task.paused:
		text = tr("TASK_PAUSED")
	elif not Game.has_role(task.role):
		text = tr(GameTask.NEEDS_KEYS[task.role])
	elif task.assignee != null:
		var working := false
		for figure in _figures:
			if figure.member == task.assignee:
				working = figure.state == CharacterFigure.State.WORKING
		text = tr("TASK_WORKING" if working else "TASK_ON_THE_WAY").format({"name": task.assignee.display_name})
	else:
		text = tr("TASK_WAITING")
	return "%s · %s" % [role_name, text]


func _build_speed_buttons() -> void:
	var group := ButtonGroup.new()
	for i in GameClock.SPEEDS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"ChipButton"
		if i != GameClock.SKIP:
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = SPEED_LABELS[i]
		button.custom_minimum_size = Vector2(44.0, 34.0)
		button.pressed.connect(set_speed.bind(i))
		_speed_row.add_child(button)
		_speed_buttons.append(button)
	_resume_speed = maxi(Game.clock.resume_speed, 1)
	_sync_speed_buttons()


func _sync_speed_buttons() -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == Game.clock.speed)


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
