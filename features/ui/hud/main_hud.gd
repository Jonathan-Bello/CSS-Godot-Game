extends CanvasLayer

@export_range(1, 10, 1) var max_health_slots: int = 5
@export_range(0, 10, 1) var current_health_slots: int = 3:
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

func _ready() -> void:
	add_to_group("main_hud")
	_update_health_slots()
	_update_solar_charges()
	set_boss_visible(false)

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
		slot.modulate = Color(1, 0.67, 0.27, 1.0) if i < current_health_slots else Color(0.25, 0.25, 0.3, 0.8)

func _update_solar_charges() -> void:
	if solar_container == null:
		return
	for i in range(solar_container.get_child_count()):
		var icon := solar_container.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.visible = i < unlocked_solar_charges
		icon.modulate = Color(0.29, 0.97, 0.72, 1.0) if i < solar_charges else Color(0.29, 0.97, 0.72, 0.2)
