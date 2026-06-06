extends Area2D
class_name CollectibleItem

@export var collectible_id: String = "collectible_id"
@export var title: String = "Objeto recuperado"
@export_multiline var description: String = "Descripcion del objeto."
@export var icon_texture: Texture2D
@export var player_group: StringName = &"player"
@export var open_popup_on_collect: bool = true
@export var pickup_sfx: AudioStream = preload("res://assets/sfx/itempick1.wav")

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_apply_sprite()
	if has_node("/root/CollectibleInventory"):
		CollectibleInventory.register_item(get_item_data())
		if CollectibleInventory.is_collected(collectible_id):
			queue_free()
			return
	body_entered.connect(_on_body_entered)
	call_deferred("_collect_overlapping_player")


func get_item_data() -> Dictionary:
	return {
		"id": collectible_id.strip_edges(),
		"title": title.strip_edges(),
		"description": description.strip_edges(),
		"sprite_path": _get_icon_path(),
	}


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group(player_group):
		return
	_collect()


func _collect_overlapping_player() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _collect() -> void:
	if collectible_id.strip_edges() == "":
		push_warning("[CollectibleItem] Falta collectible_id en %s." % name)
		return
	var collected := false
	if has_node("/root/CollectibleInventory"):
		collected = CollectibleInventory.collect_item(get_item_data(), open_popup_on_collect)
	else:
		collected = true
	if not collected:
		queue_free()
		return
	_play_pickup_sfx()
	_disable_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.22, 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _disable_pickup() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)


func _apply_sprite() -> void:
	if sprite == null:
		return
	if icon_texture != null:
		sprite.texture = icon_texture


func _get_icon_path() -> String:
	if icon_texture != null and icon_texture.resource_path != "":
		return icon_texture.resource_path
	if sprite != null and sprite.texture != null:
		return sprite.texture.resource_path
	return ""


func _play_pickup_sfx() -> void:
	if pickup_sfx == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(pickup_sfx, global_position, -7.0, 1.0)
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = pickup_sfx
	player.global_position = global_position
	player.volume_db = -7.0
	player.finished.connect(player.queue_free)
	get_tree().current_scene.add_child(player)
	player.play()
