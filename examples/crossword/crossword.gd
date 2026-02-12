extends Control

const GRID_SIZE := 10
const CELL_SIZE := 38.0

var grid := {}
var word_cells := {}
var across_words := []
var down_words := []
var numbers := {}
var player_letters := {}
var selected := Vector2i(-1, -1)
var is_across := true
var cell_panels := {}
var cell_labels := {}

const WORD_SETS := [
	[
		["GODOT", "Game engine for this project"],
		["NODE", "Building block of a scene"],
		["TREE", "Hierarchical scene structure"],
		["CODE", "What programmers write"],
		["DEMO", "A sample application"],
		["EDIT", "Modify or change"],
		["OPEN", "Not closed; a source type"],
		["RUN", "Execute the project"],
	],
	[
		["OCEAN", "Large body of salt water"],
		["CLOUD", "White shape in the sky"],
		["STONE", "Hard natural material"],
		["LEAF", "Green part of a plant"],
		["RAIN", "Water falling from clouds"],
		["OAK", "Type of sturdy tree"],
		["SUN", "Our nearest star"],
		["WIND", "Moving air"],
	],
	[
		["BREAD", "Baked staple food"],
		["CREAM", "Dairy topping"],
		["RICE", "Asian staple grain"],
		["BEAN", "Legume used in chili"],
		["DATE", "Sweet desert fruit"],
		["HERB", "Basil or thyme"],
		["JAM", "Fruit preserve"],
		["TEA", "Hot brewed drink"],
	],
]

@onready var grid_container: GridContainer = $Margin/Layout/LeftSide/GridContainer
@onready var across_clues: VBoxContainer = $Margin/Layout/RightSide/ClueScroll/Clues/AcrossClues
@onready var down_clues: VBoxContainer = $Margin/Layout/RightSide/ClueScroll/Clues/DownClues
@onready var status_label: Label = $Margin/Layout/RightSide/StatusLabel
@onready var check_btn: Button = $Margin/Layout/RightSide/Buttons/CheckButton
@onready var new_btn: Button = $Margin/Layout/RightSide/Buttons/NewButton


func _ready() -> void:
	randomize()
	check_btn.pressed.connect(_on_check)
	new_btn.pressed.connect(_on_new_puzzle)
	grid_container.columns = GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	_new_puzzle()


func _new_puzzle() -> void:
	_clear_all()
	for attempt in range(10):
		var set_idx := randi() % WORD_SETS.size()
		var words: Array = WORD_SETS[set_idx].duplicate(true)
		words.shuffle()
		_generate(words)
		if across_words.size() + down_words.size() >= 4:
			break
		grid.clear()
		word_cells.clear()
		across_words.clear()
		down_words.clear()
		numbers.clear()
	_build_grid()
	_build_clues()
	status_label.text = "Click a cell and type!"


func _clear_all() -> void:
	grid.clear()
	word_cells.clear()
	across_words.clear()
	down_words.clear()
	numbers.clear()
	player_letters.clear()
	selected = Vector2i(-1, -1)
	cell_panels.clear()
	cell_labels.clear()
	for c in grid_container.get_children():
		c.queue_free()
	for c in across_clues.get_children():
		c.queue_free()
	for c in down_clues.get_children():
		c.queue_free()


func _generate(words: Array) -> void:
	words.sort_custom(func(a, b): return a[0].length() > b[0].length())
	var first: String = words[0][0]
	var sx := (GRID_SIZE - first.length()) / 2
	var sy := GRID_SIZE / 2
	_place(first, Vector2i(sx, sy), true)
	across_words.append({"word": first, "clue": words[0][1], "pos": Vector2i(sx, sy), "number": 0})
	for i in range(1, words.size()):
		_try_place(words[i][0], words[i][1])
	_number_clues()


func _place(word: String, pos: Vector2i, horiz: bool) -> void:
	for i in range(word.length()):
		var c := Vector2i(pos.x + i, pos.y) if horiz else Vector2i(pos.x, pos.y + i)
		grid[c] = word[i]
		if not word_cells.has(c):
			word_cells[c] = []
		word_cells[c].append(horiz)


func _try_place(word: String, clue: String) -> bool:
	for i in range(word.length()):
		var ch := word[i]
		for pos in grid:
			if grid[pos] != ch:
				continue
			var vstart := Vector2i(pos.x, pos.y - i)
			if _can_place(word, vstart, false):
				_place(word, vstart, false)
				down_words.append({"word": word, "clue": clue, "pos": vstart, "number": 0})
				return true
			var hstart := Vector2i(pos.x - i, pos.y)
			if _can_place(word, hstart, true):
				_place(word, hstart, true)
				across_words.append({"word": word, "clue": clue, "pos": hstart, "number": 0})
				return true
	return false


func _can_place(word: String, pos: Vector2i, horiz: bool) -> bool:
	var found_cross := false
	for i in range(word.length()):
		var c := Vector2i(pos.x + i, pos.y) if horiz else Vector2i(pos.x, pos.y + i)
		if c.x < 0 or c.x >= GRID_SIZE or c.y < 0 or c.y >= GRID_SIZE:
			return false
		if grid.has(c):
			if grid[c] != word[i]:
				return false
			for wh in word_cells[c]:
				if wh == horiz:
					return false
			found_cross = true
		else:
			if horiz:
				if grid.has(Vector2i(c.x, c.y - 1)) or grid.has(Vector2i(c.x, c.y + 1)):
					return false
			else:
				if grid.has(Vector2i(c.x - 1, c.y)) or grid.has(Vector2i(c.x + 1, c.y)):
					return false
	if horiz:
		if grid.has(Vector2i(pos.x - 1, pos.y)) or grid.has(Vector2i(pos.x + word.length(), pos.y)):
			return false
	else:
		if grid.has(Vector2i(pos.x, pos.y - 1)) or grid.has(Vector2i(pos.x, pos.y + word.length())):
			return false
	return found_cross


func _number_clues() -> void:
	var all_pos := {}
	for e in across_words:
		all_pos[e["pos"]] = true
	for e in down_words:
		all_pos[e["pos"]] = true
	var sorted_pos := all_pos.keys()
	sorted_pos.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	var n := 1
	for p in sorted_pos:
		numbers[p] = n
		for e in across_words:
			if e["pos"] == p:
				e["number"] = n
		for e in down_words:
			if e["pos"] == p:
				e["number"] = n
		n += 1


func _build_grid() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos := Vector2i(x, y)
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			var style := StyleBoxFlat.new()
			style.set_border_width_all(1)
			if grid.has(pos):
				style.bg_color = Color(0.95, 0.95, 0.95)
				style.border_color = Color(0.5, 0.5, 0.5)
				panel.add_theme_stylebox_override("panel", style)
				var lbl := Label.new()
				lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 18)
				lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
				panel.add_child(lbl)
				cell_labels[pos] = lbl
				if numbers.has(pos):
					var nl := Label.new()
					nl.text = str(numbers[pos])
					nl.add_theme_font_size_override("font_size", 9)
					nl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
					nl.position = Vector2(2, 0)
					panel.add_child(nl)
				cell_panels[pos] = panel
				panel.gui_input.connect(_cell_input.bind(pos))
				panel.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				style.bg_color = Color(0.12, 0.12, 0.17)
				style.border_color = Color(0.12, 0.12, 0.17)
				panel.add_theme_stylebox_override("panel", style)
				panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_container.add_child(panel)


func _build_clues() -> void:
	across_words.sort_custom(func(a, b): return a["number"] < b["number"])
	down_words.sort_custom(func(a, b): return a["number"] < b["number"])
	for e in across_words:
		var lbl := Label.new()
		lbl.text = "%d. %s" % [e["number"], e["clue"]]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		across_clues.add_child(lbl)
	for e in down_words:
		var lbl := Label.new()
		lbl.text = "%d. %s" % [e["number"], e["clue"]]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		down_clues.add_child(lbl)


func _cell_input(event: InputEvent, pos: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected == pos:
			is_across = not is_across
		selected = pos
		_highlight()


func _highlight() -> void:
	for p in cell_panels:
		var s := StyleBoxFlat.new()
		s.set_border_width_all(1)
		if p == selected:
			s.bg_color = Color(0.6, 0.8, 1.0)
			s.border_color = Color(0.3, 0.5, 0.8)
		else:
			s.bg_color = Color(0.95, 0.95, 0.95)
			s.border_color = Color(0.5, 0.5, 0.5)
		cell_panels[p].add_theme_stylebox_override("panel", s)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if selected == Vector2i(-1, -1):
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_BACKSPACE:
			player_letters.erase(selected)
			if cell_labels.has(selected):
				cell_labels[selected].text = ""
			_step(-1)
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_move(Vector2i(selected.x - 1, selected.y))
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_move(Vector2i(selected.x + 1, selected.y))
			get_viewport().set_input_as_handled()
		KEY_UP:
			_move(Vector2i(selected.x, selected.y - 1))
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_move(Vector2i(selected.x, selected.y + 1))
			get_viewport().set_input_as_handled()
		_:
			if key.unicode > 0:
				var ch := String.chr(key.unicode).to_upper()
				if ch >= "A" and ch <= "Z":
					player_letters[selected] = ch
					cell_labels[selected].text = ch
					_step(1)
					get_viewport().set_input_as_handled()


func _step(dir: int) -> void:
	var next: Vector2i
	if is_across:
		next = Vector2i(selected.x + dir, selected.y)
	else:
		next = Vector2i(selected.x, selected.y + dir)
	_move(next)


func _move(pos: Vector2i) -> void:
	if cell_panels.has(pos):
		selected = pos
		_highlight()


func _on_check() -> void:
	var correct := 0
	var total := grid.size()
	for pos in grid:
		if player_letters.has(pos) and player_letters[pos] == grid[pos]:
			correct += 1
	if correct == total:
		status_label.text = "All %d letters correct!" % total
	else:
		status_label.text = "%d / %d correct" % [correct, total]
	for p in cell_panels:
		var s := StyleBoxFlat.new()
		s.set_border_width_all(1)
		if player_letters.has(p) and player_letters[p] == grid[p]:
			s.bg_color = Color(0.7, 1.0, 0.7)
			s.border_color = Color(0.3, 0.6, 0.3)
		elif player_letters.has(p):
			s.bg_color = Color(1.0, 0.7, 0.7)
			s.border_color = Color(0.6, 0.3, 0.3)
		else:
			s.bg_color = Color(0.95, 0.95, 0.95)
			s.border_color = Color(0.5, 0.5, 0.5)
		cell_panels[p].add_theme_stylebox_override("panel", s)


func _on_new_puzzle() -> void:
	_new_puzzle()
