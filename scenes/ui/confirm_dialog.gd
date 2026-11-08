class_name ConfirmDialog
extends Control
## Окно с вопросом и двумя кнопками. Esc и кнопка отмены просто закрывают его.
## Тексты задаются ключами переводов там, куда окно вставлено.

signal confirmed
signal cancelled

@export var title_key := ""
@export var body_key := ""
@export var confirm_key := ""
@export var cancel_key := ""
## Окно только со сведениями (титры): без кнопки «да», только закрыть.
@export var show_confirm := true

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	hide()
	_title.text = title_key
	_body.text = body_key
	_confirm_button.text = confirm_key
	_cancel_button.text = cancel_key
	_confirm_button.visible = show_confirm
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(close)


## Отмена — безопасный вариант, поэтому фокус на ней.
## Если тексту нужны подстановки ({name} и т.п.), их передают в values.
func open(values: Dictionary = {}) -> void:
	_body.text = tr(body_key).format(values) if not values.is_empty() else body_key
	show()
	_cancel_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()
