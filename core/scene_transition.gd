extends CanvasLayer

const DEFAULT_FADE_TIME := 0.35
const STATIC_TEXTURE_SIZE := Vector2i(192, 108)
const STATIC_REFRESH_TIME := 0.035

var pending_spawn_marker := ""
var pending_spawn_position := Vector2.ZERO
var has_pending_spawn_position := false
var _is_transitioning := false
var _fade_rect: ColorRect
var _static_rect: TextureRect
var _static_rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)
	_static_rng.randomize()
	_static_rect = TextureRect.new()
	_static_rect.name = "StaticRect"
	_static_rect.expand_mode = TextureRect.ExpandMode.EXPAND_IGNORE_SIZE
	_static_rect.stretch_mode = TextureRect.StretchMode.STRETCH_SCALE
	_static_rect.modulate = Color(1, 1, 1, 0.0)
	_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_static_rect)

func transition_to_scene(scene_path: String, spawn_marker: String = "", fade_time: float = DEFAULT_FADE_TIME, music_stream: AudioStream = null, music_volume_db: float = -9.0, music_fade_time: float = 0.55) -> void:
	await _transition_to_scene(scene_path, spawn_marker, fade_time, music_stream, music_volume_db, music_fade_time, false, 0.0)

func transition_to_scene_with_static(scene_path: String, spawn_marker: String = "", fade_time: float = 0.85, static_hold_time: float = 0.45, music_stream: AudioStream = null, music_volume_db: float = -9.0, music_fade_time: float = 0.55) -> void:
	await _transition_to_scene(scene_path, spawn_marker, fade_time, music_stream, music_volume_db, music_fade_time, true, static_hold_time)

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

func set_pending_spawn_position(position: Vector2) -> void:
	pending_spawn_position = position
	has_pending_spawn_position = true
	pending_spawn_marker = ""

func _transition_to_scene(scene_path: String, spawn_marker: String, fade_time: float, music_stream: AudioStream, music_volume_db: float, music_fade_time: float, use_static: bool, static_hold_time: float) -> void:
	scene_path = _normalize_scene_path(scene_path)
	if _is_transitioning or scene_path == "":
		return
	_is_transitioning = true
	pending_spawn_marker = spawn_marker
	await _set_static_visible(use_static)
	await fade_out(fade_time)
	if use_static:
		await _hold_static(static_hold_time)
	if has_node("/root/AudioManager") and music_stream != null:
		AudioManager.play_music(music_stream, music_fade_time, music_volume_db)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	_apply_pending_spawn()
	if use_static:
		await _hold_static(static_hold_time * 0.5)
	await fade_in(fade_time)
	await _set_static_visible(false)
	_is_transitioning = false

func _normalize_scene_path(scene_path: String) -> String:
	match scene_path:
		"res://content/levels/city_main.tscn":
			return "res://content/levels/citadel_main.tscn"
		_:
			return scene_path

func _set_static_visible(should_show: bool) -> void:
	if _static_rect == null:
		return
	if not should_show and _static_rect.modulate.a <= 0.0:
		_static_rect.visible = false
		return
	if should_show:
		_static_rect.texture = _make_static_texture()
		_static_rect.visible = true
	var target_alpha := 0.0
	if should_show:
		target_alpha = 0.32
	var tween := create_tween()
	tween.tween_property(_static_rect, "modulate:a", target_alpha, 0.12)
	await tween.finished
	if not should_show:
		_static_rect.visible = false

func _hold_static(duration: float) -> void:
	if _static_rect == null or duration <= 0.0:
		return
	var elapsed := 0.0
	while elapsed < duration:
		_static_rect.texture = _make_static_texture()
		var wait_time: float = min(STATIC_REFRESH_TIME, duration - elapsed)
		await get_tree().create_timer(wait_time, false).timeout
		elapsed += wait_time

func _make_static_texture() -> ImageTexture:
	var image := Image.create(STATIC_TEXTURE_SIZE.x, STATIC_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in STATIC_TEXTURE_SIZE.y:
		for x in STATIC_TEXTURE_SIZE.x:
			var value: float = 1.0 if _static_rng.randf() > 0.5 else 0.0
			var alpha: float = _static_rng.randf_range(0.08, 0.38)
			image.set_pixel(x, y, Color(value, value, value, alpha))
	return ImageTexture.create_from_image(image)

func _apply_pending_spawn() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	print("[SceneTransition] _apply_pending_spawn: pending_spawn_marker='%s', has_pending_spawn_position=%s, pending_spawn_position=%s" % [pending_spawn_marker, has_pending_spawn_position, pending_spawn_position])
	if has_pending_spawn_position:
		player.global_position = pending_spawn_position
		print("[SceneTransition] Aplicando posición: %s" % pending_spawn_position)
		if player.has_method("set_respawn_checkpoint"):
			player.call("set_respawn_checkpoint", pending_spawn_position)
		has_pending_spawn_position = false
		pending_spawn_position = Vector2.ZERO
		pending_spawn_marker = ""
		return
	if pending_spawn_marker == "":
		return
	var marker := scene.find_child(pending_spawn_marker, true, false) as Node2D
	if marker == null:
		push_warning("[SceneTransition] No se pudo aplicar spawn '%s'." % pending_spawn_marker)
		print("[SceneTransition] Player posición actual: %s" % player.global_position)
		return
	print("[SceneTransition] Encontrado marcador '%s' en posición: %s" % [pending_spawn_marker, marker.global_position])
	player.global_position = marker.global_position
	print("[SceneTransition] Jugador reposicionado a: %s" % marker.global_position)
	if player.has_method("set_respawn_checkpoint"):
		player.call("set_respawn_checkpoint", marker.global_position)
	pending_spawn_marker = ""
