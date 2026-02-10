extends PanelContainer

signal card_deleted(column_index: int, card_index: int)

var column_index: int
var card_index: int

@onready var card_label: Label = $MarginContainer/HBoxContainer/CardLabel
@onready var delete_button: Button = $MarginContainer/HBoxContainer/DeleteButton


func _ready() -> void:
	delete_button.pressed.connect(_on_delete_pressed)


func setup(col_idx: int, c_idx: int, text: String) -> void:
	column_index = col_idx
	card_index = c_idx
	card_label.text = text


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = card_label.text
	set_drag_preview(preview)
	modulate.a = 0.3
	return {"type": "kanban_card", "column_index": column_index, "card_index": card_index, "text": card_label.text}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0


func _on_delete_pressed() -> void:
	card_deleted.emit(column_index, card_index)
