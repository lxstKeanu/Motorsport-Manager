class_name GameTask
extends Resource
## Задача в очереди (GDD 6): какая роль её делает, где и сколько работы в игровых минутах.
## Исполнителя игрок не назначает: персонажи сами берут задачи своей роли по порядку очереди.

## Ключи «Нужен механик» и т.п. — когда в команде нет никого с нужной ролью.
const NEEDS_KEYS := {
	TeamMember.Role.DRIVER: "TASK_NEEDS_DRIVER",
	TeamMember.Role.MECHANIC: "TASK_NEEDS_MECHANIC",
	TeamMember.Role.DESIGNER: "TASK_NEEDS_DESIGNER",
	TeamMember.Role.EXECUTIVE: "TASK_NEEDS_EXECUTIVE",
}

@export var title_key := ""
@export var role := TeamMember.Role.MECHANIC
## Клетка, где делается работа.
@export var cell := Vector2i.ZERO
@export var work_minutes := 60.0
@export var progress := 0.0
@export var paused := false
## Кто сейчас делает. Не сохраняется: после загрузки задачи разберут заново.
var assignee: TeamMember


static func create(key: String, task_role: TeamMember.Role, at_cell: Vector2i, minutes: float) -> GameTask:
	var task := GameTask.new()
	task.title_key = key
	task.role = task_role
	task.cell = at_cell
	task.work_minutes = minutes
	return task


func fraction() -> float:
	return clampf(progress / work_minutes, 0.0, 1.0) if work_minutes > 0.0 else 1.0


func is_done() -> bool:
	return progress >= work_minutes
