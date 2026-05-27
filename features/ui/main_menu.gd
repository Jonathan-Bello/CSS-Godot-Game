extends Control

@export_file("*.tscn") var new_game_scene: String = "res://features/ui/game_intro.tscn"
@export var new_game_spawn_marker: String = ""
@export var title_music: AudioStream = preload("res://assets/music/Verdant Circuit.mp3")
@export var accept_sfx: AudioStream = preload("res://assets/sfx/Menu_Select_01.mp3")
@export var focus_sfx: AudioStream = preload("res://assets/sfx/Menu_Select_00.mp3")

@onready var new_button: Button = %NewButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_music(title_music, 0.6, -10.0)
	new_button.pressed.connect(_on_new_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	for button in [new_button, load_button, quit_button]:
		button.focus_entered.connect(_play_focus_sfx)
		button.mouse_entered.connect(_play_focus_sfx)
	new_button.grab_focus()

func _on_new_pressed() -> void:
	_play_accept_sfx()
	if has_node("/root/AudioManager"):
		AudioManager.stop_music(0.35)
	if has_node("/root/SceneTransition"):
		await SceneTransition.transition_to_scene(new_game_scene, new_game_spawn_marker, 0.35)
	else:
		get_tree().change_scene_to_file(new_game_scene)

func _on_load_pressed() -> void:
	_play_accept_sfx()
	status_label.text = "No hay partida guardada."

func _on_quit_pressed() -> void:
	_play_accept_sfx()
	get_tree().quit()

func _play_focus_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(focus_sfx, -18.0, 1.0)

func _play_accept_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(accept_sfx, -12.0, 1.0)
