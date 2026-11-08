class_name CharacterFigure
extends Node2D
## Персонаж на участке (GDD 6). Приходит и уходит по распорядку, сам берёт из очереди задачи
## своей роли, идёт к ним по клеткам и работает. Без задачи бродит по своей территории.
## Рисуется заглушкой в 2.5D: ноги, туловище в цвет одежды, голова, причёска, имя над головой.

signal task_finished(member: TeamMember, task: GameTask)

enum State { AWAY, IDLE, WALKING, WORKING, LEAVING }

## Скорость ходьбы на ×1, клеток (метров) в реальную секунду. На других скоростях — пропорционально.
const WALK_SPEED := 3.0
## Сколько реальных секунд (на ×1) бездельник стоит, прежде чем пройтись.
const IDLE_PAUSE := Vector2(2.0, 6.0)
## Если до задачи не дойти, она бросается, и новую человек ищет не сразу.
const RETRY_DELAY := 3.0

const PANTS := Color(0.2, 0.22, 0.27)
const OUTLINE := Color(0.05, 0.05, 0.06, 0.9)
const BAR_BACK := Color(0, 0, 0, 0.6)
const BAR_FILL := Color(0.941, 0.541, 0.141)

var member: TeamMember
var state := State.AWAY
var task: GameTask
## Где стоит человек, в клетках (дробно): центр клетки — x.5.
var cell_position := Vector2.ZERO

var _path := PackedVector2Array()
var _nav: GarageNav
var _layout: GarageLayout
var _board: TaskBoard
var _rng := RandomNumberGenerator.new()
var _idle_timer := 0.0
var _walk_phase := 0.0


func setup(team_member: TeamMember, nav: GarageNav, layout: GarageLayout, board: TaskBoard) -> void:
	member = team_member
	_nav = nav
	_layout = layout
	_board = board
	_rng.seed = hash(member.display_name)
	visible = false


## Один шаг жизни: walk_delta — реальные секунды с учётом скорости игры (для ходьбы),
## minutes — сколько игровых минут прошло (для работы), now — текущее игровое время.
func step(walk_delta: float, minutes: float, now: float) -> void:
	var should_be_here := member.phase_at(now, Game.clock.overtime) == GameClock.Phase.GARAGE
	if state == State.AWAY:
		if not should_be_here:
			return
		_arrive()
	elif not should_be_here and state != State.LEAVING:
		_leave()

	# Задачу поставили на паузу или убрали: бросаем её.
	if task != null and task.assignee != member:
		task = null
		if state != State.LEAVING:
			_path.clear()
			state = State.IDLE

	if not _path.is_empty():
		_follow_path(walk_delta * WALK_SPEED)
		queue_redraw()
		if not _path.is_empty():
			return
		if state == State.LEAVING:
			_go_away()
			return
		state = State.WORKING if task != null else State.IDLE

	match state:
		State.IDLE:
			_idle(walk_delta)
		State.WORKING:
			if minutes > 0.0:
				queue_redraw()
				if _board.work(task, minutes):
					var done := task
					task = null
					state = State.IDLE
					task_finished.emit(member, done)


func _idle(walk_delta: float) -> void:
	_idle_timer -= walk_delta
	if _idle_timer > 0.0:
		return
	task = _board.take_for(member)
	if task != null:
		_path = _nav.find_path(cell_position, task.cell)
		if not _path.is_empty():
			state = State.WALKING
		elif cell_position.distance_to(Vector2(task.cell) + Vector2(0.5, 0.5)) <= 1.5:
			state = State.WORKING
		else:
			_board.release(task)
			task = null
			_idle_timer = RETRY_DELAY
		return
	# Делать нечего: пройтись по своей части участка.
	_idle_timer = _rng.randf_range(IDLE_PAUSE.x, IDLE_PAUSE.y)
	var areas := _areas_here()
	if areas.is_empty():
		return
	var target := _nav.random_walkable_in(areas, _rng)
	if target != Vector2i(-1, -1):
		_path = _nav.find_path(cell_position, target)


## Своя часть участка, где человек сейчас стоит, чтобы не бродить из бокса во двор и обратно.
## Кто стоит вне своей территории (только пришёл), идёт в бокс с машиной.
func _areas_here() -> Array[Rect2i]:
	var here := Vector2i(cell_position.floor())
	var result: Array[Rect2i] = []
	for area in _layout.owned_areas():
		if area.has_point(here):
			result.append(area.grow(-1))
			return result
	var garage := _layout.parcel_at(Vector2i(_layout.parking_spot.floor()))
	if garage != null:
		result.append(garage.rect.grow(-1))
	return result


func _arrive() -> void:
	cell_position = Vector2(_layout.entry) + Vector2(0.5, 0.5)
	position = cell_position * GarageMap.CELL_SIZE
	state = State.IDLE
	_idle_timer = 0.0
	visible = true


func _leave() -> void:
	if task != null:
		_board.release(task)
		task = null
	state = State.LEAVING
	_path = _nav.find_path(cell_position, _layout.entry)
	if _path.is_empty():
		_go_away()


func _go_away() -> void:
	state = State.AWAY
	_path.clear()
	visible = false


func _follow_path(distance: float) -> void:
	_walk_phase += distance * 4.0
	while distance > 0.0 and not _path.is_empty():
		var next := _path[0]
		var gap := cell_position.distance_to(next)
		if gap <= distance:
			cell_position = next
			_path.remove_at(0)
			distance -= gap
		else:
			cell_position += (next - cell_position) / gap * distance
			distance = 0.0
	position = cell_position * GarageMap.CELL_SIZE


func _draw() -> void:
	if member == null:
		return
	var unit := GarageMap.CELL_SIZE
	var look := member.appearance if member.appearance != null else Appearance.new()
	var bob := Vector2(0.0, -absf(sin(_walk_phase)) * 2.0) if state == State.WALKING or state == State.LEAVING else Vector2.ZERO

	_ellipse(Vector2.ZERO, Vector2(0.26, 0.12) * unit, Color(0, 0, 0, 0.3))
	var hip := GarageMap.raise(0.85) + bob
	var shoulder := GarageMap.raise(1.5) + bob
	var head := GarageMap.raise(1.75) + bob
	if look.hair_style == Appearance.HairStyle.LONG:
		draw_rect(Rect2(head + Vector2(-0.17, 0.0) * unit, Vector2(0.34 * unit, shoulder.y - head.y + 6.0)), look.hair_tint())
	draw_rect(Rect2(Vector2(-0.15 * unit, hip.y), Vector2(0.3 * unit, -hip.y + bob.y)), PANTS)
	draw_rect(Rect2(Vector2(-0.22 * unit, shoulder.y), Vector2(0.44 * unit, hip.y - shoulder.y)), look.shirt_color())
	draw_circle(head, 0.17 * unit, look.skin_color())
	_draw_hair(head, look)
	draw_circle(head, 0.17 * unit, OUTLINE, false, 1.0)

	var font := ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	var name_base := head + Vector2(0.0, -0.3 * unit)
	var width := font.get_string_size(member.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, name_base - Vector2(width * 0.5, 0.0), member.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, OUTLINE)
	draw_string(font, name_base - Vector2(width * 0.5, 0.0), member.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if state == State.WORKING and task != null:
		var bar := Rect2(name_base + Vector2(-0.45 * unit, -0.55 * unit), Vector2(0.9 * unit, 5.0))
		draw_rect(bar, BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * task.fraction(), bar.size.y)), BAR_FILL)


func _draw_hair(head: Vector2, look: Appearance) -> void:
	var unit := GarageMap.CELL_SIZE
	match look.hair_style:
		Appearance.HairStyle.SHORT, Appearance.HairStyle.LONG:
			_half_circle(head, 0.18 * unit, look.hair_tint())
		Appearance.HairStyle.CURLY:
			_half_circle(head, 0.18 * unit, look.hair_tint())
			for offset: Vector2 in [Vector2(-0.14, -0.08), Vector2(0.0, -0.15), Vector2(0.14, -0.08)]:
				draw_circle(head + offset * unit, 0.08 * unit, look.hair_tint())
		Appearance.HairStyle.CAP:
			_half_circle(head, 0.19 * unit, look.shirt_color())
			draw_rect(Rect2(head + Vector2(-0.2, -0.02) * unit, Vector2(0.4, 0.05) * unit), look.shirt_color().darkened(0.3))


func _half_circle(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * i / 12.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
