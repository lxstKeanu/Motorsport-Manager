class_name GarageLayout
extends Resource
## Участок с гаражом: сетка клеток 1×1 м (GDD 7).
## Посередине у главной дороги наш огороженный двор с маленьким боксом. Вокруг соседские дома,
## за дорогой промзона с корпусами, на севере поля. Всё, кроме дорог и газонов, закрыто
## (см. Parcel): позже это можно будет купить. Строить можно только на своей территории.

enum Terrain { GRASS, ASPHALT, FLOOR, WALL, GATE, PAVEMENT, DIRT, FIELD, HEDGE, YARD }

const TERRAIN_KEYS := {
	Terrain.GRASS: "TERRAIN_GRASS",
	Terrain.ASPHALT: "TERRAIN_ASPHALT",
	Terrain.FLOOR: "TERRAIN_FLOOR",
	Terrain.WALL: "TERRAIN_WALL",
	Terrain.GATE: "TERRAIN_GATE",
	Terrain.PAVEMENT: "TERRAIN_PAVEMENT",
	Terrain.DIRT: "TERRAIN_DIRT",
	Terrain.FIELD: "TERRAIN_FIELD",
	Terrain.HEDGE: "TERRAIN_HEDGE",
	Terrain.YARD: "TERRAIN_YARD",
}
const START_SIZE := Vector2i(200, 150)
const BOX_SIZE := Vector2i(10, 8)
## Габариты седана в метрах: ширина и длина.
const CAR_SIZE := Vector2(1.8, 4.48)
## Цена полей за квадратный метр.
const FIELD_PRICE_PER_CELL := 10
## Зерно для расстановки деревьев и кустов: участок каждый раз одинаковый.
const DECOR_SEED := 20261108

@export var size := Vector2i.ZERO
## Тип каждой клетки построчно: индекс = y * size.x + x.
@export var cells := PackedByteArray()
@export var parcels: Array[Parcel] = []
## Проезжие части улиц: по середине каждой рисуется разметка вдоль длинной стороны.
@export var streets: Array[Rect2i] = []
## Украшения в координатах клеток: деревья, кусты, фонари, маленькие кирпичные постройки.
@export var trees := PackedVector2Array()
@export var bushes := PackedVector2Array()
@export var lamps := PackedVector2Array()
@export var sheds := PackedVector2Array()
## Где стоит машина: центр в клетках. Пока единственная машина — седан.
@export var parking_spot := Vector2.ZERO
## Хлам в боксе и завалы во дворе: убирает механик. Клетки.
@export var junk: Array[Vector2i] = []
@export var debris: Array[Vector2i] = []
## Где команда появляется, приходя в гараж, и куда уходит: подъезд к нашему боксу.
@export var entry := Vector2i.ZERO
## Свободный газон на время расстановки деревьев: 1 — можно сажать. Не сохраняется.
var _lawn := PackedByteArray()


static func create_empty(grid_size: Vector2i, terrain: Terrain = Terrain.GRASS) -> GarageLayout:
	var layout := GarageLayout.new()
	layout.size = grid_size
	layout.cells.resize(grid_size.x * grid_size.y)
	layout.cells.fill(terrain)
	return layout


## Стартовый участок.
## Дороги: главная внизу с карманом на обочине; на востоке она поворачивает на север, у полей
## уходит на запад и дальше на север сквозь поля; от восточной дороги — проезд в промзону.
static func create_starting() -> GarageLayout:
	var layout := create_empty(START_SIZE)

	# Поля на севере, вокруг каждого — лесополоса.
	var fields: Array[Rect2i] = [
		Rect2i(2, 2, 28, 68), Rect2i(34, 2, 26, 32), Rect2i(34, 38, 26, 32), Rect2i(74, 2, 34, 66),
		Rect2i(112, 2, 30, 30), Rect2i(112, 36, 30, 34), Rect2i(146, 2, 52, 68),
	]
	for i in fields.size():
		layout.fill(fields[i].grow(1), Terrain.HEDGE)
		layout.fill(fields[i], Terrain.FIELD)
		var price := int(roundf(fields[i].get_area() * FIELD_PRICE_PER_CELL / 500.0) * 500.0)
		layout.parcels.append(Parcel.create("PARCEL_FIELD", fields[i], Parcel.Kind.LAND, price, false, i + 1))

	layout.streets = [
		Rect2i(0, 136, 118, 6), Rect2i(112, 76, 6, 66), Rect2i(64, 76, 54, 6),
		Rect2i(64, 0, 6, 82), Rect2i(118, 104, 82, 5),
	]
	for street in layout.streets:
		layout.fill(street, Terrain.ASPHALT)
	layout.fill(Rect2i(84, 142, 18, 3), Terrain.ASPHALT)

	# Наш участок: двор под стройку, перед ним бокс со сломанным седаном и подъезд к дороге.
	var yard := Rect2i(54, 100, 26, 18)
	layout.fill(yard, Terrain.YARD)
	layout.parcels.append(Parcel.create("PARCEL_OWN_YARD", yard, Parcel.Kind.LAND, 0, true))
	var box := Rect2i(62, 118, BOX_SIZE.x, BOX_SIZE.y)
	layout.add_building(box, Rect2i(65, box.end.y - 1, 4, 1))
	layout.parcels.append(Parcel.create("PARCEL_BOX", box, Parcel.Kind.BUILDING, 0, true, 1))
	layout.fill(Rect2i(64, 126, 6, 10), Terrain.ASPHALT)

	# Соседские дома с черепичными крышами и подъездами к главной дороге.
	layout._add_grounds("PARCEL_HOUSE", 1, Rect2i(4, 96, 30, 30), [Rect2i(6, 100, 24, 16)], Parcel.Roof.TILE, 32000)
	layout._add_grounds("PARCEL_HOUSE", 2, Rect2i(36, 92, 16, 34), [Rect2i(38, 96, 12, 10), Rect2i(38, 108, 12, 14)], Parcel.Roof.TILE, 26000)
	layout._add_grounds("PARCEL_HOUSE", 3, Rect2i(84, 98, 24, 28), [Rect2i(86, 100, 20, 22)], Parcel.Roof.TILE, 38000)
	for driveway: Rect2i in [Rect2i(16, 116, 4, 20), Rect2i(42, 122, 4, 14), Rect2i(94, 122, 4, 14)]:
		layout.fill(driveway, Terrain.ASPHALT)

	# Промзона за восточной дорогой: участки с серыми корпусами.
	layout._add_grounds("PARCEL_UNIT", 1, Rect2i(120, 84, 36, 19), [Rect2i(123, 86, 22, 15), Rect2i(147, 90, 6, 10)], Parcel.Roof.METAL, 55000)
	layout._add_grounds("PARCEL_UNIT", 2, Rect2i(160, 84, 38, 19),
		[Rect2i(162, 86, 6, 14), Rect2i(170, 86, 6, 14), Rect2i(178, 86, 6, 14), Rect2i(186, 86, 10, 14)], Parcel.Roof.METAL, 70000)
	layout._add_grounds("PARCEL_UNIT", 3, Rect2i(120, 111, 40, 24), [Rect2i(124, 114, 28, 16)], Parcel.Roof.METAL, 90000)
	for driveway: Rect2i in [Rect2i(132, 101, 4, 3), Rect2i(176, 100, 4, 4), Rect2i(132, 109, 4, 5)]:
		layout.fill(driveway, Terrain.ASPHALT)

	layout.lamps = PackedVector2Array()
	for x: int in [8, 28, 50, 78, 104]:
		layout.lamps.append(Vector2(x + 0.5, 135.4))
	for x: int in [20, 50, 110]:
		layout.lamps.append(Vector2(x + 0.5, 142.6))
	for y: int in [90, 110, 128]:
		layout.lamps.append(Vector2(111.4, y + 0.5))
	for y: int in [10, 30, 50]:
		layout.lamps.append(Vector2(70.6, y + 0.5))
	for x: int in [150, 190]:
		layout.lamps.append(Vector2(x + 0.5, 103.4))
	layout.sheds = PackedVector2Array([Vector2(46.5, 86.5), Vector2(6.5, 146.5), Vector2(72.5, 73.5)])
	layout._scatter_decor()

	# Чуть ближе к задней стене: перед носом остаётся место, и машина не заходит под южную стену.
	layout.parking_spot = Vector2(67.0, 121.7)
	layout.junk = [Vector2i(63, 120), Vector2i(70, 122), Vector2i(64, 124)]
	layout.debris = [Vector2i(58, 104), Vector2i(72, 107), Vector2i(62, 113)]
	layout.entry = Vector2i(66, 131)
	return layout


## Участок с отдельными зданиями и землёй вокруг: дом с двором или промышленный участок.
func _add_grounds(key: String, index: int, area: Rect2i, building_rects: Array, roof_style: Parcel.Roof, cost: int) -> void:
	var parcel := Parcel.create(key, area, Parcel.Kind.BUILDING, cost, false, index)
	parcel.roof = roof_style
	for building: Rect2i in building_rects:
		add_building(building, Rect2i())
		parcel.buildings.append(building)
	parcels.append(parcel)


## Клетки, которые занимает машина: сквозь неё не ходят.
func car_cells() -> Rect2i:
	var half := CAR_SIZE * 0.5
	var from := Vector2i((parking_spot - half).floor())
	var to := Vector2i((parking_spot + half).ceil())
	return Rect2i(from, to - from)


## Своя территория: здесь бродят те, кому нечем заняться.
func owned_areas() -> Array[Rect2i]:
	var areas: Array[Rect2i] = []
	for parcel in parcels:
		if parcel.owned:
			areas.append(parcel.rect)
	return areas


## Участок земли: голая земля под будущую стройку.
func add_land(parcel: Parcel) -> void:
	fill(parcel.rect, Terrain.DIRT)
	parcels.append(parcel)


## Деревья и кусты на газонах вне чужих участков. Расстановка с постоянным зерном,
## поэтому участок всегда выглядит одинаково.
func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	_lawn = PackedByteArray()
	_lawn.resize(size.x * size.y)
	for i in _lawn.size():
		_lawn[i] = 1 if cells[i] == Terrain.GRASS else 0
	for parcel in parcels:
		var area := parcel.rect.intersection(Rect2i(Vector2i.ZERO, size))
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				_lawn[y * size.x + x] = 0
	# Возле фонарей и кирпичных построек деревья не сажаем.
	for spot in lamps + sheds:
		var around := Rect2i(Vector2i(spot.floor()) - Vector2i(2, 2), Vector2i(5, 5)).intersection(Rect2i(Vector2i.ZERO, size))
		for y in range(around.position.y, around.end.y):
			for x in range(around.position.x, around.end.x):
				_lawn[y * size.x + x] = 0
	trees = _scatter(rng, 220, 1, 2)
	bushes = _scatter(rng, 80, 1, 2)
	_lawn = PackedByteArray()


## Случайные точки на свободном газоне: вокруг каждой в радиусе clearance только газон,
## и точки не ближе spacing клеток друг к другу. Занятое место отмечается в _lawn.
func _scatter(rng: RandomNumberGenerator, count: int, clearance: int, spacing: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var attempts := count * 40
	while points.size() < count and attempts > 0:
		attempts -= 1
		var cell := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		if not _is_clear(cell, clearance):
			continue
		points.append(Vector2(cell) + Vector2(0.5, 0.5))
		var taken := Rect2i(cell - Vector2i(spacing, spacing), Vector2i(spacing * 2 + 1, spacing * 2 + 1)).intersection(Rect2i(Vector2i.ZERO, size))
		for y in range(taken.position.y, taken.end.y):
			for x in range(taken.position.x, taken.end.x):
				_lawn[y * size.x + x] = 0
	return points


func _is_clear(cell: Vector2i, clearance: int) -> bool:
	for y in range(cell.y - clearance, cell.y + clearance + 1):
		for x in range(cell.x - clearance, cell.x + clearance + 1):
			if not has_cell(Vector2i(x, y)) or _lawn[y * size.x + x] == 0:
				return false
	return true


## Здание: стены по контуру, пол внутри и ворота в указанных клетках стены.
func add_building(outer: Rect2i, gate: Rect2i) -> void:
	fill(outer, Terrain.WALL)
	fill(outer.grow(-1), Terrain.FLOOR)
	fill(gate, Terrain.GATE)


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_terrain(cell: Vector2i) -> Terrain:
	return cells[cell.y * size.x + cell.x] as Terrain


func set_terrain(cell: Vector2i, terrain: Terrain) -> void:
	cells[cell.y * size.x + cell.x] = terrain


## Заливает прямоугольник, обрезая его по границам участка.
func fill(rect: Rect2i, terrain: Terrain) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, size))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			set_terrain(Vector2i(x, y), terrain)


## Часть участка, в которой лежит клетка, или null, если клетка общая (дорога, газон).
func parcel_at(cell: Vector2i) -> Parcel:
	for parcel in parcels:
		if parcel.rect.has_point(cell):
			return parcel
	return null


func is_open(cell: Vector2i) -> bool:
	var parcel := parcel_at(cell)
	return parcel == null or parcel.owned
