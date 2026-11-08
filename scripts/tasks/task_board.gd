class_name TaskBoard
extends Resource
## Очередь задач команды. Порядок в списке — приоритет: выше — раньше.
## Каждый берёт первую свободную задачу своей роли, не стоящую на паузе.

## Встроенный сигнал changed значит: состав или порядок задач изменился, кто-то взял или бросил задачу.
signal completed(task: GameTask)

@export var tasks: Array[GameTask] = []


func add(task: GameTask) -> void:
	tasks.append(task)
	changed.emit()


## Первая подходящая задача для человека. Он сразу становится исполнителем.
func take_for(member: TeamMember) -> GameTask:
	for task in tasks:
		if task.assignee == null and not task.paused and task.role == member.role:
			task.assignee = member
			changed.emit()
			return task
	return null


## Исполнитель бросает задачу (ушёл домой и т.п.). Сделанная часть остаётся.
func release(task: GameTask) -> void:
	if task.assignee == null:
		return
	task.assignee = null
	changed.emit()


## Добавляет сделанную работу. Возвращает true, если задача закончена и снята с доски.
func work(task: GameTask, minutes: float) -> bool:
	task.progress = minf(task.progress + minutes, task.work_minutes)
	if not task.is_done():
		return false
	tasks.erase(task)
	task.assignee = null
	completed.emit(task)
	changed.emit()
	return true


## Сдвигает задачу по очереди: -1 — выше, 1 — ниже.
func move(task: GameTask, offset: int) -> void:
	var index := tasks.find(task)
	var target := clampi(index + offset, 0, tasks.size() - 1)
	if index < 0 or target == index:
		return
	tasks.remove_at(index)
	tasks.insert(target, task)
	changed.emit()


## Задача на паузе никем не берётся, а тот, кто её делал, бросает её.
func set_paused(task: GameTask, value: bool) -> void:
	task.paused = value
	if value:
		task.assignee = null
	changed.emit()
