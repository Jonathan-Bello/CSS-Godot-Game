extends Node

const BULLET_PROFILE_PATH := "user://bullets/bullet_current.json"

var _api_key: String = ""
var _context: Dictionary = {
	"screen": "world",
	"level": "",
	"zone_id": "",
	"quest_id": "",
	"quest_step": "",
	"objective": "Explorar la zona actual y completar el siguiente reto.",
	"current_area_description": "",
	"current_dialog_context": "",
	"recent_event": "",
	"level_context_document": "",
	"assistant_mode": "gameplay_helper",
	"helper_context": "",
	"runtime_environment": ""
}

func _ready() -> void:
	_context["runtime_environment"] = get_runtime_environment()

func set_api_key(value: String) -> void:
	_api_key = value.strip_edges()

func clear_api_key() -> void:
	_api_key = ""

func get_api_key() -> String:
	if _api_key != "":
		return _api_key
	var web_key := _read_web_api_key()
	if web_key != "":
		_api_key = web_key
		return _api_key
	return ""

func has_api_key() -> bool:
	return get_api_key() != ""

func is_web_runtime() -> bool:
	if has_node("/root/RuntimeEnvironment") and RuntimeEnvironment.has_method("is_web"):
		return bool(RuntimeEnvironment.call("is_web"))
	return OS.has_feature("web")

func get_runtime_environment() -> String:
	if has_node("/root/RuntimeEnvironment") and RuntimeEnvironment.has_method("detect"):
		return String(RuntimeEnvironment.call("detect"))
	if is_web_runtime():
		return "web"
	if OS.has_feature("editor"):
		return "editor"
	return "desktop"

func _read_web_api_key() -> String:
	if not OS.has_feature("web"):
		return ""
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return ""
	var value: Variant = bridge.call("eval", "String(window.HEMIS_PLAYER_API_KEY || window.EMIS_PLAYER_API_KEY || '')", true)
	return String(value).strip_edges()

func update_level(level_id: String, objective: String = "") -> void:
	var clean_level := level_id.strip_edges()
	if clean_level != "":
		_context["level"] = clean_level
		_context["zone_id"] = clean_level
	if objective.strip_edges() != "":
		_context["objective"] = objective.strip_edges()
	_context["screen"] = "world"

func set_level_context_document(text: String) -> void:
	_context["level_context_document"] = text.strip_edges().left(8000)

func set_level_context_document_from_file(path: String) -> void:
	var clean_path := path.strip_edges()
	if clean_path == "":
		set_level_context_document("")
		return
	if not FileAccess.file_exists(clean_path):
		push_warning("[HemisGameContext] No existe documento de contexto: %s" % clean_path)
		set_level_context_document("")
		return
	var file := FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		push_warning("[HemisGameContext] No se pudo leer documento de contexto: %s" % clean_path)
		set_level_context_document("")
		return
	set_level_context_document(file.get_as_text())

func update_from_trigger(data: Dictionary) -> void:
	for key in data.keys():
		var value: Variant = data[key]
		if value is String:
			var clean := String(value).strip_edges()
			if clean != "":
				_context[String(key)] = clean
		elif value is Array or value is PackedStringArray:
			_context[String(key)] = value
	_context["screen"] = String(_context.get("screen", "world"))

func get_context() -> Dictionary:
	var snapshot := _context.duplicate(true)
	snapshot["runtime_environment"] = get_runtime_environment()
	snapshot["movement_unlocks"] = _read_movement_unlocks()
	snapshot["active_bullet"] = _read_active_bullet_context()
	return snapshot

func _read_movement_unlocks() -> Dictionary:
	var movement := get_node_or_null("/root/MovementUnlocks")
	if movement != null and movement.has_method("get_unlock_state"):
		var raw: Variant = movement.call("get_unlock_state")
		if typeof(raw) == TYPE_DICTIONARY:
			return raw
	return {}

func _read_active_bullet_context() -> Dictionary:
	if not FileAccess.file_exists(BULLET_PROFILE_PATH):
		return {}
	var file := FileAccess.open(BULLET_PROFILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var profile: Dictionary = parsed
	return {
		"css_text": String(profile.get("css_text", "")).left(1200),
		"css_rules": profile.get("css_rules", []),
		"css_properties": profile.get("css_properties", {}),
		"updated_at": String(profile.get("updated_at", ""))
	}
