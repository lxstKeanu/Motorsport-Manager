class_name SedanTop
extends Node2D
## Старый седан в 2.5D, заглушка: рыжая краска, багажник в грунте, пятно ржавчины на капоте.
## Рисуется в метрах, нос смотрит вниз, к воротам. Размеры как на чертеже в меню: 4,48 × 1,8 м.
## Высота сдвигает картинку вверх так же, как у стен (GarageMap.lift).

const HALF_LENGTH := 2.24
const HALF_WIDTH := 0.9
const AXLE := 1.48
## Высота верха кузова и крыши, в метрах.
const BODY_HEIGHT := 0.8
const ROOF_HEIGHT := 1.4

const PAINT := Color(0.55, 0.36, 0.27)
const PAINT_SIDE := Color(0.4, 0.26, 0.2)
const PRIMER := Color(0.5, 0.5, 0.48)
const RUST := Color(0.4, 0.22, 0.13)
const GLASS := Color(0.15, 0.19, 0.24)
const TYRE := Color(0.07, 0.07, 0.08)
const BUMPER := Color(0.22, 0.22, 0.23)
const HEADLIGHT := Color(0.93, 0.9, 0.72)
const TAILLIGHT := Color(0.55, 0.12, 0.1)
const SHADOW := Color(0, 0, 0, 0.3)


func _ready() -> void:
	Settings.changed.connect(queue_redraw)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * GarageMap.CELL_SIZE)
	var body_up := _lift(BODY_HEIGHT)
	var roof_up := _lift(ROOF_HEIGHT)
	var footprint := Rect2(-HALF_WIDTH, -HALF_LENGTH, HALF_WIDTH * 2.0, HALF_LENGTH * 2.0)

	_rounded(footprint.grow(0.08), 0.35, SHADOW)
	for y: float in [-AXLE, AXLE]:
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(side * (HALF_WIDTH - 0.02) - 0.13, y - 0.33, 0.26, 0.66), TYRE)

	# Кузов: контур на земле и верх, сдвинутый на высоту. Между ними спереди виден передок.
	_rounded(footprint, 0.3, PAINT_SIDE)
	var top := Rect2(footprint.position + body_up, footprint.size)
	var nose_top := top.end.y
	var nose_height := HALF_LENGTH - nose_top
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(side * 0.6 - 0.17, nose_top + nose_height * 0.12, 0.34, nose_height * 0.4), HEADLIGHT)
	draw_rect(Rect2(-HALF_WIDTH + 0.1, nose_top + nose_height * 0.62, HALF_WIDTH * 2.0 - 0.2, nose_height * 0.3), BUMPER)

	_rounded(top, 0.3, PAINT)
	# Крышка багажника в грунте — её когда-то меняли.
	_rounded(Rect2(top.position + Vector2(0.12, 0.12), Vector2(1.56, 0.62)), 0.12, PRIMER)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(side * 0.62 - 0.16, top.position.y + 0.02, 0.32, 0.08), TAILLIGHT)
	# Капот: линии панелей и ржавчина.
	draw_line(Vector2(-0.62, 1.08) + body_up, Vector2(-0.6, 2.1) + body_up, PAINT.darkened(0.2), 0.03)
	draw_line(Vector2(0.62, 1.08) + body_up, Vector2(0.6, 2.1) + body_up, PAINT.darkened(0.2), 0.03)
	draw_circle(Vector2(0.28, 1.62) + body_up, 0.17, RUST)
	draw_circle(Vector2(0.4, 1.74) + body_up, 0.09, RUST)

	# Остекление на уровне кузова и крыша выше: спереди между ними видно лобовое стекло, сзади — заднее.
	_rounded(Rect2(Vector2(-0.8, -1.42) + body_up, Vector2(1.6, 2.4)), 0.2, GLASS)
	_rounded(Rect2(Vector2(-0.72, -0.95) + roof_up, Vector2(1.44, 1.33)), 0.12, PAINT.lightened(0.08))
	draw_set_transform(Vector2.ZERO)


## Сдвиг в метрах. Если машины в настройках показаны сверху, сдвига нет.
func _lift(height: float) -> Vector2:
	return GarageMap.lift(height, GarageMap.Layer.VEHICLES) / GarageMap.CELL_SIZE


func _rounded(rect: Rect2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - radius, rect.position.y + radius), -PI / 2.0],
		[Vector2(rect.end.x - radius, rect.end.y - radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI / 2.0],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI],
	]
	for corner: Array in corners:
		for i in 5:
			var angle: float = corner[1] + PI / 2.0 * i / 4.0
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
