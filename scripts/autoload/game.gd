extends Node
## Текущая игра: команда, деньги, участок с гаражом и время. Сохранение и загрузка появятся на этапе 10.

signal money_changed
## Пришли зарплаты основателей с основной работы: общая сумма за неделю.
signal salary_paid(amount: int)
## Кто-то из команды ушёл с основной работы.
signal day_job_quit(member: TeamMember)
## На участке что-то поменялось (убрали хлам и т.п.): карту нужно перерисовать.
signal garage_changed

## Стартовые деньги (GDD 3.4). Баланс подберём позже.
const STARTING_MONEY := 5000
## Сколько игровых минут занимает уборка одной кучи.
const JUNK_MINUTES := 90.0
const DEBRIS_MINUTES := 120.0

var team: Array[TeamMember] = []
## Название, эмблема и цвет команды: задаются в мастере новой игры (см. TeamStyle).
var team_name := ""
var team_emblem := 0
var team_color := 0
var money := 0
var garage: GarageLayout
var clock: GameClock
var tasks: TaskBoard
## Панель «С чего начать» скрыта игроком.
var objectives_hidden := false
## Случайности игры. Тесты задают ему зерно.
var rng := RandomNumberGenerator.new()


## Начинает новую игру с командой, собранной на экране создания.
## Берёт копии, чтобы дальнейшие правки на экране не меняли команду.
func start_new_game(members: Array[TeamMember], new_team_name: String = "", emblem: int = 0, color: int = 0) -> void:
	team_name = new_team_name.strip_edges()
	team_emblem = emblem
	team_color = color
	objectives_hidden = false
	team.clear()
	for member in members:
		var copy: TeamMember = member.duplicate(true)
		copy.display_name = copy.display_name.strip_edges()
		team.append(copy)
	money = STARTING_MONEY
	garage = GarageLayout.create_starting()
	clock = GameClock.new()
	clock.passed.connect(_on_time_passed)
	rng.randomize()
	# Первые задачи: в боксе хлам, во дворе завалы. Пока это ручная работа механика.
	tasks = TaskBoard.new()
	for cell in garage.junk:
		tasks.add(GameTask.create("TASK_CLEAR_JUNK", TeamMember.Role.MECHANIC, cell, JUNK_MINUTES))
	for cell in garage.debris:
		tasks.add(GameTask.create("TASK_CLEAR_YARD", TeamMember.Role.MECHANIC, cell, DEBRIS_MINUTES))
	tasks.completed.connect(_on_task_completed)
	money_changed.emit()


## Название команды для показа. Если его не задали, по имени первого основателя.
func display_team_name() -> String:
	if not team_name.is_empty():
		return team_name
	var hero := get_hero()
	return tr("TEAM_DEFAULT_NAME").format({"name": hero.display_name}) if hero != null else tr("GAME_TITLE")


## Первые цели для панели «С чего начать»: ключ текста и выполнена ли.
## Ремонт седана и запись в серию появятся на этапах 5 и 8, пока они не выполняются.
func objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"key": "OBJ_CLEAR_JUNK", "done": garage.junk.is_empty()},
		{"key": "OBJ_CLEAR_YARD", "done": garage.debris.is_empty()},
		{"key": "OBJ_FIX_SEDAN", "done": false},
		{"key": "OBJ_ENTER_SERIES", "done": false},
	]
	return result


func has_role(role: TeamMember.Role) -> bool:
	for member in team:
		if member.role == role:
			return true
	return false


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit()


## Уход с основной работы — решение игрока, обратно не вернуться (GDD 4.1).
func quit_day_job(member: TeamMember) -> void:
	if member == null or not member.has_day_job:
		return
	member.has_day_job = false
	day_job_quit.emit(member)


## Кто из команды сейчас в гараже.
func members_in_garage() -> Array[TeamMember]:
	var result: Array[TeamMember] = []
	for member in team:
		if member.phase_at(clock.minutes, clock.overtime) == GameClock.Phase.GARAGE:
			result.append(member)
	return result


## Сколько в неделю приносят основные работы основателей.
func weekly_income() -> int:
	var total := 0
	for member in team:
		if member.has_day_job:
			total += member.weekly_income()
	return total


## Убранная куча исчезает с участка.
func _on_task_completed(task: GameTask) -> void:
	if task.title_key == "TASK_CLEAR_JUNK":
		garage.junk.erase(task.cell)
	elif task.title_key == "TASK_CLEAR_YARD":
		garage.debris.erase(task.cell)
	garage_changed.emit()


## В пятницу вечером каждый основатель с основной работой приносит свой недельный доход (GDD 4.1).
func _on_time_passed(from: float, to: float) -> void:
	for _payday in GameClock.occurrences(from, to, GameClock.FRIDAY, GameClock.PAYDAY_MINUTE):
		var total := weekly_income()
		if total > 0:
			add_money(total)
			salary_paid.emit(total)


func get_hero() -> TeamMember:
	for member in team:
		if member.is_hero:
			return member
	return null


## Сумма с разделением разрядов: $5,000 по-английски, $5 000 по-русски.
## Значок валюты — из настроек; рубль пишется после числа: 5 000 ₽.
func format_money(amount: int) -> String:
	var digits := str(absi(amount))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(-3)
	groups.push_front(digits)
	# По-русски разряды делит неразрывный пробел, чтобы сумма не переносилась.
	var separator := " " if Settings.language == "ru" else ","
	var sign := "-" if amount < 0 else ""
	if Settings.currency == "rub":
		return "%s%s %s" % [sign, separator.join(groups), Settings.currency_symbol()]
	return "%s%s%s" % [sign, Settings.currency_symbol(), separator.join(groups)]
