extends Area2D
class_name RespawnZone

@export var player_group: StringName = &"player"
@export var respawn_method: StringName = &"respawn_at_checkpoint"

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return
	if body.has_method(respawn_method):
		body.call(respawn_method)
