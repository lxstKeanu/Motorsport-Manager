extends Control
## Фон меню: чертёж старого седана на миллиметровке.
## Рисуется кодом: не зависит от разрешения, а подписи переводятся вместе с игрой.

const BG := Color(0.047, 0.055, 0.067)
const GRID_MINOR := Color(0.42, 0.55, 0.72, 0.05)
const GRID_MAJOR := Color(0.42, 0.55, 0.72, 0.11)
const INK := Color(0.94, 0.54, 0.14, 0.9)
const INK_DIM := Color(0.94, 0.54, 0.14, 0.3)
const NOTE := Color(0.62, 0.68, 0.78, 0.8)
const NOTE_DIM := Color(0.62, 0.68, 0.78, 0.35)
const NOTE_SIZE := 13

const MINOR_STEP := 24.0
const MAJOR_EVERY := 5
## Медленный дрейф сетки, пикселей в секунду.
const DRIFT := Vector2(5.0, 2.5)

## Габариты седана в чертёжных единицах (1 ед. = 10 мм).
const HALF_LENGTH := 224.0
const HALF_WIDTH := 90.0
const AXLE_X := 148.0

## Центр машины в долях экрана.
@export var car_center := Vector2(0.67, 0.5)
## Масштаб машины для экрана 1600×900.
@export var car_scale := 1.45
## Ширина затемнения слева в долях экрана, чтобы читалось меню. 0 — без затемнения.
@export_range(0.0, 1.0) var left_shade := 0.55
@export var animate := true

var _time := 0.0
var _origin := Vector2.ZERO
var _k := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if animate:
		_time += delta
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_grid()
	_k = minf(size.x / 1600.0, size.y / 900.0) * car_scale
	_origin = size * car_center
	_draw_construction_lines()
	_draw_car()
	_draw_dimensions()
	_draw_callout(Vector2(150.0, -24.0), Vector2(204.0, -178.0), tr("BP_ENGINE"))
	_draw_callout(Vector2(AXLE_X, 86.0), Vector2(214.0, 182.0), tr("BP_BRAKES"))
	_draw_title_block()
	if left_shade > 0.0:
		_draw_left_shade()


func _draw_grid() -> void:
	var period := MINOR_STEP * MAJOR_EVERY
	var shift := Vector2(fposmod(_time * DRIFT.x, period), fposmod(_time * DRIFT.y, period))
	var i := 0
	var x := shift.x - period
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_MAJOR if i % MAJOR_EVERY == 0 else GRID_MINOR)
		x += MINOR_STEP
		i += 1
	i = 0
	var y := shift.y - period
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_MAJOR if i % MAJOR_EVERY == 0 else GRID_MINOR)
		y += MINOR_STEP
		i += 1


func _draw_construction_lines() -> void:
	draw_dashed_line(_p(Vector2(-HALF_LENGTH - 50.0, 0.0)), _p(Vector2(HALF_LENGTH + 50.0, 0.0)), INK_DIM, 1.0, 10.0)
	for axle: float in [-AXLE_X, AXLE_X]:
		draw_dashed_line(_p(Vector2(axle, -HALF_WIDTH - 28.0)), _p(Vector2(axle, HALF_WIDTH + 28.0)), INK_DIM, 1.0, 6.0)


func _draw_car() -> void:
	# Колёса под кузовом, поэтому бледные.
	for axle: float in [-AXLE_X, AXLE_X]:
		for side: float in [-1.0, 1.0]:
			_outline(_rect_points(axle - 30.0, side * 76.0, axle + 30.0, side * 98.0), INK_DIM)
	# Кузов и линия бортов.
	_outline(_rounded_rect_points(-HALF_LENGTH, -HALF_WIDTH, HALF_LENGTH, HALF_WIDTH, 30.0), INK, 2.0)
	_outline(_rounded_rect_points(-HALF_LENGTH + 12.0, -HALF_WIDTH + 10.0, HALF_LENGTH - 12.0, HALF_WIDTH - 10.0, 22.0), INK_DIM)
	# Лобовое стекло, крыша, заднее стекло.
	_outline([Vector2(88, -76), Vector2(94, 0), Vector2(88, 76), Vector2(34, 70), Vector2(30, 0), Vector2(34, -70)], INK, 1.5)
	_outline(_rounded_rect_points(-98.0, -70.0, 34.0, 70.0, 10.0), INK, 1.5)
	_outline([Vector2(-98, -70), Vector2(-102, 0), Vector2(-98, 70), Vector2(-142, 76), Vector2(-148, 0), Vector2(-142, -76)], INK, 1.5)
	# Капот и крышка багажника.
	_outline([Vector2(104, -44), Vector2(206, -40)], INK_DIM, 1.0, false)
	_outline([Vector2(104, 44), Vector2(206, 40)], INK_DIM, 1.0, false)
	_outline([Vector2(-162, -80), Vector2(-168, 0), Vector2(-162, 80)], INK_DIM, 1.0, false)
	# Зеркала, фары, фонари.
	for side: float in [-1.0, 1.0]:
		_outline([Vector2(40, side * 90), Vector2(54, side * 90), Vector2(51, side * 104), Vector2(42, side * 104)], INK, 1.5)
		_outline(_rect_points(208.0, side * 50.0, 218.0, side * 76.0), INK, 1.5)
		_outline(_rect_points(-218.0, side * 54.0, -210.0, side * 78.0), INK, 1.5)


func _draw_dimensions() -> void:
	# Габаритная длина — снизу.
	var y_length := HALF_WIDTH + 42.0
	for x: float in [-HALF_LENGTH, HALF_LENGTH]:
		draw_line(_p(Vector2(x, HALF_WIDTH + 8.0)), _p(Vector2(x, y_length)) + Vector2(0, 8), NOTE_DIM)
	_dimension_line(_p(Vector2(-HALF_LENGTH, y_length)), _p(Vector2(HALF_LENGTH, y_length)), "4 480")
	# Колёсная база — сверху.
	var y_base := -HALF_WIDTH - 42.0
	for x: float in [-AXLE_X, AXLE_X]:
		draw_line(_p(Vector2(x, -HALF_WIDTH - 30.0)), _p(Vector2(x, y_base)) - Vector2(0, 8), NOTE_DIM)
	_dimension_line(_p(Vector2(-AXLE_X, y_base)), _p(Vector2(AXLE_X, y_base)), "2 960")
	# Ширина — справа.
	var x_width := HALF_LENGTH + 46.0
	for y: float in [-HALF_WIDTH, HALF_WIDTH]:
		draw_line(_p(Vector2(HALF_LENGTH + 8.0, y)), _p(Vector2(x_width, y)) + Vector2(8, 0), NOTE_DIM)
	_dimension_line(_p(Vector2(x_width, -HALF_WIDTH)), _p(Vector2(x_width, HALF_WIDTH)), "1 800")


func _dimension_line(from: Vector2, to: Vector2, text: String) -> void:
	draw_line(from, to, NOTE, 1.0, true)
	for tip: Vector2 in [from, to]:
		draw_line(tip + Vector2(-4, 4), tip + Vector2(4, -4), NOTE, 1.5, true)
	var middle := (from + to) * 0.5
	if is_equal_approx(from.x, to.x):
		_text(middle + Vector2(10, 5), text, NOTE_SIZE, NOTE, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		_text(middle + Vector2(0, -7), text, NOTE_SIZE, NOTE, HORIZONTAL_ALIGNMENT_CENTER)


## Выноска: точка на детали, ломаная линия и подпись над полкой.
func _draw_callout(target: Vector2, elbow: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	var start := _p(target)
	var bend := _p(elbow)
	var shelf := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE).x + 16.0
	draw_circle(start, 3.0, INK)
	draw_polyline(PackedVector2Array([start, bend, bend + Vector2(shelf, 0)]), NOTE, 1.0, true)
	_text(bend + Vector2(8, -7), text, NOTE_SIZE, NOTE, HORIZONTAL_ALIGNMENT_LEFT)


## Штамп чертежа в правом нижнем углу.
func _draw_title_block() -> void:
	var heading_font := get_theme_font("font", "HeaderLabel")
	var block := Rect2(size.x - 352.0, size.y - 156.0, 320.0, 84.0)
	draw_rect(block, Color(BG, 0.9))
	draw_rect(block, NOTE_DIM, false, 1.0)
	draw_line(block.position + Vector2(0, 36), block.position + Vector2(block.size.x, 36), NOTE_DIM)
	_text(block.position + Vector2(14, 27), tr("BP_TITLE"), 20, INK, HORIZONTAL_ALIGNMENT_LEFT, heading_font)
	_text(block.position + Vector2(14, 57), tr("BP_STATUS"), 12, NOTE, HORIZONTAL_ALIGNMENT_LEFT)
	_text(block.position + Vector2(14, 75), tr("BP_SHEET"), 12, NOTE_DIM, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_left_shade() -> void:
	var solid_width := size.x * left_shade * 0.5
	var fade_end := size.x * left_shade
	var solid := Color(BG, 0.96)
	var clear := Color(BG, 0.0)
	draw_rect(Rect2(0.0, 0.0, solid_width, size.y), solid)
	draw_polygon(
		PackedVector2Array([Vector2(solid_width, 0.0), Vector2(fade_end, 0.0), Vector2(fade_end, size.y), Vector2(solid_width, size.y)]),
		PackedColorArray([solid, clear, clear, solid]))


func _text(pos: Vector2, text: String, font_size: int, color: Color, align: HorizontalAlignment, font: Font = null) -> void:
	if font == null:
		font = get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	draw_string(font, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Переводит точку чертежа в экранные координаты.
func _p(local: Vector2) -> Vector2:
	return _origin + local * _k


func _outline(points: Array, color: Color, width: float = 1.0, closed: bool = true) -> void:
	var screen := PackedVector2Array()
	for point: Vector2 in points:
		screen.append(_p(point))
	if closed and not screen.is_empty():
		screen.append(screen[0])
	draw_polyline(screen, color, width, true)


func _rect_points(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


func _rounded_rect_points(x0: float, y0: float, x1: float, y1: float, radius: float, segments: int = 6) -> Array:
	var points := []
	var corners := [
		[Vector2(x1 - radius, y0 + radius), -PI / 2.0],
		[Vector2(x1 - radius, y1 - radius), 0.0],
		[Vector2(x0 + radius, y1 - radius), PI / 2.0],
		[Vector2(x0 + radius, y0 + radius), PI],
	]
	for corner: Array in corners:
		var center: Vector2 = corner[0]
		var start_angle: float = corner[1]
		for i in segments + 1:
			var angle := start_angle + PI / 2.0 * float(i) / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
