extends StaticBody2D
class_name CssDestructibleBlock

@export var max_health: int = 3
@export var css_metadata: Dictionary = {
	"properties": {
		"background-color": "red"
	}
}
@export var default_color: Color = Color(0.76, 0.27, 0.27, 1.0)
@export var damaged_color: Color = Color(1.0, 0.83, 0.34, 1.0)
@export var destroyed_color: Color = Color(0.18, 0.18, 0.18, 0.35)
@export var sprite_texture: Texture2D

var health: int
var state: String = "vida"

@onready var visual: ColorRect = $Visual
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	health = max(1, max_health)
	_update_visual_mode()

func apply_css_bullet_hit(bullet_profile: Dictionary) -> void:
	if state == "destruido":
		return
	if not _has_exact_match(bullet_profile):
		return

	health -= 1
	if health <= 0:
		state = "destruido"
		_on_destroyed()
		return

	state = "danado"
	_play_damage_feedback()

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

func _play_damage_feedback() -> void:
	if sprite_texture != null and sprite.texture == null:
		sprite.texture = sprite_texture
	var tw := create_tween()
	tw.tween_property(visual, "color", damaged_color, 0.08)
	tw.tween_property(visual, "color", default_color, 0.14)

func _on_destroyed() -> void:
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if sprite_texture != null and sprite.texture == null:
		sprite.texture = sprite_texture
	var tw := create_tween()
	tw.tween_property(visual, "color", destroyed_color, 0.16)
	tw.tween_interval(0.06)
	tw.tween_callback(queue_free)

func _update_visual_mode() -> void:
	visual.color = default_color
	if sprite_texture != null:
		sprite.texture = sprite_texture
		sprite.visible = true
		visual.visible = true
