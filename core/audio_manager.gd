extends Node

const DEFAULT_MUSIC_FADE := 0.45
const DEFAULT_MUSIC_VOLUME_DB := -9.0
const DEFAULT_SFX_VOLUME_DB := -4.0

var _music_player: AudioStreamPlayer = null
var _music_tween: Tween = null
var _current_music_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_player()

func play_music(stream: AudioStream, fade_time: float = DEFAULT_MUSIC_FADE, volume_db: float = DEFAULT_MUSIC_VOLUME_DB) -> void:
	if stream == null:
		stop_music(fade_time)
		return
	_ensure_music_player()
	var next_path := stream.resource_path
	if _music_player.playing and _current_music_path == next_path:
		_fade_music_to(volume_db, fade_time)
		return
	if _music_tween:
		_music_tween.kill()
	_configure_music_loop(stream)
	_music_player.stream = stream
	_music_player.volume_db = -80.0 if fade_time > 0.0 else volume_db
	_music_player.play()
	_current_music_path = next_path
	_fade_music_to(volume_db, fade_time)

func stop_music(fade_time: float = DEFAULT_MUSIC_FADE) -> void:
	if _music_player == null or not _music_player.playing:
		_current_music_path = ""
		return
	if _music_tween:
		_music_tween.kill()
	if fade_time <= 0.0:
		_music_player.stop()
		_current_music_path = ""
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
	_music_tween.tween_callback(_finish_music_stop)

func play_sfx(stream: AudioStream, volume_db: float = DEFAULT_SFX_VOLUME_DB, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
	return player

func play_sfx_at(stream: AudioStream, global_position: Vector2, volume_db: float = DEFAULT_SFX_VOLUME_DB, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	if stream == null:
		return null
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = global_position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(player)
	player.play()
	return player

func _ensure_music_player() -> void:
	if _music_player != null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

func _fade_music_to(volume_db: float, fade_time: float) -> void:
	if _music_tween:
		_music_tween.kill()
	if fade_time <= 0.0:
		_music_player.volume_db = volume_db
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", volume_db, fade_time)

func _finish_music_stop() -> void:
	if _music_player:
		_music_player.stop()
	_current_music_path = ""

func _configure_music_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
