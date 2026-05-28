extends Node
class_name LevelBootstrap

@export var start_music: AudioStream
@export_range(-48.0, 6.0, 0.5) var music_volume_db: float = -9.0
@export_range(0.0, 5.0, 0.05) var music_fade_time: float = 0.6
@export var default_spawn_marker: StringName = &"PlayerStart"
@export var level_id: String = ""
@export_multiline var level_objective: String = ""

func _ready() -> void:
	if has_node("/root/EmisGameContext"):
		var resolved_level := level_id.strip_edges()
		if resolved_level == "":
			resolved_level = get_tree().current_scene.scene_file_path.get_file().get_basename()
		EmisGameContext.update_level(resolved_level, level_objective)
	if has_node("/root/AudioManager") and start_music != null:
		AudioManager.play_music(start_music, music_fade_time, music_volume_db)
	if has_node("/root/SceneTransition"):
		if SceneTransition.pending_spawn_marker == "":
			SceneTransition.pending_spawn_marker = String(default_spawn_marker)
		SceneTransition.apply_pending_spawn()
