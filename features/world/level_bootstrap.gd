extends Node
class_name LevelBootstrap

@export var start_music: AudioStream
@export_range(-48.0, 6.0, 0.5) var music_volume_db: float = -9.0
@export_range(0.0, 5.0, 0.05) var music_fade_time: float = 0.6
@export var default_spawn_marker: StringName = &"PlayerStart"
@export var level_id: String = ""
@export_multiline var level_objective: String = ""
@export_file("*.md") var hemis_context_document: String = ""

func _ready() -> void:
	if has_node("/root/HemisGameContext"):
		var resolved_level := level_id.strip_edges()
		if resolved_level == "":
			resolved_level = get_tree().current_scene.scene_file_path.get_file().get_basename()
		HemisGameContext.update_level(resolved_level, level_objective)
		if HemisGameContext.has_method("set_level_context_document_from_file"):
			HemisGameContext.call("set_level_context_document_from_file", hemis_context_document)
	if has_node("/root/AudioManager") and start_music != null:
		AudioManager.play_music(start_music, music_fade_time, music_volume_db)
	if has_node("/root/SceneTransition"):
		if has_node("/root/GameSave") and GameSave.has_method("is_loading_saved_game") and bool(GameSave.call("is_loading_saved_game")):
			return
		if SceneTransition.pending_spawn_marker == "":
			SceneTransition.pending_spawn_marker = String(default_spawn_marker)
		SceneTransition.apply_pending_spawn()
