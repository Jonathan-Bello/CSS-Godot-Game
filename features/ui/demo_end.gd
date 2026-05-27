extends Control

@export var end_image: Texture2D
@export_file("*.tscn") var main_menu_scene: String = "res://features/ui/main_menu.tscn"

@onready var image_slot: TextureRect = %ImageSlot


func _ready() -> void:
	if end_image != null:
		image_slot.texture = end_image
		image_slot.visible = true
	else:
		image_slot.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if has_node("/root/SceneTransition"):
			await SceneTransition.transition_to_scene(main_menu_scene, "", 0.45)
		else:
			get_tree().change_scene_to_file(main_menu_scene)
