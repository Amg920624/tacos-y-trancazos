extends Node
## Autoload "GameManager": run flow (mode → 3 shifts → results/shop → win/lose), input map,
## scene transitions, achievements and a global toast overlay.

signal achievement_unlocked(id: String, title: String)

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"select": "res://scenes/mode_selection.tscn",
	"canasta": "res://scenes/canasta_mode.tscn",
	"carnitas": "res://scenes/carnitas_mode.tscn",
	"pastor": "res://scenes/pastor_mode.tscn",
	"shop": "res://scenes/upgrade_menu.tscn",
	"results": "res://scenes/results_screen.tscn",
	"end": "res://scenes/end_screen.tscn",
}
const SHIFT_DAYS := ["Viernes", "Sábado", "Domingo"]
const SHIFTS_PER_RUN := 3
const ACHIEVEMENTS := {
	"rey_trompo": {"title": "El Rey del Trompo", "desc": "5 cortes perfectos seguidos en el trompo."},
	"canastero": {"title": "Canastero Sin Miedo", "desc": "Vende en las tres zonas en un mismo turno."},
	"domingo_gloria": {"title": "Domingo de Gloria", "desc": "Sobrevive al Domingo de Carnitas."},
	"salsa_dios": {"title": "Salsa Nivel Dios", "desc": "8 pedidos perfectos en un solo turno."},
	"barrio": {"title": "El Barrio Me Respalda", "desc": "Llega a 400 de AURA."},
	"comal_oro": {"title": "Tres Comales de Oro", "desc": "Recibe la mejor reseña del crítico."},
	"gorron": {"title": "Ahí Te Ves, Gorrón", "desc": "Corre a El Gorrón de tu puesto."},
	"legendario": {"title": "Taquero Legendario", "desc": "Gana una partida completa."},
}

var mode := ""
var shift_index := 0
var run_active := false
var run_result := ""        # "", "win", "lose"
var lose_reason := ""
var achievements: Array = []
var shift_history: Array = []
var last_shift: Dictionary = {}
var critic_done := false
var tutorial_seen: Dictionary = {}
var test_mode := false       # tests: goto() records the request instead of changing scene
var last_goto := ""
var _snapshot: Dictionary = {}
var _fader: ColorRect
var _toast_layer: CanvasLayer
var _toasts: VBoxContainer
var _busy := false
var language := "es"
var _translation_loaded := false

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["es", "en"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_language()
	_setup_input()
	_build_overlay()
	Aura.level_up.connect(_on_level_up)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if str(a).begins_with("--tour"):
			var tour = load("res://scripts/dev/screenshot_tour.gd").new()
			add_child(tour)


# ---------------------------------------------------------------- language

## Spanish is the source language; English comes from data/i18n_en.json (Spanish text → English).
func _load_language() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = str(cfg.get_value("game", "language", "es"))
	if not (language in LANGUAGES):
		language = "es"
	set_language(language, false)


func set_language(lang: String, save := true) -> void:
	language = lang if lang in LANGUAGES else "es"
	if not _translation_loaded:
		_translation_loaded = true
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n_en.json")) if FileAccess.file_exists("res://data/i18n_en.json") else null
		if typeof(data) == TYPE_DICTIONARY:
			var t := Translation.new()
			t.locale = "en"
			for k in data.keys():
				t.add_message(str(k), str(data[k]))
			TranslationServer.add_translation(t)
		else:
			push_warning("No se pudo cargar data/i18n_en.json; el juego queda en español.")
	TranslationServer.set_locale(language)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("game", "language", language)
		cfg.save(SETTINGS_PATH)


func toggle_language() -> void:
	set_language("en" if language == "es" else "es")


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("interact", [KEY_E])
	_add_action("dash", [KEY_SPACE])
	_add_action("attack", [KEY_J], [MOUSE_BUTTON_LEFT])
	_add_action("special", [KEY_K], [MOUSE_BUTTON_RIGHT])
	_add_action("switch", [KEY_Q])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("mute", [KEY_M])
	_add_action("confirm", [KEY_E, KEY_ENTER, KEY_KP_ENTER])
	_add_action("choice_2", [KEY_K])
	_add_action("dev_event", [KEY_F2])
	_add_action("dev_critic", [KEY_F3])
	_add_action("dev_end", [KEY_F4])
	# Let E also press focused menu buttons.
	_add_action("ui_accept", [KEY_E])


func _add_action(action: String, keys: Array, mouse: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
	for b in mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)


# ---------------------------------------------------------------- run flow

func start_new_run(p_mode: String) -> void:
	var m := DB.mode(p_mode)
	if m.is_empty() or not m.get("unlocked", false):
		push_warning("Negocio no disponible: " + p_mode)
		return
	mode = p_mode
	shift_index = 0
	run_active = true
	run_result = ""
	lose_reason = ""
	shift_history.clear()
	last_shift = {}
	critic_done = false
	Economy.reset(int(m.get("start_cash", 150)))
	Aura.reset()
	Upgrades.reset()
	SaveManager.save_game()
	goto(mode)


func continue_run() -> bool:
	if not SaveManager.load_game():
		return false
	if not run_active:
		return false
	goto("shop" if shift_index > 0 else mode)
	return true


func mode_data() -> Dictionary:
	return DB.mode(mode)


func shift_target() -> int:
	var targets: Array = mode_data().get("shift_targets", [250, 330, 420])
	return int(targets[mini(shift_index, targets.size() - 1)])


func shift_time() -> float:
	return float(mode_data().get("shift_time", 150))


func daily_cost() -> int:
	var costs: Array = mode_data().get("daily_costs", [40, 50, 60])
	return int(costs[mini(shift_index, costs.size() - 1)])


func day_name() -> String:
	return tr(SHIFT_DAYS[clampi(shift_index, 0, SHIFT_DAYS.size() - 1)])


## Called by a mode right before its shift starts, so the shift can be restarted cleanly.
func begin_shift_snapshot() -> void:
	_snapshot = {"economy": Economy.to_dict(), "aura": Aura.to_dict()}


func restart_shift() -> void:
	if not _snapshot.is_empty():
		Economy.from_dict(_snapshot["economy"])
		Aura.from_dict(_snapshot["aura"])
	goto(mode)


## Mode reports the end of a shift. stats needs at least "revenue"; "failed_reason" ends the run.
func finish_shift(stats: Dictionary) -> void:
	EventManager.end_shift()
	var cuota := daily_cost()
	Economy.charge(cuota, "gastos_fijos")
	stats["day"] = day_name()
	stats["shift"] = shift_index
	stats["revenue"] = Economy.shift_revenue
	stats["costs"] = Economy.shift_costs
	stats["cost_items"] = Economy.shift_cost_items.duplicate()
	stats["profit"] = Economy.shift_revenue - Economy.shift_costs
	stats["target"] = shift_target()
	stats["aura_delta"] = Aura.shift_aura
	stats["cash"] = Economy.cash
	stats["daily_cost"] = cuota
	stats["daily_cost_label"] = mode_data().get("daily_cost_label", "Gastos fijos")
	var failed: String = stats.get("failed_reason", "")
	stats["met"] = failed == "" and Economy.shift_revenue >= stats["target"]
	if int(stats.get("perfect", 0)) >= 8:
		unlock("salsa_dios")
	shift_history.append(stats)
	last_shift = stats
	if failed != "":
		_lose(failed)
	elif not stats["met"]:
		_lose(tr("No llegaste a la meta del %s (%s de %s).") % [day_name(), Economy.money(Economy.shift_revenue), Economy.money(stats["target"])])
	elif Economy.is_bankrupt():
		_lose("Te fuiste a la quiebra: los gastos te comieron vivo.")
	elif shift_index >= SHIFTS_PER_RUN - 1:
		run_result = "win"
		run_active = false
		unlock("legendario")
	else:
		shift_index += 1
	SaveManager.save_game()
	goto("results")


func _lose(reason: String) -> void:
	run_result = "lose"
	lose_reason = reason
	run_active = false


func after_results() -> void:
	if run_result != "":
		goto("end")
	else:
		goto("shop")


func start_next_shift() -> void:
	SaveManager.save_game()
	goto(mode)


func total_revenue() -> int:
	var t := 0
	for s in shift_history:
		t += int(s.get("revenue", 0))
	return t


# ---------------------------------------------------------------- achievements & toasts

func unlock(id: String) -> void:
	if id in achievements or not ACHIEVEMENTS.has(id):
		return
	achievements.append(id)
	var title: String = ACHIEVEMENTS[id]["title"]
	achievement_unlocked.emit(id, title)
	AudioManager.play("achievement")
	toast(tr("¡LOGRO! %s") % tr(title), Color("ffcc00"))


func _on_level_up(_level: int, title: String) -> void:
	toast(tr("Subiste de nivel: %s") % title, Color("e4a3ff"))
	AudioManager.play("aura")
	if Aura.aura >= 400:
		unlock("barrio")


func toast(text: String, color := Color.WHITE) -> void:
	if _toasts == null:
		return
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.04, 0.03, 0.92)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", color)
	panel.add_child(l)
	_toasts.add_child(panel)
	var tw := panel.create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)


func _build_overlay() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 90
	add_child(_toast_layer)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(8, 300)
	_toasts.size = Vector2(300, 50)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toasts)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fader = ColorRect.new()
	_fader.color = Color(0.05, 0.03, 0.02, 0.0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.size = Vector2(640, 360)
	fade_layer.add_child(_fader)


# ---------------------------------------------------------------- scenes

func goto(key: String) -> void:
	last_goto = key
	if test_mode:
		return
	var path: String = SCENES.get(key, SCENES["menu"])
	get_tree().paused = false
	if _busy:
		get_tree().change_scene_to_file(path)
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, 0.18)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))
	tw.tween_interval(0.05)
	tw.tween_property(_fader, "color:a", 0.0, 0.22)
	tw.tween_callback(func(): _busy = false)


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"shift_index": shift_index,
		"run_active": run_active,
		"run_result": run_result,
		"achievements": achievements.duplicate(),
		"shift_history": shift_history.duplicate(true),
		"critic_done": critic_done,
		"tutorial_seen": tutorial_seen.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	mode = str(d.get("mode", ""))
	shift_index = clampi(int(d.get("shift_index", 0)), 0, SHIFTS_PER_RUN - 1)
	run_active = bool(d.get("run_active", false))
	run_result = str(d.get("run_result", ""))
	achievements = []
	for a in d.get("achievements", []):
		if ACHIEVEMENTS.has(str(a)):
			achievements.append(str(a))
	shift_history = d.get("shift_history", []) if typeof(d.get("shift_history")) == TYPE_ARRAY else []
	critic_done = bool(d.get("critic_done", false))
	tutorial_seen = d.get("tutorial_seen", {}) if typeof(d.get("tutorial_seen")) == TYPE_DICTIONARY else {}
