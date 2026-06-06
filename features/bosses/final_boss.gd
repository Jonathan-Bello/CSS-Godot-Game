extends CharacterBody2D
class_name FinalBoss

signal health_changed(current: float, maximum: float)
signal defeated

## Nombre que se muestra en la barra de vida y en el dialogo inicial.
@export var boss_name: String = "Nucleo de la Ciudadela"
## Vida total del jefe. Las fases se calculan como porcentaje de este valor.
@export var max_health: float = 180.0
## Grupo donde se busca al jugador para deteccion, fijar objetivo y bloqueo de control.
@export var player_group: StringName = &"player"
## AnimationPlayer del esqueleto del jefe.
@export var animation_player_path: NodePath = ^"AnimationPlayer"

@export_group("Dialogo inicial")
## Si esta activo, el jefe habla antes de iniciar el patron de combate.
@export var intro_dialog_enabled: bool = true
## Lineas que dice el jefe al detectar al jugador.
@export var intro_dialog_lines: PackedStringArray = PackedStringArray(["INTRUSO DETECTADO.", "Protocolo de defensa final activado."])
## Tiempo que cada linea permanece en pantalla antes de iniciar el combate.
@export_range(0.2, 8.0, 0.05) var intro_dialog_duration_per_line: float = 1.45
## Bloquea el movimiento del jugador mientras se muestra el dialogo del jefe.
@export var lock_player_during_intro: bool = true

@export_group("Deteccion")
## Permite que el jefe arranque solo si el jugador entra en rango. Desactivalo si lo inicia una arena.
@export var auto_start_on_player_range: bool = true
## Distancia de activacion cuando auto_start_on_player_range esta activo.
@export_range(200.0, 2400.0, 10.0) var detection_range: float = 1150.0

@export_group("Arena y caida")
## Si esta activo, el jefe usa manual_arena_left_x/right_x para limitar donde puede caer.
@export var use_manual_arena_limits: bool = false
## Limite izquierdo de la arena en coordenadas globales.
@export var manual_arena_left_x: float = 4200.0
## Limite derecho de la arena en coordenadas globales.
@export var manual_arena_right_x: float = 7800.0
## Si no usas limites manuales, esta es la mitad del ancho de arena desde la posicion inicial del jefe.
@export_range(320.0, 7000.0, 10.0) var max_target_distance_from_home: float = 2200.0
## Si lo asignas, la Y global de este Marker2D/Node2D sera el suelo donde cae el jefe.
@export var landing_marker_path: NodePath
## Activa un valor manual de suelo para que el jefe no quede flotando si su escena esta colocada alta.
@export var use_landing_y_override: bool = false
## Y global exacta donde el jefe debe aterrizar cuando use_landing_y_override esta activo.
@export var landing_y_override: float = 500.0

@export_group("Ataque de salto")
## Pausa corta antes de brincar. Sube esto si quieres que el salto sea mas telegrafiado.
@export_range(0.0, 1.2, 0.05) var pre_jump_delay: float = 0.32
## Altura a la que se va el jefe cuando sale de pantalla.
@export_range(500.0, 2600.0, 25.0) var offscreen_jump_height: float = 1450.0
## Altura desde la que reaparece para caer sobre el aviso.
@export_range(500.0, 2600.0, 25.0) var fall_start_height: float = 1350.0
## Duracion del salto hacia arriba.
@export_range(0.08, 0.8, 0.01) var jump_out_time: float = 0.26
## Duracion de la caida. Menor valor = caida mas brusca.
@export_range(0.08, 0.8, 0.01) var fall_time: float = 0.22
## Tiempo oculto en fase 1 antes del aviso de caida.
@export_range(0.0, 1.5, 0.05) var hidden_time_phase_1: float = 0.8
## Tiempo oculto en fase 2 antes del aviso de caida.
@export_range(0.0, 1.5, 0.05) var hidden_time_phase_2: float = 0.45
## Tiempo oculto en fase 3 antes del aviso de caida.
@export_range(0.0, 1.5, 0.05) var hidden_time_phase_3: float = 0.22
## Tiempo visible de la senal roja antes de que el jefe caiga.
@export_range(0.1, 1.0, 0.01) var warning_time: float = 0.5
## Separacion entre brincos en combos de fase 2 y fase 3.
@export_range(0.0, 0.8, 0.01) var combo_jump_gap: float = 0.16
## Tiempo vulnerable despues de una caida en fase 1.
@export_range(0.1, 3.0, 0.05) var stun_time_phase_1: float = 1.55
## Tiempo vulnerable despues del combo en fase 2.
@export_range(0.1, 3.0, 0.05) var stun_time_phase_2: float = 0.9
## Tiempo vulnerable despues del combo en fase 3.
@export_range(0.1, 3.0, 0.05) var stun_time_phase_3: float = 0.38
## Ancho del area que dana al jugador al caer.
@export_range(16.0, 420.0, 1.0) var crush_radius_x: float = 180.0
## Alto del area que dana al jugador al caer.
@export_range(16.0, 420.0, 1.0) var crush_radius_y: float = 160.0
## Dano de contacto aplicado si el jugador esta bajo la caida.
@export var contact_damage: int = 1

@export_group("Debilidad por lado")
## Color correcto cuando el impacto llega por el lado izquierdo del jefe.
@export var left_side_weak_color: String = "red"
## Color correcto cuando el impacto llega por el lado derecho del jefe.
@export var right_side_weak_color: String = "blue"
## Dano si el color coincide con el lado vulnerable.
@export_range(1.0, 60.0, 1.0) var weak_spot_damage: float = 22.0
## Dano minimo si pegas durante stun pero con color incorrecto.
@export_range(0.0, 20.0, 1.0) var wrong_color_damage: float = 3.0

@export_group("Feedback")
## Musica que empieza justo cuando inicia el combate del jefe.
@export var boss_music: AudioStream = preload("res://assets/music/Verdant Circuit.mp3")
## Volumen de la musica del jefe.
@export_range(-48.0, 6.0, 0.5) var boss_music_volume_db: float = -7.5
## Tiempo de fundido para cambiar a musica de jefe.
@export_range(0.0, 5.0, 0.05) var boss_music_fade_time: float = 0.45
## Sonido de encendido al detectar al jugador por primera vez.
@export var activation_sfx: AudioStream = preload("res://assets/sfx/boss/encendido.wav")
## Sonido de cada aterrizaje.
@export var landing_sfx: AudioStream = preload("res://assets/sfx/boss/fall.wav")
## Sonido de destruccion al morir.
@export var destruction_sfx: AudioStream = preload("res://assets/sfx/boss/artil.die.wav")
## Duracion del temblor de camara en caidas normales.
@export_range(0.0, 2.0, 0.05) var shake_duration: float = 0.34
## Intensidad del temblor de camara en caidas normales.
@export_range(0.0, 90.0, 1.0) var shake_strength: float = 34.0
## Duracion del temblor de camara cuando muere.
@export_range(0.0, 2.0, 0.05) var defeat_shake_duration: float = 1.25
## Intensidad del temblor de camara cuando muere.
@export_range(0.0, 120.0, 1.0) var defeat_shake_strength: float = 72.0
## Texto final que aparece despues del flash blanco.
@export var thanks_message: String = "Gracias por jugar"
## Credito mostrado despues del fade a negro.
@export var credits_message: String = "Creado por Jonathan Alexis Bello López"
## Imagenes que se muestran como adelanto despues de los creditos.
@export var teaser_image_paths: PackedStringArray = PackedStringArray([
	"res://assets/art/end_teaser/robot_scout_full.svg",
	"res://assets/art/end_teaser/robot_heavy_full.svg",
	"res://assets/art/end_teaser/robot_sideview.svg",
	"res://assets/art/end_teaser/jefe_final.png",
	"res://assets/art/end_teaser/guardianes_ciudadela.png",
	"res://assets/art/end_teaser/hub.png",
	"res://assets/art/end_teaser/mundo.png",
	"res://assets/art/end_teaser/zona_tienda.png",
	"res://assets/art/end_teaser/xanat_hemis.png"
])
## Tiempo que permanece cada imagen del adelanto.
@export_range(0.4, 8.0, 0.05) var teaser_image_hold_time: float = 2.1
## Tiempo que permanece el mensaje de gracias antes del fundido negro.
@export_range(0.4, 8.0, 0.05) var thanks_hold_time: float = 1.9
## Texto para regresar al titulo despues del adelanto.
@export var continue_prompt: String = "Aplasta E para continuar"
## Accion que confirma el fin del epilogo.
@export var continue_action: StringName = &"interact"
## Escena del titulo a la que se regresa al final.
@export_file("*.tscn") var title_scene: String = "res://features/ui/main_menu.tscn"
## Desplazamiento visual de la senal roja respecto al punto exacto de caida.
@export var warning_marker_offset: Vector2 = Vector2(0.0, 130.0)
## Radio horizontal de la senal roja de caida.
@export_range(24.0, 520.0, 1.0) var warning_marker_radius_x: float = 190.0
## Radio vertical de la senal roja de caida.
@export_range(12.0, 180.0, 1.0) var warning_marker_radius_y: float = 34.0

var current_health: float
var active := false
var defeated_flag := false

var _player: CharacterBody2D = null
var _home_position := Vector2.ZERO
var _pattern_running := false
var _vulnerable := false
var _camera_shake_token := 0
var _active_motion_tween: Tween = null
var _stun_feedback_tween: Tween = null
var _intro_running := false
var _intro_completed := false
var _activation_sfx_played := false

@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer


func _ready() -> void:
	current_health = max_health
	_home_position = global_position
	_set_collision_enabled(false)
	set_process(true)
	_update_hud()
	_hide_boss_bar()


func _process(_delta: float) -> void:
	if active or _intro_running or defeated_flag or not auto_start_on_player_range or not visible:
		return
	_player = _get_player()
	if _player == null:
		return
	if global_position.distance_to(_player.global_position) <= detection_range:
		start_encounter()


func start_encounter() -> void:
	if defeated_flag or active or _intro_running:
		return
	visible = true
	_play_activation_sfx_once()
	_player = _get_player()
	if intro_dialog_enabled and not _intro_completed and not _get_intro_lines().is_empty():
		_intro_running = true
		call_deferred("_run_intro_then_begin_combat")
		return
	_begin_combat()


func _begin_combat() -> void:
	if defeated_flag:
		return
	active = true
	visible = true
	_set_collision_enabled(true)
	_player = _get_player()
	_play_boss_music()
	_update_hud()
	if not _pattern_running:
		call_deferred("_run_attack_pattern")


func _run_intro_then_begin_combat() -> void:
	if defeated_flag:
		_intro_running = false
		return
	_set_collision_enabled(false)
	_lock_player_control(lock_player_during_intro)
	var dialog := _create_boss_dialog_overlay()
	var overlay := dialog.get("overlay") as CanvasLayer
	var line_label := dialog.get("line") as Label
	var lines := _get_intro_lines()
	for line in lines:
		if defeated_flag:
			break
		if line_label != null:
			line_label.text = line
		await _wait(intro_dialog_duration_per_line)
	if is_instance_valid(overlay):
		overlay.queue_free()
	_lock_player_control(false)
	_intro_completed = true
	_intro_running = false
	_begin_combat()


func apply_css_bullet_hit(bullet_profile: Dictionary) -> void:
	if defeated_flag or not active:
		return
	if not _vulnerable:
		_play_hit_feedback(Color(0.45, 0.5, 0.56, 1.0))
		return

	var impact_position := _resolve_impact_position(bullet_profile)
	var required_color := right_side_weak_color if impact_position.x >= global_position.x else left_side_weak_color
	var is_weak_hit := _bullet_has_color(bullet_profile, required_color)
	var damage := weak_spot_damage if is_weak_hit else wrong_color_damage
	if damage <= 0.0:
		_play_hit_feedback(Color(0.45, 0.5, 0.56, 1.0))
		return
	_play_hit_feedback(Color(0.25, 0.55, 1.0, 1.0) if is_weak_hit else Color(1.0, 0.28, 0.22, 1.0))
	take_damage(damage)


func take_damage(amount: float) -> void:
	if defeated_flag:
		return
	current_health = maxf(0.0, current_health - maxf(amount, 0.0))
	_update_hud()
	if current_health <= 0.0:
		_defeat()


func _run_attack_pattern() -> void:
	_pattern_running = true
	while active and not defeated_flag and is_inside_tree():
		var phase := _get_phase()
		var jump_count := _get_jump_count_for_phase(phase)
		for jump_index in range(jump_count):
			if defeated_flag or not active:
				break
			await _perform_crush_jump(phase)
			if jump_index < jump_count - 1:
				await _wait(combo_jump_gap)
		if defeated_flag or not active:
			break
		await _enter_stun(_get_stun_time_for_phase(phase))
	_pattern_running = false


func _perform_crush_jump(phase: int) -> void:
	if _encounter_cancelled():
		return
	_vulnerable = false
	_set_collision_enabled(true)
	_play_anim(&"Pre_Jump")
	await _wait(pre_jump_delay)
	if _encounter_cancelled():
		return

	var target := _get_locked_target_position()
	_play_anim(&"Jump")
	await _move_to(Vector2(target.x, target.y - offscreen_jump_height), jump_out_time, Tween.TRANS_QUAD, Tween.EASE_IN)
	if _encounter_cancelled():
		return
	visible = false
	_set_collision_enabled(false)
	await _wait(_get_hidden_time_for_phase(phase))
	if _encounter_cancelled():
		return

	await _show_landing_warning(target, warning_time)
	if _encounter_cancelled():
		return
	global_position = Vector2(target.x, target.y - fall_start_height)
	visible = true
	_set_collision_enabled(true)
	_play_anim(&"fall")
	await _move_to(target, fall_time, Tween.TRANS_EXPO, Tween.EASE_IN)
	if _encounter_cancelled():
		return
	_play_anim(&"aterrizar")
	_play_landing_feedback(phase)
	_apply_crush_damage()


func _enter_stun(duration: float) -> void:
	if _encounter_cancelled():
		return
	_vulnerable = true
	_play_anim(&"Idle")
	var tw := create_tween()
	_stun_feedback_tween = tw
	tw.set_loops(maxi(1, int(duration / 0.16)))
	tw.tween_property(self, "modulate", Color(1.0, 0.82, 0.48, 1.0), 0.08)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	await _wait(duration)
	if is_instance_valid(tw):
		tw.kill()
	if _stun_feedback_tween == tw:
		_stun_feedback_tween = null
	if _encounter_cancelled():
		return
	modulate = Color.WHITE
	_vulnerable = false


func _get_phase() -> int:
	var ratio := current_health / maxf(max_health, 1.0)
	if ratio <= 0.25:
		return 3
	if ratio <= 0.666:
		return 2
	return 1


func _get_jump_count_for_phase(phase: int) -> int:
	match phase:
		3:
			return 3
		2:
			return 2
		_:
			return 1


func _get_hidden_time_for_phase(phase: int) -> float:
	match phase:
		3:
			return hidden_time_phase_3
		2:
			return hidden_time_phase_2
		_:
			return hidden_time_phase_1


func _get_stun_time_for_phase(phase: int) -> float:
	match phase:
		3:
			return stun_time_phase_3
		2:
			return stun_time_phase_2
		_:
			return stun_time_phase_1


func _get_locked_target_position() -> Vector2:
	_player = _get_player()
	var target_x := _home_position.x
	if _player != null:
		target_x = _player.global_position.x
	if use_manual_arena_limits:
		var left := minf(manual_arena_left_x, manual_arena_right_x)
		var right := maxf(manual_arena_left_x, manual_arena_right_x)
		target_x = clampf(target_x, left, right)
	else:
		target_x = clampf(target_x, _home_position.x - max_target_distance_from_home, _home_position.x + max_target_distance_from_home)
	return Vector2(target_x, _get_landing_y())


func _get_landing_y() -> float:
	if String(landing_marker_path) != "":
		var marker := get_node_or_null(landing_marker_path) as Node2D
		if marker != null:
			return marker.global_position.y
	if use_landing_y_override:
		return landing_y_override
	return _home_position.y


func _show_landing_warning(target: Vector2, duration: float) -> void:
	var marker := Node2D.new()
	marker.name = "FinalBossLandingWarning"
	marker.global_position = target + warning_marker_offset
	marker.z_index = 200
	var fill := Polygon2D.new()
	fill.color = Color(1.0, 0.05, 0.05, 0.26)
	fill.polygon = _make_ellipse_polygon(warning_marker_radius_x, warning_marker_radius_y, 40)
	marker.add_child(fill)
	var outline := Line2D.new()
	outline.width = 6.0
	outline.default_color = Color(1.0, 0.18, 0.12, 0.9)
	outline.closed = true
	outline.points = _make_ellipse_polygon(warning_marker_radius_x, warning_marker_radius_y, 40)
	marker.add_child(outline)
	(get_tree().current_scene if get_tree().current_scene != null else get_tree().root).add_child(marker)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(marker, "scale", Vector2(1.08, 1.08), 0.12)
	tw.tween_property(marker, "scale", Vector2.ONE, 0.12)
	await _wait(duration)
	if is_instance_valid(tw):
		tw.kill()
	if is_instance_valid(marker):
		marker.queue_free()


func _make_ellipse_polygon(radius_x: float, radius_y: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(maxi(point_count, 8)):
		var angle := TAU * float(i) / float(maxi(point_count, 8))
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _move_to(target: Vector2, duration: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	if duration <= 0.0:
		global_position = target
		return
	var start := global_position
	var elapsed := 0.0
	while elapsed < duration:
		if _encounter_cancelled():
			return
		var delta := maxf(get_process_delta_time(), 0.016)
		elapsed += delta
		var ratio := clampf(elapsed / duration, 0.0, 1.0)
		global_position = start.lerp(target, _ease_motion_ratio(ratio, trans, easing))
		await get_tree().process_frame
	global_position = target


func _ease_motion_ratio(ratio: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> float:
	var t := clampf(ratio, 0.0, 1.0)
	if easing == Tween.EASE_IN:
		match trans:
			Tween.TRANS_QUAD:
				return t * t
			Tween.TRANS_EXPO:
				return 0.0 if t <= 0.0 else pow(2.0, 10.0 * (t - 1.0))
	return t


func _apply_crush_damage() -> void:
	_player = _get_player()
	if _player == null:
		return
	var delta := _player.global_position - global_position
	if absf(delta.x) > crush_radius_x or absf(delta.y) > crush_radius_y:
		return
	if _player.has_method("apply_enemy_contact_damage"):
		var knockback := Vector2(signf(delta.x) * 520.0, -360.0)
		_player.call("apply_enemy_contact_damage", self, contact_damage, knockback)


func _play_landing_feedback(phase: int) -> void:
	_play_landing_sfx()
	var strength := shake_strength * (1.45 if phase == 3 else 1.0)
	var duration := shake_duration * (1.25 if phase == 3 else 1.0)
	_shake_camera(duration, strength)


func _play_boss_music() -> void:
	if boss_music == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_music(boss_music, boss_music_fade_time, boss_music_volume_db)


func _play_activation_sfx_once() -> void:
	if _activation_sfx_played or activation_sfx == null:
		return
	_activation_sfx_played = true
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(activation_sfx, global_position, -3.0, 1.0)
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = activation_sfx
	player.global_position = global_position
	player.volume_db = -3.0
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_landing_sfx() -> void:
	if landing_sfx == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(landing_sfx, global_position, -3.0, randf_range(0.82, 0.98))
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = landing_sfx
	player.global_position = global_position
	player.volume_db = -3.0
	player.pitch_scale = randf_range(0.82, 0.98)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _resolve_impact_position(bullet_profile: Dictionary) -> Vector2:
	var raw: Variant = bullet_profile.get("impact_position", global_position)
	if raw is Vector2:
		return raw
	_player = _get_player()
	if _player != null:
		return _player.global_position
	return global_position


func _bullet_has_color(bullet_profile: Dictionary, expected_color: String) -> bool:
	var expected := CssAffinity.normalize_color(expected_color)
	var bullet_props: Dictionary = bullet_profile.get("properties", {})
	for raw_prop in ["fill", "background-color", "color"]:
		var prop := String(raw_prop)
		if not bullet_props.has(prop):
			continue
		var value := CssAffinity.normalize_property_value(prop, String(bullet_props[prop]))
		if value == expected:
			return true
	return false


func _play_hit_feedback(color: Color) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", color, 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)


func _defeat() -> void:
	if defeated_flag:
		return
	defeated_flag = true
	active = false
	_vulnerable = false
	_pattern_running = false
	if is_instance_valid(_active_motion_tween):
		_active_motion_tween.kill()
	if is_instance_valid(_stun_feedback_tween):
		_stun_feedback_tween.kill()
	_active_motion_tween = null
	_stun_feedback_tween = null
	_set_collision_enabled(false)
	_lock_player_control(true)
	_hide_boss_bar()
	defeated.emit()
	_play_defeat_sequence()


func _play_defeat_sequence() -> void:
	_play_destruction_sfx()
	_spawn_destruction_particles()
	_shake_camera(defeat_shake_duration, defeat_shake_strength)
	var overlay := _create_end_overlay()
	var flash := overlay.get_node("Flash") as ColorRect
	var label := overlay.get_node("Message") as Label
	label.text = thanks_message
	label.visible = false

	var boss_tw := create_tween()
	boss_tw.tween_property(self, "modulate:a", 0.0, 1.2)

	var flash_tw := create_tween()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_tw.tween_property(flash, "color:a", 1.0, 0.05)
	flash_tw.tween_interval(0.18)
	flash_tw.tween_callback(func() -> void:
		label.visible = true
	)
	flash_tw.tween_property(flash, "color:a", 0.12, 1.35)
	await _wait(thanks_hold_time)
	await _play_credits_sequence(overlay)
	if is_instance_valid(self):
		queue_free()


func _create_end_overlay() -> CanvasLayer:
	var overlay := CanvasLayer.new()
	overlay.layer = 90
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var flash := ColorRect.new()
	flash.name = "Flash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(flash)
	var label := Label.new()
	label.name = "Message"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.02, 0.025, 0.03, 1.0))
	overlay.add_child(label)
	get_tree().root.add_child(overlay)
	return overlay


func _play_credits_sequence(overlay: CanvasLayer) -> void:
	if not is_instance_valid(overlay):
		return
	var black := ColorRect.new()
	black.name = "BlackFade"
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(black)

	var center := VBoxContainer.new()
	center.name = "Credits"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -610.0
	center.offset_top = -330.0
	center.offset_right = 610.0
	center.offset_bottom = 330.0
	center.add_theme_constant_override("separation", 16)
	overlay.add_child(center)

	var title := Label.new()
	title.text = credits_message
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98, 1.0))
	title.modulate.a = 0.0
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Adelanto de lo que viene"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9, 1.0))
	subtitle.modulate.a = 0.0
	center.add_child(subtitle)

	var image_row := HBoxContainer.new()
	image_row.add_theme_constant_override("separation", 22)
	image_row.alignment = BoxContainer.ALIGNMENT_CENTER
	image_row.modulate.a = 0.0
	center.add_child(image_row)

	var left_image := _create_teaser_texture_rect()
	var right_image := _create_teaser_texture_rect()
	image_row.add_child(left_image)
	image_row.add_child(right_image)

	var prompt := Label.new()
	prompt.text = continue_prompt
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.76, 0.28, 1.0))
	prompt.modulate.a = 0.0
	center.add_child(prompt)

	var fade_tw := create_tween()
	fade_tw.tween_property(black, "color:a", 0.96, 1.1)
	fade_tw.parallel().tween_property(title, "modulate:a", 1.0, 0.9)
	fade_tw.parallel().tween_property(subtitle, "modulate:a", 1.0, 0.9)
	await fade_tw.finished

	var loaded_images := _load_teaser_textures()
	if loaded_images.is_empty():
		await _wait(2.0)
	else:
		var index := 0
		while index < loaded_images.size():
			left_image.texture = loaded_images[index]
			right_image.visible = index + 1 < loaded_images.size()
			if right_image.visible:
				right_image.texture = loaded_images[index + 1]
			image_row.modulate.a = 0.0
			var image_tw := create_tween()
			image_tw.tween_property(image_row, "modulate:a", 1.0, 0.45)
			image_tw.tween_interval(teaser_image_hold_time)
			image_tw.tween_property(image_row, "modulate:a", 0.0, 0.35)
			await image_tw.finished
			index += 2

	var prompt_tw := create_tween()
	prompt_tw.tween_property(prompt, "modulate:a", 1.0, 0.35)
	await prompt_tw.finished
	await _wait_for_epilogue_continue()
	await _return_to_title()


func _create_teaser_texture_rect() -> TextureRect:
	var image_rect := TextureRect.new()
	image_rect.custom_minimum_size = Vector2(570, 410)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return image_rect


func _wait_for_epilogue_continue() -> void:
	while is_inside_tree():
		if Input.is_action_just_pressed(continue_action) or Input.is_action_just_pressed(&"ui_accept"):
			return
		await get_tree().process_frame


func _return_to_title() -> void:
	var clean_scene := title_scene.strip_edges()
	if clean_scene == "":
		return
	if has_node("/root/SceneTransition"):
		await SceneTransition.transition_to_scene(clean_scene, "", 0.55)
	else:
		get_tree().change_scene_to_file(clean_scene)


func _load_teaser_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for raw_path in teaser_image_paths:
		var path := String(raw_path).strip_edges()
		if path == "" or not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _spawn_destruction_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "FinalBossDestructionParticles"
	particles.global_position = global_position
	particles.z_index = 250
	particles.amount = 120
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.randomness = 0.58
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 520.0)
	particles.initial_velocity_min = 160.0
	particles.initial_velocity_max = 620.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 8.0
	particles.color = Color(1.0, 0.42, 0.18, 1.0)
	(get_tree().current_scene if get_tree().current_scene != null else get_tree().root).add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _play_destruction_sfx() -> void:
	if destruction_sfx == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(destruction_sfx, -5.0, 0.86)
		return
	var player := AudioStreamPlayer.new()
	player.stream = destruction_sfx
	player.volume_db = -5.0
	player.pitch_scale = 0.86
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _shake_camera(duration: float, strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_camera_shake_token += 1
	var token := _camera_shake_token
	var base_offset := camera.offset
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(camera) and token == _camera_shake_token:
		var delta := get_process_delta_time()
		elapsed += maxf(delta, 0.016)
		var ratio := 1.0 - clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
		camera.offset = base_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		) * ratio
		await get_tree().process_frame
	if is_instance_valid(camera) and token == _camera_shake_token:
		camera.offset = base_offset


func _play_anim(anim_name: StringName) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(anim_name):
		return
	var animation: Animation = animation_player.get_animation(anim_name)
	if animation == null or not _animation_has_valid_tracks(animation):
		return
	animation_player.play(anim_name)


func _animation_has_valid_tracks(animation: Animation) -> bool:
	for track_index in range(animation.get_track_count()):
		if animation.track_get_key_count(track_index) <= 0:
			return false
	return true


func _encounter_cancelled() -> bool:
	return defeated_flag or not active or not is_inside_tree()


func _get_intro_lines() -> Array[String]:
	var lines: Array[String] = []
	for raw_line in intro_dialog_lines:
		var line := String(raw_line).strip_edges()
		if line != "":
			lines.append(line)
	return lines


func _create_boss_dialog_overlay() -> Dictionary:
	var overlay := CanvasLayer.new()
	overlay.name = "FinalBossDialogOverlay"
	overlay.layer = 55
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 126)
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -380.0
	panel.offset_top = -172.0
	panel.offset_right = 380.0
	panel.offset_bottom = -46.0
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var speaker := Label.new()
	speaker.text = boss_name.to_upper()
	speaker.add_theme_font_size_override("font_size", 16)
	speaker.add_theme_color_override("font_color", Color(1.0, 0.24, 0.18, 1.0))
	box.add_child(speaker)

	var line := Label.new()
	line.name = "Line"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 24)
	line.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98, 1.0))
	box.add_child(line)

	get_tree().root.add_child(overlay)
	return {
		"overlay": overlay,
		"line": line,
	}


func _lock_player_control(locked: bool) -> void:
	var player := _get_player()
	if player != null and player.has_method("set_external_control_lock"):
		player.call("set_external_control_lock", locked)


func _get_player() -> CharacterBody2D:
	if _player != null and is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group(player_group) as CharacterBody2D


func _update_hud() -> void:
	health_changed.emit(current_health, max_health)
	if not active:
		return
	var hud := get_tree().get_first_node_in_group("main_hud")
	if hud != null and hud.has_method("set_boss_data"):
		hud.call("set_boss_data", boss_name, current_health, max_health)


func _hide_boss_bar() -> void:
	var hud := get_tree().get_first_node_in_group("main_hud")
	if hud != null and hud.has_method("set_boss_visible"):
		hud.call("set_boss_visible", false)


func _set_collision_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not enabled)
		elif child is Area2D:
			var area := child as Area2D
			area.set_deferred("monitoring", enabled)
			area.set_deferred("monitorable", enabled)
			for area_child in area.get_children():
				if area_child is CollisionShape2D:
					area_child.set_deferred("disabled", not enabled)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout
