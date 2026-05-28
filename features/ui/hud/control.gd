extends Control

const EmisClientScript = preload("res://core/emis_client.gd")
const TUTORIAL_FLAGS_PATH := "user://progress/tutorial_flags.json"
const SOLAR_PILLAR_TUTORIAL_VERSION := 1
const WRY_EXTENSION_PATH := "res://addons/godot_wry/WRY.gdextension"
@onready var panel: PanelContainer = $PanelContainer
@onready var web: Control = $PanelContainer/WebView

@export var window_size: Vector2 = Vector2(1664, 900)
@export var content_padding: int = 0

var last_css: String = ""
var last_svg: String = ""
var last_bullet_profile_path: String = ""
var _web_hydration_payload: Dictionary = {}
var _emis_client: Node = null
var _emis_conversation_id: String = ""
var _emis_api_key: String = ""
var _last_loaded_html: String = ""
var _overlay_template_path: String = "res://features/ui/hud/web_overlay_editor.html"

var _loading_sfx_player: AudioStreamPlayer = null
@export var overlay_open_prelude_seconds: float = 0.32
var _awaiting_html_ready: bool = false
var _use_dom_overlay: bool = false
var _dom_overlay_callback: Variant = null


signal overlay_opened
signal overlay_closed

func _ready() -> void:
	add_to_group("web_overlay")
	visible = false
	panel.visible = false
	web.visible = false

	_use_dom_overlay = OS.has_feature("web")
	if _use_dom_overlay:
		_setup_dom_overlay_bridge()

	_ensure_emis_client()
	_ensure_loading_sfx_player()
	_layout_and_sync()
	print("[WebOverlay] READY")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_and_sync()

func _layout_and_sync() -> void:
	var vp := get_viewport_rect().size
	panel.custom_minimum_size = vp
	panel.size = vp
	panel.position = Vector2.ZERO

	web.position = panel.position + Vector2(content_padding, content_padding)
	web.size = panel.size - Vector2(content_padding * 2, content_padding * 2)

func _ensure_runtime_webview() -> void:
	if OS.has_feature("web"):
		return
	if web != null and web.has_method("load_html"):
		return
	_ensure_wry_extension_loaded()
	if not ClassDB.can_instantiate("WebView"):
		return
	var parent := web.get_parent()
	if parent == null:
		return
	var index := web.get_index()
	parent.remove_child(web)
	web.queue_free()
	var native_web := ClassDB.instantiate("WebView") as Control
	if native_web == null:
		return
	native_web.name = "WebView"
	native_web.visible = false
	native_web.set("transparent", true)
	native_web.set("url", "about:blank")
	native_web.set("html", "")
	native_web.set("devtools", false)
	native_web.set("focused_when_created", false)
	parent.add_child(native_web)
	parent.move_child(native_web, index)
	web = native_web

func _ensure_wry_extension_loaded() -> void:
	if OS.has_feature("web") or ClassDB.can_instantiate("WebView"):
		return
	if not FileAccess.file_exists(WRY_EXTENSION_PATH):
		push_warning("[WebOverlay] No se encontro WRY.gdextension en %s" % WRY_EXTENSION_PATH)
		return
	var load_status := GDExtensionManager.load_extension(WRY_EXTENSION_PATH)
	if ClassDB.can_instantiate("WebView"):
		print("[WebOverlay] WRY cargado para overlay de escritorio. status=", load_status)
	else:
		push_warning("[WebOverlay] WRY no registro WebView. status=%s; reinicia Godot si la extension fue restaurada durante esta sesion." % load_status)

func _should_use_dom_overlay() -> bool:
	return OS.has_feature("web")

func _prepare_overlay_backend() -> bool:
	_use_dom_overlay = _should_use_dom_overlay()
	if _use_dom_overlay:
		if _dom_overlay_callback == null:
			_setup_dom_overlay_bridge()
		return _get_js_bridge() != null

	_ensure_runtime_webview()
	if web == null or not web.has_method("load_html"):
		push_warning("[WebOverlay] WebView nativo no disponible; no se puede abrir overlay HTML en escritorio")
		return false

	web.set("url", "about:blank")
	web.set("html", "")
	web.set("transparent", true)
	web.set("devtools", false)
	if web.has_signal("ipc_message") and not web.is_connected("ipc_message", Callable(self , "_on_web_ipc_message")):
		web.connect("ipc_message", Callable(self , "_on_web_ipc_message"))
	return true

func _get_js_bridge() -> Object:
	if not Engine.has_singleton("JavaScriptBridge"):
		return null
	return Engine.get_singleton("JavaScriptBridge")

func _setup_dom_overlay_bridge() -> void:
	var bridge := _get_js_bridge()
	if bridge == null:
		push_warning("[WebOverlay] JavaScriptBridge no disponible para overlay web")
		return
	_dom_overlay_callback = bridge.call("create_callback", Callable(self, "_on_dom_overlay_message"))
	var window = bridge.call("get_interface", "window")
	if window != null:
		window.__cssGameGodotOverlayMessage = _dom_overlay_callback
	bridge.call("eval", _dom_overlay_bootstrap_js(), true)

func _dom_overlay_bootstrap_js() -> String:
	return """
(function(){
  if(window.__cssGameOverlayInstalled) return;
  window.__cssGameOverlayInstalled = true;
  function ensureOverlay(){
    var root = document.getElementById('css-game-html-overlay');
    if(!root){
      root = document.createElement('div');
      root.id = 'css-game-html-overlay';
      root.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:none;background:rgba(2,4,10,.72);';
      var frame = document.createElement('iframe');
      frame.id = 'css-game-html-overlay-frame';
      frame.setAttribute('allow', 'autoplay; fullscreen; clipboard-read; clipboard-write');
      frame.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%;border:0;background:transparent;display:block;';
      root.appendChild(frame);
      document.body.appendChild(root);
    }
    return root;
  }
  function patchHtml(html){
    var bridgeScript = '<script>window.ipc={postMessage:function(message){parent.postMessage({__cssGameOverlayIpc:true,message:String(message)},\"*\");}};<\\/script>';
    var text = String(html || '');
    if(text.indexOf('window.ipc') === -1){
      text = text.replace('</head>', bridgeScript + '</head>');
    }
    return text;
  }
  window.__cssGameOverlayOpen = function(html){
    var root = ensureOverlay();
    var frame = document.getElementById('css-game-html-overlay-frame');
    root.style.display = 'block';
    document.documentElement.style.overflow = 'hidden';
    document.body.style.overflow = 'hidden';
    frame.srcdoc = patchHtml(html);
    setTimeout(function(){ try{ frame.focus(); }catch(e){} }, 30);
  };
  window.__cssGameOverlayClose = function(){
    var root = document.getElementById('css-game-html-overlay');
    var frame = document.getElementById('css-game-html-overlay-frame');
    if(frame) frame.srcdoc = 'about:blank';
    if(root) root.style.display = 'none';
    document.documentElement.style.overflow = '';
    document.body.style.overflow = '';
  };
  window.__cssGameOverlayEval = function(code){
    var frame = document.getElementById('css-game-html-overlay-frame');
    if(!frame || !frame.contentWindow) return;
    frame.contentWindow.eval(String(code || ''));
  };
  window.addEventListener('message', function(event){
    var data = event.data;
    if(!data || data.__cssGameOverlayIpc !== true) return;
    if(typeof window.__cssGameGodotOverlayMessage === 'function'){
      window.__cssGameGodotOverlayMessage(String(data.message || ''));
    }
  });
})();
"""

func _on_dom_overlay_message(args: Array) -> void:
	if args.is_empty():
		return
	_on_web_ipc_message(String(args[0]))

func _emit_overlay_opened() -> void:
	emit_signal("overlay_opened")

func _emit_overlay_closed() -> void:
	emit_signal("overlay_closed")

func open() -> void:
	_open_with_template("res://features/ui/hud/web_overlay_editor.html")

func open_chat_overlay() -> void:
	_open_with_template("res://features/ui/hud/web_overlay_emis_chat.html")

func _open_with_template(template_path: String) -> void:
	_overlay_template_path = template_path
	print("[WebOverlay] open() template=", _overlay_template_path)
	if not _prepare_overlay_backend():
		return
	visible = true
	panel.visible = true
	if not _use_dom_overlay:
		web.visible = false

	# Mientras esté abierto, el panel debe “parar” el input de la escena
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	await get_tree().process_frame
	_layout_and_sync()
	await _play_overlay_open_prelude()
	_awaiting_html_ready = true
	if _use_dom_overlay:
		_close_dom_overlay()
	else:
		web.set("html", "")
		web.set("url", "about:blank")
	_load_editor_html()
	print("[WebOverlay] open -> esperando html_loaded")

func close() -> void:
	print("[WebOverlay] close()")

	# Quita el foco del WebView
	if not _use_dom_overlay and web.has_method("focus_parent"):
		web.call_deferred("focus_parent")
	if not _use_dom_overlay and web.has_method("unfocus"):
		web.call_deferred("unfocus")
	get_viewport().gui_release_focus()

	# Oculta overlay y deja de interceptar input
	if _use_dom_overlay:
		_close_dom_overlay()
	else:
		web.visible = false
	panel.visible = false
	visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Limpia contenido para próximas aperturas
	if not _use_dom_overlay:
		web.set("html", "")
		web.set("url", "about:blank")

	_emit_overlay_closed()



func _ensure_loading_sfx_player() -> void:
	if _loading_sfx_player == null:
		_loading_sfx_player = AudioStreamPlayer.new()
		_loading_sfx_player.name = "OverlayOpenSfx"
		add_child(_loading_sfx_player)
		_loading_sfx_player.stream = _build_overlay_open_sfx()

func _build_overlay_open_sfx() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = maxf(0.08, overlay_open_prelude_seconds)
	var frame_count: int = int(float(sample_rate) * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for i in range(frame_count):
		var t: float = float(i) / float(sample_rate)
		var progress: float = minf(t / duration, 1.0)
		var env: float = progress * (1.0 - progress) * 4.0
		var freq: float = lerpf(520.0, 880.0, progress)
		var amp: float = sin(TAU * freq * t) * env * 0.32
		var sample: int = int(clampf(amp, -1.0, 1.0) * 32767.0)
		bytes[i * 2] = sample & 0xFF
		bytes[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _play_overlay_open_prelude() -> void:
	_ensure_loading_sfx_player()
	if _loading_sfx_player and _loading_sfx_player.stream:
		_loading_sfx_player.play()
	await get_tree().create_timer(overlay_open_prelude_seconds).timeout

func _finish_overlay_open_after_html_ready() -> void:
	if _use_dom_overlay:
		return
	if web:
		web.visible = true
		web.call_deferred("focus")

func _open_dom_overlay(html: String) -> void:
	var bridge := _get_js_bridge()
	if bridge == null:
		push_warning("[WebOverlay] JavaScriptBridge no disponible para abrir overlay")
		return
	bridge.call("eval", "window.__cssGameOverlayOpen(%s);" % JSON.stringify(html), true)

func _close_dom_overlay() -> void:
	var bridge := _get_js_bridge()
	if bridge == null:
		return
	bridge.call("eval", "if(window.__cssGameOverlayClose){window.__cssGameOverlayClose();}", true)

func _eval_overlay_js(js: String) -> void:
	if _use_dom_overlay:
		var bridge := _get_js_bridge()
		if bridge == null:
			push_warning("[WebOverlay] JavaScriptBridge no disponible para eval")
			return
		bridge.call("eval", "window.__cssGameOverlayEval(%s);" % JSON.stringify(js), true)
		return
	if not web.has_method("eval"):
		push_warning("[WebOverlay] WebView sin metodo eval")
		return
	web.call_deferred("eval", js)

func _input(ev: InputEvent) -> void:
	if visible and ev.is_action_pressed("ui_cancel"):
		close()

# -----------------------------
# SECRET / ENV HELPERS
# -----------------------------
func _read_env_file(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var eq := line.find("=")
		if eq == -1:
			continue
		var k := line.substr(0, eq).strip_edges()
		var v := line.substr(eq + 1).strip_edges()
		# Quita comillas si vienen
		if (v.begins_with("\"") and v.ends_with("\"")) or (v.begins_with("'") and v.ends_with("'")):
			v = v.substr(1, v.length() - 2)
		out[k] = v
	return out

func _get_secret(key_name: String) -> String:
	# 1) variable de entorno real (ideal)
	var v := OS.get_environment(key_name)
	if v != "":
		return v

	# 2) modo dev: leer .env (NO recomendado para producción)
	# Puedes decidir moverlo a user://.env para no empacarlo en export.
	var env_res := _read_env_file("res://.env")
	if env_res.has(key_name) and String(env_res[key_name]) != "":
		return String(env_res[key_name])

	var env_user := _read_env_file("user://.env")
	if env_user.has(key_name) and String(env_user[key_name]) != "":
		return String(env_user[key_name])

	return ""

func _inject_window_var(var_name: String, value: String) -> void:
	if value == "":
		return
	if not web.has_method("eval"):
		return

	# Escapar para JS string literal simple
	var safe := value
	safe = safe.replace("\\", "\\\\")
	safe = safe.replace("'", "\\'")
	safe = safe.replace("\n", "\\n")
	safe = safe.replace("\r", "")

	var js := "window.%s='%s';" % [var_name, safe]
	web.call_deferred("eval", js)

# -----------------------------
# HTML LOADER
# -----------------------------
func _read_editor_html_template() -> String:
	var template_path := _overlay_template_path
	if template_path == "":
		template_path = "res://features/ui/hud/web_overlay_editor.html"
	if not FileAccess.file_exists(template_path):
		push_warning("[WebOverlay] No se encontró template HTML: %s" % template_path)
		return ""
	var file := FileAccess.open(template_path, FileAccess.READ)
	if file == null:
		push_warning("[WebOverlay] No se pudo abrir template HTML: %s" % template_path)
		return ""
	var html := file.get_as_text()
	# Hardening: si el template llega con escapes heredados del antiguo string
	# embebido (ej. [\\s\\S] o <\\/script>), normalizamos a regex JS válido.
	html = html.replace("\\\\s", "\\s")
	html = html.replace("\\\\S", "\\S")
	html = html.replace("<\\\\/script>", "<\\/script>")
	return html

func _read_overlay_font_data_uri() -> String:
	var font_path := "res://assets/fonts/quantico_regular.ttf"
	if not FileAccess.file_exists(font_path):
		push_warning("[WebOverlay] No se encontró fuente OverlayDisplay: %s" % font_path)
		return ""
	var font_file := FileAccess.open(font_path, FileAccess.READ)
	if font_file == null:
		push_warning("[WebOverlay] No se pudo abrir fuente OverlayDisplay: %s" % font_path)
		return ""
	var bytes := font_file.get_buffer(font_file.get_length())
	if bytes.is_empty():
		push_warning("[WebOverlay] Fuente OverlayDisplay vacía: %s" % font_path)
		return ""
	return "data:font/ttf;base64,%s" % Marshalls.raw_to_base64(bytes)

func _read_text_resource(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_warning("[WebOverlay] No se encontró recurso HTML: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[WebOverlay] No se pudo abrir recurso HTML: %s" % path)
		return ""
	return file.get_as_text()

func _read_codemirror_css() -> String:
	var paths := PackedStringArray([
		"res://features/ui/hud/vendor/codemirror/codemirror.min.css",
		"res://features/ui/hud/vendor/codemirror/show-hint.min.css"
	])
	var chunks: Array[String] = []
	for path in paths:
		var text := _read_text_resource(path)
		if text != "":
			chunks.append(text)
	return "\n".join(chunks)

func _read_codemirror_js() -> String:
	var paths := PackedStringArray([
		"res://features/ui/hud/vendor/codemirror/codemirror.min.js",
		"res://features/ui/hud/vendor/codemirror/css.min.js",
		"res://features/ui/hud/vendor/codemirror/show-hint.min.js",
		"res://features/ui/hud/vendor/codemirror/css-hint.min.js"
	])
	var chunks: Array[String] = []
	for path in paths:
		var text := _read_text_resource(path)
		if text != "":
			chunks.append(text.replace("</script>", "<\\/script>"))
	return "\n".join(chunks)

func _load_editor_html() -> void:
	_web_hydration_payload = _read_bullet_hydration_payload()
	if _overlay_template_path.ends_with("web_overlay_editor.html"):
		var should_show_solar_tutorial := _should_show_first_solar_pillar_tutorial()
		_web_hydration_payload["show_solar_pillar_tutorial"] = should_show_solar_tutorial
		_web_hydration_payload["first_solar_pillar_opened"] = not should_show_solar_tutorial
		_web_hydration_payload["solar_pillar_tutorial_version"] = SOLAR_PILLAR_TUTORIAL_VERSION
	if _overlay_template_path.ends_with("web_overlay_emis_chat.html"):
		_web_hydration_payload["emis_api_key_configured"] = _emis_api_key != ""
	var html := _read_editor_html_template()
	if html == "":
		html = "<!doctype html><html><body style='margin:0;background:#111;color:#fff'>Editor no disponible</body></html>"

	var font_data_uri := _read_overlay_font_data_uri()
	html = html.replace("__OVERLAY_FONT_DATA_URI__", font_data_uri)
	html = html.replace("__CODEMIRROR_CSS__", _read_codemirror_css())
	html = html.replace("__CODEMIRROR_JS__", _read_codemirror_js())

	_last_loaded_html = html
	if _use_dom_overlay:
		_open_dom_overlay(html)
		return
	var base_url := "https://overlay.local/"
	var supports_base_url := false
	for method_info in web.get_method_list():
		if str(method_info.get("name", "")) != "load_html":
			continue
		var argc := int(method_info.get("args", []).size())
		if argc >= 2:
			supports_base_url = true
			break
	if supports_base_url:
		web.call("load_html", html, base_url)
	else:
		print("[WebOverlay] load_html sin base URL: plugin expone firma de 1 parámetro")
		web.call("load_html", html)

func _debug_print_html_context(error_line: int, context_radius: int = 4) -> void:
	if _last_loaded_html == "":
		return
	if error_line <= 0:
		return
	var lines := _last_loaded_html.split("\n")
	var total := lines.size()
	if total == 0:
		return
	var start_line :Variant= max(1, error_line - context_radius)
	var end_line :Variant = min(total, error_line + context_radius)
	print("[WebOverlay][JS][ctx] around about:blank:%s (total=%s)" % [error_line, total])
	for idx in range(start_line, end_line + 1):
		var marker := ">>" if idx == error_line else "  "
		print("[WebOverlay][JS][ctx]%s L%s: %s" % [marker, idx, lines[idx - 1]])

func _on_web_ipc_message(msg: String) -> void:
	print("[WebOverlay] ipc_message: ", msg)

	if msg == "close":
		close()
		return

	if msg == "html_loaded":
		print("[WebOverlay] HTML cargado")
		if not _web_hydration_payload.is_empty():
			_hydrate_web_editor(_web_hydration_payload)
			_web_hydration_payload = {}
		if _awaiting_html_ready:
			_awaiting_html_ready = false
			_finish_overlay_open_after_html_ready()
			_emit_overlay_opened()
			print("[WebOverlay] open -> HTML visible y focus listo")
		return

	if msg == "img_error":
		push_warning("[WebOverlay] Error rasterizando SVG")
		return

	var data: Variant = JSON.parse_string(msg)
	if typeof(data) == TYPE_DICTIONARY:
		match str(data.get("type", "")):
			"debug_js_log":
				print("[WebOverlay][JS][log] %s" % str(data.get("message", "")))
			"debug_js_error":
				var message := str(data.get("message", ""))
				var source := str(data.get("source", ""))
				var line_number := int(data.get("line", 0))
				var column_number := int(data.get("column", 0))
				push_warning("[WebOverlay][JS] %s @%s:%s:%s" % [message, source, line_number, column_number])
				if source == "about:blank":
					_debug_print_html_context(line_number, 6)
			"debug_font_status":
				print("[WebOverlay][Font] estado=%s ready=%s distinct_metrics=%s active=%s computed=%s" % [
					str(data.get("requested", "OverlayDisplay")),
					str(data.get("ready", false)),
					str(data.get("distinct_metrics", false)),
					str(data.get("active_overlay_font", false)),
					str(data.get("computed_font_family", ""))
				])
			"close":
				close()
				return
			"save_css":
				_save_css_draft(data)
			"equip_bullet":
				_save_and_equip_bullet(data)
				close()
			"solar_pillar_tutorial_started":
				_mark_first_solar_pillar_opened(false)
			"solar_pillar_tutorial_done":
				_mark_first_solar_pillar_opened(true)
			"emis_api_key_submit":
				_set_emis_api_key(String(data.get("api_key", "")))
			"chat_request":
				_handle_chat_request(data)

func _set_emis_api_key(value: String) -> void:
	_emis_api_key = value.strip_edges()
	if has_node("/root/EmisGameContext"):
		EmisGameContext.set_api_key(_emis_api_key)
	var client := _get_emis_client()
	if client != null and client.has_method("set_player_api_key"):
		client.call("set_player_api_key", _emis_api_key)
	var configured := _emis_api_key != ""
	print("[Emis] API key de jugador configurada=%s" % configured)
	_send_emis_api_key_status_to_web(configured)

func _handle_chat_request(data: Dictionary) -> void:
	var raw_message := String(data.get("message", ""))
	var message := raw_message.strip_edges()
	if message == "":
		push_warning("[Emis] chat_request inválido: message vacío")
		_send_emis_reply_to_web({
			"ok": false,
			"error": "message vacío",
			"code": "invalid_response"
		})
		return

	var incoming_context: Dictionary = {}
	var raw_context: Variant = data.get("context", {})
	if typeof(raw_context) == TYPE_DICTIONARY:
		incoming_context = raw_context

	var context := _build_emis_context(incoming_context)
	var payload := _build_emis_payload_for_backend(data, context, message)
	print("[Emis] solicitud -> %s" % JSON.stringify(payload))

	var response: Dictionary = {}
	var client := _get_emis_client()
	if client == null:
		var no_client_msg := "Cliente Emis no disponible"
		push_warning("[Emis] " + no_client_msg)
		response = {"ok": false, "error": no_client_msg, "code": "network"}
	elif client.has_method("request_chat"):
		var result: Variant = await client.call("request_chat", payload)
		if typeof(result) == TYPE_DICTIONARY:
			response = result
		else:
			response = {"ok": false, "error": "Respuesta inválida del cliente Emis", "code": "invalid_response"}
	elif client.has_method("chat_request"):
		var alt_result: Variant = await client.call("chat_request", payload)
		if typeof(alt_result) == TYPE_DICTIONARY:
			response = alt_result
		else:
			response = {"ok": false, "error": "Respuesta inválida del cliente Emis", "code": "invalid_response"}
	else:
		response = {"ok": false, "error": "Cliente Emis sin método de chat compatible", "code": "invalid_response"}

	if not bool(response.get("ok", false)):
		push_warning("[Emis] error <- %s (%s)" % [String(response.get("error", "desconocido")), String(response.get("code", "unknown"))])
	else:
		_update_emis_conversation_id(response)
		print("[Emis] respuesta <- %s" % JSON.stringify(response))
	_send_emis_reply_to_web(response)

func _build_emis_payload_for_backend(data: Dictionary, context: Dictionary, message: String) -> Dictionary:
	var normalized_message := message.substr(0, min(message.length(), 1200))
	var intent_mode := String(data.get("intent_mode", context.get("intent_mode", "auto"))).strip_edges().to_lower()
	if intent_mode != "tutor_css" and intent_mode != "guia_juego":
		intent_mode = "auto"

	var player_context := _build_player_context_for_emis(data, context)
	var css_snapshot_fragment := String(context.get("css_text", last_css)).strip_edges()
	if css_snapshot_fragment.length() > 10000:
		css_snapshot_fragment = css_snapshot_fragment.substr(0, 10000)

	var payload := {
		"message": normalized_message,
		"intent_mode": intent_mode,
		"chat_surface": _resolve_chat_surface(data, context),
		"player_context": player_context,
		"css_snapshot_fragment": css_snapshot_fragment
	}

	if _emis_conversation_id == "":
		_emis_conversation_id = _create_conversation_id()
	if _emis_conversation_id != "":
		payload["conversation_id"] = _emis_conversation_id

	return payload

func _resolve_chat_surface(data: Dictionary, context: Dictionary) -> String:
	var surface := String(data.get("chat_surface", context.get("chat_surface", ""))).strip_edges().to_lower()
	if surface == "general_chat":
		return "general_chat"
	return "bullet_creator"

func _build_player_context_for_emis(data: Dictionary, context: Dictionary) -> Dictionary:
	var game_context := _get_emis_game_context_snapshot()
	var snapshot: Dictionary = {}
	var raw_snapshot: Variant = context.get("snapshot", {})
	if typeof(raw_snapshot) == TYPE_DICTIONARY:
		snapshot = raw_snapshot

	var player_context: Dictionary = {}
	var chat_surface := _resolve_chat_surface(data, context)
	var default_screen := "bullet_creator" if chat_surface == "bullet_creator" else "world"
	player_context["screen"] = String(data.get("screen", context.get("screen", game_context.get("screen", default_screen)))).strip_edges()
	player_context["level"] = String(data.get("level", context.get("level", game_context.get("level", "")))).strip_edges()
	player_context["objective"] = String(data.get("objective", context.get("objective", game_context.get("objective", "")))).strip_edges()
	player_context["zone_id"] = String(data.get("zone_id", context.get("zone_id", game_context.get("zone_id", "")))).strip_edges()
	player_context["quest_id"] = String(data.get("quest_id", context.get("quest_id", game_context.get("quest_id", "")))).strip_edges()
	player_context["quest_step"] = String(data.get("quest_step", context.get("quest_step", game_context.get("quest_step", "")))).strip_edges()
	player_context["current_area_description"] = String(game_context.get("current_area_description", "")).strip_edges()
	player_context["current_dialog_context"] = String(game_context.get("current_dialog_context", "")).strip_edges()
	player_context["recent_event"] = String(game_context.get("recent_event", "")).strip_edges()

	var unlocked_css_raw: Variant = data.get("unlocked_css", context.get("unlocked_css", snapshot.get("detected_properties", [])))
	player_context["unlocked_css"] = _to_packed_string_array(unlocked_css_raw)
	player_context["nearby_npcs"] = _to_packed_string_array(data.get("nearby_npcs", context.get("nearby_npcs", [])))
	player_context["available_portals"] = _to_packed_string_array(data.get("available_portals", context.get("available_portals", [])))
	player_context["inventory_tags"] = _to_packed_string_array(data.get("inventory_tags", context.get("inventory_tags", [])))
	player_context["failed_attempts_css"] = _to_packed_string_array(data.get("failed_attempts_css", context.get("failed_attempts_css", [])))
	var active_bullet: Variant = game_context.get("active_bullet", {})
	if typeof(active_bullet) == TYPE_DICTIONARY:
		player_context["active_bullet"] = active_bullet
	var movement_unlocks: Variant = game_context.get("movement_unlocks", {})
	if typeof(movement_unlocks) == TYPE_DICTIONARY:
		player_context["movement_unlocks"] = movement_unlocks
	return player_context

func _get_emis_game_context_snapshot() -> Dictionary:
	if has_node("/root/EmisGameContext") and EmisGameContext.has_method("get_context"):
		var raw: Variant = EmisGameContext.call("get_context")
		if typeof(raw) == TYPE_DICTIONARY:
			return raw
	return {}

func _create_conversation_id() -> String:
	return "conv_%s_%s" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]

func _update_emis_conversation_id(response: Dictionary) -> void:
	var raw: Dictionary = {}
	var raw_response: Variant = response.get("raw", {})
	if typeof(raw_response) == TYPE_DICTIONARY:
		raw = raw_response

	var from_raw := String(raw.get("conversation_id", "")).strip_edges()
	if from_raw != "":
		_emis_conversation_id = from_raw
		return

	var from_top_level := String(response.get("conversation_id", "")).strip_edges()
	if from_top_level != "":
		_emis_conversation_id = from_top_level

func _to_packed_string_array(raw: Variant) -> PackedStringArray:
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		var mapped := PackedStringArray()
		for item in raw:
			var value := String(item).strip_edges().to_lower()
			if value != "":
				mapped.append(value)
		return mapped
	return PackedStringArray()

func _build_emis_context(data_from_js: Dictionary) -> Dictionary:
	# Contrato estable emis_chat_v1:
	# {
	#   contract_version: String,
	#   css_text: String,
	#   svg_text: String,
	#   bullet_equipped: bool,
	#   updated_at: String,
	#   detected_properties: PackedStringArray,
	#   css_rules: PackedStringArray,
	#   locked_properties: PackedStringArray,
	#   unlock_state: Dictionary,
	#   all_properties: PackedStringArray,
	#   history: Array[Dictionary]?,
	#   snapshot: Dictionary
	# }
	var context := data_from_js.duplicate(true)
	var hydration := _read_bullet_hydration_payload()
	var snapshot: Dictionary = {}
	var raw_snapshot: Variant = context.get("snapshot", {})
	if typeof(raw_snapshot) == TYPE_DICTIONARY:
		snapshot = raw_snapshot

	var css_text := String(snapshot.get("css_text", String(context.get("css_text", context.get("css", "")))))
	if css_text == "":
		css_text = String(hydration.get("css_text", last_css))

	var svg_text := String(snapshot.get("svg_text", String(context.get("svg_text", context.get("svg", "")))))
	if svg_text == "":
		svg_text = String(hydration.get("svg_text", ""))
	if svg_text == "":
		svg_text = last_svg

	var detected_from_js := _to_packed_string_array(snapshot.get("detected_properties", context.get("detected_properties", [])))
	var detected_backend := _extract_css_rules(css_text)
	var detected_properties := detected_from_js if not detected_from_js.is_empty() else detected_backend

	var locked_from_js := _to_packed_string_array(snapshot.get("locked_properties", context.get("locked_properties", [])))
	var locked_backend := _get_locked_properties_from_singleton(css_text)
	var locked_properties := locked_from_js if not locked_from_js.is_empty() else locked_backend

	var unlock_state := _get_unlock_state_from_singleton()
	var unlock_state_from_js: Variant = snapshot.get("unlock_state", context.get("unlock_state", {}))
	if typeof(unlock_state_from_js) == TYPE_DICTIONARY:
		var from_js_dict: Dictionary = unlock_state_from_js
		if not from_js_dict.is_empty():
			unlock_state = from_js_dict

	var bullet_equipped := bool(snapshot.get("bullet_equipped", context.get("bullet_equipped", hydration.get("bullet_equipped", false))))
	var updated_at := String(snapshot.get("updated_at", context.get("updated_at", hydration.get("updated_at", ""))))

	context["contract_version"] = String(context.get("contract_version", "emis_chat_v1"))
	context["css_text"] = css_text
	context["svg_text"] = svg_text
	context["css"] = css_text
	context["svg"] = svg_text
	context["bullet_equipped"] = bullet_equipped
	context["updated_at"] = updated_at
	context["detected_properties"] = detected_properties
	context["css_rules"] = detected_backend
	context["locked_properties"] = locked_properties
	context["unlock_state"] = unlock_state
	context["all_properties"] = _get_all_properties_from_singleton()

	context["snapshot"] = {
		"css_text": css_text,
		"svg_text": svg_text,
		"detected_properties": detected_properties,
		"locked_properties": locked_properties,
		"unlock_state": unlock_state,
		"bullet_equipped": bullet_equipped,
		"updated_at": updated_at
	}
	return context

func _ensure_emis_client() -> void:
	if is_instance_valid(_emis_client):
		return
	_emis_client = EmisClientScript.new()
	_emis_client.name = "EmisClient"
	add_child(_emis_client)
	if _emis_api_key != "" and _emis_client.has_method("set_player_api_key"):
		_emis_client.call("set_player_api_key", _emis_api_key)
	if _emis_client.has_method("add_to_group"):
		_emis_client.call("add_to_group", "emis_client")
	print("[Emis] Cliente local inicializado")

func _get_emis_client() -> Node:
	if is_instance_valid(_emis_client):
		return _emis_client

	var root := get_tree().root
	if root == null:
		return null
	var by_name := root.get_node_or_null("EmisClient")
	if by_name != null:
		return by_name
	var by_group := get_tree().get_first_node_in_group("emis_client")
	if by_group != null:
		return by_group
	return null

func _send_emis_reply_to_web(payload: Dictionary) -> void:
	var safe_payload := payload
	if safe_payload.is_empty():
		safe_payload = {"error": "Respuesta vacía del backend Emis"}
	var js := "window.onEmisReply(%s);" % JSON.stringify(safe_payload)
	_eval_overlay_js(js)

func _send_emis_api_key_status_to_web(configured: bool) -> void:
	var js := "if(window.onEmisApiKeyStatus){window.onEmisApiKeyStatus(%s);}" % JSON.stringify({
		"configured": configured
	})
	_eval_overlay_js(js)

func _save_css_draft(data: Dictionary) -> void:
	last_css = String(data.get("css", ""))
	last_svg = String(data.get("svg", ""))
	var dir_path := "user://bullets"
	var mkdir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		push_warning("[WebOverlay] No se pudo crear directorio de borradores. err=%s" % mkdir_err)
		return

	var draft_path := "%s/bullet_draft.json" % dir_path
	var now_iso := Time.get_datetime_string_from_system(true, true)
	var draft := {
		"css_text": last_css,
		"svg_text": last_svg,
		"updated_at": now_iso
	}
	var draft_file := FileAccess.open(draft_path, FileAccess.WRITE)
	if draft_file == null:
		push_warning("[WebOverlay] No se pudo guardar borrador editable")
		return
	draft_file.store_string(JSON.stringify(draft, "\t"))
	draft_file.flush()
	print("[WebOverlay] CSS draft persistido en %s" % draft_path)

func _save_and_equip_bullet(data: Dictionary) -> void:
	last_css = String(data.get("css", ""))
	last_svg = String(data.get("svg", ""))
	_save_css_draft(data)

	var data_url := String(data.get("data_url", ""))
	var prefix := "base64,"
	var base64_index := data_url.find(prefix)
	if base64_index == -1:
		push_warning("[WebOverlay] data_url inválida para bullet")
		return

	var bytes := Marshalls.base64_to_raw(data_url.substr(base64_index + prefix.length()))
	if bytes.is_empty():
		push_warning("[WebOverlay] PNG vacío para bullet")
		return

	var dir_path := "user://bullets"
	var mkdir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		push_warning("[WebOverlay] No se pudo crear directorio bullets. err=%s" % mkdir_err)
		return

	var image_path := "%s/bullet_current.png" % dir_path
	var profile_path := "%s/bullet_current.json" % dir_path

	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		push_warning("[WebOverlay] PNG inválido para bullet")
		return
	if image.save_png(image_path) != OK:
		push_warning("[WebOverlay] No se pudo guardar imagen bullet")
		return

	var meta: Dictionary = data.get("meta", {})
	var now_iso := Time.get_datetime_string_from_system(true, true)
	var existing_created_at := ""
	if FileAccess.file_exists(profile_path):
		var existing_data = _read_json_file(profile_path)
		if typeof(existing_data) == TYPE_DICTIONARY:
			existing_created_at = String(existing_data.get("created_at", ""))
	if existing_created_at == "":
		existing_created_at = now_iso

	var normalized_properties: Dictionary = _parse_relevant_properties_from_singleton(last_css)
	var locked_properties: PackedStringArray = _get_locked_properties_from_singleton(last_css)
	var profile := {
		"sprite_path": image_path,
		"image_path": image_path,
		"meta": {
			"w": int(meta.get("w", image.get_width())),
			"h": int(meta.get("h", image.get_height()))
		},
		"css_text": last_css,
		"css_rules": _extract_css_rules(last_css),
		"css_properties": normalized_properties,
		"css_locked_properties": locked_properties,
		"css_properties_used": _extract_css_rules(last_css),
		"damage_base": 1,
		"svg_text": last_svg,
		"created_at": existing_created_at,
		"updated_at": now_iso
	}

	var json_file := FileAccess.open(profile_path, FileAccess.WRITE)
	if json_file == null:
		push_warning("[WebOverlay] No se pudo abrir perfil bullet para escritura")
		return
	json_file.store_string(JSON.stringify(profile, "\t"))
	json_file.flush()
	last_bullet_profile_path = profile_path
	print("[WebOverlay] Bullet guardada en %s" % profile_path)
	print("[WebOverlay] profile(user://): %s" % profile_path)
	print("[WebOverlay] profile(abs): %s" % ProjectSettings.globalize_path(profile_path))
	print("[WebOverlay] image(user://): %s" % image_path)
	print("[WebOverlay] image(abs): %s" % ProjectSettings.globalize_path(image_path))
	profile["profile_path"] = profile_path
	_notify_player_to_equip_bullet(profile)

func _notify_player_to_equip_bullet(profile: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("[WebOverlay] No se encontró jugador para equipar bullet")
		return
	if player.has_method("equip_bullet_from_profile"):
		player.call("equip_bullet_from_profile", profile)
	elif player.has_method("equip_bullet_profile"):
		player.call("equip_bullet_profile", profile)
	else:
		push_warning("[WebOverlay] Jugador sin método equip_bullet_from_profile(profile)")

func _read_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	if text.strip_edges() == "":
		return null
	return JSON.parse_string(text)

func _read_bullet_hydration_payload() -> Dictionary:
	var unlock_state: Dictionary = _get_unlock_state_from_singleton()
	var all_properties: PackedStringArray = _get_all_properties_from_singleton()
	var base_payload := {
		"unlock_state": unlock_state,
		"all_properties": all_properties,
		"bullet_equipped": false,
		"updated_at": ""
	}
	var draft_path := "user://bullets/bullet_draft.json"
	var profile_path := "user://bullets/bullet_current.json"
	var css_text := ""
	var svg_text := ""
	var updated_at := ""
	var bullet_equipped := false

	if FileAccess.file_exists(draft_path):
		var draft_raw: Variant = _read_json_file(draft_path)
		if typeof(draft_raw) == TYPE_DICTIONARY:
			var draft_data: Dictionary = draft_raw
			css_text = String(draft_data.get("css_text", ""))
			svg_text = String(draft_data.get("svg_text", ""))
			updated_at = String(draft_data.get("updated_at", ""))

	if FileAccess.file_exists(profile_path):
		var profile_raw: Variant = _read_json_file(profile_path)
		if typeof(profile_raw) == TYPE_DICTIONARY:
			var profile_data: Dictionary = profile_raw
			bullet_equipped = true
			if updated_at == "":
				updated_at = String(profile_data.get("updated_at", ""))
			if css_text == "":
				css_text = String(profile_data.get("css_text", ""))
			if svg_text == "":
				svg_text = String(profile_data.get("svg_text", ""))

	base_payload["bullet_equipped"] = bullet_equipped
	base_payload["updated_at"] = updated_at
	if css_text != "":
		base_payload["css_text"] = css_text
	if svg_text != "":
		base_payload["svg_text"] = svg_text
	return base_payload

func _read_tutorial_flags() -> Dictionary:
	if not FileAccess.file_exists(TUTORIAL_FLAGS_PATH):
		return {}
	var file := FileAccess.open(TUTORIAL_FLAGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var flags: Dictionary = parsed
	return flags

func _save_tutorial_flags(flags: Dictionary) -> void:
	var dir_path := "user://progress"
	var mkdir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mkdir_err != OK and mkdir_err != ERR_ALREADY_EXISTS:
		push_warning("[WebOverlay] No se pudo crear directorio progress. err=%s" % mkdir_err)
		return
	var file := FileAccess.open(TUTORIAL_FLAGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[WebOverlay] No se pudo guardar tutorial_flags")
		return
	file.store_string(JSON.stringify(flags, "\t"))
	file.flush()

func _should_show_first_solar_pillar_tutorial() -> bool:
	var flags := _read_tutorial_flags()
	var completed_version := int(flags.get("solar_pillar_tutorial_completed_version", 0))
	return completed_version < SOLAR_PILLAR_TUTORIAL_VERSION

func _mark_first_solar_pillar_opened(completed: bool = false) -> void:
	var flags := _read_tutorial_flags()
	if not bool(flags.get("first_solar_pillar_opened", false)):
		flags["first_solar_pillar_opened_at"] = Time.get_datetime_string_from_system(true, true)
	flags["first_solar_pillar_opened"] = true
	flags["solar_pillar_tutorial_seen"] = bool(flags.get("solar_pillar_tutorial_seen", false)) or completed
	flags["solar_pillar_tutorial_started_version"] = SOLAR_PILLAR_TUTORIAL_VERSION
	if completed:
		flags["solar_pillar_tutorial_seen"] = true
		flags["solar_pillar_tutorial_completed_version"] = SOLAR_PILLAR_TUTORIAL_VERSION
		flags["solar_pillar_tutorial_completed_at"] = Time.get_datetime_string_from_system(true, true)
	_save_tutorial_flags(flags)

func _hydrate_web_editor(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var js := "hydrateFromGodot(%s);" % JSON.stringify(payload)
	_eval_overlay_js(js)

func _extract_css_rules(text: String) -> PackedStringArray:
	var rules := PackedStringArray()
	for chunk in text.split(";"):
		var pair := chunk.strip_edges()
		if pair == "":
			continue
		var idx := pair.find(":")
		if idx == -1:
			continue
		var key := pair.substr(0, idx).strip_edges().to_lower()
		if key != "":
			rules.append(key)
	return rules

func _get_css_affinity_singleton() -> Node:
	return get_tree().root.get_node_or_null("CssAffinity")

func _get_css_unlocks_singleton() -> Node:
	return get_tree().root.get_node_or_null("CssUnlocks")

func _parse_relevant_properties_from_singleton(css_text: String) -> Dictionary:
	var singleton := _get_css_affinity_singleton()
	if singleton != null and singleton.has_method("parse_relevant_properties"):
		var parsed: Variant = singleton.call("parse_relevant_properties", css_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {}

func _get_locked_properties_from_singleton(css_text: String) -> PackedStringArray:
	var singleton := _get_css_unlocks_singleton()
	if singleton != null and singleton.has_method("get_locked_properties_from_css"):
		var locked: Variant = singleton.call("get_locked_properties_from_css", css_text)
		if locked is PackedStringArray:
			return locked
		if locked is Array:
			return PackedStringArray(locked)
	return PackedStringArray()

func _get_unlock_state_from_singleton() -> Dictionary:
	var singleton := _get_css_unlocks_singleton()
	if singleton != null and singleton.has_method("get_unlock_state"):
		var state: Variant = singleton.call("get_unlock_state")
		if typeof(state) == TYPE_DICTIONARY:
			return state
	return {}

func _get_all_properties_from_singleton() -> PackedStringArray:
	var singleton := _get_css_unlocks_singleton()
	if singleton != null and singleton.has_method("get_all_properties"):
		var all_props: Variant = singleton.call("get_all_properties")
		if all_props is PackedStringArray:
			return all_props
		if all_props is Array:
			return PackedStringArray(all_props)
	return PackedStringArray()
