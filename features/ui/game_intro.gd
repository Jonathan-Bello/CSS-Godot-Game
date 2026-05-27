extends Control

@export_file("*.tscn") var next_scene: String = "res://content/levels/tutorial_cave.tscn"
@export var next_spawn_marker: String = "PlayerStart"
@export var intro_image: Texture2D
@export var impact_sfx: AudioStream = preload("res://assets/sfx/stomp.ogg")
@export var dialog_tick_sfx: AudioStream = preload("res://assets/sfx/dialogs/male_deep_1.ogg")
@export_range(8.0, 80.0, 1.0) var chars_per_second: float = 34.0
@export_range(0.0, 4.0, 0.1) var line_hold_seconds: float = 1.15
@export_range(0.0, 2.0, 0.05) var impact_hold_seconds: float = 0.65
@export_range(0.0, 60.0, 1.0) var shake_strength: float = 26.0
@export_range(0.0, 2.0, 0.05) var shake_duration: float = 0.55
@export_range(0.0, 0.2, 0.005) var dialog_tick_interval: float = 0.055
@export_range(-40.0, 6.0, 1.0) var dialog_tick_volume_db: float = -18.0
@export_range(0.5, 1.5, 0.01) var dialog_tick_pitch_min: float = 0.78
@export_range(0.5, 1.5, 0.01) var dialog_tick_pitch_max: float = 0.92

@onready var stage: Control = %Stage
@onready var lore_label: Label = %LoreLabel
@onready var image_slot: TextureRect = %ImageSlot
@onready var flash: ColorRect = %Flash

var _skip_requested := false
var _last_dialog_tick_msec := -100000

var intro_lines: PackedStringArray = PackedStringArray([
	"La ciudad nació de una promesa: que la tecnología y la naturaleza podían sostener juntas el futuro.",
	"Por años, la luz solar recorrió sus torres, los jardines crecieron sobre el concreto y las máquinas cuidaron cada rincón.",
	"Pero ninguna ciudad está preparada para quedarse sin voces.",
	"Ahora solo quedan pasillos vacíos, raíces sobre el metal y sistemas antiguos repitiendo órdenes que nadie escucha.",
	"Aun así, quiero que sepas algo: hice todo lo posible para que este lugar pudiera recibirte con calma."
])


func _ready() -> void:
	if intro_image != null:
		image_slot.texture = intro_image
		image_slot.visible = true
	else:
		image_slot.visible = false
	lore_label.text = ""
	flash.color = Color(1.0, 0.95, 0.72, 0.0)
	await get_tree().process_frame
	await _run_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_skip_requested = true
		get_viewport().set_input_as_handled()


func _run_intro() -> void:
	for line in intro_lines:
		await _show_line(line)
		if _skip_requested:
			break

	_skip_requested = false
	await _distort_signal()
	await _impact_sequence()
	await _show_line("Espera… el suelo…\n¿Qué está pasando?\nTodo va a estar bien… solo necesito que sigas moviéndote.", 1.25)
	await _go_to_game()


func _show_line(text: String, hold_override: float = -1.0) -> void:
	lore_label.text = text
	lore_label.visible_characters = 0
	var total_chars := text.length()
	var delay := 1.0 / maxf(chars_per_second, 1.0)
	for i in range(total_chars):
		if _skip_requested:
			lore_label.visible_characters = total_chars
			return
		lore_label.visible_characters = i + 1
		_play_dialog_tick(text.substr(i, 1))
		await get_tree().create_timer(delay).timeout
	var hold_time := hold_override if hold_override >= 0.0 else line_hold_seconds
	await _wait_or_skip(hold_time)


func _distort_signal() -> void:
	lore_label.text = "La señal se distorsiona."
	lore_label.visible_characters = -1
	var base_position := stage.position
	for i in range(8):
		if _skip_requested:
			break
		lore_label.modulate.a = 0.35 if i % 2 == 0 else 1.0
		stage.position = base_position + Vector2(randf_range(-8.0, 8.0), randf_range(-5.0, 5.0))
		await get_tree().create_timer(0.055).timeout
	lore_label.modulate.a = 1.0
	stage.position = base_position
	await _wait_or_skip(0.15)


func _impact_sequence() -> void:
	_play_impact_sfx()
	_flash_once()
	await _shake_stage()
	await _wait_or_skip(impact_hold_seconds)


func _flash_once() -> void:
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.45, 0.04)
	tween.tween_property(flash, "color:a", 0.0, 0.22)


func _shake_stage() -> void:
	var elapsed := 0.0
	var base_position := stage.position
	while elapsed < shake_duration:
		var delta := get_process_delta_time()
		elapsed += delta
		var ratio := 1.0 - clampf(elapsed / maxf(shake_duration, 0.001), 0.0, 1.0)
		stage.position = base_position + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		) * ratio
		await get_tree().process_frame
	stage.position = base_position


func _wait_or_skip(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _play_impact_sfx() -> void:
	if impact_sfx == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(impact_sfx, -3.0, 0.72)
		return
	var player := AudioStreamPlayer.new()
	player.stream = impact_sfx
	player.volume_db = -3.0
	player.pitch_scale = 0.72
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_dialog_tick(character: String) -> void:
	if dialog_tick_sfx == null or character.strip_edges() == "":
		return
	var now := Time.get_ticks_msec()
	var interval_msec := int(dialog_tick_interval * 1000.0)
	if now - _last_dialog_tick_msec < interval_msec:
		return
	_last_dialog_tick_msec = now
	var pitch := randf_range(dialog_tick_pitch_min, dialog_tick_pitch_max)
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(dialog_tick_sfx, dialog_tick_volume_db, pitch)
		return
	var player := AudioStreamPlayer.new()
	player.stream = dialog_tick_sfx
	player.volume_db = dialog_tick_volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _go_to_game() -> void:
	if has_node("/root/SceneTransition"):
		await SceneTransition.transition_to_scene(next_scene, next_spawn_marker, 0.55)
	else:
		get_tree().change_scene_to_file(next_scene)
