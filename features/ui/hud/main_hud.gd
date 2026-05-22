extends CanvasLayer

@export_range(1, 10, 1) var max_solar_charges: int = 4
@export_range(0, 10, 1) var solar_charges: int = 4:
	set(value):
		solar_charges = clampi(value, 0, max_solar_charges)
		_update_solar_charges()

@onready var health_bar: ProgressBar = %PlayerHealthBar
@onready var boss_container: Control = %BossBarContainer
@onready var boss_bar: ProgressBar = %BossHealthBar
@onready var boss_name_label: Label = %BossNameLabel
@onready var solar_container: HBoxContainer = %SolarChargesContainer
@onready var emis_button: TextureButton = %EmisButton
@onready var emis_badge: Label = %EmisBadge

func _ready() -> void:
	_update_solar_charges()
	set_boss_visible(false)

func set_player_health(current: float, maximum: float) -> void:
	health_bar.max_value = maxf(1.0, maximum)
	health_bar.value = clampf(current, 0.0, health_bar.max_value)

func set_boss_visible(is_visible: bool) -> void:
	boss_container.visible = is_visible

func set_boss_data(name_text: String, current: float, maximum: float) -> void:
	boss_name_label.text = "< %s >" % name_text.to_upper()
	boss_bar.max_value = maxf(1.0, maximum)
	boss_bar.value = clampf(current, 0.0, boss_bar.max_value)
	set_boss_visible(true)

func set_emis_notification(visible_notification: bool) -> void:
	emis_badge.visible = visible_notification

func _update_solar_charges() -> void:
	if solar_container == null:
		return
	for i in range(solar_container.get_child_count()):
		var icon := solar_container.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.modulate = Color(0.29, 0.97, 0.72, 1.0) if i < solar_charges else Color(0.29, 0.97, 0.72, 0.2)
