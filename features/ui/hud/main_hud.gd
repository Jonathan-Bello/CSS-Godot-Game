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
@onready var shoot_delay_bar: ProgressBar = %ShootDelayBar

@export var emis_alert_message: String = "¡Ey! Tengo una pista para ti."
var emis_alert_active: bool = false
var _emis_bounce_t: float = 0.0
var _emis_base_scale: Vector2 = Vector2.ONE

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

func set_player_health(current: float, maximum: float) -> void:
	max_health_slots = maxi(1, int(round(maximum)))
	current_health_slots = clampi(int(round(current)), 0, max_health_slots)
	_update_health_slots()

func set_boss_visible(is_visible: bool) -> void:
	boss_container.visible = is_visible

func set_boss_data(name_text: String, current: float, maximum: float) -> void:
	boss_name_label.text = "< %s >" % name_text.to_upper()
	boss_bar.max_value = maxf(1.0, maximum)
	boss_bar.value = clampf(current, 0.0, boss_bar.max_value)
	set_boss_visible(true)

func set_emis_notification(visible_notification: bool) -> void:
	emis_badge.visible = visible_notification


func _process(delta: float) -> void:
	if emis_button == null:
		return
	if emis_alert_active:
		_emis_bounce_t += delta * 9.0
		var pulse := 1.0 + sin(_emis_bounce_t) * 0.13
		emis_button.scale = _emis_base_scale * pulse
	else:
		_emis_bounce_t = 0.0
		emis_button.scale = _emis_base_scale

func set_emis_alert(active: bool, message: String = "") -> void:
	emis_alert_active = active
	set_emis_notification(active)
	if message.strip_edges() != "":
		emis_alert_message = message
	if not active and emis_dialog:
		emis_dialog.visible = false

func _on_emis_button_pressed() -> void:
	var overlay := get_tree().get_first_node_in_group("web_overlay")
	if emis_alert_active:
		if emis_dialog_label:
			emis_dialog_label.text = emis_alert_message
		if emis_dialog:
			emis_dialog.visible = true
		set_emis_alert(false)
		return
	if overlay and overlay.has_method("open_chat_overlay"):
		overlay.call("open_chat_overlay")
	elif overlay and overlay.has_method("open"):
		overlay.call("open")

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
