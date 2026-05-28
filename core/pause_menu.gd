extends CanvasLayer

const MAIN_MENU_SCENE := "res://features/ui/main_menu.tscn"

var _root: Control
var _panel: PanelContainer
var _resume_button: Button
var _exit_button: Button
var _is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	_set_open(false)

func _unhandled_input(event: InputEvent) -> void:
	if not _can_pause_current_scene():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_set_open(not _is_open)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PauseMenuRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.68)
	_root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_resume_button = Button.new()
	_resume_button.text = "Continuar"
	_resume_button.custom_minimum_size = Vector2(300, 46)
	_resume_button.pressed.connect(func(): _set_open(false))
	box.add_child(_resume_button)

	_exit_button = Button.new()
	_exit_button.text = "Salir"
	_exit_button.custom_minimum_size = Vector2(300, 46)
	_exit_button.pressed.connect(_save_and_exit)
	box.add_child(_exit_button)

func _set_open(open: bool) -> void:
	_is_open = open
	_root.visible = open
	get_tree().paused = open
	if open and _resume_button:
		_resume_button.grab_focus()

func _save_and_exit() -> void:
	_root.visible = false
	_is_open = false
	if has_node("/root/GameSave"):
		await GameSave.save_and_return_to_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _can_pause_current_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var scene_path := scene.scene_file_path
	if scene_path == "" or scene_path == MAIN_MENU_SCENE:
		return false
	return get_tree().get_first_node_in_group("player") != null
