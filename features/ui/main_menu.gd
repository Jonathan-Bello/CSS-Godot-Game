extends Control

@export_file("*.tscn") var new_game_scene: String = "res://features/ui/game_intro.tscn"
@export var new_game_spawn_marker: String = ""
@export var title_music: AudioStream = preload("res://assets/music/Verdant Circuit.mp3")
@export var accept_sfx: AudioStream = preload("res://assets/sfx/Menu_Select_01.mp3")
@export var focus_sfx: AudioStream = preload("res://assets/sfx/Menu_Select_00.mp3")

@onready var new_button: Button = %NewButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel
@onready var buttons_container: VBoxContainer = $Layout/Content/Buttons

var _hemis_button: Button = null
var _hemis_key_dialog: ConfirmationDialog = null
var _hemis_key_input: LineEdit = null
var _api_gate: Control = null
var _api_gate_input: LineEdit = null

func _ready() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_music(title_music, 0.6, -10.0)
	new_button.pressed.connect(_on_new_pressed)
	load_button.pressed.connect(_on_load_pressed)
	_update_load_button_state()
	_apply_runtime_menu_rules()
	if not _is_web_runtime():
		_create_hemis_key_button()
	_create_api_gate()
	for button in _get_focusable_buttons():
		button.focus_entered.connect(_play_focus_sfx)
		button.mouse_entered.connect(_play_focus_sfx)
	new_button.grab_focus()

func _apply_runtime_menu_rules() -> void:
	if _is_web_runtime():
		quit_button.visible = false
		quit_button.disabled = true
		quit_button.focus_mode = Control.FOCUS_NONE
		new_button.focus_neighbor_top = NodePath("../LoadButton")
		new_button.focus_neighbor_bottom = NodePath("../LoadButton")
		load_button.focus_neighbor_top = NodePath("../NewButton")
		load_button.focus_neighbor_bottom = NodePath("../NewButton")
		return
	quit_button.visible = true
	quit_button.disabled = false
	quit_button.focus_mode = Control.FOCUS_ALL
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func _on_new_pressed() -> void:
	_play_accept_sfx()
	if not _is_web_runtime() and not _has_hemis_api_key():
		_show_api_gate()
		return
	_start_new_game()

func _start_new_game() -> void:
	if has_node("/root/GameSave") and GameSave.has_method("reset_new_game_state"):
		GameSave.call("reset_new_game_state")
	if has_node("/root/AudioManager"):
		AudioManager.stop_music(0.35)
	if has_node("/root/SceneTransition"):
		await SceneTransition.transition_to_scene(new_game_scene, new_game_spawn_marker, 0.35)
	else:
		get_tree().change_scene_to_file(new_game_scene)

func _on_load_pressed() -> void:
	_play_accept_sfx()
	if not has_node("/root/GameSave") or not GameSave.has_method("has_save") or not bool(GameSave.call("has_save")):
		status_label.text = "No hay partida guardada."
		_update_load_button_state()
		return
	if has_node("/root/AudioManager"):
		AudioManager.stop_music(0.35)
	var loaded := await GameSave.load_saved_game()
	if not loaded:
		status_label.text = "No se pudo cargar la partida."
		_update_load_button_state()

func _on_quit_pressed() -> void:
	_play_accept_sfx()
	get_tree().quit()

func _create_hemis_key_button() -> void:
	_hemis_button = Button.new()
	_hemis_button.name = "HemisKeyButton"
	_hemis_button.custom_minimum_size = new_button.custom_minimum_size
	_hemis_button.text = "Activar Hemis"
	_hemis_button.theme = new_button.theme
	for style_name in ["normal", "pressed", "hover", "focus"]:
		var style := new_button.get_theme_stylebox(style_name)
		if style != null:
			_hemis_button.add_theme_stylebox_override(style_name, style)
	_hemis_button.add_theme_font_override("font", new_button.get_theme_font("font"))
	_hemis_button.add_theme_font_size_override("font_size", new_button.get_theme_font_size("font_size"))
	_hemis_button.pressed.connect(_on_hemis_key_pressed)
	buttons_container.add_child(_hemis_button)
	_create_hemis_key_dialog()

func _create_hemis_key_dialog() -> void:
	_hemis_key_dialog = ConfirmationDialog.new()
	_hemis_key_dialog.title = "Activar Hemis"
	_hemis_key_dialog.ok_button_text = "Guardar key"
	_hemis_key_dialog.cancel_button_text = "Cancelar"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Ingresa tu API key de Gemini. Se mantendra activa mientras esta sesion este abierta."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hemis_key_input = LineEdit.new()
	_hemis_key_input.secret = true
	_hemis_key_input.placeholder_text = "API key de Gemini"
	box.add_child(label)
	box.add_child(_hemis_key_input)
	margin.add_child(box)
	_hemis_key_dialog.add_child(margin)
	_hemis_key_dialog.confirmed.connect(_save_hemis_key_from_dialog)
	add_child(_hemis_key_dialog)

func _on_hemis_key_pressed() -> void:
	_play_accept_sfx()
	if _hemis_key_input:
		_hemis_key_input.text = ""
	if _hemis_key_dialog:
		_hemis_key_dialog.popup_centered(Vector2i(560, 180))

func _save_hemis_key_from_dialog() -> void:
	var key := _hemis_key_input.text.strip_edges() if _hemis_key_input else ""
	if key == "":
		status_label.text = "Hemis sigue inactivo: no se ingreso API key."
		return
	if has_node("/root/HemisGameContext"):
		HemisGameContext.set_api_key(key)
	status_label.text = "Hemis activado para esta sesion."
	if _hemis_button:
		_hemis_button.text = "Hemis activado"

func _has_hemis_api_key() -> bool:
	if has_node("/root/HemisGameContext") and HemisGameContext.has_method("has_api_key"):
		return bool(HemisGameContext.call("has_api_key"))
	return false

func _is_web_runtime() -> bool:
	if has_node("/root/RuntimeEnvironment") and RuntimeEnvironment.has_method("is_web"):
		return bool(RuntimeEnvironment.call("is_web"))
	if has_node("/root/HemisGameContext") and HemisGameContext.has_method("is_web_runtime"):
		return bool(HemisGameContext.call("is_web_runtime"))
	return OS.has_feature("web")

func _create_api_gate() -> void:
	_api_gate = Control.new()
	_api_gate.name = "HemisApiGate"
	_api_gate.visible = false
	_api_gate.process_mode = Node.PROCESS_MODE_ALWAYS
	_api_gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_api_gate.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_api_gate)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.92)
	_api_gate.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_api_gate.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Activar Hemis"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var copy := Label.new()
	copy.text = "Ingresa tu API key de Gemini para activar el chat de Hemis. Se mantendra solo en memoria durante esta sesion."
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(copy)

	_api_gate_input = LineEdit.new()
	_api_gate_input.secret = true
	_api_gate_input.placeholder_text = "API key de Gemini"
	_api_gate_input.text_submitted.connect(_on_api_gate_text_submitted)
	box.add_child(_api_gate_input)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(_hide_api_gate)
	row.add_child(cancel)

	var accept := Button.new()
	accept.text = "Guardar y jugar"
	accept.pressed.connect(_confirm_api_gate)
	row.add_child(accept)

func _show_api_gate() -> void:
	status_label.text = "Hemis necesita una API key antes de iniciar."
	_api_gate.visible = true
	if _api_gate_input:
		_api_gate_input.text = ""
		_api_gate_input.grab_focus()

func _hide_api_gate() -> void:
	if _api_gate:
		_api_gate.visible = false
	new_button.grab_focus()

func _confirm_api_gate() -> void:
	var key := _api_gate_input.text.strip_edges() if _api_gate_input else ""
	if key == "":
		status_label.text = "Ingresa una API key para activar Hemis."
		return
	if has_node("/root/HemisGameContext"):
		HemisGameContext.set_api_key(key)
	if _hemis_button:
		_hemis_button.text = "Hemis activado"
	_hide_api_gate()
	_start_new_game()

func _on_api_gate_text_submitted(_text: String) -> void:
	_confirm_api_gate()

func _get_focusable_buttons() -> Array[Button]:
	var buttons: Array[Button] = [new_button, load_button]
	if _hemis_button != null:
		buttons.append(_hemis_button)
	if quit_button.visible and not quit_button.disabled:
		buttons.append(quit_button)
	return buttons

func _update_load_button_state() -> void:
	var can_load := has_node("/root/GameSave") and GameSave.has_method("has_save") and bool(GameSave.call("has_save"))
	load_button.disabled = not can_load
	load_button.focus_mode = Control.FOCUS_ALL if can_load else Control.FOCUS_NONE
	if not can_load:
		status_label.text = "No hay partida guardada."

func _play_focus_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(focus_sfx, -18.0, 1.0)

func _play_accept_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(accept_sfx, -12.0, 1.0)
