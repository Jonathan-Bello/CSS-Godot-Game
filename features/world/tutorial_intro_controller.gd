extends Node
class_name TutorialIntroController

@export var player_group: StringName = &"player"
@export var camera_path: NodePath = ^"../Player/Camera2D"
@export var intro_lines: PackedStringArray = PackedStringArray([
	"Ey! Eso fue una caida fuerte. Me escuchas?",
	"Soy Hemis. Antes de avanzar: muevete con A y D, y salta con Espacio.",
	"Sube con calma hasta el pilar solar. Ahi te explico como usar CSS para alterar el mundo."
])
@export_range(0.0, 2800.0, 25.0) var impact_velocity_threshold: float = 750.0
@export_range(0.0, 2.0, 0.05) var dialogue_delay: float = 0.35
@export_range(0.0, 2.0, 0.05) var shake_duration: float = 0.45
@export_range(0.0, 80.0, 1.0) var shake_strength: float = 30.0
@export var impact_sfx: AudioStream = preload("res://assets/sfx/stomp.ogg")

var _player: CharacterBody2D
var _camera: Camera2D
var _camera_base_offset := Vector2.ZERO
var _was_on_floor := false
var _last_vertical_velocity := 0.0
var _impact_triggered := false
var _shake_time_left := 0.0


func _ready() -> void:
	if has_node("/root/GameSave") and GameSave.has_method("is_loading_saved_game") and bool(GameSave.call("is_loading_saved_game")):
		_impact_triggered = true
		set_physics_process(false)
		set_process(false)
		return
	call_deferred("_bind_runtime_nodes")


func _physics_process(_delta: float) -> void:
	if _impact_triggered or _player == null:
		return
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor and _last_vertical_velocity >= impact_velocity_threshold:
		_trigger_intro_impact()
	_was_on_floor = on_floor
	_last_vertical_velocity = _player.velocity.y


func _process(delta: float) -> void:
	if _shake_time_left <= 0.0 or _camera == null:
		return
	_shake_time_left = maxf(0.0, _shake_time_left - delta)
	if _shake_time_left <= 0.0:
		_camera.offset = _camera_base_offset
		return
	var ratio := _shake_time_left / maxf(shake_duration, 0.001)
	_camera.offset = _camera_base_offset + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	) * ratio


func _bind_runtime_nodes() -> void:
	_player = get_tree().get_first_node_in_group(player_group) as CharacterBody2D
	_camera = get_node_or_null(camera_path) as Camera2D
	if _camera != null:
		_camera_base_offset = _camera.offset
	if _player != null:
		_was_on_floor = _player.is_on_floor()
		_last_vertical_velocity = _player.velocity.y


func _trigger_intro_impact() -> void:
	_impact_triggered = true
	_shake_time_left = shake_duration
	_play_impact_sfx()
	_show_intro_dialog_after_delay()


func _show_intro_dialog_after_delay() -> void:
	if dialogue_delay > 0.0:
		await get_tree().create_timer(dialogue_delay).timeout
	var hud := get_tree().get_first_node_in_group("main_hud")
	if hud != null and hud.has_method("start_hemis_tutorial_dialog"):
		hud.call("start_hemis_tutorial_dialog", intro_lines, true)


func _play_impact_sfx() -> void:
	if impact_sfx == null:
		return
	var impact_position := _player.global_position if _player != null else Vector2.ZERO
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(impact_sfx, impact_position, -3.0, 0.88)
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = impact_sfx
	player.volume_db = -3.0
	player.pitch_scale = 0.88
	player.global_position = impact_position
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
