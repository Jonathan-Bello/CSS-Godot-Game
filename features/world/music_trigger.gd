extends Area2D
class_name MusicTrigger

@export var music_stream: AudioStream
@export var player_group: StringName = &"player"
@export_range(-48.0, 6.0, 0.5) var volume_db: float = -9.0
@export_range(0.0, 5.0, 0.05) var fade_time: float = 0.7
@export var play_once: bool = false
@export var stop_on_exit: bool = false

var _played := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if play_once and _played:
		return
	if not body.is_in_group(player_group):
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_music(music_stream, fade_time, volume_db)
	_played = true

func _on_body_exited(body: Node) -> void:
	if not stop_on_exit:
		return
	if not body.is_in_group(player_group):
		return
	if has_node("/root/AudioManager"):
		AudioManager.stop_music(fade_time)
