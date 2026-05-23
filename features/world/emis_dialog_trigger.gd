extends Area2D
class_name EmisDialogTrigger

@export_multiline var dialog_lines: PackedStringArray = PackedStringArray(["Bienvenido. Usa este punto para iniciar tutoriales de Emis."])
@export var one_shot: bool = true
@export var stop_player_during_dialog: bool = true
@export var require_manual_interaction: bool = false
@export var interaction_action: StringName = &"ui_accept"

var _triggered := false
var _player_inside := false

func _ready() -> void:
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
	var hud := get_tree().get_first_node_in_group("main_hud")
	if hud == null or not hud.has_method("start_emis_tutorial_dialog"):
		push_warning("[EmisDialogTrigger] No se encontró MainHUD con start_emis_tutorial_dialog().")
		return
	hud.call("start_emis_tutorial_dialog", dialog_lines, stop_player_during_dialog)
	if one_shot:
		_triggered = true
		set_deferred("monitoring", false)
