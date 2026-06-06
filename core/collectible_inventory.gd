extends Node

signal item_collected(item_data: Dictionary)

const POPUP_SCENE: PackedScene = preload("res://features/ui/collectibles/collectible_popup.tscn")

var _known_items: Dictionary = {}
var _collected_items: Dictionary = {}
var _active_popup: CanvasLayer = null


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_instance_valid(_active_popup) and _active_popup.visible:
			return
		open_inventory_screen()
		get_viewport().set_input_as_handled()


func reset_inventory() -> void:
	_known_items.clear()
	_collected_items.clear()
	if is_instance_valid(_active_popup):
		_active_popup.queue_free()
	_active_popup = null


func register_item(item_data: Dictionary) -> void:
	var item_id := _get_item_id(item_data)
	if item_id == "":
		return
	_known_items[item_id] = _sanitize_item_data(item_data)


func collect_item(item_data: Dictionary, open_popup: bool = true) -> bool:
	var item_id := _get_item_id(item_data)
	if item_id == "":
		push_warning("[CollectibleInventory] Coleccionable sin id.")
		return false
	if _collected_items.has(item_id):
		return false
	var clean_data := _sanitize_item_data(item_data)
	_known_items[item_id] = clean_data
	_collected_items[item_id] = clean_data
	item_collected.emit(clean_data)
	if open_popup:
		open_item_screen(clean_data)
	return true


func is_collected(item_id: String) -> bool:
	return _collected_items.has(item_id.strip_edges())


func get_collected_items() -> Array:
	var items: Array = []
	for item_id in _collected_items.keys():
		items.append(_collected_items[item_id])
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("title", "")).naturalnocasecmp_to(String(b.get("title", ""))) < 0
	)
	return items


func get_save_data() -> Dictionary:
	return _collected_items.duplicate(true)


func restore_collected_items(raw: Variant) -> void:
	_collected_items.clear()
	if typeof(raw) == TYPE_DICTIONARY:
		var data: Dictionary = raw
		for raw_id in data.keys():
			var item_data := _sanitize_item_data(data[raw_id])
			var item_id := _get_item_id(item_data)
			if item_id != "":
				_collected_items[item_id] = item_data
				_known_items[item_id] = item_data
	elif typeof(raw) == TYPE_ARRAY:
		for raw_item in raw:
			var item_data := _sanitize_item_data(raw_item)
			var item_id := _get_item_id(item_data)
			if item_id != "":
				_collected_items[item_id] = item_data
				_known_items[item_id] = item_data


func open_item_screen(item_data: Dictionary) -> void:
	var popup := _ensure_popup()
	if popup != null and popup.has_method("show_item"):
		popup.call("show_item", _sanitize_item_data(item_data))


func open_inventory_screen() -> void:
	var popup := _ensure_popup()
	if popup != null and popup.has_method("show_inventory"):
		popup.call("show_inventory", get_collected_items())


func _ensure_popup() -> CanvasLayer:
	if is_instance_valid(_active_popup):
		return _active_popup
	_active_popup = POPUP_SCENE.instantiate() as CanvasLayer
	if _active_popup == null:
		return null
	get_tree().root.add_child(_active_popup)
	_active_popup.tree_exited.connect(func() -> void:
		_active_popup = null
	)
	return _active_popup


func _sanitize_item_data(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = raw
	return {
		"id": String(data.get("id", "")).strip_edges(),
		"title": String(data.get("title", "Objeto sin nombre")).strip_edges(),
		"description": String(data.get("description", "")).strip_edges(),
		"sprite_path": String(data.get("sprite_path", "")).strip_edges(),
	}


func _get_item_id(item_data: Dictionary) -> String:
	return String(item_data.get("id", "")).strip_edges()
