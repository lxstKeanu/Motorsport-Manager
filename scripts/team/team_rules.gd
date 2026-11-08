class_name TeamRules
## Правила стартового состава: сколько основателей, какая сложность, что проверить перед началом.
## Функции возвращают ключи переводов, а не готовый текст.

const MAX_FOUNDERS := 4
## Сложность по числу основателей: в одиночку тяжелее всего (GDD 3.3).
const DIFFICULTY_KEYS: Array[String] = ["DIFFICULTY_1", "DIFFICULTY_2", "DIFFICULTY_3", "DIFFICULTY_4"]
const DIFFICULTY_HINT_KEYS: Array[String] = ["DIFFICULTY_1_HINT", "DIFFICULTY_2_HINT", "DIFFICULTY_3_HINT", "DIFFICULTY_4_HINT"]
## Где стоит отметка на шкале «легко — хардкор» (0 — легко, 1 — хардкор).
const DIFFICULTY_MARKS: Array[float] = [0.86, 0.64, 0.42, 0.2]


static func difficulty_index(founder_count: int) -> int:
	return clampi(founder_count, 1, MAX_FOUNDERS) - 1


static func difficulty_key(founder_count: int) -> String:
	return DIFFICULTY_KEYS[difficulty_index(founder_count)]


static func difficulty_hint_key(founder_count: int) -> String:
	return DIFFICULTY_HINT_KEYS[difficulty_index(founder_count)]


static func difficulty_mark(founder_count: int) -> float:
	return DIFFICULTY_MARKS[difficulty_index(founder_count)]


## Ошибки, из-за которых начать игру нельзя.
static func name_errors(members: Array[TeamMember]) -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	var has_duplicate := false
	for member in members:
		var key := member.display_name.strip_edges().to_lower()
		if key.is_empty():
			if not errors.has("TEAM_ERROR_NAME_EMPTY"):
				errors.append("TEAM_ERROR_NAME_EMPTY")
		elif seen.has(key):
			has_duplicate = true
		seen[key] = true
	if has_duplicate:
		errors.append("TEAM_ERROR_NAME_DUPLICATE")
	return errors


## Предупреждения о составе: начать можно, но первая цель — закрыть дыру (GDD 3.3).
static func role_warnings(members: Array[TeamMember]) -> Array[String]:
	var warnings: Array[String] = []
	if not _has_role(members, TeamMember.Role.MECHANIC):
		warnings.append("TEAM_WARN_NO_MECHANIC")
	if not _has_role(members, TeamMember.Role.DRIVER):
		warnings.append("TEAM_WARN_NO_DRIVER")
	return warnings


## Роль для нового основателя: первая, которой ещё нет в команде.
static func default_founder_role(members: Array[TeamMember]) -> TeamMember.Role:
	for role in TeamMember.ROLES:
		if not _has_role(members, role):
			return role
	return TeamMember.Role.MECHANIC


static func _has_role(members: Array[TeamMember], role: TeamMember.Role) -> bool:
	for member in members:
		if member.role == role:
			return true
	return false
