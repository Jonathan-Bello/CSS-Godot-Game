extends CanvasLayer

var _root: Control
var _title_label: Label
var _description_label: Label
var _texture_rect: TextureRect
var _item_list: ItemList
var _inventory_items: Array = []
var _locked_player: Node = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


func show_item(item_data: Dictionary) -> void:
	_inventory_items.clear()
	_item_list.visible = false
	_set_item(item_data)
	_open()


func show_inventory(items: Array) -> void:
	_inventory_items = items.duplicate(true)
	_item_list.clear()
	for item_data in _inventory_items:
		_item_list.add_item(String(item_data.get("title", "Objeto")))
	_item_list.visible = true
	if _inventory_items.is_empty():
		_set_item({
			"title": "Inventario",
			"description": "Aun no has recuperado coleccionables.",
			"sprite_path": "",
		})
	else:
		_item_list.select(0)
		_set_item(_inventory_items[0])
	_open()


func close() -> void:
	hide()
	_lock_player(false)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 260)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_top = -130.0
	panel.offset_right = 340.0
	panel.offset_bottom = 130.0
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	main.add_child(_title_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(170, 0)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_inventory_item_selected)
	body.add_child(_item_list)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(148, 148)
	body.add_child(icon_panel)

	_texture_rect = TextureRect.new()
	_texture_rect.custom_minimum_size = Vector2(132, 132)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_panel.add_child(_texture_rect)

	_description_label = Label.new()
	_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 18)
	body.add_child(_description_label)

	var hint := Label.new()
	hint.text = "E / I / Esc para cerrar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	main.add_child(hint)


func _open() -> void:
	show()
	_lock_player(true)


func _set_item(item_data: Dictionary) -> void:
	_title_label.text = String(item_data.get("title", "Objeto"))
	_description_label.text = String(item_data.get("description", ""))
	_texture_rect.texture = _load_texture(String(item_data.get("sprite_path", "")))


func _load_texture(path: String) -> Texture2D:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _on_inventory_item_selected(index: int) -> void:
	if index < 0 or index >= _inventory_items.size():
		return
	_set_item(_inventory_items[index])


func _lock_player(locked: bool) -> void:
	if locked:
		_locked_player = get_tree().get_first_node_in_group("player")
	if _locked_player != null and is_instance_valid(_locked_player) and _locked_player.has_method("set_external_control_lock"):
		_locked_player.call("set_external_control_lock", locked)
	if not locked:
		_locked_player = null
