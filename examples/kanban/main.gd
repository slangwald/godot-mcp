extends Control

const KanbanColumn = preload("res://examples/kanban/kanban_column.tscn")

@onready var column_container: HBoxContainer = $MarginContainer/VBoxContainer/ColumnContainer


func _ready() -> void:
	_refresh_board()


func _refresh_board() -> void:
	for child in column_container.get_children():
		column_container.remove_child(child)
		child.queue_free()
	for i in BoardManager.data.columns.size():
		var col_data := BoardManager.data.columns[i]
		var col_node := KanbanColumn.instantiate()
		column_container.add_child(col_node)
		col_node.setup(i, col_data.title)
		col_node.refresh_cards(col_data.cards)
		col_node.card_added.connect(_on_card_added)
		col_node.card_dropped.connect(_on_card_dropped)
		col_node.card_deleted.connect(_on_card_deleted)


func _on_card_added(column_index: int, text: String) -> void:
	BoardManager.add_card(column_index, text)
	_refresh_board()


func _on_card_dropped(from_col: int, from_idx: int, to_col: int, to_idx: int) -> void:
	BoardManager.move_card(from_col, from_idx, to_col, to_idx)
	_refresh_board()


func _on_card_deleted(column_index: int, card_index: int) -> void:
	BoardManager.delete_card(column_index, card_index)
	_refresh_board()
