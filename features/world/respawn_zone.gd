extends Area2D
class_name RespawnZone

@export var player_group: StringName = &"player"
@export var respawn_method: StringName = &"kill_and_respawn"

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return
	if body.has_method(respawn_method):
		body.call(respawn_method)
