extends Node2D
## Shared base for stationary taquerías (carnitas, pastor).
## Owns the kitchen, counter slots, customer queue, plate assembly, serving and evaluation,
## shift timer, HUD, pause, events, critic and the difficult customer.
## Subclasses override the _mode_* hooks and generate_order().

const Pix = preload("res://scripts/art/pix.gd")
const Customer = preload("res://scripts/entities/customer_controller.gd")
const Player = preload("res://scripts/entities/player_controller.gd")
const Hud = preload("res://scripts/ui/hud_controller.gd")
const PopupText = preload("res://scripts/ui/popup_text.gd")
const Backdrop = preload("res://scripts/art/street_backdrop.gd")
const Instructions = preload("res://scripts/ui/instructions_overlay.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const OrderManager = preload("res://scripts/gameplay/order_manager.gd")

const STATION_Y := 160.0
const SERVE_Y := 204.0
const INTERACT_RADIUS := 27.0
const TORTILLA_PRESSES := 4

var mode_id := "carnitas"
var shift_time := 150.0
var time_left := 150.0
var running := false
var ended := false
var rng := RandomNumberGenerator.new()

var backdrop: Node2D
var equipment: Node2D
var front: Node2D
var actors: Node2D
var fx: Node2D
var player: Player
var hud: Hud
var pause_menu: PauseMenu
var orders: OrderManager

var stations: Array = []          # [{"id": String, "x": float, "label": String}]
var slot_xs: Array = [110.0, 220.0, 330.0, 440.0]
var plate := {"tacos": [], "verdura": false, "salsa": "", "pina": false}
var max_plate := 3
var near: Dictionary = {}
var combo := 0
var combo_enabled := false
var tortillas_ok := true
var tortilla_progress := 0
var critic_customer: Node2D = null
var difficult_customer: Node2D = null
var stats := {"served": 0, "perfect": 0, "wrong": 0, "angry": 0, "tacos": 0, "wasted": 0, "best_combo": 0, "critic_stars": -1}
var _t := 0.0


# ---------------------------------------------------------------- hooks for subclasses

func _mode_id() -> String:
	return "carnitas"

func _mode_setup() -> void:
	pass

func _mode_buy_ingredients() -> void:
	pass

func _mode_process(_delta: float) -> void:
	pass

func _mode_station(_id: String) -> void:
	pass

func _mode_station_prompt(_id: String) -> String:
	return ""

func _mode_switch() -> void:
	pass

func _mode_special() -> void:
	pass

func _mode_attack() -> void:
	pass

func _mode_event_started(_id: String) -> void:
	pass

func _mode_event_timeout(_id: String) -> void:
	pass

func _mode_after_serve(_c, _res: Dictionary) -> void:
	pass

func _mode_highlights() -> Array:
	return []

func _mode_instructions() -> Array:
	return []

func _mode_draw_equipment(_ci: Node2D) -> void:
	pass

func _mode_signature_event() -> String:
	return ""

func generate_order(_c) -> Dictionary:
	return {"filling": "pastor", "qty": 1, "verdura": true, "salsa": "verde"}

func patience_rate_for(_c) -> float:
	return 1.0


# ---------------------------------------------------------------- setup

func _ready() -> void:
	rng.randomize()
	mode_id = _mode_id()
	shift_time = GameManager.shift_time()
	time_left = shift_time
	_build_layers()
	var m := DB.mode(mode_id)
	var xs := slot_xs.duplicate()
	if Upgrades.stat("extra_slot", mode_id) > 0.0:
		xs.append(550.0)
	orders = OrderManager.new()
	orders.mode = self
	add_child(orders)
	orders.setup(xs, float(m.get("spawn_interval", 6.5)) * [1.0, 0.9, 0.82][clampi(GameManager.shift_index, 0, 2)])
	orders.customer_angry.connect(_on_customer_angry)
	_mode_setup()
	hud = Hud.new()
	hud.mode_ref = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	Aura.aura_changed.connect(_on_aura_changed)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_timeout.connect(_on_event_timeout)
	GameManager.begin_shift_snapshot()
	Economy.begin_shift()
	Aura.begin_shift()
	_mode_buy_ingredients()
	AudioManager.play_music(m.get("music", "day"))
	if GameManager.test_mode:
		start_shift()
	else:
		_show_instructions()


func _build_layers() -> void:
	backdrop = Backdrop.new()
	backdrop.z_index = -10
	add_child(backdrop)
	equipment = Node2D.new()
	equipment.draw.connect(func(): _draw_equipment(equipment))
	add_child(equipment)
	player = Player.new()
	player.position = Vector2(300, 182)
	add_child(player)
	front = Node2D.new()
	front.draw.connect(func(): _draw_front(front))
	add_child(front)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)


func _show_instructions() -> void:
	var m := DB.mode(mode_id)
	var first: bool = not GameManager.tutorial_seen.get(mode_id, false)
	var lines: Array = []
	if first:
		lines = _mode_instructions()
	else:
		lines = [tr("%s: hoy la meta es %s.") % [GameManager.day_name(), Economy.money(GameManager.shift_target())],
			tr("Gastos fijos al cierre: %s (%s).") % [Economy.money(GameManager.daily_cost()), tr(m.get("daily_cost_label", ""))],
			"WASD moverte · E usar · Q cambiar · ESPACIO esquivar · ESC pausa"]
	lines.append("")
	lines.append(tr("META DEL %s: %s en ventas · Tiempo: %s") % [GameManager.day_name().to_upper(), Economy.money(GameManager.shift_target()), Pix.fmt_time(shift_time)])
	var ov := Instructions.new()
	ov.setup(tr("%s — %s") % [m.get("stand_name", "").to_upper(), GameManager.day_name().to_upper()], lines, "Presiona E o ENTER para abrir el puesto")
	ov.closed.connect(start_shift)
	add_child(ov)
	GameManager.tutorial_seen[mode_id] = true


func start_shift() -> void:
	if running or ended:
		return
	running = true
	EventManager.begin_shift(mode_id, GameManager.shift_index)
	hud.banner(DB.line("shift_start", "¡A vender!"), Color("ffcc00"), 2.5)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_t += delta
	if not running or ended:
		equipment.queue_redraw()
		front.queue_redraw()
		return
	time_left = maxf(0.0, time_left - delta)
	var t_norm := 1.0 - time_left / shift_time
	EventManager.update(delta, t_norm)
	orders.update(delta, t_norm)
	player.step(delta)
	player.plate = plate
	_mode_process(delta)
	_update_near()
	hud.prompt = _prompt_text()
	equipment.queue_redraw()
	front.queue_redraw()
	if time_left <= 0.0:
		end_shift("")


func _unhandled_input(event: InputEvent) -> void:
	if not running or ended:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("switch"):
		_mode_switch()
	elif event.is_action_pressed("special"):
		_mode_special()
	elif event.is_action_pressed("attack"):
		_mode_attack()
	elif event.is_action_pressed("dash"):
		if player.dash():
			AudioManager.play("attack", -10.0, 1.4)
	elif event.is_action_pressed("dev_event"):
		var sig := _mode_signature_event()
		if sig != "":
			EventManager.try_start(sig, true)
	elif event.is_action_pressed("dev_critic"):
		EventManager.try_start("critico", true)
	elif event.is_action_pressed("dev_end"):
		time_left = minf(time_left, 3.0)


func patience_scale() -> float:
	return [1.0, 0.92, 0.85][clampi(GameManager.shift_index, 0, 2)]


func order_speech(c) -> String:
	var lines: Array = c.archetype.get("lines", [])
	var item := DB.recipe_name(c.order.get("filling", ""), true).to_lower()
	var s := "¡Jefe! Écheme {qty} de {item}."
	if lines.size() > 0:
		s = lines[rng.randi() % lines.size()]
	return tr(s).replace("{qty}", str(c.order.get("qty", 1))).replace("{item}", item)


# ---------------------------------------------------------------- interaction

func station_pos(id: String) -> Vector2:
	for s in stations:
		if s["id"] == id:
			return Vector2(s["x"], STATION_Y)
	return Vector2(-999, -999)


func _update_near() -> void:
	near = {}
	var best := INTERACT_RADIUS
	var p: Vector2 = player.position
	for s in stations:
		var d := p.distance_to(Vector2(s["x"], STATION_Y))
		if d < best:
			best = d
			near = {"kind": "station", "id": s["id"]}
	for i in orders.slot_xs.size():
		var d := p.distance_to(Vector2(orders.slot_xs[i], SERVE_Y))
		if d < best:
			best = d
			near = {"kind": "slot", "slot": i}


func _prompt_text() -> String:
	if near.is_empty():
		return "WASD: moverte · Q: cambiar · ESPACIO: esquivar · ESC: pausa"
	if near["kind"] == "slot":
		var c := orders.customer_at(near["slot"])
		if c == null or not c.is_waiting():
			return "Nadie esperando en este lugar"
		if plate["tacos"].is_empty():
			return "Arma el pedido y regresa (E: entregar)"
		return "E: Entregar el pedido"
	var id: String = near["id"]
	match id:
		"verdura":
			return "E: Cebolla y cilantro"
		"salsa_verde":
			return "E: Salsa verde"
		"salsa_roja":
			return "E: Salsa roja"
		"pina":
			return "E: Piña"
		"basura":
			return "E: Tirar el plato"
		"tortillas":
			if not tortillas_ok:
				return tr("E: ¡Calentar tortillas! (%d/%d)") % [tortilla_progress, TORTILLA_PRESSES]
			return "Tortillas calientitas en su servilleta"
	return _mode_station_prompt(id)


func interact() -> void:
	if not player.is_free() or near.is_empty():
		return
	if near["kind"] == "slot":
		serve(near["slot"])
		return
	match near["id"]:
		"verdura":
			add_verdura()
		"salsa_verde":
			add_salsa("verde")
		"salsa_roja":
			add_salsa("roja")
		"pina":
			add_pina()
		"basura":
			trash_plate()
		"tortillas":
			_tortillas_interact()
		_:
			_mode_station(near["id"])


func popup(text: String, color := Color("fff3d6"), pos = null) -> void:
	var at: Vector2 = pos if pos != null else player.position + Vector2(0, -36)
	PopupText.spawn(fx, at, text, color, 8, 1.1)


# ---------------------------------------------------------------- plate

func plate_add_taco(filling: String, quality: float) -> bool:
	if plate["tacos"].size() >= max_plate:
		popup("¡Ya no cabe otro taco!", Color("ffb3b3"))
		return false
	if not tortillas_ok:
		popup("¡No hay tortillas!", Color("ffb3b3"))
		return false
	plate["tacos"].append({"filling": filling, "quality": clampf(quality, 0.0, 1.0)})
	return true


func clear_plate() -> void:
	plate = {"tacos": [], "verdura": false, "salsa": "", "pina": false}
	player.plate = plate


func add_verdura() -> void:
	if plate["tacos"].is_empty():
		popup("Primero los tacos, jefe")
		return
	if plate["verdura"]:
		popup("Ya tiene cebolla y cilantro")
		return
	plate["verdura"] = true
	player.do_action("chop", 0.22)
	AudioManager.play("chop", -6.0, 1.2)


func add_salsa(kind: String) -> void:
	if plate["tacos"].is_empty():
		popup("Primero los tacos, jefe")
		return
	if plate["salsa"] == kind:
		popup(tr("Ya tiene salsa %s") % kind)
		return
	if plate["salsa"] != "":
		popup(tr("¡Ya le pusiste salsa %s!") % plate["salsa"], Color("ffb3b3"))
		return
	plate["salsa"] = kind
	player.do_action("chop", 0.2)
	AudioManager.play("pina", -10.0, 0.7)


func add_pina() -> bool:
	if plate["tacos"].is_empty():
		popup("Primero los tacos, jefe")
		return false
	if plate["pina"]:
		popup("Ya tiene piña")
		return false
	plate["pina"] = true
	player.do_action("chop", 0.2)
	AudioManager.play("pina", -6.0)
	return true


func trash_plate() -> void:
	if plate["tacos"].is_empty():
		popup("No hay nada que tirar")
		return
	stats["wasted"] += plate["tacos"].size()
	clear_plate()
	popup("¡A la basura!", Color("ffb3b3"))
	AudioManager.play("fail", -8.0, 1.4)


func _tortillas_interact() -> void:
	if tortillas_ok:
		popup("Hay tortillas de sobra")
		return
	tortilla_progress += 1
	player.do_action("chop", 0.3)
	AudioManager.play("sizzle", -4.0)
	if tortilla_progress >= TORTILLA_PRESSES:
		tortillas_ok = true
		popup("¡Tortillas calientitas!", Color("8ef58e"))
		EventManager.resolve("sin_tortillas", true, player.position + Vector2(0, -50), true)


# ---------------------------------------------------------------- serving

func unit_price(filling: String) -> float:
	return DB.price(filling) * (1.0 + Upgrades.stat("price", mode_id))


func combo_cap() -> int:
	return 4 + int(Upgrades.stat("combo_cap", mode_id))


func combo_mult() -> float:
	if not combo_enabled:
		return 1.0
	return 1.0 + 0.25 * mini(combo, combo_cap())


## Compares the plate against the order. Public so tests can check the rules directly.
func evaluate(order: Dictionary, p: Dictionary, speed := 1.0) -> Dictionary:
	var tacos: Array = p.get("tacos", [])
	var n := tacos.size()
	var want := int(order.get("qty", 1))
	var fill_ok := n > 0
	var q_sum := 0.0
	for t in tacos:
		if t.get("filling", "") != order.get("filling", ""):
			fill_ok = false
		q_sum += float(t.get("quality", 1.0))
	var quality := q_sum / maxf(1.0, n)
	var verd_ok := bool(p.get("verdura", false)) == bool(order.get("verdura", false))
	var salsa_ok := str(p.get("salsa", "")) == str(order.get("salsa", ""))
	var pina_ok := (not order.has("pina")) or bool(p.get("pina", false)) == bool(order.get("pina", false))
	var garnish_ok := verd_ok and salsa_ok and pina_ok
	var verdict := "ok"
	if not fill_ok:
		verdict = "wrong"
	elif n < want:
		verdict = "short"
	elif not garnish_ok:
		verdict = "garnish"
	elif quality >= 0.85 and speed >= 0.35:
		verdict = "perfect"
	var sat := 0.05
	match verdict:
		"perfect", "ok":
			sat = clampf(0.35 + 0.35 * quality + 0.3 * speed, 0.0, 1.0)
		"garnish":
			sat = 0.45
		"short":
			sat = 0.4
	return {"verdict": verdict, "quality": quality, "speed": speed, "n": n, "want": want,
		"fill_ok": fill_ok, "qty_ok": n == want, "garnish_ok": garnish_ok, "satisfaction": sat}


func serve(slot_idx: int) -> bool:
	var c := orders.customer_at(slot_idx)
	if c == null or not c.is_waiting():
		popup("Aquí no hay nadie esperando")
		return false
	if plate["tacos"].is_empty():
		popup("¡Primero arma el pedido!")
		return false
	var res := evaluate(c.order, plate, c.patience_ratio())
	clear_plate()
	_apply_result(c, res)
	orders.release(c)
	return true


func _apply_result(c, res: Dictionary) -> void:
	var filling: String = c.order.get("filling", "")
	var price := unit_price(filling)
	var tip := float(c.archetype.get("tip", 0.0)) + Aura.tip_bonus() + 0.15 * float(res["speed"])
	var q := float(res["quality"])
	var want := int(res["want"])
	var pay := 0.0
	var aura := 0
	var line := ""
	var happy := true
	match res["verdict"]:
		"perfect":
			if combo_enabled:
				combo += 1
				stats["best_combo"] = maxi(stats["best_combo"], combo)
			pay = price * want * (0.7 + 0.3 * q) * (1.0 + tip) * combo_mult()
			aura = 15 + (5 * mini(combo, combo_cap()) if combo_enabled else 0)
			line = DB.line("happy", "¡Qué ricos!")
			stats["perfect"] += 1
			AudioManager.play("perfect", -4.0)
		"ok":
			combo = 0
			pay = price * want * (0.7 + 0.3 * q) * (1.0 + tip * 0.5)
			aura = 8
			line = DB.line("ok", "Gracias, jefe.")
		"garnish":
			combo = 0
			pay = price * want * 0.85
			aura = -5
			line = DB.line("garnish_wrong", "Bueno, ya qué.")
		"short":
			combo = 0
			pay = price * res["n"] * 0.8
			aura = -5
			line = DB.line("short", "Faltan tacos.")
		"wrong":
			combo = 0
			pay = 0.0
			aura = -15
			happy = false
			line = DB.line("wrong", "¡Yo no pedí esto!")
			stats["wrong"] += 1
	if c.modifier == "difficult" and res["verdict"] in ["perfect", "ok"]:
		pay *= 2.0
	var got := Economy.add_sale(pay)
	if res["verdict"] != "wrong":
		stats["served"] += 1
		stats["tacos"] += mini(res["n"], want)
	c.payment = got
	c.satisfaction = res["satisfaction"]
	Aura.record_satisfaction(res["satisfaction"])
	var at: Vector2 = c.position + Vector2(0, -34)
	if got > 0:
		PopupText.spawn(fx, at + Vector2(0, 10), "+" + Economy.money(got), Color("8ef58e"), 9, 1.2)
		AudioManager.play("cash", -3.0)
	else:
		AudioManager.play("fail", -2.0)
	if aura != 0:
		Aura.add(aura, "", at - Vector2(0, 6), true)
	c.receive(happy, line)
	if c.modifier == "critic":
		_critic_review(c, res)
	if c == difficult_customer:
		EventManager.resolve("cliente_dificil", res["verdict"] in ["perfect", "ok"], at, true)
		difficult_customer = null
	_mode_after_serve(c, res)


func _on_customer_angry(c) -> void:
	stats["angry"] += 1
	combo = 0
	Aura.record_satisfaction(0.0)
	Aura.add(-15, "", c.position + Vector2(0, -40), true)
	AudioManager.play("angry", -2.0)
	if c == critic_customer:
		_critic_review(c, {"fill_ok": false, "qty_ok": false, "garnish_ok": false, "quality": 0.0, "speed": 0.0, "satisfaction": 0.0})
	if c == difficult_customer:
		EventManager.resolve("cliente_dificil", false, c.position + Vector2(0, -50), true)
		difficult_customer = null


func _critic_review(c, res: Dictionary) -> void:
	if c.revealed_critic:
		return
	c.revealed_critic = true
	var score := 0.0
	if res.get("fill_ok", false) and res.get("qty_ok", false):
		score += 40.0
	if res.get("garnish_ok", false):
		score += 10.0
	score += 25.0 * float(res.get("quality", 0.0))
	score += 20.0 * float(res.get("speed", 0.0))
	score += 5.0 * float(res.get("satisfaction", 0.0))
	var stars := 0
	if score >= 85.0:
		stars = 3
	elif score >= 60.0:
		stars = 2
	elif score >= 35.0:
		stars = 1
	var aura_by_stars := [-20, 10, 50, 100]
	var aura: int = aura_by_stars[stars]
	stats["critic_stars"] = stars
	Aura.add(aura, "RESEÑA DEL CRÍTICO", c.position + Vector2(0, -50), true)
	hud.show_review(stars, DB.critic_review(stars), aura)
	if stars == 3:
		GameManager.unlock("comal_oro")
	EventManager.resolve("critico", stars >= 2)
	critic_customer = null


# ---------------------------------------------------------------- events

func _on_event_started(ev: Dictionary) -> void:
	var id: String = ev.get("id", "")
	var banner: String = ev.get("banner", "")
	if banner != "":
		hud.banner(banner, Color("ffcc00"), 3.5)
		AudioManager.play("order", 0.0, 0.8)
	match id:
		"critico":
			critic_customer = orders.spawn(DB.archetype("critico"), "critic")
			GameManager.critic_done = true
		"cliente_dificil":
			difficult_customer = orders.spawn(DB.archetype("exigente"), "difficult")
		"sin_tortillas":
			tortillas_ok = false
			tortilla_progress = 0
			AudioManager.play("fail", -4.0)
		_:
			_mode_event_started(id)


func _on_event_timeout(id: String) -> void:
	match id:
		"sin_tortillas":
			tortillas_ok = true
			hud.banner("Llegó el de las tortillas... tarde.", Color("ffb3b3"), 2.5)
		"critico":
			critic_customer = null
		"cliente_dificil":
			difficult_customer = null
		_:
			_mode_event_timeout(id)


func _on_aura_changed(_total: int, delta: int, message: String, pos: Vector2, has_pos: bool) -> void:
	if delta == 0 or not is_inside_tree():
		return
	var at: Vector2 = pos if has_pos else player.position + Vector2(0, -44)
	var col := Color("ffd34d") if delta > 0 else Color("ff6b6b")
	PopupText.spawn(fx, at, Aura.popup_text(delta, message), col, 8, 1.5)
	if delta >= 20:
		AudioManager.play("aura", -4.0)


# ---------------------------------------------------------------- end of shift

func end_shift(failed_reason := "") -> void:
	if ended:
		return
	ended = true
	running = false
	hud.prompt = ""
	AudioManager.play("shift_end")
	var s := stats.duplicate()
	s["failed_reason"] = failed_reason
	s["mode"] = mode_id
	s["events_ok"] = EventManager.handled_count()
	s["highlights"] = _mode_highlights()
	if GameManager.test_mode:
		GameManager.finish_shift(s)
		return
	hud.banner("¡SE ACABÓ EL TURNO!" if failed_reason == "" else "¡SE ACABÓ!", Color("ffcc00") if failed_reason == "" else Color("ff6b6b"), 2.0)
	get_tree().create_timer(1.8).timeout.connect(GameManager.finish_shift.bind(s))


# ---------------------------------------------------------------- drawing

func _draw_equipment(ci: Node2D) -> void:
	_mode_draw_equipment(ci)
	for s in stations:
		match s["id"]:
			"verdura":
				_draw_bowl(ci, s["x"], Color("d8d2c0"), "verdura")
			"salsa_verde":
				_draw_molcajete(ci, s["x"], Pix.C_SALSA_VERDE)
			"salsa_roja":
				_draw_salsa_bowl(ci, s["x"], Pix.C_SALSA_ROJA)
			"pina":
				_draw_bowl(ci, s["x"], Color("e6b422"), "pina")
			"basura":
				_draw_trash(ci, s["x"])
			"tortillas":
				_draw_tortillas(ci, s["x"])
	if not near.is_empty() and near["kind"] == "station" and running:
		var x: float = station_pos(near["id"]).x
		var bob := sin(_t * 8.0) * 1.5
		var pts := PackedVector2Array([Vector2(x - 4, 112 + bob), Vector2(x + 4, 112 + bob), Vector2(x, 117 + bob)])
		ci.draw_colored_polygon(pts, Color("ffcc00"))
	for s in stations:
		var lbl: String = s.get("label", "")
		if lbl != "":
			Pix.text(ci, Vector2(s["x"] - 30, 150), lbl, 6, Color("1d1410"), HORIZONTAL_ALIGNMENT_CENTER, 60)


func _draw_bowl(ci: Node2D, x: float, fill: Color, kind: String) -> void:
	Pix.r(ci, x - 13, 128, 26, 10, Color("e7e3d8"))
	Pix.r(ci, x - 13, 136, 26, 2, Color("b8b2a6"))
	Pix.r(ci, x - 11, 126, 22, 4, fill)
	if kind == "verdura":
		for i in 9:
			Pix.r(ci, x - 10 + (i * 7) % 20, 125 + (i * 3) % 4, 2, 2, Pix.C_ONION)
		for i in 7:
			Pix.r(ci, x - 9 + (i * 5) % 18, 126 + (i * 2) % 3, 2, 1, Pix.C_CILANTRO)
	elif kind == "pina":
		for i in 6:
			Pix.r(ci, x - 10 + i * 3.5, 124 + (i % 2) * 2, 3, 3, Pix.C_PINA)


func _draw_molcajete(ci: Node2D, x: float, fill: Color) -> void:
	Pix.r(ci, x - 12, 127, 24, 10, Color("4a4a48"))
	Pix.r(ci, x - 10, 137, 4, 2, Color("3a3a38"))
	Pix.r(ci, x + 6, 137, 4, 2, Color("3a3a38"))
	Pix.r(ci, x - 10, 125, 20, 4, fill)
	Pix.r(ci, x - 6, 125, 3, 1, fill.lightened(0.3))
	for i in 5:
		Pix.r(ci, x - 11 + i * 5, 131, 1, 1, Color("6a6a66"))


func _draw_salsa_bowl(ci: Node2D, x: float, fill: Color) -> void:
	Pix.r(ci, x - 12, 127, 24, 10, Color("a0522d"))
	Pix.r(ci, x - 12, 127, 24, 2, Color("c06a3d"))
	Pix.r(ci, x - 10, 125, 20, 4, fill)
	Pix.r(ci, x - 5, 125, 3, 1, fill.lightened(0.3))
	Pix.r(ci, x + 6, 118, 2, 9, Color("8b5a2b"))


func _draw_trash(ci: Node2D, x: float) -> void:
	Pix.r(ci, x - 10, 118, 20, 20, Color("4d5a66"))
	Pix.r(ci, x - 11, 116, 22, 3, Color("39444e"))
	Pix.r(ci, x - 8, 114, 16, 3, Color("222222"))
	for i in 3:
		Pix.r(ci, x - 6 + i * 5, 121, 1, 14, Color("5f6d7a"))


func _draw_tortillas(ci: Node2D, x: float) -> void:
	ci.draw_circle(Vector2(x, 132), 15, Color("2b2b2b"))
	ci.draw_circle(Vector2(x, 131), 13, Color("3a3a3a"))
	if tortillas_ok:
		Pix.r(ci, x - 11, 122, 22, 12, Color("e8e0c8"))
		for i in 4:
			Pix.r(ci, x - 11, 123 + i * 3, 22, 1, [Pix.C_ROSA, Pix.C_VERDE, Pix.C_AMARILLO, Pix.C_NARANJA][i])
		Pix.r(ci, x - 8, 119, 16, 4, Pix.C_TORTILLA)
	else:
		var p := float(tortilla_progress) / TORTILLA_PRESSES
		ci.draw_circle(Vector2(x, 129), 9, Pix.C_TORTILLA.darkened(0.2 * (1.0 - p)))
		if int(_t * 4.0) % 2 == 0:
			Pix.text(ci, Vector2(x - 20, 112), "¡SIN TORTILLAS!", 6, Color("ff4d4d"), HORIZONTAL_ALIGNMENT_CENTER, 40, 2, Color.BLACK)
		Pix.r(ci, x - 12, 145, 24, 3, Color(0, 0, 0, 0.6))
		Pix.r(ci, x - 12, 145, 24 * p, 3, Color("ffcc00"))


func _draw_front(ci: Node2D) -> void:
	Pix.steel(ci, Rect2(12, 212, 616, 10))
	Pix.r(ci, 12, 222, 616, 18, Color("9aa1a8"))
	Pix.r(ci, 12, 238, 616, 2, Pix.C_STEEL_LO)
	for k in 13:
		Pix.r(ci, 20 + k * 48, 224, 1, 14, Color(1, 1, 1, 0.12))
	# Napkin holder and lime bowl on the counter
	Pix.r(ci, 24, 204, 12, 9, Color("d9d9d9"))
	Pix.r(ci, 26, 202, 8, 4, Color("ffffff"))
	for i in 5:
		Pix.icon_lime(ci, Vector2(604 + (i % 3) * 5 - 5, 207 - (i / 3) * 3), 2.5)
	for i in orders.slot_xs.size():
		var x: float = orders.slot_xs[i]
		var c := orders.customer_at(i)
		var highlight: bool = running and not near.is_empty() and near["kind"] == "slot" and near["slot"] == i
		if c != null and (c.state == Customer.State.WAITING or c.state == Customer.State.ORDERING) and not c.in_line:
			_draw_ticket(ci, x, c, highlight)
		elif highlight:
			Pix.frame(ci, Rect2(x - 27, 214, 54, 24), Color(1, 0.8, 0, 0.6))


func _draw_ticket(ci: Node2D, x: float, c, highlight: bool) -> void:
	var rect := Rect2(x - 27, 214, 54, 24)
	if highlight:
		Pix.r(ci, rect.position.x - 2, rect.position.y - 2, rect.size.x + 4, rect.size.y + 4, Color("ffcc00"))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("fffaf0"))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, 2, Color("c1121f"))
	var o: Dictionary = c.order
	var filling: String = o.get("filling", "")
	Pix.text(ci, Vector2(rect.position.x + 2, rect.position.y + 9), tr("%d × %s") % [o.get("qty", 1), DB.recipe_name(filling, true)], 7, Color("1d1410"))
	Pix.taco_open(ci, Vector2(rect.position.x + 7, rect.position.y + 15), filling, {"verdura": o.get("verdura", false), "salsa": o.get("salsa", ""), "pina": o.get("pina", false)}, 0.55)
	var ix := rect.position.x + 19
	Pix.icon_verdura(ci, Vector2(ix, rect.position.y + 15), not o.get("verdura", false))
	Pix.icon_salsa(ci, Vector2(ix + 12, rect.position.y + 15), o.get("salsa", ""))
	if o.has("pina"):
		Pix.icon_pina(ci, Vector2(ix + 24, rect.position.y + 16), not o.get("pina", false))
	Pix.patience_bar(ci, rect.position.x + 2, rect.end.y - 4, rect.size.x - 4, c.patience_ratio())
