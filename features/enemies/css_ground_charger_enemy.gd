extends CssEnemyBase
class_name CssGroundChargerEnemy

enum State { PATROL, WINDUP, CHARGE, RECOVER }

@export var patrol_speed: float = 95.0
@export var detection_range: float = 780.0
@export var detection_height: float = 150.0
@export var windup_time: float = 0.42
@export var charge_time: float = 0.55
@export var recover_time: float = 0.45
@export var charge_speed: float = 760.0
@export var charge_start_boost: float = 1.35
@export var windup_pullback_speed: float = 90.0
@export var acceleration: float = 2200.0
@export var gravity: float = 3800.0
@export var charge_sfx: AudioStream = preload("res://assets/sfx/Robot_Activated_00.mp3")

var state := State.PATROL
var _state_time := 0.0
var _move_dir := -1.0
var _windup_feedback_played := false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	match state:
		State.PATROL:
			_update_patrol(delta)
		State.WINDUP:
			_update_windup(delta)
		State.CHARGE:
			_update_charge(delta)
		State.RECOVER:
			_update_recover(delta)
	move_and_slide()
	if is_on_wall() and state != State.WINDUP:
		_move_dir *= -1.0
		face_toward(global_position + Vector2(_move_dir, 0.0))
		if state == State.CHARGE:
			_enter_recover()
	apply_contact_damage_to_overlaps()


func _update_patrol(delta: float) -> void:
	_play_anim(&"walk")
	if is_player_in_range(detection_range, detection_height):
		var offset_x := player.global_position.x - global_position.x
		_move_dir = 1.0 if offset_x > 0.0 else -1.0 if offset_x < 0.0 else 0.0
		if _move_dir == 0.0:
			_move_dir = facing_sign
		face_toward(player.global_position)
		_enter_state(State.WINDUP)
		return
	velocity.x = move_toward(velocity.x, _move_dir * patrol_speed, acceleration * delta)
	face_toward(global_position + Vector2(_move_dir, 0.0))


func _update_windup(delta: float) -> void:
	_play_anim(&"windup")
	if not _windup_feedback_played:
		_play_windup_feedback()
		_windup_feedback_played = true
	velocity.x = move_toward(velocity.x, -_move_dir * windup_pullback_speed, acceleration * delta)
	_state_time -= delta
	if _state_time <= 0.0:
		_enter_state(State.CHARGE)


func _update_charge(delta: float) -> void:
	_play_anim(&"charge")
	velocity.x = move_toward(velocity.x, _move_dir * charge_speed, acceleration * delta)
	_state_time -= delta
	if _state_time <= 0.0:
		_enter_recover()


func _update_recover(delta: float) -> void:
	_play_anim(&"recover")
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	_state_time -= delta
	if _state_time <= 0.0:
		_enter_state(State.PATROL)


func _enter_recover() -> void:
	_enter_state(State.RECOVER)


func _enter_state(next_state: int) -> void:
	state = next_state
	match state:
		State.WINDUP:
			_state_time = windup_time
			_windup_feedback_played = false
		State.CHARGE:
			_state_time = charge_time
			velocity.x = _move_dir * charge_speed * charge_start_boost
			_play_charge_sfx()
			_play_charge_burst_feedback()
		State.RECOVER:
			_state_time = recover_time
		_:
			_state_time = 0.0


func _play_windup_feedback() -> void:
	if body_visual == null:
		return
	var tw := create_tween()
	tw.tween_property(body_visual, "scale", Vector2(_base_visual_scale.x * 1.18, _base_visual_scale.y * 0.86), windup_time)


func _play_charge_burst_feedback() -> void:
	if body_visual == null:
		return
	var tw := create_tween()
	tw.tween_property(body_visual, "scale", Vector2(_base_visual_scale.x * 0.86, _base_visual_scale.y * 1.14), 0.06)
	tw.tween_property(body_visual, "scale", _base_visual_scale, 0.16)


func _play_charge_sfx() -> void:
	if charge_sfx == null:
		return
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx_at(charge_sfx, global_position, -5.0, randf_range(1.08, 1.18))
		return
	var player_2d := AudioStreamPlayer2D.new()
	player_2d.stream = charge_sfx
	player_2d.global_position = global_position
	player_2d.volume_db = -5.0
	player_2d.pitch_scale = randf_range(1.08, 1.18)
	player_2d.finished.connect(player_2d.queue_free)
	var parent := get_tree().current_scene
	if parent == null:
		parent = self
	parent.add_child(player_2d)
	player_2d.play()
