extends CanvasLayer

@export_range(1, 10, 1) var max_health_slots: int = 4
@export_range(0, 10, 1) var current_health_slots: int = 2:
	set(value):
		current_health_slots = clampi(value, 0, max_health_slots)
		_update_health_slots()

@export_range(1, 10, 1) var max_solar_charges: int = 5
@export_range(0, 10, 1) var unlocked_solar_charges: int = 3:
	set(value):
		unlocked_solar_charges = clampi(value, 1, max_solar_charges)
		solar_charges = mini(solar_charges, unlocked_solar_charges)
		_update_solar_charges()

@export_range(0, 10, 1) var solar_charges: int = 2:
	set(value):
		solar_charges = clampi(value, 0, unlocked_solar_charges)
		_update_solar_charges()

@onready var health_slots_container: HBoxContainer = %HealthSlotsContainer
@onready var boss_container: Control = %BossBarContainer
@onready var boss_bar: ProgressBar = %BossHealthBar
@onready var boss_name_label: Label = %BossNameLabel
@onready var solar_container: HBoxContainer = %SolarChargesContainer
@onready var emis_badge: Label = %EmisBadge
@onready var emis_button: TextureButton = %EmisButton
@onready var emis_dialog: PanelContainer = %EmisDialog
@onready var emis_dialog_label: Label = %EmisDialogLabel
@onready var emis_dialog_hint_label: Label = %EmisDialogHintLabel
@onready var shoot_delay_bar: ProgressBar = %ShootDelayBar
@export_range(5.0, 240.0, 1.0) var emis_dialog_chars_per_second: float = 44.0
@export var emis_dialog_tick_sfx: AudioStream = preload("res://assets/sfx/dialogs/quick_1.ogg")
@export_range(0.0, 0.2, 0.005) var emis_dialog_tick_interval: float = 0.03

@export var emis_alert_message: String = "¡Ey! Tengo una pista para ti."
var emis_alert_active: bool = false
var _emis_bounce_t: float = 0.0
var _emis_base_scale: Vector2 = Vector2.ONE

var _dialog_queue: Array[String] = []
var _dialog_index: int = -1
var _dialog_lock_player: bool = false
var _dialog_active: bool = false
var _dialog_reveal_text: String = ""
var _dialog_reveal_chars: int = 0
var _dialog_reveal_accum: float = 0.0
var _dialog_tick_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("main_hud")
	_update_health_slots()
	_update_solar_charges()
	set_boss_visible(false)
	if emis_button:
		_emis_base_scale = emis_button.scale
		emis_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not emis_button.is_connected("pressed", Callable(self, "_on_emis_button_pressed")):
			emis_button.connect("pressed", Callable(self, "_on_emis_button_pressed"))
	if emis_dialog:
		emis_dialog.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _dialog_active:
		return
	if event.is_action_pressed("interact"):
		if _is_dialog_revealing():
			_reveal_dialog_instantly()
			get_viewport().set_input_as_handled()
			return
		advance_emis_dialog()
		get_viewport().set_input_as_handled()

func set_player_health(current: float, maximum: float) -> void:
	max_health_slots = maxi(1, int(round(maximum)))
	current_health_slots = clampi(int(round(current)), 0, max_health_slots)
	_update_health_slots()

func set_boss_visible(should_show: bool) -> void:
	boss_container.visible = should_show

func set_boss_data(name_text: String, current: float, maximum: float) -> void:
	boss_name_label.text = "< %s >" % name_text.to_upper()
	boss_bar.max_value = maxf(1.0, maximum)
	boss_bar.value = clampf(current, 0.0, boss_bar.max_value)
	set_boss_visible(true)

func set_emis_notification(visible_notification: bool) -> void:
	emis_badge.visible = visible_notification


func _process(delta: float) -> void:
	_dialog_tick_cooldown = maxf(0.0, _dialog_tick_cooldown - delta)
	_update_dialog_reveal(delta)
	if emis_button == null:
		return
	if emis_alert_active:
		_emis_bounce_t += delta * 9.0
		var pulse := 1.0 + sin(_emis_bounce_t) * 0.13
		emis_button.scale = _emis_base_scale * pulse
	else:
		_emis_bounce_t = 0.0
		emis_button.scale = _emis_base_scale
	_update_emis_activation_visual()

func set_emis_alert(active: bool, message: String = "") -> void:
	emis_alert_active = active
	set_emis_notification(active)
	if message.strip_edges() != "":
		emis_alert_message = message
	if not active and emis_dialog:
		emis_dialog.visible = false

func _on_emis_button_pressed() -> void:
	if _dialog_active:
		advance_emis_dialog()
		return
	if not _is_emis_available():
		start_emis_tutorial_dialog(PackedStringArray([
			"Emis esta inactivo. Vuelve al menu principal y usa Activar Emis para ingresar tu API key de Gemini."
		]), false)
		return
	var overlay := get_tree().get_first_node_in_group("web_overlay")
	if emis_alert_active:
		start_emis_tutorial_dialog(PackedStringArray([emis_alert_message]), false)
		set_emis_alert(false)
		return
	if overlay and overlay.has_method("open_chat_overlay"):
		overlay.call("open_chat_overlay")
	elif overlay and overlay.has_method("open"):
		overlay.call("open")

func _is_emis_available() -> bool:
	if _is_web_runtime():
		return true
	if has_node("/root/EmisGameContext") and EmisGameContext.has_method("has_api_key"):
		return bool(EmisGameContext.call("has_api_key"))
	return false

func _is_web_runtime() -> bool:
	if has_node("/root/RuntimeEnvironment") and RuntimeEnvironment.has_method("is_web"):
		return bool(RuntimeEnvironment.call("is_web"))
	if has_node("/root/EmisGameContext") and EmisGameContext.has_method("is_web_runtime"):
		return bool(EmisGameContext.call("is_web_runtime"))
	return OS.has_feature("web")

func _update_emis_activation_visual() -> void:
	if emis_button == null:
		return
	emis_button.modulate = Color(1, 1, 1, 1) if _is_emis_available() else Color(0.34, 0.38, 0.42, 0.58)

func restore_all() -> void:
	current_health_slots = max_health_slots
	solar_charges = unlocked_solar_charges
	_update_health_slots()
	_update_solar_charges()

func _update_health_slots() -> void:
	if health_slots_container == null:
		return
	for i in range(health_slots_container.get_child_count()):
		var slot := health_slots_container.get_child(i) as TextureRect
		if slot == null:
			continue
		slot.visible = i < max_health_slots
		slot.modulate = Color(1, 1, 1, 1.0) if i < current_health_slots else Color(0.28, 0.28, 0.32, 0.45)

func _update_solar_charges() -> void:
	if solar_container == null:
		return
	for i in range(solar_container.get_child_count()):
		var icon := solar_container.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.visible = i < unlocked_solar_charges
		icon.modulate = Color(1, 1, 1, 1.0) if i < solar_charges else Color(0.45, 0.45, 0.45, 0.5)

func set_shoot_delay_progress(progress_ratio: float) -> void:
	if shoot_delay_bar == null:
		return
	shoot_delay_bar.value = clampf(progress_ratio, 0.0, 1.0) * 100.0

func start_emis_tutorial_dialog(lines: PackedStringArray, stop_player: bool = true) -> void:
	if lines.is_empty():
		return
	_dialog_queue.clear()
	for line in lines:
		var clean := String(line).strip_edges()
		if clean != "":
			_dialog_queue.append(clean)
	if _dialog_queue.is_empty():
		return
	_dialog_index = -1
	_dialog_lock_player = stop_player
	_dialog_active = true
	set_emis_alert(true, _dialog_queue[0])
	_apply_dialog_player_lock(true)
	advance_emis_dialog()

func advance_emis_dialog() -> void:
	if not _dialog_active:
		return
	_dialog_index += 1
	if _dialog_index >= _dialog_queue.size():
		_finish_emis_dialog()
		return
	if emis_dialog_label:
		_start_dialog_reveal(_dialog_queue[_dialog_index])
	if emis_dialog:
		emis_dialog.visible = true

func _finish_emis_dialog() -> void:
	_dialog_active = false
	_dialog_queue.clear()
	_dialog_index = -1
	_dialog_reveal_text = ""
	_dialog_reveal_chars = 0
	_dialog_reveal_accum = 0.0
	_dialog_tick_cooldown = 0.0
	if emis_dialog:
		emis_dialog.visible = false
	set_emis_alert(false)
	_apply_dialog_player_lock(false)

func _apply_dialog_player_lock(locked: bool) -> void:
	if not _dialog_lock_player:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_external_control_lock"):
		player.call("set_external_control_lock", locked)

func _start_dialog_reveal(text: String) -> void:
	_dialog_reveal_text = text
	_dialog_reveal_chars = 0
	_dialog_reveal_accum = 0.0
	_dialog_tick_cooldown = 0.0
	if emis_dialog_label:
		emis_dialog_label.text = _dialog_reveal_text
		emis_dialog_label.visible_characters = 0

func _update_dialog_reveal(delta: float) -> void:
	if emis_dialog_label == null:
		return
	if _dialog_reveal_text == "":
		return
	if _dialog_reveal_chars >= _dialog_reveal_text.length():
		return
	_dialog_reveal_accum += maxf(delta, 0.0) * maxf(emis_dialog_chars_per_second, 1.0)
	var reveal_step := int(floor(_dialog_reveal_accum))
	if reveal_step <= 0:
		return
	_dialog_reveal_accum -= float(reveal_step)
	var previous_chars := _dialog_reveal_chars
	_dialog_reveal_chars = mini(_dialog_reveal_chars + reveal_step, _dialog_reveal_text.length())
	emis_dialog_label.visible_characters = _dialog_reveal_chars
	_play_dialog_tick(previous_chars, _dialog_reveal_chars)

func _is_dialog_revealing() -> bool:
	return _dialog_reveal_chars < _dialog_reveal_text.length()

func _reveal_dialog_instantly() -> void:
	if emis_dialog_label == null:
		return
	_dialog_reveal_chars = _dialog_reveal_text.length()
	_dialog_reveal_accum = 0.0
	emis_dialog_label.visible_characters = _dialog_reveal_chars

func _play_dialog_tick(previous_chars: int, current_chars: int) -> void:
	if emis_dialog_tick_sfx == null or current_chars <= previous_chars:
		return
	if _dialog_tick_cooldown > 0.0:
		return
	var last_index := clampi(current_chars - 1, 0, _dialog_reveal_text.length() - 1)
	var shown_char := _dialog_reveal_text.substr(last_index, 1)
	if shown_char.strip_edges() == "":
		return
	_dialog_tick_cooldown = emis_dialog_tick_interval
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(emis_dialog_tick_sfx, -14.0, randf_range(0.96, 1.05))
		return
	var player := AudioStreamPlayer.new()
	player.stream = emis_dialog_tick_sfx
	player.volume_db = -14.0
	player.pitch_scale = randf_range(0.96, 1.05)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
