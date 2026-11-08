@tool
class_name DifficultyBar
extends Control
## Шкала сложности: полоса от «легко» (зелёный) до «хардкор» (красный) и отметка на ней.

const COLORS: Array[Color] = [
	Color(0.36, 0.72, 0.56),
	Color(0.85, 0.78, 0.38),
	Color(0.94, 0.54, 0.14),
	Color(0.86, 0.3, 0.26),
]
const BAR_HEIGHT := 8.0
const MARK := Color(1, 1, 1)

## Положение отметки: 0 — легко, 1 — хардкор.
@export_range(0.0, 1.0) var mark := 0.5:
	set(value):
		mark = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 22.0)


func _draw() -> void:
	var top := (size.y - BAR_HEIGHT) * 0.5
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var segments := COLORS.size() - 1
	for i in segments:
		var x0 := size.x * i / segments
		var x1 := size.x * (i + 1) / segments
		points = PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, top + BAR_HEIGHT), Vector2(x0, top + BAR_HEIGHT)])
		colors = PackedColorArray([COLORS[i], COLORS[i + 1], COLORS[i + 1], COLORS[i]])
		draw_polygon(points, colors)
	var x := size.x * mark
	draw_rect(Rect2(x - 3.0, 0.0, 6.0, size.y), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(x - 2.0, 1.0, 4.0, size.y - 2.0), MARK)
