class_name Parcel
extends Resource
## Часть участка: гаражный бокс, дом, промышленный участок с корпусами или поле.
## Чужие закрыты, их можно будет купить, чтобы занять здания или получить землю под стройку.

enum Kind { BUILDING, LAND }
## Крыша закрытых зданий: серая металлическая (склады, корпуса) или черепичная (дома).
enum Roof { METAL, TILE }

## Ключ названия. Если в тексте есть %d, туда подставляется number.
@export var name_key := ""
@export var number := 0
## Вся земля части участка. У зданий-боксов совпадает со зданием.
@export var rect := Rect2i()
## Здания внутри участка. Пусто — здание занимает весь rect (бокс) или зданий нет (земля).
@export var buildings: Array[Rect2i] = []
@export var kind := Kind.BUILDING
@export var roof := Roof.METAL
@export var price := 0
@export var owned := false


static func create(key: String, area: Rect2i, parcel_kind: Kind, cost: int, is_owned: bool = false, index: int = 0) -> Parcel:
	var parcel := Parcel.new()
	parcel.name_key = key
	parcel.rect = area
	parcel.kind = parcel_kind
	parcel.price = cost
	parcel.owned = is_owned
	parcel.number = index
	return parcel


## Здания для рисования крыш: свои или вся часть участка, если это одно здание.
func building_rects() -> Array[Rect2i]:
	if not buildings.is_empty():
		return buildings
	var whole: Array[Rect2i] = []
	if kind == Kind.BUILDING:
		whole.append(rect)
	return whole


## Участок с отдельными зданиями и землёй вокруг (промзона, дом с двором).
func has_grounds() -> bool:
	return not buildings.is_empty()


func display_name() -> String:
	var text := tr(name_key)
	return text % number if text.contains("%d") else text
