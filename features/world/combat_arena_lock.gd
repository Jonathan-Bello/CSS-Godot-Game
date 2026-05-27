extends Area2D
class_name CombatArenaLock

@export var player_group: StringName = &"player"
@export var left_wall_path: NodePath
@export var right_wall_path: NodePath
@export var left_closed_position: Vector2
@export var right_closed_position: Vector2
@export var close_duration: float = 0.45
@export var one_shot: bool = true

var _triggered := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered and one_shot:
		return
	if body == null or not body.is_in_group(player_group):
		return
	_triggered = true
	_close_wall(left_wall_path, left_closed_position)
	_close_wall(right_wall_path, right_closed_position)


func _close_wall(path: NodePath, closed_position: Vector2) -> void:
	var wall := get_node_or_null(path) as Node2D
	if wall == null:
		return
	wall.visible = true
	wall.process_mode = Node.PROCESS_MODE_INHERIT
	var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", false)
	var tw := create_tween()
	tw.tween_property(wall, "position", closed_position, close_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
