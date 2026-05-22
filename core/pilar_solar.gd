extends Area2D

@export_group("Interacción")
@export var overlay_path: NodePath = ^"../Player/Camera2D/Control"
@export var player_group: StringName = &"player"
@export var interact_action: StringName = &"interact"

@export_group("Visual")
@export_node_path("Sprite2D") var pillar_sprite_path: NodePath = ^"Sprite2D"
@export var unlit_region: Rect2 = Rect2(384.0, 256.0, 128.0, 128.0)
@export var lit_region: Rect2 = Rect2(512.0, 256.0, 128.0, 128.0)
@export var light_up_duration: float = 0.35

var overlay: Node = null
var player_in_range := false
var current_player: Node = null
var is_lit := false

@onready var pillar_sprite: Sprite2D = get_node_or_null(pillar_sprite_path)
@onready var main_hud: Node = get_tree().get_first_node_in_group("main_hud")

func _ready() -> void:
	var n := get_node_or_null(overlay_path)
	if n == null:
		n = get_tree().get_first_node_in_group("web_overlay")
	overlay = _find_overlay_node(n)

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))

	_apply_pillar_state(false)

func _find_overlay_node(start: Node) -> Node:
	var p := start
	while p != null:
		if p.has_method("open"):
			return p
		p = p.get_parent()
	return null

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if event.is_action_pressed(interact_action):
		_rest_at_pillar()

func _rest_at_pillar() -> void:
	if overlay:
		overlay.call("open")
	if main_hud and main_hud.has_method("restore_all"):
		main_hud.call("restore_all")
	if not is_lit:
		await _animate_light_up()
		is_lit = true

func _animate_light_up() -> void:
	if pillar_sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(pillar_sprite, "modulate", Color(1.2, 1.2, 1.2, 1.0), light_up_duration * 0.5)
	tween.tween_callback(func() -> void:
		_apply_pillar_state(true)
	)
	tween.tween_property(pillar_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), light_up_duration * 0.5)
	await tween.finished

func _apply_pillar_state(lit: bool) -> void:
	if pillar_sprite == null:
		return
	pillar_sprite.region_enabled = true
	pillar_sprite.region_rect = lit_region if lit else unlit_region

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		player_in_range = true
		current_player = body

func _on_body_exited(body: Node) -> void:
	if body == current_player:
		player_in_range = false
		current_player = null
