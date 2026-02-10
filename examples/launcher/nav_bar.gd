extends CanvasLayer

const SCENES := {
	"menu": "res://examples/launcher/launcher.tscn",
	"kanban": "res://examples/kanban/main.tscn",
	"cube": "res://examples/cube/cube.tscn",
	"cookie": "res://examples/cookie_clicker/cookie_clicker.tscn",
}

var bar: HBoxContainer


func _ready() -> void:
	layer = 100

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.size = Vector2(0, 40)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	bar = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	panel.add_child(bar)

	_add_button("Menu", SCENES["menu"])
	_add_separator()
	_add_button("Kanban", SCENES["kanban"])
	_add_button("Cube", SCENES["cube"])
	_add_button("Cookie", SCENES["cookie"])


func _add_button(label: String, scene_path: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
	bar.add_child(btn)


func _add_separator() -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	bar.add_child(sep)
