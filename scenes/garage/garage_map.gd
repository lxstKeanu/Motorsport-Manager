class_name GarageMap
extends Node2D
## Рисует участок по GarageLayout в 2.5D: вид сверху, у всего высокого видна южная грань,
## а верх сдвинут вверх на высоту. Наш бокс открыт (видно пол), закрытые здания — с крышей,
## у домов черепичные, у полей таблички «Продаётся». Графика — заглушки, рисуется кодом.
## Какие слои рисовать в 2.5D, а какие сверху, задаётся в настройках (вкладка «Вид»).

## Слои вида: здания, стены и заборы; машины; деревья, фонари, таблички и завалы;
## оборудование — станки, верстаки, стеллажи (пока это ящики и покрышки в боксе).
enum Layer { WALLS, VEHICLES, MISC, EQUIPMENT }

## Размер клетки (1 м) в пикселях при масштабе 1.
const CELL_SIZE := 48.0
## Насколько метр высоты сдвигает картинку вверх, в клетках.
const HEIGHT_SCALE := 0.4
const WALL_HEIGHT := 2.6
const DOOR_HEIGHT := 2.2
const LINTEL := 0.4
## Поле вокруг участка, куда ещё может заехать камера, в клетках.
const VIEW_MARGIN := 2.0

const TERRAIN_COLORS := {
	GarageLayout.Terrain.GRASS: Color(0.13, 0.19, 0.12),
	GarageLayout.Terrain.ASPHALT: Color(0.17, 0.18, 0.2),
	GarageLayout.Terrain.FLOOR: Color(0.36, 0.37, 0.38),
	GarageLayout.Terrain.WALL: Color(0.36, 0.37, 0.38),
	GarageLayout.Terrain.GATE: Color(0.36, 0.37, 0.38),
	GarageLayout.Terrain.PAVEMENT: Color(0.37, 0.37, 0.36),
	GarageLayout.Terrain.DIRT: Color(0.3, 0.26, 0.2),
	GarageLayout.Terrain.FIELD: Color(0.31, 0.24, 0.16),
	GarageLayout.Terrain.HEDGE: Color(0.1, 0.16, 0.09),
	GarageLayout.Terrain.YARD: Color(0.3, 0.29, 0.26),
}
## Через что асфальт отделён бордюром: всё, кроме самого асфальта и зданий.
const CURB_NEIGHBOURS := [
	GarageLayout.Terrain.GRASS, GarageLayout.Terrain.DIRT, GarageLayout.Terrain.PAVEMENT,
	GarageLayout.Terrain.FIELD, GarageLayout.Terrain.HEDGE, GarageLayout.Terrain.YARD,
]
## Углы клетки: верх-лево, верх-право, низ-право, низ-лево. Для каждого — соседи по двум сторонам и по диагонали.
const CORNER_NEIGHBOURS := [
	[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1)],
	[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1)],
	[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1)],
	[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1)],
]
## Какие углы касаются стороны клетки: верх, право, низ, лево.
const SIDE_CORNERS := [[0, 1], [1, 2], [2, 3], [3, 0]]
const FURROW := Color(0.24, 0.18, 0.12)
const FURROW_LIGHT := Color(0.36, 0.28, 0.19)
const HEDGE_LIGHT := Color(0.15, 0.23, 0.12)
const GRAVEL := Color(0.38, 0.36, 0.33)
const PLOT_LINE := Color(0.72, 0.74, 0.76, 0.75)
const TILE_ROOF := Color(0.55, 0.37, 0.29)
const TILE_LINE := Color(0.47, 0.31, 0.24)
const TILE_RIDGE := Color(0.63, 0.44, 0.35)
const TILE_EDGE := Color(0.4, 0.26, 0.2)
const SHED_HOLE := Color(0.12, 0.1, 0.09)
const WALL_TOP := Color(0.7, 0.67, 0.62)
const WALL_FRONT := Color(0.5, 0.47, 0.43)
const WALL_EDGE := Color(0.32, 0.3, 0.28)
const ROOF := Color(0.33, 0.37, 0.42)
const ROOF_RIB := Color(0.29, 0.32, 0.37)
const ROOF_EDGE := Color(0.46, 0.5, 0.55)
const SKYLIGHT := Color(0.46, 0.56, 0.62)
const DOOR := Color(0.4, 0.42, 0.45)
const DOOR_SLAT := Color(0.32, 0.34, 0.37)
const HAZARD := Color(0.941, 0.541, 0.141, 0.9)
const CURB := Color(0.55, 0.56, 0.58)
const ROAD_MARK := Color(0.85, 0.85, 0.8, 0.7)
const GRID := Color(1, 1, 1, 0.07)
const SIGN := Color(0.93, 0.91, 0.85)
const SIGN_TEXT := Color(0.12, 0.12, 0.13)
const LABEL := Color(0.92, 0.93, 0.95)
const LABEL_DIM := Color(0.941, 0.541, 0.141)
const SHADOW := Color(0, 0, 0, 0.25)
const OWN_BORDER := Color(0.941, 0.541, 0.141, 0.85)
const CRATE := Color(0.55, 0.42, 0.27)
const TYRE_JUNK := Color(0.1, 0.1, 0.11)
const RUBBLE := Color(0.46, 0.44, 0.41)
const BRICK := Color(0.58, 0.32, 0.24)
const TREE := Color(0.12, 0.23, 0.11)
const TREE_LIGHT := Color(0.17, 0.3, 0.15)
const TRUNK := Color(0.32, 0.23, 0.16)
const POLE := Color(0.5, 0.52, 0.55)
const LAMP := Color(0.98, 0.9, 0.6)

var layout: GarageLayout:
	set(value):
		layout = value
		queue_redraw()


func _ready() -> void:
	# Вид (2.5D или сверху) и валюта цен на табличках берутся из настроек.
	Settings.changed.connect(queue_redraw)


func _notification(what: int) -> void:
	# На крышах и табличках есть тексты и цены.
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func cell_at(world_position: Vector2) -> Vector2i:
	return Vector2i((to_local(world_position) / CELL_SIZE).floor())


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)


## Область, в которой держится камера: участок и поле вокруг.
func world_bounds() -> Rect2:
	var plot := Rect2(Vector2.ZERO, Vector2(layout.size) * CELL_SIZE)
	return plot.grow(VIEW_MARGIN * CELL_SIZE)


## Сдвиг картинки для высоты в метрах. Если слой в настройках показан сверху, сдвига нет.
static func lift(height: float, layer: Layer = Layer.WALLS) -> Vector2:
	return raise(height) if Settings.is_3d(layer) else Vector2.ZERO


## Сдвиг для высоты без оглядки на настройки: людей всегда рисуем в 2.5D.
static func raise(height: float) -> Vector2:
	return Vector2(0.0, -height * HEIGHT_SCALE * CELL_SIZE)


func _draw() -> void:
	if layout == null:
		return
	for y in layout.size.y:
		for x in layout.size.x:
			_draw_ground(Vector2i(x, y))
	_draw_street_marking()
	_draw_grid()
	_draw_plot_lines()
	_draw_shadows()
	# Граница своей земли лежит на земле: стены и деревья её перекрывают.
	for parcel in layout.parcels:
		if parcel.owned and parcel.kind == Parcel.Kind.LAND:
			_draw_own_border(parcel)

	# Всё высокое рисуем по рядам с севера на юг: что южнее, то перекрывает северное.
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			var terrain := layout.get_terrain(cell)
			if (terrain == GarageLayout.Terrain.WALL or terrain == GarageLayout.Terrain.GATE) and layout.is_open(cell):
				_draw_wall(cell, terrain)
		for parcel in layout.parcels:
			if parcel.owned:
				continue
			if parcel.kind == Parcel.Kind.BUILDING:
				for building in parcel.building_rects():
					if building.end.y - 1 == y:
						_draw_closed_building(parcel, building)
			elif parcel.rect.end.y - 1 == y:
				_draw_sale_sign(Vector2(parcel.rect.get_center().x, parcel.rect.end.y) * CELL_SIZE, parcel)
		_draw_props_in_row(y)

	for parcel in layout.parcels:
		if not parcel.owned:
			_draw_parcel_label(parcel)


# --- Земля ---

func _draw_ground(cell: Vector2i) -> void:
	var terrain := layout.get_terrain(cell)
	var rect := cell_rect(cell)
	var color: Color = TERRAIN_COLORS[terrain]
	var variation := float(_cell_hash(cell) % 3)
	draw_rect(rect, color)

	match terrain:
		GarageLayout.Terrain.ASPHALT:
			_draw_road_cell(cell, rect)
		GarageLayout.Terrain.FIELD:
			# Борозды поперёк поля.
			for i in 3:
				var y := rect.position.y + CELL_SIZE * (i + 0.5) / 3.0
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), FURROW, 4.0)
				draw_line(Vector2(rect.position.x, y + 4.0), Vector2(rect.end.x, y + 4.0), FURROW_LIGHT, 2.0)
		GarageLayout.Terrain.HEDGE:
			draw_circle(rect.get_center() + Vector2(-0.15, -0.1) * CELL_SIZE, CELL_SIZE * 0.42, HEDGE_LIGHT)
			draw_circle(rect.get_center() + Vector2(0.2, 0.15) * CELL_SIZE, CELL_SIZE * 0.3, color.darkened(0.2))
		GarageLayout.Terrain.YARD:
			# Гравий: редкие светлые камешки.
			for i in 3:
				var h := _cell_hash(cell + Vector2i(i * 7, i * 3))
				draw_circle(rect.position + Vector2(float(h % 9) / 9.0, float((h / 9) % 9) / 9.0) * CELL_SIZE, 2.0, GRAVEL)
		GarageLayout.Terrain.DIRT:
			# Пустырь зарастает: редкие пучки травы.
			if _cell_hash(cell) % 5 == 0:
				var tuft := rect.position + Vector2(0.3 + 0.1 * variation, 0.5) * CELL_SIZE
				draw_circle(tuft, CELL_SIZE * 0.16, TERRAIN_COLORS[GarageLayout.Terrain.GRASS])
				draw_circle(tuft + Vector2(CELL_SIZE * 0.22, -CELL_SIZE * 0.08), CELL_SIZE * 0.11, TERRAIN_COLORS[GarageLayout.Terrain.GRASS])
	# Во внутренние углы поворотов и перекрёстков асфальт заходит дугой.
	if terrain != GarageLayout.Terrain.ASPHALT:
		for corner in _concave_corners(cell):
			_corner_patch(rect, corner, TERRAIN_COLORS[GarageLayout.Terrain.ASPHALT])


## Асфальт: бордюры по краям и скругления углов. Наружные углы дороги срезаются дугой,
## а во внутренние углы перекрёстков и поворотов асфальт заходит дугой в соседнюю клетку.
func _draw_road_cell(cell: Vector2i, rect: Rect2) -> void:
	var rounded := _convex_corners(cell)
	for corner in rounded:
		var outside: Vector2i = cell + CORNER_NEIGHBOURS[corner][0]
		var color: Color = TERRAIN_COLORS[layout.get_terrain(outside)] if layout.has_cell(outside) else TERRAIN_COLORS[GarageLayout.Terrain.GRASS]
		_corner_patch(rect, corner, color)
	var sides := _rect_sides(rect)
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var neighbour: Vector2i = cell + directions[i]
		if not layout.has_cell(neighbour) or not CURB_NEIGHBOURS.has(layout.get_terrain(neighbour)):
			continue
		# Сторона уходит в скругление своего угла или в асфальтовую дугу соседа — прямого бордюра нет.
		if rounded.has(SIDE_CORNERS[i][0]) or rounded.has(SIDE_CORNERS[i][1]):
			continue
		var fillets := _concave_corners(neighbour)
		var facing: Array = SIDE_CORNERS[(i + 2) % 4]
		if fillets.has(facing[0]) or fillets.has(facing[1]):
			continue
		var inward: Vector2 = -Vector2(directions[i]) * 1.5
		draw_line(sides[i][0] + inward, sides[i][1] + inward, CURB, 3.0)


func _is_road(cell: Vector2i) -> bool:
	return not layout.has_cell(cell) or layout.get_terrain(cell) == GarageLayout.Terrain.ASPHALT


## Мягкая земля вокруг дороги (трава, поле, гравий): там углы асфальта скругляются, а у стен зданий нет.
func _is_soft(cell: Vector2i) -> bool:
	return layout.has_cell(cell) and CURB_NEIGHBOURS.has(layout.get_terrain(cell))


## Наружные углы асфальтовой клетки: обе стороны угла и диагональ — мягкая земля, не дорога и не здание.
func _convex_corners(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for corner in 4:
		var near: Array = CORNER_NEIGHBOURS[corner]
		if _is_soft(cell + near[0]) and _is_soft(cell + near[1]) and _is_soft(cell + near[2]):
			result.append(corner)
	return result


## Внутренние углы для клетки не-дороги: обе стороны угла и диагональ — дорога.
func _concave_corners(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	if not CURB_NEIGHBOURS.has(layout.get_terrain(cell)):
		return result
	for corner in 4:
		var near: Array = CORNER_NEIGHBOURS[corner]
		if _is_road(cell + near[0]) and _is_road(cell + near[1]) and _is_road(cell + near[2]):
			result.append(corner)
	return result


## Заливает угол клетки снаружи дуги радиусом в клетку с центром в противоположном углу
## и проводит по дуге бордюр.
func _corner_patch(rect: Rect2, corner: int, color: Color) -> void:
	var points := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var center: Vector2 = points[(corner + 2) % 4]
	var from: Vector2 = points[(corner + 1) % 4]
	var to: Vector2 = points[(corner + 3) % 4]
	var start_angle := (from - center).angle()
	var sweep := wrapf((to - center).angle() - start_angle, -PI, PI)
	var arc := PackedVector2Array()
	for i in 9:
		var angle := start_angle + sweep * i / 8.0
		arc.append(center + Vector2(cos(angle), sin(angle)) * CELL_SIZE)
	var polygon := PackedVector2Array([points[corner]])
	polygon.append_array(arc)
	draw_colored_polygon(polygon, color)
	draw_polyline(arc, CURB, 3.0, true)


## Обводит стороны клетки, за которыми лежит один из указанных типов.
func _draw_edges(cell: Vector2i, rect: Rect2, neighbour_terrains: Array, color: Color, width: float) -> void:
	var sides := _rect_sides(rect)
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var neighbour: Vector2i = cell + directions[i]
		if layout.has_cell(neighbour) and neighbour_terrains.has(layout.get_terrain(neighbour)):
			var inward: Vector2 = -Vector2(directions[i]) * width * 0.5
			draw_line(sides[i][0] + inward, sides[i][1] + inward, color, width)


## Прерывистая осевая вдоль длинной стороны каждой улицы. На перекрёстках и поворотах она прерывается.
func _draw_street_marking() -> void:
	for street in layout.streets:
		var vertical := street.size.y > street.size.x
		var along := Vector2i(1, 0) if not vertical else Vector2i(0, 1)
		var start := street.position.x if not vertical else street.position.y
		var finish := street.end.x if not vertical else street.end.y
		# Куски улицы, которые не заняты другими улицами.
		var gaps: Array[Vector2i] = []
		for other in layout.streets:
			if other == street or not other.intersects(street):
				continue
			var cut := other.intersection(street)
			gaps.append(Vector2i(cut.position.x, cut.end.x) if not vertical else Vector2i(cut.position.y, cut.end.y))
		gaps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		var middle := (street.position.y + street.size.y * 0.5) if not vertical else (street.position.x + street.size.x * 0.5)
		var cursor := start
		for gap: Vector2i in gaps + [Vector2i(finish, finish)]:
			if gap.x - cursor >= 2:
				var from := Vector2(along) * (cursor + 1) + Vector2(along.y, along.x) * middle
				var to := Vector2(along) * (gap.x - 1) + Vector2(along.y, along.x) * middle
				draw_dashed_line(from * CELL_SIZE, to * CELL_SIZE, ROAD_MARK, CELL_SIZE * 0.12, CELL_SIZE * 1.5)
			cursor = maxi(cursor, gap.y)


## Сетка видна только на своей земле: там строят. На остальной карте она лишь мешала бы.
func _draw_grid() -> void:
	for area in layout.owned_areas():
		var rect := Rect2(Vector2(area.position) * CELL_SIZE, Vector2(area.size) * CELL_SIZE)
		for x in range(area.position.x, area.end.x + 1):
			draw_line(Vector2(x * CELL_SIZE, rect.position.y), Vector2(x * CELL_SIZE, rect.end.y), GRID, -1.0)
		for y in range(area.position.y, area.end.y + 1):
			draw_line(Vector2(rect.position.x, y * CELL_SIZE), Vector2(rect.end.x, y * CELL_SIZE), GRID, -1.0)


## Тени на земле: свет падает с северо-запада, поэтому тень лежит к востоку от стен и зданий.
func _draw_shadows() -> void:
	var width := -lift(WALL_HEIGHT).y * 0.5
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			var terrain := layout.get_terrain(cell)
			if terrain != GarageLayout.Terrain.WALL or not layout.is_open(cell):
				continue
			var east := cell + Vector2i.RIGHT
			if layout.has_cell(east) and layout.get_terrain(east) == GarageLayout.Terrain.WALL:
				continue
			var rect := cell_rect(cell)
			draw_rect(Rect2(rect.end.x, rect.position.y, width, rect.size.y), SHADOW)
	for parcel in layout.parcels:
		if parcel.owned:
			continue
		for building in parcel.building_rects():
			var rect := Rect2(Vector2(building.position) * CELL_SIZE, Vector2(building.size) * CELL_SIZE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x + width, rect.position.y + width),
				Vector2(rect.end.x + width, rect.end.y),
				rect.end,
			]), SHADOW)


# --- Стены и здания ---

## Стена открытого здания: южная грань (если южнее не стена) и верх, сдвинутый на высоту.
## Над воротами — только перемычка, под ней виден проём.
func _draw_wall(cell: Vector2i, terrain: GarageLayout.Terrain) -> void:
	var rect := cell_rect(cell)
	var top := Rect2(rect.position + lift(WALL_HEIGHT), rect.size)
	var base_y := rect.end.y
	var below := cell + Vector2i.DOWN
	var below_is_wall := layout.has_cell(below) and layout.get_terrain(below) == GarageLayout.Terrain.WALL

	if terrain == GarageLayout.Terrain.GATE and not Settings.is_3d(Layer.WALLS):
		# Сверху у открытых ворот видно только порог: перемычки над проёмом нет.
		draw_line(Vector2(rect.position.x, base_y - 2.0), Vector2(rect.end.x, base_y - 2.0), HAZARD, 4.0)
		return
	if terrain == GarageLayout.Terrain.GATE:
		var lintel_bottom := base_y + lift(WALL_HEIGHT - LINTEL).y
		draw_rect(Rect2(rect.position.x, top.end.y, rect.size.x, lintel_bottom - top.end.y), WALL_FRONT)
		draw_line(Vector2(rect.position.x, lintel_bottom), Vector2(rect.end.x, lintel_bottom), DOOR_SLAT, 3.0)
		draw_line(Vector2(rect.position.x, base_y - 2.0), Vector2(rect.end.x, base_y - 2.0), HAZARD, 4.0)
	elif not below_is_wall:
		draw_rect(Rect2(rect.position.x, top.end.y, rect.size.x, base_y - top.end.y), WALL_FRONT)
	draw_rect(top, WALL_TOP)

	# Тёмная кромка там, где верх стены обрывается, чтобы стены читались контуром.
	var sides := _rect_sides(top)
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var neighbour: Vector2i = cell + directions[i]
		var neighbour_terrain := layout.get_terrain(neighbour) if layout.has_cell(neighbour) else GarageLayout.Terrain.GRASS
		if neighbour_terrain != GarageLayout.Terrain.WALL and neighbour_terrain != GarageLayout.Terrain.GATE:
			draw_line(sides[i][0], sides[i][1], WALL_EDGE, 2.0)


## Закрытое здание: южная стена с опущенными воротами и крыша — серая металлическая
## у складов и корпусов или черепичная у домов.
func _draw_closed_building(parcel: Parcel, building: Rect2i) -> void:
	var rect := Rect2(Vector2(building.position) * CELL_SIZE, Vector2(building.size) * CELL_SIZE)
	var roof := Rect2(rect.position + lift(WALL_HEIGHT), rect.size)
	draw_rect(Rect2(rect.position.x, roof.end.y, rect.size.x, rect.end.y - roof.end.y), WALL_FRONT)
	var door_top := rect.end.y + lift(DOOR_HEIGHT).y
	for x in range(building.position.x, building.end.x):
		if layout.get_terrain(Vector2i(x, building.end.y - 1)) != GarageLayout.Terrain.GATE:
			continue
		var door := Rect2(x * CELL_SIZE, door_top, CELL_SIZE, rect.end.y - door_top)
		draw_rect(door, DOOR)
		var slat_y := door.position.y + 4.0
		while slat_y < door.end.y:
			draw_line(Vector2(door.position.x, slat_y), Vector2(door.end.x, slat_y), DOOR_SLAT, 1.5)
			slat_y += 5.0
	if parcel.roof == Parcel.Roof.TILE:
		_draw_tile_roof(roof)
		return
	draw_rect(roof, ROOF)
	var rib_x := roof.position.x + CELL_SIZE * 0.5
	while rib_x < roof.end.x:
		draw_line(Vector2(rib_x, roof.position.y + 3.0), Vector2(rib_x, roof.end.y - 3.0), ROOF_RIB, 2.0)
		rib_x += CELL_SIZE * 0.5
	# Световые фонари на больших крышах.
	if building.size.x >= 20:
		for i in range(1, 4):
			var skylight := Rect2(roof.position.x + roof.size.x * i / 4.0 - CELL_SIZE * 1.5, roof.position.y + CELL_SIZE * 2.0, CELL_SIZE * 3.0, roof.size.y - CELL_SIZE * 4.0)
			draw_rect(skylight, SKYLIGHT)
			draw_rect(skylight, ROOF_EDGE, false, 2.0)
	draw_rect(roof, ROOF_EDGE, false, 3.0)


## Черепичная крыша: ряды черепицы поперёк ската и конёк вдоль длинной стороны.
func _draw_tile_roof(roof: Rect2) -> void:
	draw_rect(roof, TILE_ROOF)
	var along_x := roof.size.x >= roof.size.y
	var step := CELL_SIZE * 0.35
	if along_x:
		var y := roof.position.y + step
		while y < roof.end.y:
			draw_line(Vector2(roof.position.x, y), Vector2(roof.end.x, y), TILE_LINE, 1.5)
			y += step
		draw_line(Vector2(roof.position.x, roof.get_center().y), Vector2(roof.end.x, roof.get_center().y), TILE_RIDGE, 4.0)
	else:
		var x := roof.position.x + step
		while x < roof.end.x:
			draw_line(Vector2(x, roof.position.y), Vector2(x, roof.end.y), TILE_LINE, 1.5)
			x += step
		draw_line(Vector2(roof.get_center().x, roof.position.y), Vector2(roof.get_center().x, roof.end.y), TILE_RIDGE, 4.0)
	draw_rect(roof, TILE_EDGE, false, 3.0)


## Граница участков с землёй вокруг зданий (дома, промзона): светлый бордюр.
func _draw_plot_lines() -> void:
	for parcel in layout.parcels:
		if parcel.has_grounds():
			var rect := Rect2(Vector2(parcel.rect.position) * CELL_SIZE, Vector2(parcel.rect.size) * CELL_SIZE).grow(-3.0)
			draw_rect(rect, PLOT_LINE, false, 3.0)


# --- Поля ---

func _draw_sale_sign(base: Vector2, parcel: Parcel) -> void:
	var board_size := Vector2(CELL_SIZE * 3.6, CELL_SIZE * 0.95)
	var board := Rect2(base + lift(1.0, Layer.MISC) - Vector2(board_size.x * 0.5, board_size.y), board_size)
	for side: float in [-1.2, 1.2]:
		draw_line(base + Vector2(side * CELL_SIZE, 0.0), Vector2(base.x + side * CELL_SIZE, board.end.y), POLE, 4.0)
	draw_rect(board, SIGN)
	draw_rect(board, HAZARD, false, 3.0)
	var font := _font()
	_text_centered(font, tr("PARCEL_FOR_SALE_SIGN"), Vector2(board.get_center().x, board.position.y + CELL_SIZE * 0.4), 15, SIGN_TEXT)
	_text_centered(font, Game.format_money(parcel.price), Vector2(board.get_center().x, board.position.y + CELL_SIZE * 0.8), 17, SIGN_TEXT)


## Своя земля обведена пунктиром: здесь можно строить.
func _draw_own_border(parcel: Parcel) -> void:
	var rect := Rect2(Vector2(parcel.rect.position) * CELL_SIZE, Vector2(parcel.rect.size) * CELL_SIZE).grow(-2.0)
	for side in _rect_sides(rect):
		draw_dashed_line(side[0], side[1], OWN_BORDER, 3.0, CELL_SIZE * 0.5)


# --- Деревья, кусты, фонари ---

func _draw_props_in_row(row: int) -> void:
	for cell in layout.junk:
		if cell.y == row:
			_draw_junk(cell_rect(cell))
	for cell in layout.debris:
		if cell.y == row:
			_draw_debris(cell_rect(cell))
	for spot in layout.sheds:
		if int(spot.y) == row:
			_draw_shed(spot * CELL_SIZE)
	for spot in layout.bushes:
		if int(spot.y) == row:
			_draw_crown(spot * CELL_SIZE, 0.6, 0.7)
	for spot in layout.trees:
		if int(spot.y) == row:
			var base := spot * CELL_SIZE
			draw_line(base, base + lift(2.6, Layer.MISC), TRUNK, CELL_SIZE * 0.22)
			_draw_crown(base, 3.4, 1.5)
	for spot in layout.lamps:
		if int(spot.y) == row:
			_draw_lamp(spot * CELL_SIZE)


## Хлам в боксе: ящик и стопка старых покрышек.
func _draw_junk(rect: Rect2) -> void:
	var unit := CELL_SIZE
	var crate := Rect2(rect.position + Vector2(0.08, 0.3) * unit, Vector2(0.5, 0.5) * unit)
	_draw_block(crate, 0.6, CRATE)
	var tyre_base := rect.position + Vector2(0.72, 0.72) * unit
	for level in 3:
		var center := tyre_base + lift(0.22 * level, Layer.EQUIPMENT)
		_ellipse(center, Vector2(0.24, 0.16) * unit, TYRE_JUNK)
		_ellipse(center, Vector2(0.11, 0.07) * unit, TYRE_JUNK.lightened(0.15))


## Завал во дворе: куча битого кирпича и обломков.
func _draw_debris(rect: Rect2) -> void:
	var unit := CELL_SIZE
	var base := rect.get_center() + Vector2(0.0, 0.25) * unit
	_ellipse(base + Vector2(0.08, 0.05) * unit, Vector2(0.55, 0.25) * unit, SHADOW)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-0.5, 0.0) * unit, base + Vector2(-0.3, -0.25) * unit + lift(0.4, Layer.MISC),
		base + Vector2(0.05, -0.3) * unit + lift(0.6, Layer.MISC), base + Vector2(0.35, -0.2) * unit + lift(0.35, Layer.MISC),
		base + Vector2(0.5, 0.0) * unit,
	]), RUBBLE)
	for brick: Vector2 in [Vector2(-0.25, -0.12), Vector2(0.12, -0.18), Vector2(0.28, -0.05)]:
		draw_rect(Rect2(base + brick * unit + lift(0.3, Layer.MISC), Vector2(0.2, 0.09) * unit), BRICK)


## Маленькая кирпичная постройка (колодец, будка) 2×2 м с тёмным проёмом сверху.
func _draw_shed(center: Vector2) -> void:
	var footprint := Rect2(center - Vector2.ONE * CELL_SIZE, Vector2.ONE * CELL_SIZE * 2.0)
	var top := Rect2(footprint.position + lift(1.2, Layer.MISC), footprint.size)
	draw_rect(Rect2(footprint.position.x, top.end.y, footprint.size.x, footprint.end.y - top.end.y), BRICK.darkened(0.3))
	draw_rect(top, BRICK)
	draw_rect(top.grow(-CELL_SIZE * 0.45), SHED_HOLE)
	draw_rect(top, BRICK.darkened(0.45), false, 2.0)


## Небольшой ящик в 2.5D: передняя грань и крышка, поднятая на высоту.
func _draw_block(footprint: Rect2, height: float, color: Color) -> void:
	var top := Rect2(footprint.position + lift(height, Layer.EQUIPMENT), footprint.size)
	draw_rect(Rect2(footprint.position.x, top.end.y, footprint.size.x, footprint.end.y - top.end.y), color.darkened(0.3))
	draw_rect(top, color)
	draw_rect(top, color.darkened(0.45), false, 1.5)


func _draw_crown(base: Vector2, height: float, radius: float) -> void:
	_ellipse(base + Vector2(0.35, 0.15) * CELL_SIZE, Vector2(radius, radius * 0.55) * CELL_SIZE, SHADOW)
	var center := base + lift(height, Layer.MISC)
	draw_circle(center, radius * CELL_SIZE, TREE)
	draw_circle(center - Vector2(0.3, 0.3) * radius * CELL_SIZE, radius * 0.6 * CELL_SIZE, TREE_LIGHT)


func _draw_lamp(base: Vector2) -> void:
	var top := base + lift(5.5, Layer.MISC)
	draw_line(base, top, POLE, CELL_SIZE * 0.12)
	draw_line(top, top + Vector2(0.0, CELL_SIZE * 0.9), POLE, CELL_SIZE * 0.1)
	draw_rect(Rect2(top + Vector2(-CELL_SIZE * 0.22, CELL_SIZE * 0.8), Vector2(CELL_SIZE * 0.44, CELL_SIZE * 0.18)), LAMP)


# --- Подписи ---

## Над закрытым зданием — замок, название и цена; над пустырём табличка уже есть.
func _draw_parcel_label(parcel: Parcel) -> void:
	if parcel.kind != Parcel.Kind.BUILDING:
		return
	# Подпись на крыше самого большого здания участка; на больших зданиях она крупнее.
	var biggest := parcel.rect
	if parcel.has_grounds():
		biggest = parcel.buildings[0]
		for building in parcel.buildings:
			if building.get_area() > biggest.get_area():
				biggest = building
	var label_scale := clampf(biggest.size.x / 10.0, 1.0, 2.5)
	var center := Vector2(biggest.get_center()) * CELL_SIZE + lift(WALL_HEIGHT)
	var font := _font()
	var font_size := int(20.0 * label_scale)
	_draw_padlock(center + Vector2(0.0, -CELL_SIZE * 0.9 * label_scale), label_scale)
	_text_centered(font, parcel.display_name(), center + Vector2(0.0, CELL_SIZE * 0.25 * label_scale), font_size, LABEL)
	_text_centered(font, Game.format_money(parcel.price), center + Vector2(0.0, CELL_SIZE * 0.8 * label_scale), font_size, LABEL_DIM)


func _draw_padlock(center: Vector2, size_scale: float) -> void:
	var unit := CELL_SIZE * size_scale
	var body := Rect2(center + Vector2(-0.3, -0.05) * unit, Vector2(0.6, 0.45) * unit)
	draw_arc(center + Vector2(0.0, -0.08) * unit, unit * 0.2, PI, TAU, 12, LABEL, 4.0 * size_scale)
	draw_line(center + Vector2(-0.2, -0.08) * unit, center + Vector2(-0.2, 0.0) * unit, LABEL, 4.0 * size_scale)
	draw_line(center + Vector2(0.2, -0.08) * unit, center + Vector2(0.2, 0.0) * unit, LABEL, 4.0 * size_scale)
	draw_rect(body, LABEL)
	draw_circle(body.get_center(), unit * 0.06, ROOF)


func _font() -> Font:
	var theme := ThemeDB.get_project_theme()
	return theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font


func _text_centered(font: Font, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, baseline_center - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Помощники ---

## Стороны прямоугольника: верх, право, низ, лево.
func _rect_sides(rect: Rect2) -> Array:
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	return [[a, b], [b, c], [d, c], [a, d]]


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663))
