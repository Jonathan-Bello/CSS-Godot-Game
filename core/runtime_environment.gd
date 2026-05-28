extends Node

const ENV_WEB := "web"
const ENV_EDITOR := "editor"
const ENV_DESKTOP := "desktop"

var current_environment: String = ENV_DESKTOP

func _ready() -> void:
	current_environment = detect()
	print("[RuntimeEnvironment] running as %s" % current_environment)

func detect() -> String:
	if is_web():
		return ENV_WEB
	if is_editor():
		return ENV_EDITOR
	return ENV_DESKTOP

func is_web() -> bool:
	return OS.has_feature("web")

func is_editor() -> bool:
	return OS.has_feature("editor")

func is_desktop() -> bool:
	return not is_web()
