extends StaticBody2D
class_name CssTogglePlatform

@export var css_metadata: Dictionary = {
	"properties": {
		"background-color": "blue"
	}
}
@export var starts_active: bool = false
@export var inactive_color: Color = Color(0.75, 0.85, 1.0, 0.2)
@export var active_color: Color = Color(0.35, 0.6, 1.0, 1.0)
@export var hit_flash_color: Color = Color(1.0, 0.95, 0.55, 1.0)
@export var sprite_texture: Texture2D

var is_active: bool = false

@onready var visual: ColorRect = $Visual
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	is_active = starts_active
	_apply_state_visual(false)

func apply_css_bullet_hit(bullet_profile: Dictionary) -> void:
	if not _has_exact_match(bullet_profile):
		return
	is_active = not is_active
	_play_hit_feedback()
	_apply_state_visual(true)

func _has_exact_match(bullet_profile: Dictionary) -> bool:
	var target_props: Dictionary = CssAffinity.normalize_affinity(css_metadata.get("properties", {}))
	var bullet_props: Dictionary = bullet_profile.get("properties", {})

	for raw_prop in target_props.keys():
		var prop := String(raw_prop)
		if not bullet_props.has(prop):
			continue
		var bullet_value := CssAffinity.normalize_property_value(prop, String(bullet_props[prop]))
		if bullet_value == String(target_props[prop]):
			return true
	return false

func _play_hit_feedback() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "color", hit_flash_color, 0.06)
	tw.tween_property(visual, "color", active_color if is_active else inactive_color, 0.12)

func _apply_state_visual(animate: bool) -> void:
	if sprite_texture != null:
		sprite.texture = sprite_texture
		sprite.visible = true
	# Activo: sólido, con colisión. Inactivo: silueta translúcida sin colisión.
	var target_color := active_color if is_active else inactive_color
	if animate:
		var tw := create_tween()
		tw.tween_property(visual, "color", target_color, 0.1)
	else:
		visual.color = target_color
	if collision:
		collision.set_deferred("disabled", not is_active)
	# Asegura que la plataforma entre/salga limpiamente de colisiones de físicas.
	collision_layer = 1 if is_active else 0
	collision_mask = 1 if is_active else 0
