extends CharacterBody2D
class_name CssEnemyBase

signal died(enemy: Node)

@export var player_group: StringName = &"player"
@export var max_health: int = 6
@export var contact_damage: int = 1
@export var contact_knockback: Vector2 = Vector2(900.0, -520.0)
@export var css_affinity: Dictionary = {
	"properties": {
		"background-color": "blue",
		"fill": "blue"
	},
	"property_bonus": 1,
	"critical_bonus": 3
}
@export var affinity_resource: Resource
@export var body_visual_path: NodePath = ^"Skeleton2D/Parts"
@export var animation_player_path: NodePath = ^"Skeleton2D/AnimationPlayer"
@export var contact_damage_area_path: NodePath = ^"ContactDamageArea"
@export var normal_hit_sfx: AudioStream = preload("res://assets/sfx/metal_swing1.wav")
@export var critical_hit_sfx: AudioStream = preload("res://assets/sfx/Robot_Activated_00.mp3")
@export_group("Variant")
@export var variant_id: StringName = &"default"
@export var variant_css_properties: Dictionary = {}
@export var variant_visual_tint: Color = Color(1, 1, 1, 1)
@export var variant_visual_scale: Vector2 = Vector2.ONE
@export var variant_z_index: int = 0
@export var variant_outline_enabled: bool = false
@export var variant_outline_color: Color = Color(0.05, 0.06, 0.07, 1.0)
@export_range(1.0, 1.35, 0.01) var variant_outline_scale: float = 1.08
@export_range(0.1, 5.0, 0.05) var variant_health_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var variant_contact_damage_multiplier: float = 1.0
@export var variant_property_bonus_override: int = -1
@export var variant_critical_bonus_override: int = -1
@export var variant_contact_enabled: bool = true
@export var variant_world_collision_enabled: bool = true

var health: int
var player: CharacterBody2D
var facing_sign := -1.0
var _is_dead := false
var _base_modulate := Color.WHITE
var _base_visual_scale := Vector2.ONE

@onready var body_visual: Node2D = get_node_or_null(body_visual_path) as Node2D
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer
@onready var contact_damage_area: Area2D = get_node_or_null(contact_damage_area_path) as Area2D


func _ready() -> void:
	add_to_group("enemies")
	_apply_variant_stats()
	health = maxi(1, max_health)
	player = get_tree().get_first_node_in_group(player_group) as CharacterBody2D
	if body_visual != null:
		_apply_variant_visual()
		_base_modulate = body_visual.modulate
		_base_visual_scale = body_visual.scale
	if not variant_world_collision_enabled:
		collision_layer = 0
		collision_mask = 0
	if contact_damage_area != null:
		contact_damage_area.collision_layer = 0
		contact_damage_area.collision_mask = 2
		contact_damage_area.monitoring = variant_contact_enabled
		contact_damage_area.monitorable = false
		if not variant_contact_enabled:
			_set_collision_children_disabled(contact_damage_area, true)
		if not contact_damage_area.body_entered.is_connected(_on_contact_damage_body_entered):
			contact_damage_area.body_entered.connect(_on_contact_damage_body_entered)
	_play_anim(&"idle")


func apply_css_bullet_hit(bullet_profile: Dictionary) -> void:
	if _is_dead:
		return
	var result := CssAffinity.compute_damage(bullet_profile, _resolve_affinity())
	var final_damage := int(result.get("damage", 0))
	if final_damage <= 0:
		_play_hit_feedback(Color(0.35, 0.35, 0.38, 1.0))
		return
	health -= final_damage
	var level := String(result.get("level", "none"))
	_play_hit_feedback(_color_for_hit_level(level))
	_play_damage_sfx(level)
	if health <= 0:
		_die()


func get_health_ratio() -> float:
	return float(maxi(health, 0)) / float(maxi(max_health, 1))


func is_player_in_range(check_range: float, vertical_range: float = -1.0) -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(player_group) as CharacterBody2D
	if player == null:
		return false
	var delta := player.global_position - global_position
	var vertical_ok := vertical_range < 0.0 or absf(delta.y) <= vertical_range
	return absf(delta.x) <= check_range and vertical_ok


func face_toward(target_position: Vector2) -> void:
	var offset_x := target_position.x - global_position.x
	var direction := 1.0 if offset_x > 0.0 else -1.0 if offset_x < 0.0 else 0.0
	if direction == 0.0:
		return
	facing_sign = direction
	var visual := get_node_or_null(^"Skeleton2D") as Node2D
	if visual != null:
		visual.scale.x = absf(visual.scale.x) * -facing_sign


func _resolve_affinity() -> Dictionary:
	var resolved := css_affinity.duplicate(true)
	if affinity_resource != null and affinity_resource.has_method("get_affinity_dictionary"):
		var from_resource: Variant = affinity_resource.call("get_affinity_dictionary")
		if typeof(from_resource) == TYPE_DICTIONARY:
			resolved.merge(from_resource, true)
	if not variant_css_properties.is_empty():
		var properties: Dictionary = resolved.get("properties", {}).duplicate(true)
		properties.merge(variant_css_properties, true)
		resolved["properties"] = properties
	if variant_property_bonus_override >= 0:
		resolved["property_bonus"] = variant_property_bonus_override
	if variant_critical_bonus_override >= 0:
		resolved["critical_bonus"] = variant_critical_bonus_override
	return resolved


func _on_contact_damage_body_entered(body: Node) -> void:
	if _is_dead or body == null or not body.has_method("apply_enemy_contact_damage"):
		return
	body.call("apply_enemy_contact_damage", self, contact_damage, contact_knockback)


func apply_contact_damage_to_overlaps() -> void:
	if _is_dead or contact_damage_area == null or not contact_damage_area.monitoring:
		return
	for body in contact_damage_area.get_overlapping_bodies():
		_on_contact_damage_body_entered(body)


func _play_anim(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation == animation_name:
		return
	animation_player.play(animation_name)


func _apply_variant_stats() -> void:
	max_health = maxi(1, int(round(float(max_health) * variant_health_multiplier)))
	contact_damage = maxi(0, int(round(float(contact_damage) * variant_contact_damage_multiplier)))


func _apply_variant_visual() -> void:
	body_visual.modulate = body_visual.modulate * variant_visual_tint
	body_visual.scale = Vector2(
		body_visual.scale.x * variant_visual_scale.x,
		body_visual.scale.y * variant_visual_scale.y
	)
	body_visual.z_index += variant_z_index
	if variant_outline_enabled:
		_add_variant_outline()


func _add_variant_outline() -> void:
	if body_visual == null:
		return
	var polygons := body_visual.find_children("*", "Polygon2D", true, false)
	for raw_polygon in polygons:
		var polygon := raw_polygon as Polygon2D
		if polygon == null or polygon.name.ends_with("Outline"):
			continue
		var outline := polygon.duplicate() as Polygon2D
		if outline == null:
			continue
		outline.name = "%sOutline" % polygon.name
		outline.color = variant_outline_color
		outline.z_index = polygon.z_index - 1
		outline.scale = polygon.scale * variant_outline_scale
		polygon.get_parent().add_child(outline)


func _set_collision_children_disabled(root: Node, disabled: bool) -> void:
	for child in root.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)
		_set_collision_children_disabled(child, disabled)


func _play_hit_feedback(color: Color) -> void:
	if body_visual == null:
		return
	var tw := create_tween()
	tw.tween_property(body_visual, "modulate", color, 0.06)
	tw.parallel().tween_property(body_visual, "scale", _base_visual_scale * 1.08, 0.06)
	tw.tween_property(body_visual, "modulate", _base_modulate, 0.12)
	tw.parallel().tween_property(body_visual, "scale", _base_visual_scale, 0.12)


func _play_damage_sfx(level: String) -> void:
	var stream := critical_hit_sfx if level == "high" else normal_hit_sfx
	if stream == null:
		return
	var pitch := randf_range(0.96, 1.04)
	var volume := -4.5
	if level == "high":
		pitch = randf_range(0.86, 0.94)
		volume = -2.0
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(stream, global_position, volume, pitch)
		return
	var player_2d := AudioStreamPlayer2D.new()
	player_2d.stream = stream
	player_2d.global_position = global_position
	player_2d.volume_db = volume
	player_2d.pitch_scale = pitch
	player_2d.finished.connect(player_2d.queue_free)
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(player_2d)
	player_2d.play()


func _color_for_hit_level(level: String) -> Color:
	if level == "high":
		return Color(1.0, 0.88, 0.24, 1.0)
	if level == "medium":
		return Color(1.0, 0.35, 0.35, 1.0)
	return Color(0.8, 0.1, 0.1, 1.0)


func _die() -> void:
	_is_dead = true
	died.emit(self)
	set_physics_process(false)
	if contact_damage_area != null:
		contact_damage_area.set_deferred("monitoring", false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	if body_visual != null:
		var tw := create_tween()
		tw.tween_property(body_visual, "scale", body_visual.scale * 0.8, 0.12)
		tw.parallel().tween_property(body_visual, "modulate:a", 0.0, 0.12)
		await tw.finished
	queue_free()
