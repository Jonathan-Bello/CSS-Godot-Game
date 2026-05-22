extends Area2D

@export var overlay_path: NodePath = ^"../Player/Camera2D/Control"
@export var player_group: StringName = &"player"
@export var interact_action: StringName = &"interact"

var overlay: Node = null
var player_in_range := false
var current_player: Node = null

func _ready() -> void:
	print("[CssTerminal] READY overlay_path=", overlay_path)
	var n := get_node_or_null(overlay_path)
	if n == null:
		n = get_tree().get_first_node_in_group("web_overlay")
	overlay = _find_overlay_node(n)
	if overlay:
		var scr: Script = overlay.get_script() as Script
		var scr_path: String = scr.resource_path if scr != null else "<sin script>"
		print("[CssTerminal] overlay FINAL -> ", overlay.get_path(),
			" class=", overlay.get_class(), " has_open?=", overlay.has_method("open"),
			" script.path=", scr_path)
	else:
		push_warning("[CssTerminal] No pude resolver overlay. Revisa overlay_path o el grupo 'web_overlay'.")

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))

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
		print("[CssTerminal] input detectado -> acción '", interact_action, "' | in_range=", player_in_range, " | overlay_ok=", overlay != null)
		if overlay:
			print("[CssTerminal] → overlay.open() por tecla en ", overlay.get_path())
			overlay.call("open")

func _on_body_entered(body: Node) -> void:
	print("[CssTerminal] body_entered: ", body.name, " groups=", body.get_groups())
	if body.is_in_group(player_group):
		player_in_range = true
		current_player = body
		print("[CssTerminal] Jugador en rango del pilar. Pulsa '", interact_action, "' para abrir panel.")

func _on_body_exited(body: Node) -> void:
	print("[CssTerminal] body_exited: ", body.name)
	if body == current_player:
		player_in_range = false
		current_player = null
		print("[CssTerminal] Jugador salió del rango del pilar.")
