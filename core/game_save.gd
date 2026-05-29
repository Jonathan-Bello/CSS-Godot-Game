extends Node

const SAVE_PATH := "user://save/game_save.json"
const MAIN_MENU_SCENE := "res://features/ui/main_menu.tscn"
const RESET_DIRS := [
	"user://bullets",
	"user://progress",
	"user://save"
]

var _loading_saved_game := false
var _heard_dialog_triggers := {}
var _activated_solar_pillars := {}
var _pending_player_position := Vector2.ZERO
var _has_pending_player_position := false
var _pending_bullet_save_data := {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func is_loading_saved_game() -> bool:
	return _loading_saved_game

func reset_new_game_state() -> void:
	_loading_saved_game = false
	_heard_dialog_triggers.clear()
	_activated_solar_pillars.clear()
	_clear_pending_player_position()
	_pending_bullet_save_data.clear()
	for path in RESET_DIRS:
		_remove_dir_recursive(path)
	if has_node("/root/CssUnlocks") and CssUnlocks.has_method("reset_unlocks"):
		CssUnlocks.call("reset_unlocks")
	if has_node("/root/MovementUnlocks") and MovementUnlocks.has_method("reset_unlocks"):
		MovementUnlocks.call("reset_unlocks")

func save_current_game(player_override: Node2D = null) -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "" or scene.scene_file_path == MAIN_MENU_SCENE:
		return false
	var player := player_override
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false

	var dir_path := "user://save"
	var mkdir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		push_warning("[GameSave] No se pudo crear directorio save. err=%s" % mkdir_err)
		return false

	var payload := {
		"__version": 1,
		"scene_path": scene.scene_file_path,
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"equipped_bullet": _get_player_bullet_save_data(player),
		"heard_dialog_triggers": _heard_dialog_triggers.duplicate(true),
		"activated_solar_pillars": _activated_solar_pillars.duplicate(true),
		"saved_at": Time.get_datetime_string_from_system(true, true)
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[GameSave] No se pudo abrir archivo de guardado.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	print("[GameSave] Partida guardada en %s" % ProjectSettings.globalize_path(SAVE_PATH))
	return true

func load_saved_game() -> bool:
	var data := _read_save()
	var scene_path := _normalize_scene_path(String(data.get("scene_path", "")))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return false
	var position := _position_from_save(data.get("player_position", {}))
	_load_heard_dialog_triggers(data.get("heard_dialog_triggers", {}))
	_load_activated_solar_pillars(data.get("activated_solar_pillars", {}))
	_set_pending_player_position(position)
	_set_pending_bullet_save_data(data.get("equipped_bullet", {}))
	_loading_saved_game = true
	if has_node("/root/SceneTransition"):
		if SceneTransition.has_method("set_pending_spawn_position"):
			SceneTransition.call("set_pending_spawn_position", position)
		if SceneTransition.has_method("transition_to_scene_with_static"):
			await SceneTransition.transition_to_scene_with_static(scene_path, "", 0.85, 0.45)
		else:
			await SceneTransition.transition_to_scene(scene_path, "", 0.85)
	else:
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
	_apply_saved_player_position(position)
	_apply_saved_player_bullet()
	_clear_pending_player_position()
	_pending_bullet_save_data.clear()
	_loading_saved_game = false
	return true

func _normalize_scene_path(scene_path: String) -> String:
	match scene_path:
		"res://content/levels/city_main.tscn":
			return "res://content/levels/citadel_main.tscn"
		_:
			return scene_path

func is_dialog_trigger_heard(trigger_id: String) -> bool:
	var key := trigger_id.strip_edges()
	return key != "" and bool(_heard_dialog_triggers.get(key, false))

func mark_dialog_trigger_heard(trigger_id: String) -> void:
	var key := trigger_id.strip_edges()
	if key == "":
		return
	_heard_dialog_triggers[key] = true

func is_solar_pillar_activated(pillar_id: String) -> bool:
	var key := pillar_id.strip_edges()
	return key != "" and bool(_activated_solar_pillars.get(key, false))

func mark_solar_pillar_activated(pillar_id: String) -> void:
	var key := pillar_id.strip_edges()
	if key == "":
		return
	_activated_solar_pillars[key] = true

func apply_pending_player_position(player: Node2D) -> bool:
	if player == null or not _has_pending_player_position:
		return false
	player.global_position = _pending_player_position
	if player.has_method("set_respawn_checkpoint"):
		player.call("set_respawn_checkpoint", _pending_player_position)
	if not _pending_bullet_save_data.is_empty() and player.has_method("restore_equipped_bullet_from_save"):
		player.call("restore_equipped_bullet_from_save", _pending_bullet_save_data)
	return true

func save_and_return_to_menu() -> void:
	save_current_game()
	get_tree().paused = false
	if has_node("/root/SceneTransition"):
		await SceneTransition.transition_to_scene(MAIN_MENU_SCENE, "", 0.25)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _position_from_save(raw: Variant) -> Vector2:
	if typeof(raw) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var data: Dictionary = raw
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))

func _load_heard_dialog_triggers(raw: Variant) -> void:
	_heard_dialog_triggers.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	for raw_key in data.keys():
		var key := String(raw_key).strip_edges()
		if key != "":
			_heard_dialog_triggers[key] = bool(data[raw_key])

func _load_activated_solar_pillars(raw: Variant) -> void:
	_activated_solar_pillars.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var data: Dictionary = raw
	for raw_key in data.keys():
		var key := String(raw_key).strip_edges()
		if key != "":
			_activated_solar_pillars[key] = bool(data[raw_key])

func _set_pending_player_position(position: Vector2) -> void:
	_pending_player_position = position
	_has_pending_player_position = true

func _clear_pending_player_position() -> void:
	_pending_player_position = Vector2.ZERO
	_has_pending_player_position = false

func _set_pending_bullet_save_data(raw: Variant) -> void:
	_pending_bullet_save_data.clear()
	if typeof(raw) == TYPE_DICTIONARY:
		_pending_bullet_save_data = raw

func _apply_saved_player_position(position: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	player.global_position = position
	if player.has_method("set_respawn_checkpoint"):
		player.call("set_respawn_checkpoint", position)

func _apply_saved_player_bullet() -> void:
	if _pending_bullet_save_data.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("restore_equipped_bullet_from_save"):
		return
	player.call("restore_equipped_bullet_from_save", _pending_bullet_save_data)

func _get_player_bullet_save_data(player: Node2D) -> Dictionary:
	if player == null or not player.has_method("get_equipped_bullet_save_data"):
		return {}
	var raw: Variant = player.call("get_equipped_bullet_save_data")
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw

func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if dir.current_is_dir():
				_remove_dir_recursive(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
