extends Area2D
class_name FootstepAudioTrigger

@export var player_group: StringName = &"player"
@export var footstep_sfx: AudioStream = preload("res://assets/sfx/step_metal.ogg")
@export var override_tile_surface: bool = false
@export var reset_on_exit: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(player_group):
		return
	if body.has_method("set_footstep_sfx"):
		body.call("set_footstep_sfx", footstep_sfx, override_tile_surface)

func _on_body_exited(body: Node) -> void:
	if not reset_on_exit:
		return
	if not body.is_in_group(player_group):
		return
	if body.has_method("reset_footstep_sfx"):
		body.call("reset_footstep_sfx")
