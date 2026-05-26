extends CanvasLayer

@export_multiline var textos : Array[String]
@export var dialog_tick_sfx: AudioStream = preload("res://assets/sfx/dialogs/quick_1.ogg")
@export_range(0.0, 0.2, 0.005) var dialog_tick_interval: float = 0.03

var iterar =0
var _last_visible_chars := 0
var _dialog_tick_cooldown := 0.0

func _ready():
	iniciar_dialogo()

func show_text (txt: String):
	show()
	$"color cuadro tex/Label".hide()
	get_tree().paused = true
	$"color cuadro tex/texto".text =txt
	$"color cuadro tex/texto".visible_ratio = 0.0
	_last_visible_chars = 0
	_dialog_tick_cooldown = 0.0
	$"animacion cuadro de textois".play("texto")

func _process(delta: float) -> void:
	_dialog_tick_cooldown = maxf(0.0, _dialog_tick_cooldown - delta)
	if not visible:
		return
	var label: Label = $"color cuadro tex/texto"
	var visible_chars := int(round(label.visible_ratio * float(label.text.length())))
	if visible_chars > _last_visible_chars:
		_play_dialog_tick(label, visible_chars)
	_last_visible_chars = visible_chars

func iniciar_dialogo ():
	show_text(textos[iterar])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cambio cuadro de diaologo"):
		iterar += 1
		if iterar >= textos.size():
			get_tree().paused = false
			hide()
			iterar = 0
			return
		show_text(textos[iterar])

func _on_animacion_cuadro_de_textois_animation_finished(anim_name: StringName) -> void:
	if anim_name == "texto":
		$"animacion cuadro de textois".play("texto cuadro continuar")

func _play_dialog_tick(label: Label, visible_chars: int) -> void:
	if dialog_tick_sfx == null or _dialog_tick_cooldown > 0.0:
		return
	var last_index := clampi(visible_chars - 1, 0, label.text.length() - 1)
	var shown_char := label.text.substr(last_index, 1)
	if shown_char.strip_edges() == "":
		return
	_dialog_tick_cooldown = dialog_tick_interval
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(dialog_tick_sfx, -14.0, randf_range(0.96, 1.05))
		return
	var player := AudioStreamPlayer.new()
	player.stream = dialog_tick_sfx
	player.volume_db = -14.0
	player.pitch_scale = randf_range(0.96, 1.05)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
