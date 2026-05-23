extends Area2D

@export var overlay_path: NodePath = ^"../Player/Camera2D/Control"
@export var player_group: StringName = &"player"
@export var interact_action: StringName = &"interact"
@export var pillar_sprite_path: NodePath = ^"PillarSprite"
@export var tileset_texture: Texture2D = preload("res://assets/art/tilesets/master_tileset_128x128.svg")
@export var sprite_size: Vector2 = Vector2(128, 128)
@export var sprite_separation: Vector2 = Vector2(16, 16)
@export var off_region: Rect2 = Rect2(287, 287, 128, 128)

var on_region: Rect2:
	get:
		var step := sprite_size + sprite_separation
		return Rect2(off_region.position - Vector2(step.x, 0.0), sprite_size)

var overlay: Node = null
var player_in_range := false
var current_player: Node = null
var _is_activated := false

@onready var pillar_sprite: Sprite2D = get_node_or_null(pillar_sprite_path)

func _ready() -> void:
	var n := get_node_or_null(overlay_path)
	if n == null:
		n = get_tree().get_first_node_in_group("web_overlay")
	overlay = _find_overlay_node(n)

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))

	_apply_pillar_state(_is_activated)

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
		_activate_checkpoint()

func _activate_checkpoint() -> void:
	if overlay:
		overlay.call("open")
	_is_activated = true
	_apply_pillar_state(true)
	_restore_player_and_hub()

func _restore_player_and_hub() -> void:
	if current_player and current_player.has_method("restore_all"):
		current_player.call("restore_all")
	var main_hud := get_tree().get_first_node_in_group("main_hud")
	if main_hud and main_hud.has_method("restore_all"):
		main_hud.call("restore_all")

func _apply_pillar_state(is_on: bool) -> void:
	if pillar_sprite == null:
		return
	if tileset_texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = tileset_texture
	atlas.region = on_region if is_on else off_region
	pillar_sprite.texture = atlas

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		player_in_range = true
		current_player = body

func _on_body_exited(body: Node) -> void:
	if body == current_player:
		player_in_range = false
		current_player = null
