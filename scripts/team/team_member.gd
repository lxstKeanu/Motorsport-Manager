class_name TeamMember
extends Resource
## Основатель команды, созданный игроком (GDD 3). Первый основатель — сам игрок.
## В команде работает бесплатно, а деньги приносит основная работа: доход раз в неделю,
## в гараж — после работы. Каждый делает только дело своей роли (GDD 5.1).

enum Role { DRIVER, MECHANIC, DESIGNER, EXECUTIVE }

const ROLES: Array[Role] = [Role.DRIVER, Role.MECHANIC, Role.DESIGNER, Role.EXECUTIVE]
const ROLE_NAME_KEYS := {
	Role.DRIVER: "ROLE_DRIVER",
	Role.MECHANIC: "ROLE_MECHANIC",
	Role.DESIGNER: "ROLE_DESIGNER",
	Role.EXECUTIVE: "ROLE_EXECUTIVE",
}
const ROLE_HINT_KEYS := {
	Role.DRIVER: "ROLE_DRIVER_HINT",
	Role.MECHANIC: "ROLE_MECHANIC_HINT",
	Role.DESIGNER: "ROLE_DESIGNER_HINT",
	Role.EXECUTIVE: "ROLE_EXECUTIVE_HINT",
}
## Часы основной работы по ролям, в минутах от полуночи, пн–пт. Предварительные.
const JOB_HOURS := {
	Role.DRIVER: Vector2i(9 * 60, 18 * 60),
	Role.MECHANIC: Vector2i(8 * 60, 20 * 60),
	Role.DESIGNER: Vector2i(9 * 60, 18 * 60),
	Role.EXECUTIVE: Vector2i(8 * 60, 19 * 60),
}
const NAME_MAX_LENGTH := 20
const AGE_MIN := 18
const AGE_MAX := 65
## Лучшие годы: моложе навык ещё не дорос до потенциала, старше — понемногу уходит.
const PRIME_AGE := Vector2i(28, 40)
const SKILL_LOSS_PER_YEAR := 2
const POTENTIAL_RANGE := Vector2i(70, 95)
## Доход с основной работы в неделю: база плюс за каждый пункт навыка, округляется до $10.
const INCOME_BASE := 400
const INCOME_PER_SKILL := 4

## Имя, которое ввёл игрок. В текстах событий подставляется вместо {name}.
@export var display_name := ""
@export var role := Role.MECHANIC
@export var is_hero := false
@export var appearance: Appearance
@export var age := 30
## Потолок навыка (1–100). Навык сейчас считается из потенциала и возраста.
@export var potential := 80
## Днём в будни на основной работе, в гараж приходит после неё (GDD 4).
@export var has_day_job := true


static func create(hero: bool, start_role: Role) -> TeamMember:
	var member := TeamMember.new()
	member.is_hero = hero
	member.role = start_role
	member.shuffle()
	return member


## Случайные внешность, возраст и потенциал — кнопка «Случайно» на экране создания.
func shuffle(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	appearance = Appearance.random(rng)
	age = rng.randi_range(22, 45)
	potential = rng.randi_range(POTENTIAL_RANGE.x, POTENTIAL_RANGE.y)


func skill() -> int:
	var years_off := maxi(0, PRIME_AGE.x - age) + maxi(0, age - PRIME_AGE.y)
	return clampi(potential - years_off * SKILL_LOSS_PER_YEAR, 1, 100)


func weekly_income() -> int:
	return int(snappedf(INCOME_BASE + skill() * INCOME_PER_SKILL, 10.0))


func job_start() -> int:
	return JOB_HOURS[role].x


func job_end() -> int:
	return JOB_HOURS[role].y


## Где человек в это время: на работе, дома, в гараже или спит.
## Со сверхурочными команда сидит в гараже до 02:00.
func phase_at(at_minutes: float, with_overtime: bool = false) -> GameClock.Phase:
	return GameClock.phase_at(at_minutes, has_day_job, job_start(), job_end(), with_overtime)


func role_name() -> String:
	return tr(ROLE_NAME_KEYS[role])
