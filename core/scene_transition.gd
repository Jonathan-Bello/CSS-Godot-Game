extends CanvasLayer

const DEFAULT_FADE_TIME := 0.35

var pending_spawn_marker := ""
var _is_transitioning := false
var _fade_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)

func transition_to_scene(scene_path: String, spawn_marker: String = "", fade_time: float = DEFAULT_FADE_TIME, music_stream: AudioStream = null, music_volume_db: float = -9.0, music_fade_time: float = 0.55) -> void:
	if _is_transitioning or scene_path == "":
		return
	_is_transitioning = true
	pending_spawn_marker = spawn_marker
	await fade_out(fade_time)
	if has_node("/root/AudioManager") and music_stream != null:
		AudioManager.play_music(music_stream, music_fade_time, music_volume_db)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	_apply_pending_spawn()
	await fade_in(fade_time)
	_is_transitioning = false

func fade_out(duration: float = DEFAULT_FADE_TIME) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = DEFAULT_FADE_TIME) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, duration)
	await tween.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func apply_pending_spawn() -> void:
	_apply_pending_spawn()

func _apply_pending_spawn() -> void:
	if pending_spawn_marker == "":
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var marker := scene.find_child(pending_spawn_marker, true, false) as Node2D
	var player := scene.get_tree().get_first_node_in_group("player") as Node2D
	if marker == null or player == null:
		push_warning("[SceneTransition] No se pudo aplicar spawn '%s'." % pending_spawn_marker)
		return
	player.global_position = marker.global_position
	if player.has_method("set_respawn_checkpoint"):
		player.call("set_respawn_checkpoint", marker.global_position)
	pending_spawn_marker = ""
