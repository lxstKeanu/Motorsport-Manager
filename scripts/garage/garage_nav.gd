class_name GarageNav
extends RefCounted
## Поиск пути по клеткам участка. Нельзя ходить сквозь стены, машину и чужую закрытую территорию.
## По диагонали можно, но не срезая углы.

var layout: GarageLayout
var _grid := AStarGrid2D.new()


func _init(garage_layout: GarageLayout, blocked: Array[Rect2i] = []) -> void:
	layout = garage_layout
	_grid.region = Rect2i(Vector2i.ZERO, layout.size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			if layout.get_terrain(cell) == GarageLayout.Terrain.WALL or not layout.is_open(cell):
				_grid.set_point_solid(cell)
	for rect in blocked:
		_grid.fill_solid_region(rect.intersection(_grid.region))


func is_walkable(cell: Vector2i) -> bool:
	return layout.has_cell(cell) and not _grid.is_point_solid(cell)


## Путь от точки (в клетках, можно дробную) до клетки: центры клеток по порядку, без начальной.
## Если в саму клетку не пройти, ведёт к ближайшей проходимой соседней. Нет пути — пустой массив.
func find_path(from: Vector2, to: Vector2i) -> PackedVector2Array:
	var start := Vector2i(from.floor())
	if not is_walkable(start):
		start = _nearest_walkable(start)
	var goal := to if is_walkable(to) else _nearest_walkable(to)
	var result := PackedVector2Array()
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return result
	var cells := _grid.get_id_path(start, goal)
	for i in range(1, cells.size()):
		result.append(Vector2(cells[i]) + Vector2(0.5, 0.5))
	return result


func can_reach(from: Vector2i, to: Vector2i) -> bool:
	return from == to or not find_path(Vector2(from) + Vector2(0.5, 0.5), to).is_empty()


## Случайная проходимая клетка в одном из прямоугольников: так бездельники бродят по своей территории.
func random_walkable_in(areas: Array[Rect2i], rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 30:
		var area := areas[rng.randi_range(0, areas.size() - 1)]
		var cell := Vector2i(rng.randi_range(area.position.x, area.end.x - 1), rng.randi_range(area.position.y, area.end.y - 1))
		if is_walkable(cell):
			return cell
	return Vector2i(-1, -1)


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				if is_walkable(Vector2i(x, y)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)
