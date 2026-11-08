@tool
class_name CharacterPortrait
extends Control
## Портрет-заглушка: плечи, голова и причёска рисуются кодом по внешности персонажа.
## Если внешность поменяли на месте, вызови queue_redraw().

## Портрет рисуется в квадрате 100×120 и прижимается к нижнему краю, плечи уходят за край.
const BOX := Vector2(100.0, 120.0)
const EYE := Color(0.1, 0.09, 0.09)
## Подложка светлее тёмных панелей, чтобы на ней читались чёрная одежда и чёрные волосы.
const BACKDROP := Color(0.25, 0.27, 0.31)

@export var appearance: Appearance:
	set(value):
		appearance = value
		queue_redraw()

var _origin := Vector2.ZERO
var _k := 1.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var look := appearance if appearance != null else Appearance.new()
	_k = minf(size.x / BOX.x, size.y / BOX.y)
	_origin = Vector2((size.x - BOX.x * _k) * 0.5, size.y - BOX.y * _k)

	var skin := look.skin_color()
	var hair := look.hair_tint()
	var shirt := look.shirt_color()

	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	# Длинные волосы лежат за головой и плечами.
	if look.hair_style == Appearance.HairStyle.LONG:
		_rect(Rect2(27.0, 40.0, 46.0, 52.0), hair)
	# Плечи, шея, воротник.
	_ellipse(Vector2(50.0, 122.0), Vector2(42.0, 30.0), shirt)
	# Светлый кант по плечам: силуэт виден при любом цвете одежды.
	draw_polyline(_to_screen(_arc_points(Vector2(50.0, 122.0), Vector2(42.0, 30.0), PI, TAU, 24)), shirt.lightened(0.3), maxf(1.0, 1.2 * _k), true)
	_rect(Rect2(43.0, 70.0, 14.0, 24.0), skin.darkened(0.12))
	_polygon([Vector2(41, 92), Vector2(50, 104), Vector2(59, 92), Vector2(57, 92), Vector2(50, 99), Vector2(43, 92)], shirt.darkened(0.25))
	# Голова.
	_ellipse(Vector2(50.0, 52.0), Vector2(21.0, 25.0), skin)
	_draw_hair(look.hair_style, hair, shirt)
	# Лицо: глаза и рот.
	for x: float in [42.0, 58.0]:
		draw_circle(_p(Vector2(x, 55.0)), 2.2 * _k, EYE)
	draw_line(_p(Vector2(45.0, 66.0)), _p(Vector2(55.0, 66.0)), skin.darkened(0.35), maxf(1.0, 1.4 * _k), true)


func _draw_hair(style: Appearance.HairStyle, hair: Color, shirt: Color) -> void:
	match style:
		Appearance.HairStyle.SHORT:
			_half_ellipse(Vector2(50.0, 46.0), Vector2(23.0, 22.0), hair)
		Appearance.HairStyle.LONG:
			_half_ellipse(Vector2(50.0, 46.0), Vector2(24.0, 23.0), hair)
			_rect(Rect2(27.0, 44.0, 6.0, 30.0), hair)
			_rect(Rect2(67.0, 44.0, 6.0, 30.0), hair)
		Appearance.HairStyle.CURLY:
			_half_ellipse(Vector2(50.0, 46.0), Vector2(22.0, 21.0), hair)
			for curl: Vector2 in [Vector2(30, 44), Vector2(34, 32), Vector2(43, 25), Vector2(55, 24), Vector2(65, 31), Vector2(70, 43)]:
				draw_circle(_p(curl), 8.0 * _k, hair)
		Appearance.HairStyle.BALD:
			pass
		Appearance.HairStyle.CAP:
			# Кепка в цвет одежды, из-под неё видны виски.
			_rect(Rect2(29.0, 42.0, 5.0, 10.0), hair)
			_rect(Rect2(66.0, 42.0, 5.0, 10.0), hair)
			_half_ellipse(Vector2(50.0, 44.0), Vector2(23.0, 20.0), shirt)
			_polygon([Vector2(26, 44), Vector2(74, 44), Vector2(80, 49), Vector2(26, 48)], shirt.darkened(0.3))


## Переводит точку из квадрата портрета в координаты контрола.
func _p(local: Vector2) -> Vector2:
	return _origin + local * _k


func _rect(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(_p(rect.position), rect.size * _k), color)


func _polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(_to_screen(points), color)


func _to_screen(points: Array) -> PackedVector2Array:
	var screen := PackedVector2Array()
	for point: Vector2 in points:
		screen.append(_p(point))
	return screen


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := _arc_points(center, radius, 0.0, TAU, 32)
	points.pop_back()  # Последняя точка совпадает с первой, а повторы ломают триангуляцию.
	_polygon(points, color)


## Верхняя половина эллипса: макушка, причёска, кепка.
func _half_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	_polygon(_arc_points(center, radius, PI, TAU, 16), color)


func _arc_points(center: Vector2, radius: Vector2, from: float, to: float, segments: int) -> Array:
	var points := []
	for i in segments + 1:
		var angle := lerpf(from, to, float(i) / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
