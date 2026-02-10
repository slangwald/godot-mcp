extends PanelContainer

signal card_added(column_index: int, text: String)
signal card_dropped(from_col: int, from_idx: int, to_col: int, to_idx: int)
signal card_deleted(column_index: int, card_index: int)

const KanbanCard = preload("res://kanban_card.tscn")

var column_index: int

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var card_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/CardList
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/InputRow/LineEdit
@onready var add_button: Button = $MarginContainer/VBoxContainer/InputRow/AddButton


func _ready() -> void:
	add_button.pressed.connect(_add_card_from_input)
	line_edit.text_submitted.connect(func(_t: String) -> void: _add_card_from_input())
	card_list.set_drag_forwarding(Callable(), _card_list_can_drop, _card_list_drop)


func setup(col_idx: int, title: String) -> void:
	column_index = col_idx
	title_label.text = title


func refresh_cards(cards: Array[CardData]) -> void:
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	for i in cards.size():
		var card_node := KanbanCard.instantiate()
		card_list.add_child(card_node)
		card_node.setup(column_index, i, cards[i].text)
		card_node.card_deleted.connect(_on_card_deleted)


func _card_list_can_drop(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "kanban_card"


func _card_list_drop(at_position: Vector2, data: Variant) -> void:
	var drop_index := card_list.get_child_count()
	for i in card_list.get_child_count():
		var child := card_list.get_child(i)
		if at_position.y < child.position.y + child.size.y * 0.5:
			drop_index = i
			break
	card_dropped.emit(data["column_index"], data["card_index"], column_index, drop_index)


func _add_card_from_input() -> void:
	var text := line_edit.text.strip_edges()
	if text.is_empty():
		return
	card_added.emit(column_index, text)
	line_edit.clear()
	line_edit.grab_focus()


func _on_card_deleted(col_idx: int, c_idx: int) -> void:
	card_deleted.emit(col_idx, c_idx)
