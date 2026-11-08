class_name TeamStyle
## Эмблемы и цвета команды для мастера новой игры и верхней панели.
## Эмблемы — белые SVG, при показе их красят в цвет команды.

const EMBLEMS: Array[String] = [
	"res://ui/icons/emblems/wheel.svg",
	"res://ui/icons/emblems/shield.svg",
	"res://ui/icons/emblems/lightning.svg",
	"res://ui/icons/emblems/piston.svg",
	"res://ui/icons/emblems/wrench.svg",
	"res://ui/icons/emblems/flame.svg",
	"res://ui/icons/emblems/wings.svg",
	"res://ui/icons/emblems/gear.svg",
	"res://ui/icons/emblems/flag.svg",
	"res://ui/icons/emblems/crown.svg",
	"res://ui/icons/emblems/horseshoe.svg",
	"res://ui/icons/emblems/rocket.svg",
]
const COLORS: Array[Color] = [
	Color(0.94, 0.54, 0.14),
	Color(0.84, 0.27, 0.24),
	Color(0.27, 0.5, 0.86),
	Color(0.27, 0.66, 0.42),
	Color(0.93, 0.76, 0.2),
	Color(0.55, 0.38, 0.8),
	Color(0.86, 0.87, 0.89),
	Color(0.18, 0.19, 0.22),
]
const NAME_MAX_LENGTH := 28


static func emblem(index: int) -> Texture2D:
	return load(EMBLEMS[clampi(index, 0, EMBLEMS.size() - 1)])


static func color(index: int) -> Color:
	return COLORS[clampi(index, 0, COLORS.size() - 1)]
