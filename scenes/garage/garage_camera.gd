class_name GarageCamera
extends Camera2D
## Камера гаража. WASD или стрелки двигают её, правая или средняя кнопка мыши перетаскивают,
## колесо и +/− меняют масштаб, приближая к курсору. За пределы участка камера не уезжает.

@export var max_zoom := 2.5
@export var zoom_step := 1.2
## Скорость прокрутки с клавиатуры в пикселях экрана в секунду.
@export var pan_speed := 900.0
## Как быстро плавный зум догоняет цель: больше — резче.
@export var zoom_smoothing := 14.0

## Границы в координатах мира. Минимальный масштаб — тот, при котором они видны целиком.
var bounds := Rect2()
var min_zoom := 0.25
## Сколько пикселей сверху занимает панель: карта считается видимой только ниже неё.
var view_inset_top := 0.0:
	set(value):
		view_inset_top = value
		_update_min_zoom()
		clamp_to_bounds()
var _target_zoom := 1.0
var _zoom_anchor := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)


## Ставит камеру на участок: границы, точка, на которую смотреть, и масштаб.
func setup(world_bounds: Rect2, focus: Vector2, start_zoom: float = 1.0) -> void:
	bounds = world_bounds
	_update_min_zoom()
	look_at_point(focus, start_zoom)


## Ставит точку мира в центр видимой области с заданным масштабом.
func look_at_point(focus: Vector2, new_zoom: float) -> void:
	var clamped := clampf(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(clamped, clamped)
	_target_zoom = clamped
	position = focus - (view_rect().get_center() - view_size() * 0.5) / clamped
	clamp_to_bounds()


func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		position += direction * pan_speed * delta / zoom.x
		clamp_to_bounds()
	if not is_equal_approx(zoom.x, _target_zoom):
		var next := lerpf(zoom.x, _target_zoom, 1.0 - exp(-zoom_smoothing * delta))
		if absf(next - _target_zoom) < 0.002:
			next = _target_zoom
		zoom_to(next, _zoom_anchor)


func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		match mouse.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_step_at(zoom_step, mouse.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_step_at(1.0 / zoom_step, mouse.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = true
			_:
				return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_in"):
		_zoom_step_at(zoom_step, view_rect().get_center())
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_step_at(1.0 / zoom_step, view_rect().get_center())


## Движение и отпускание ловим здесь, а не в _unhandled_input,
## чтобы перетаскивание не обрывалось, когда курсор проходит над панелями.
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_to_bounds()
	elif event is InputEventMouseButton and not event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_RIGHT or button == MOUSE_BUTTON_MIDDLE:
			_dragging = false


## Сразу ставит масштаб так, чтобы точка мира под anchor (координаты экрана) осталась на месте.
func zoom_to(value: float, anchor: Vector2) -> void:
	var before := screen_to_world(anchor)
	var clamped := clampf(value, min_zoom, max_zoom)
	zoom = Vector2(clamped, clamped)
	position += before - screen_to_world(anchor)
	clamp_to_bounds()


func screen_to_world(point: Vector2) -> Vector2:
	return position + (point - view_size() * 0.5) / zoom.x


func view_size() -> Vector2:
	return get_viewport_rect().size


## Часть экрана, где видна карта: всё ниже верхней панели.
func view_rect() -> Rect2:
	var size := view_size()
	var inset := clampf(view_inset_top, 0.0, size.y * 0.5)
	return Rect2(0.0, inset, size.x, size.y - inset)


## Видимая часть мира.
func visible_world_rect() -> Rect2:
	var view := view_rect()
	return Rect2(screen_to_world(view.position), view.size / zoom.x)


## Держит видимую часть мира внутри границ. Если границы меньше неё, ставит их по центру.
func clamp_to_bounds() -> void:
	if not bounds.has_area():
		return
	var visible := visible_world_rect()
	var shift := Vector2.ZERO
	for axis in 2:
		if bounds.size[axis] <= visible.size[axis]:
			shift[axis] = bounds.get_center()[axis] - visible.get_center()[axis]
		elif visible.position[axis] < bounds.position[axis]:
			shift[axis] = bounds.position[axis] - visible.position[axis]
		elif visible.end[axis] > bounds.end[axis]:
			shift[axis] = bounds.end[axis] - visible.end[axis]
	position += shift


func _zoom_step_at(factor: float, anchor: Vector2) -> void:
	_target_zoom = clampf(_target_zoom * factor, min_zoom, max_zoom)
	_zoom_anchor = anchor


func _update_min_zoom() -> void:
	if not bounds.has_area():
		return
	var view := view_rect().size
	min_zoom = minf(view.x / bounds.size.x, view.y / bounds.size.y)
	_target_zoom = clampf(_target_zoom, min_zoom, max_zoom)


func _on_viewport_resized() -> void:
	_update_min_zoom()
	zoom_to(zoom.x, view_rect().get_center())
