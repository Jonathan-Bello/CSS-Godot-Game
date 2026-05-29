extends Area2D
class_name RouteGate

@export var player_group: StringName = &"player"
@export var target_path: NodePath
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_marker: StringName = &"PlayerStart"
@export var gate_sfx: AudioStream = preload("res://assets/sfx/teleport_02.ogg")
@export var target_music: AudioStream
@export_range(-48.0, 6.0, 0.5) var music_volume_db: float = -9.0
@export_range(0.0, 5.0, 0.05) var music_fade_time: float = 0.55
@export_range(0.0, 2.0, 0.05) var scene_fade_time: float = 0.35

var _cooldown := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _cooldown or not body.is_in_group(player_group):
		return
	_cooldown = true
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(gate_sfx, global_position, -7.0)
	if target_scene != "":
		var resolved_target_scene := _normalize_scene_path(target_scene)
		if has_node("/root/SceneTransition"):
			await SceneTransition.transition_to_scene(resolved_target_scene, String(target_spawn_marker), scene_fade_time, target_music, music_volume_db, music_fade_time)
		else:
			get_tree().change_scene_to_file(resolved_target_scene)
		_cooldown = false
		return

	var target := get_node_or_null(target_path) as Node2D
	if target == null:
		push_warning("[RouteGate] No target found at %s." % target_path)
		_cooldown = false
		return
	if has_node("/root/AudioManager"):
		if target_music != null:
			AudioManager.play_music(target_music, music_fade_time, music_volume_db)
	body.global_position = target.global_position
	if body.has_method("set_respawn_checkpoint"):
		body.call("set_respawn_checkpoint", target.global_position)
	await get_tree().create_timer(0.35).timeout
	_cooldown = false

func _normalize_scene_path(scene_path: String) -> String:
	match scene_path:
		"res://content/levels/city_main.tscn":
			return "res://content/levels/citadel_main.tscn"
		_:
			return scene_path
