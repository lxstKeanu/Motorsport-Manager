class_name Appearance
extends Resource
## Внешность персонажа: номера вариантов в палитрах ниже.
## Пока это заглушка из цветов и причёски, подробность и арт-стиль ещё не решены (GDD, раздел 14).

enum HairStyle { SHORT, LONG, CURLY, BALD, CAP }

const HAIR_STYLE_KEYS := {
	HairStyle.SHORT: "HAIR_SHORT",
	HairStyle.LONG: "HAIR_LONG",
	HairStyle.CURLY: "HAIR_CURLY",
	HairStyle.BALD: "HAIR_BALD",
	HairStyle.CAP: "HAIR_CAP",
}

const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.85, 0.74),
	Color(0.94, 0.76, 0.6),
	Color(0.85, 0.64, 0.47),
	Color(0.71, 0.5, 0.34),
	Color(0.55, 0.36, 0.24),
	Color(0.38, 0.25, 0.17),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.1, 0.09, 0.09),
	Color(0.27, 0.18, 0.12),
	Color(0.47, 0.31, 0.18),
	Color(0.86, 0.72, 0.45),
	Color(0.68, 0.3, 0.15),
	Color(0.7, 0.7, 0.72),
]
const SHIRT_COLORS: Array[Color] = [
	Color(0.94, 0.54, 0.14),
	Color(0.2, 0.42, 0.75),
	Color(0.75, 0.2, 0.2),
	Color(0.24, 0.55, 0.32),
	Color(0.92, 0.78, 0.22),
	Color(0.45, 0.48, 0.53),
	Color(0.9, 0.9, 0.88),
	Color(0.15, 0.16, 0.18),
]

@export var skin := 0
@export var hair_style := HairStyle.SHORT
@export var hair_color := 0
@export var shirt := 0


static func random(rng: RandomNumberGenerator = null) -> Appearance:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := Appearance.new()
	result.skin = rng.randi_range(0, SKIN_TONES.size() - 1)
	result.hair_style = rng.randi_range(0, HairStyle.size() - 1) as HairStyle
	result.hair_color = rng.randi_range(0, HAIR_COLORS.size() - 1)
	result.shirt = rng.randi_range(0, SHIRT_COLORS.size() - 1)
	return result


func skin_color() -> Color:
	return SKIN_TONES[skin]


func hair_tint() -> Color:
	return HAIR_COLORS[hair_color]


func shirt_color() -> Color:
	return SHIRT_COLORS[shirt]
