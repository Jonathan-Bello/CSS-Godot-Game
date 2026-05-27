extends CssEnemyBase
class_name CssFlyingEnemy

@export var patrol_radius: Vector2 = Vector2(160.0, 52.0)
@export var patrol_speed: float = 1.25
@export var detection_range: float = 720.0
@export var chase_speed: float = 260.0
@export var acceleration: float = 720.0
@export var hover_amplitude: float = 20.0
@export var hover_frequency: float = 2.8
@export var stop_distance: float = 44.0

var _home_position := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	super._ready()
	_home_position = global_position


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_time += delta
	if is_player_in_range(detection_range):
		_chase_player(delta)
	else:
		_patrol(delta)
	move_and_slide()
	apply_contact_damage_to_overlaps()


func _patrol(delta: float) -> void:
	var target := _home_position + Vector2(
		sin(_time * patrol_speed) * patrol_radius.x,
		cos(_time * patrol_speed * 1.31) * patrol_radius.y
	)
	var desired := (target - global_position) / maxf(delta, 0.001)
	velocity = velocity.move_toward(desired.limit_length(chase_speed * 0.55), acceleration * delta)
	if absf(velocity.x) > 8.0:
		face_toward(global_position + Vector2(velocity.x, 0.0))
	_play_anim(&"idle")


func _chase_player(delta: float) -> void:
	if player == null:
		return
	var to_player := player.global_position - global_position
	face_toward(player.global_position)
	var desired := Vector2.ZERO
	if to_player.length() > stop_distance:
		desired = to_player.normalized() * chase_speed
	desired.y += sin(_time * hover_frequency) * hover_amplitude
	velocity = velocity.move_toward(desired, acceleration * delta)
	_play_anim(&"chase")
