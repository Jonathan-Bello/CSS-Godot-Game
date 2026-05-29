extends Area2D
class_name HemisDialogTrigger

@export_multiline var dialog_lines: PackedStringArray = PackedStringArray(["Bienvenido. Usa este punto para iniciar tutoriales de Hemis."])
@export var one_shot: bool = true
@export var stop_player_during_dialog: bool = true
@export var require_manual_interaction: bool = false
@export var interaction_action: StringName = &"ui_accept"
@export_group("Hemis Context")
@export var zone_id: String = ""
@export var quest_id: String = ""
@export var quest_step: String = ""
@export_multiline var objective: String = ""
@export_multiline var area_description: String = ""
@export_multiline var recent_event: String = ""

var _triggered := false
var _player_inside := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	if one_shot and _is_persistent_trigger_heard():
		_triggered = true
		monitoring = false
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if not require_manual_interaction or not _player_inside or _triggered:
		return
	if Input.is_action_just_pressed(interaction_action):
		_fire_trigger()

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body is CharacterBody2D:
		return
	_player_inside = true
	if not require_manual_interaction:
		_fire_trigger()

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_inside = false

func _fire_trigger() -> void:
	_update_hemis_context()
	var hud := get_tree().get_first_node_in_group("main_hud")
	if hud == null or not hud.has_method("start_hemis_tutorial_dialog"):
		push_warning("[HemisDialogTrigger] No se encontró MainHUD con start_hemis_tutorial_dialog().")
		return
	hud.call("start_hemis_tutorial_dialog", dialog_lines, stop_player_during_dialog)
	if one_shot:
		_triggered = true
		_mark_persistent_trigger_heard()
		set_deferred("monitoring", false)

func _update_hemis_context() -> void:
	if not has_node("/root/HemisGameContext"):
		return
	var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var scene_id := scene_path.get_file().get_basename() if scene_path != "" else ""
	var first_line := ""
	if not dialog_lines.is_empty():
		first_line = String(dialog_lines[0]).strip_edges()
	HemisGameContext.update_from_trigger({
		"screen": "world",
		"level": scene_id,
		"zone_id": zone_id if zone_id.strip_edges() != "" else scene_id,
		"quest_id": quest_id if quest_id.strip_edges() != "" else name,
		"quest_step": quest_step if quest_step.strip_edges() != "" else "trigger_%s" % name,
		"objective": objective,
		"current_area_description": area_description,
		"current_dialog_context": first_line,
		"recent_event": recent_event if recent_event.strip_edges() != "" else "Hemis acaba de hablar con el jugador en %s." % name
	})

func _get_persistent_trigger_id() -> String:
	var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	return "%s::%s" % [scene_path, str(get_path())]

func _is_persistent_trigger_heard() -> bool:
	if not has_node("/root/GameSave") or not GameSave.has_method("is_dialog_trigger_heard"):
		return false
	return bool(GameSave.call("is_dialog_trigger_heard", _get_persistent_trigger_id()))

func _mark_persistent_trigger_heard() -> void:
	if has_node("/root/GameSave") and GameSave.has_method("mark_dialog_trigger_heard"):
		GameSave.call("mark_dialog_trigger_heard", _get_persistent_trigger_id())
