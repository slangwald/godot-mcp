extends Node

const SAVE_PATH = "user://board.tres"

var data: BoardData


func _ready() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		data = ResourceLoader.load(SAVE_PATH) as BoardData
	if data == null:
		data = BoardData.new()
		for title in ["To Do", "In Progress", "Done"]:
			var col := ColumnData.new()
			col.title = title
			data.columns.append(col)
		save()


func save() -> void:
	ResourceSaver.save(data, SAVE_PATH)


func add_card(column_index: int, text: String) -> void:
	var card := CardData.new()
	card.text = text
	data.columns[column_index].cards.append(card)
	save()


func delete_card(column_index: int, card_index: int) -> void:
	data.columns[column_index].cards.remove_at(card_index)
	save()


func move_card(from_col: int, from_idx: int, to_col: int, to_idx: int) -> void:
	var card := data.columns[from_col].cards[from_idx]
	data.columns[from_col].cards.remove_at(from_idx)
	if from_col == to_col and to_idx > from_idx:
		to_idx -= 1
	data.columns[to_col].cards.insert(to_idx, card)
	save()
