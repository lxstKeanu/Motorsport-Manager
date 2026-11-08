class_name GameClock
extends Resource
## Игровое время и распорядок команды (GDD 4).
## Время хранится в минутах от начала игры. День 0 — понедельник первой недели.

## Время прошло: от from до to минут. Подписчики сами смотрят, что попало в этот отрезок.
signal passed(from: float, to: float)
## Перемотка дошла до утра, скорость вернулась к прежней.
signal skip_finished

enum Phase { SLEEP, DAY_JOB, HOME, GARAGE }

const MINUTES_PER_DAY := 1440
const DAYS_PER_WEEK := 7
const WORKDAYS := 5
const FRIDAY := 4
const WAKE_UP := 8 * 60
## Зарплаты приходят в пятницу вечером.
const PAYDAY_MINUTE := 18 * 60
const WEEKEND_GARAGE_START := 10 * 60
## После работы основатели сидят в гараже до полуночи.
const BEDTIME := 24 * 60
## Начало игры: понедельник, 18:00 — вечер после работы.
const START_MINUTE := 18 * 60

## Скорости: пауза, ×1, ×5, ×20 и перемотка до утра. Множители к базовой.
const SPEEDS: Array[float] = [0.0, 1.0, 5.0, 20.0, 120.0]
const SKIP := 4
## Игровых минут в секунду на скорости ×1: час идёт 10 секунд.
const MINUTES_PER_SECOND := 6.0
## Ночью все спят, поэтому время идёт быстрее, чтобы не ждать утра.
const NIGHT_MULTIPLIER := 4.0

## Сверхурочные: команда остаётся в гараже до 02:00.
const OVERTIME_END := 2 * 60
const DAYS_PER_YEAR := 365
const MONTH_DAYS: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

const WEEKDAY_KEYS: Array[String] = ["DAY_MON", "DAY_TUE", "DAY_WED", "DAY_THU", "DAY_FRI", "DAY_SAT", "DAY_SUN"]
const MONTH_KEYS: Array[String] = [
	"MONTH_JAN", "MONTH_FEB", "MONTH_MAR", "MONTH_APR", "MONTH_MAY", "MONTH_JUN",
	"MONTH_JUL", "MONTH_AUG", "MONTH_SEP", "MONTH_OCT", "MONTH_NOV", "MONTH_DEC",
]

@export var minutes := float(START_MINUTE)
## Сверхурочные включены: гараж открыт до 02:00.
@export var overtime := false
## Номер скорости в SPEEDS: 0 — пауза, SKIP — перемотка.
@export var speed := 1
## До какой минуты идёт перемотка и к какой скорости потом вернуться.
@export var skip_until := -1.0
@export var resume_speed := 1


## Перемотка до ближайших 8:00. Пока она идёт, всё живёт как обычно, только очень быстро.
func skip_to_morning() -> void:
	var today_wake := float(day() * MINUTES_PER_DAY + WAKE_UP)
	skip_until = today_wake if today_wake > minutes else today_wake + MINUTES_PER_DAY
	if speed != SKIP and speed > 0:
		resume_speed = speed
	speed = SKIP


## Продвигает время на real_seconds реальных секунд с учётом скорости и ночного ускорения.
func advance(real_seconds: float) -> void:
	if speed <= 0 or real_seconds <= 0.0:
		return
	var rate := MINUTES_PER_SECOND * SPEEDS[speed]
	if is_night(minutes, overtime):
		rate *= NIGHT_MULTIPLIER
	var amount := real_seconds * rate
	if speed == SKIP:
		amount = minf(amount, skip_until - minutes)
	advance_minutes(amount)
	if speed == SKIP and minutes >= skip_until:
		speed = resume_speed
		skip_until = -1.0
		skip_finished.emit()


## Продвигает время на игровые минуты. Удобно для тестов и перемоток.
func advance_minutes(amount: float) -> void:
	if amount <= 0.0:
		return
	var from := minutes
	minutes += amount
	passed.emit(from, minutes)


func day() -> int:
	return int(minutes) / MINUTES_PER_DAY


## День недели: 0 — понедельник, 6 — воскресенье.
func weekday() -> int:
	return weekday_of(minutes)


func minute_of_day() -> int:
	return int(minutes) % MINUTES_PER_DAY


func time_text() -> String:
	var minute := minute_of_day()
	return "%02d:%02d" % [minute / 60, minute % 60]


func weekday_name() -> String:
	return tr(WEEKDAY_KEYS[weekday()])


func is_weekend() -> bool:
	return weekday() >= WORKDAYS


## Календарная дата: «Пн 1 янв». Игра начинается в понедельник, 1 января первого года.
func date_text() -> String:
	var date := date_of(minutes)
	return "%s %d %s" % [weekday_name(), date.y, tr(MONTH_KEYS[date.x])]


## Год игры, с первого.
func year() -> int:
	return day() / DAYS_PER_YEAR + 1


## Месяц (0–11) и число (с 1) для момента времени. В году 365 дней.
static func date_of(at_minutes: float) -> Vector2i:
	var day_of_year := (int(at_minutes) / MINUTES_PER_DAY) % DAYS_PER_YEAR
	var month := 0
	while day_of_year >= MONTH_DAYS[month]:
		day_of_year -= MONTH_DAYS[month]
		month += 1
	return Vector2i(month, day_of_year + 1)


static func weekday_of(at_minutes: float) -> int:
	return (int(at_minutes) / MINUTES_PER_DAY) % DAYS_PER_WEEK


## Ночь — время сна. Со сверхурочными команда сидит в гараже до 02:00, и ночь начинается позже.
static func is_night(at_minutes: float, with_overtime: bool = false) -> bool:
	var minute := int(at_minutes) % MINUTES_PER_DAY
	if with_overtime:
		return minute >= OVERTIME_END and minute < WAKE_UP
	return minute < WAKE_UP or minute >= BEDTIME


## Во сколько гараж закрывается на ночь.
func closing_minute() -> int:
	return OVERTIME_END if overtime else BEDTIME


## Где человек в это время. В будни: до работы дома, потом на работе, после неё в гараже.
## В выходные в гараже с 10:00. Без основной работы — в гараже с подъёма до отбоя каждый день.
## Со сверхурочными ночные часы до 02:00 — продолжение вечера в гараже.
static func phase_at(at_minutes: float, has_day_job: bool, job_start: int = WAKE_UP, job_end: int = PAYDAY_MINUTE, with_overtime: bool = false) -> Phase:
	if is_night(at_minutes, with_overtime):
		return Phase.SLEEP
	var minute := int(at_minutes) % MINUTES_PER_DAY
	if not has_day_job or minute < WAKE_UP:
		return Phase.GARAGE
	if weekday_of(at_minutes) < WORKDAYS:
		if minute < job_start:
			return Phase.HOME
		return Phase.DAY_JOB if minute < job_end else Phase.GARAGE
	return Phase.HOME if minute < WEEKEND_GARAGE_START else Phase.GARAGE


## Ключ общей строки о времени суток. Подробности по каждому — в списке основателей.
func team_phase_key() -> String:
	var minute := minute_of_day()
	if is_night(minutes, overtime):
		return "PHASE_SLEEP"
	if is_weekend():
		return "PHASE_WEEKEND_MORNING" if minute < WEEKEND_GARAGE_START else "PHASE_WEEKEND_GARAGE"
	return "PHASE_DAY_JOB" if minute < PAYDAY_MINUTE else "PHASE_EVENING_GARAGE"


## Сколько раз в отрезок (from, to] наступило время minute_of_day в день недели weekday.
static func occurrences(from: float, to: float, on_weekday: int, at_minute: int) -> Array[float]:
	var result: Array[float] = []
	var first_day := int(floorf(from / MINUTES_PER_DAY))
	var last_day := int(floorf(to / MINUTES_PER_DAY))
	for day_index in range(first_day, last_day + 1):
		if day_index % DAYS_PER_WEEK != on_weekday:
			continue
		var moment := float(day_index * MINUTES_PER_DAY + at_minute)
		if moment > from and moment <= to:
			result.append(moment)
	return result
