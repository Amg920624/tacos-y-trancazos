extends "res://scripts/gameplay/stationary_mode.gd"
## MODE B — CARNITAS. Cook batches in the copper cazo while watching the heat, chop the right
## cut (maciza, surtida, cuerito) onto tortillas, garnish and serve. Inventory is finite.

const CUTS := ["maciza", "surtida", "cuerito"]

var sel := 0
var tray := {"maciza": [], "surtida": [], "cuerito": []}
var raw := {"maciza": 3, "surtida": 3, "cuerito": 2}
var cazo := {"state": "idle", "cut": "", "progress": 0.0, "quality": 1.0, "done_t": 0.0}
var heat := 0.3
var batch_portions := 6
var cook_time := 9.0
var chop_time := 0.42
var heat_rate := 0.055
var good_lo := 0.32
var good_hi := 0.72
var batches_cooked := 0
var burned := 0
var domingo_angry_start := 0


func _mode_id() -> String:
	return "carnitas"


func _mode_signature_event() -> String:
	return "domingo_carnitas"


func _mode_setup() -> void:
	stations = [
		{"id": "cazo", "x": 72.0, "label": "Cazo"},
		{"id": "tabla", "x": 170.0, "label": "Tabla"},
		{"id": "verdura", "x": 240.0, "label": "Verdura"},
		{"id": "salsa_verde", "x": 295.0, "label": "Verde"},
		{"id": "salsa_roja", "x": 345.0, "label": "Roja"},
		{"id": "tortillas", "x": 405.0, "label": "Tortillas"},
		{"id": "basura", "x": 460.0, "label": "Basura"},
	]
	backdrop.wall_color = Color("e9a23b")
	backdrop.trim_color = Color("1d4e89")
	backdrop.stand_name = "CARNITAS EL CAZO DE ORO"
	backdrop.sign_bg = Color("c1121f")
	backdrop.sign_fg = Color("ffcc00")
	backdrop.menu_title = "CARNITAS ESTILO MICHOACÁN"
	backdrop.menu_lines = ["Maciza ............ $20", "Surtida ........... $20", "Cuerito ........... $18"]
	backdrop.neighborhood = "Iztapalapa"
	backdrop.seed_value = 11
	var m := DB.mode(mode_id)
	batch_portions = int(m.get("batch_portions", 6)) + int(Upgrades.stat("batch_portions", mode_id))
	var prep := Upgrades.stat("prep_speed", mode_id)
	cook_time = 9.0 * (1.0 - prep)
	chop_time = 0.42 * (1.0 - prep)
	var hc := Upgrades.stat("heat_control", mode_id)
	heat_rate = 0.055 * (1.0 - hc)
	if hc > 0.0:
		good_lo = 0.27
		good_hi = 0.79
	var extra := int(Upgrades.stat("extra_batches", mode_id))
	var per_cut: Dictionary = m.get("batches_per_cut", {})
	for cut in CUTS:
		raw[cut] = int(per_cut.get(cut, 2)) + extra
		tray[cut] = []
		for i in int(m.get("start_portions", 5)):
			tray[cut].append(0.95)


## Shift 1 uses the starter kit; later shifts buy the meat batches up front.
func _mode_buy_ingredients() -> void:
	if GameManager.shift_index == 0:
		return
	var cost_each := int(DB.mode(mode_id).get("batch_cost", 30))
	var total := 0
	for cut in CUTS:
		total += raw[cut]
	var affordable := total
	if cost_each > 0:
		affordable = mini(total, int(floor(float(maxi(0, Economy.cash)) / cost_each)))
	while total > affordable:
		var biggest: String = CUTS[0]
		for cut in CUTS:
			if raw[cut] > raw[biggest]:
				biggest = cut
		raw[biggest] -= 1
		total -= 1
	Economy.spend(affordable * cost_each, "ingredientes")


func _mode_instructions() -> Array:
	return [
		"WASD: moverte detrás del mostrador · E: usar estación · Q: cambiar de corte",
		"CAZO: E echa la carne del corte elegido · E otra vez para MENEAR (baja el fuego)",
		"   Si la aguja llega a lo ROJO se queman. Cuando estén listas: ¡E para sacarlas!",
		"TABLA: E pica un taco del corte elegido (maciza, surtida o cuerito).",
		"Pon verdura y la salsa que diga la comanda; luego E frente al cliente para entregar.",
		"¿Te equivocaste? Tira el plato en la basura. La carne y la paciencia se acaban.",
	]


func generate_order(c) -> Dictionary:
	var available := []
	for cut in CUTS:
		if tray[cut].size() > 0 or raw[cut] > 0 or (cazo["state"] != "idle" and cazo["cut"] == cut):
			available.append(cut)
	var roll := rng.randf()
	var cut: String = "maciza" if roll < 0.4 else ("surtida" if roll < 0.75 else "cuerito")
	if c.archetype_id == "cliente_fiel":
		cut = "surtida"
	if available.size() > 0 and not (cut in available):
		cut = available[rng.randi() % available.size()]
	var qty: int = [1, 2, 2, 2, 3, 3][rng.randi() % 6]
	if c.modifier == "difficult":
		qty = 3
	var s := rng.randf()
	var salsa := "verde" if s < 0.45 else ("roja" if s < 0.86 else "")
	return {"filling": cut, "qty": qty, "verdura": rng.randf() < 0.75, "salsa": salsa}


func _mode_process(delta: float) -> void:
	if cazo["state"] != "idle":
		heat = minf(1.0, heat + heat_rate * delta)
	else:
		heat = move_toward(heat, 0.3, 0.05 * delta)
	match cazo["state"]:
		"cooking":
			var rate := 1.0
			if heat < good_lo:
				rate = 0.45
			elif heat > good_hi:
				rate = 1.15
				cazo["quality"] = maxf(0.3, cazo["quality"] - 0.12 * delta)
			cazo["progress"] += rate * delta / cook_time
			if cazo["progress"] >= 1.0:
				cazo["progress"] = 1.0
				cazo["state"] = "done"
				cazo["done_t"] = 0.0
				popup(tr("¡Ya salieron las de %s! (E)") % DB.recipe_name(cazo["cut"]).to_lower(), Color("ffcc00"), Vector2(72, 92))
				AudioManager.play("order")
		"done":
			cazo["done_t"] += delta
			if cazo["done_t"] > 3.0:
				cazo["quality"] = maxf(0.25, cazo["quality"] - 0.1 * delta)
			if heat > good_hi:
				cazo["quality"] = maxf(0.25, cazo["quality"] - 0.08 * delta)


func _mode_station(id: String) -> void:
	match id:
		"cazo":
			_cazo_interact()
		"tabla":
			chop()


func _cazo_interact() -> void:
	match cazo["state"]:
		"idle":
			var cut: String = CUTS[sel]
			if raw[cut] <= 0:
				popup(tr("Ya no hay %s cruda (Q: otro corte)") % DB.recipe_name(cut).to_lower(), Color("ffb3b3"))
				return
			raw[cut] -= 1
			cazo = {"state": "cooking", "cut": cut, "progress": 0.0, "quality": 1.0, "done_t": 0.0}
			heat = maxf(heat, 0.36)
			player.do_action("stir", 0.4)
			AudioManager.play("sizzle")
			popup(tr("¡Al cazo la %s!") % DB.recipe_name(cut).to_lower(), Color("ffcc00"))
		"cooking":
			heat = maxf(0.0, heat - 0.24)
			player.do_action("stir", 0.3)
			AudioManager.play("sizzle", -8.0, 1.3)
		"done":
			collect_batch()


func collect_batch() -> void:
	var cut: String = cazo["cut"]
	var q: float = cazo["quality"]
	for i in batch_portions:
		tray[cut].append(q)
	batches_cooked += 1
	popup(tr("+%d de %s") % [batch_portions, DB.recipe_name(cut).to_lower()], Color("8ef58e"))
	if q >= 0.85:
		Aura.add(5, "¡BIEN DORADITAS!", Vector2(72, 90), true)
	elif q < 0.6:
		burned += 1
		Aura.add(-5, "¡SE QUEMARON!", Vector2(72, 90), true)
	cazo = {"state": "idle", "cut": "", "progress": 0.0, "quality": 1.0, "done_t": 0.0}
	player.do_action("stir", 0.35)


func chop() -> bool:
	var cut: String = CUTS[sel]
	if tray[cut].is_empty():
		popup(tr("¡Se acabó la %s!") % DB.recipe_name(cut).to_lower(), Color("ffb3b3"))
		return false
	if not tortillas_ok:
		popup("¡No hay tortillas!", Color("ffb3b3"))
		return false
	if plate["tacos"].size() >= max_plate:
		popup("¡Ya no cabe otro taco!", Color("ffb3b3"))
		return false
	var q: float = tray[cut].pop_front()
	plate_add_taco(cut, q)
	player.do_action("chop", chop_time)
	AudioManager.play("chop")
	return true


func _mode_switch() -> void:
	sel = (sel + 1) % CUTS.size()
	popup(tr("Corte: %s") % DB.recipe_name(CUTS[sel]).to_upper(), Color("ffcc00"))
	AudioManager.play("ui_move")


func _mode_station_prompt(id: String) -> String:
	var cut: String = CUTS[sel]
	match id:
		"cazo":
			match cazo["state"]:
				"idle":
					return tr("E: Echar %s al cazo (quedan %d) · Q: cambiar corte") % [DB.recipe_name(cut).to_lower(), raw[cut]]
				"cooking":
					return "E: ¡Menear! (baja el fuego)"
				"done":
					return "E: ¡Sacar las carnitas!"
		"tabla":
			return tr("E: Picar taco de %s (%d en charola) · Q: cambiar corte") % [DB.recipe_name(cut).to_lower(), tray[cut].size()]
	return ""


func _mode_event_started(id: String) -> void:
	if id == "domingo_carnitas":
		orders.rush_mult = 2.4
		domingo_angry_start = stats["angry"]
		for i in 2:
			orders.spawn()


func _mode_event_timeout(id: String) -> void:
	if id == "domingo_carnitas":
		orders.rush_mult = 1.0
		var ok: bool = stats["angry"] - domingo_angry_start <= 3
		EventManager.resolve(id, ok, Vector2(320, 120), true)
		if ok:
			GameManager.unlock("domingo_gloria")
			hud.banner("¡DOMINGO DE GLORIA!", Color("8ef58e"), 3.0)
		else:
			hud.banner("La familia se fue a la barbacoa de enfrente...", Color("ffb3b3"), 3.0)


func _mode_highlights() -> Array:
	return [tr("Tandas cocinadas en el cazo: %d") % batches_cooked, tr("Tandas quemadas: %d") % burned]


# ---------------------------------------------------------------- drawing

func _mode_draw_equipment(ci: Node2D) -> void:
	_draw_cazo(ci, 72.0)
	_draw_tabla(ci, 170.0)
	# Stack of plates and plastic bags
	for i in 5:
		Pix.r(ci, 476, 132 - i * 2, 22, 2, [Color("8fcf9c"), Color("f2d06b"), Color("8fb8e8")][i % 3])
	Pix.r(ci, 502, 122, 10, 16, Color(1, 1, 1, 0.5))


func _draw_cazo(ci: Node2D, x: float) -> void:
	# Burner and flames
	Pix.r(ci, x - 30, 134, 60, 5, Color("222222"))
	var cooking: bool = cazo["state"] != "idle"
	if cooking or heat > 0.31:
		var fc := Color("4aa8ff").lerp(Color("ff7a00"), clampf(heat, 0.0, 1.0))
		for i in 7:
			var h := 3.0 + heat * 6.0 + sin(_t * 18.0 + i) * 1.5
			Pix.r(ci, x - 24 + i * 8, 134 - h, 3, h, fc)
	# Copper cazo
	var pts := PackedVector2Array([Vector2(x - 38, 104), Vector2(x + 38, 104), Vector2(x + 29, 134), Vector2(x - 29, 134)])
	ci.draw_colored_polygon(pts, Color("b87333"))
	Pix.r(ci, x - 38, 103, 76, 3, Color("e2a066"))
	Pix.r(ci, x - 30, 112, 60, 1, Color("8e5426"))
	Pix.r(ci, x - 26, 124, 52, 1, Color("8e5426"))
	for i in 6:
		Pix.r(ci, x - 30 + i * 12, 117, 2, 2, Color("e2a066"))
	Pix.r(ci, x - 44, 106, 7, 3, Color("8e5426"))
	Pix.r(ci, x + 37, 106, 7, 3, Color("8e5426"))
	# Lard and meat
	Pix.r(ci, x - 35, 105, 70, 4, Color("d9a03a"))
	if cooking:
		var cols := Pix.filling_colors(cazo["cut"])
		var mc: Color = cols[0]
		if cazo["quality"] < 0.6:
			mc = mc.darkened(0.45)
		for i in 9:
			Pix.r(ci, x - 30 + i * 7, 104 + (i % 2), 5, 3, mc if i % 3 != 0 else cols[1])
		for i in 4:
			var bx := x - 28 + fmod(i * 17.0 + _t * 9.0, 56.0)
			ci.draw_circle(Vector2(bx, 105), 1.2 + absf(sin(_t * 6.0 + i)), Color("f6d58a"))
		for i in 3:
			var sy := fmod(_t * 14.0 + i * 9.0, 26.0)
			Pix.r(ci, x - 14 + i * 14 + sin(_t * 2 + i) * 3, 100 - sy, 4, 3, Color(1, 1, 1, 0.25 * (1.0 - sy / 26.0)))
	# Paddle
	ci.draw_line(Vector2(x + 30, 104), Vector2(x + 46, 74), Color("8b5a2b"), 2.0)
	Pix.r(ci, x + 44, 70, 5, 6, Color("8b5a2b"))
	# Heat gauge
	var gx := 22.0
	var gy := 104.0
	var gh := 32.0
	Pix.r(ci, gx - 1, gy - 1, 8, gh + 2, Color("1d1410"))
	Pix.r(ci, gx, gy + gh * (1.0 - good_lo), 6, gh * good_lo, Color("4a90d9"))
	Pix.r(ci, gx, gy + gh * (1.0 - good_hi), 6, gh * (good_hi - good_lo), Color("3fbf5a"))
	Pix.r(ci, gx, gy, 6, gh * (1.0 - good_hi), Color("e63946"))
	var ny := gy + gh * (1.0 - heat)
	Pix.r(ci, gx - 3, ny - 1, 12, 2, Color("ffffff"))
	Pix.text(ci, Vector2(gx - 6, gy - 3), "FUEGO", 5, Color("1d1410"))
	# Status
	match cazo["state"]:
		"cooking":
			Pix.r(ci, x - 30, 94, 60, 5, Color(0, 0, 0, 0.6))
			Pix.r(ci, x - 29, 95, 58 * cazo["progress"], 3, Color("ffcc00"))
			Pix.text(ci, Vector2(x - 40, 91), DB.recipe_name(cazo["cut"]).to_upper(), 6, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, 80, 2, Color.BLACK)
			if heat > good_hi and int(_t * 5.0) % 2 == 0:
				Pix.text(ci, Vector2(x - 40, 84), "¡MENEA! ¡SE QUEMAN!", 6, Color("ff4d4d"), HORIZONTAL_ALIGNMENT_CENTER, 80, 2, Color.BLACK)
		"done":
			if int(_t * 4.0) % 2 == 0:
				Pix.text(ci, Vector2(x - 40, 96), "¡LISTAS! (E)", 8, Color("8ef58e"), HORIZONTAL_ALIGNMENT_CENTER, 80, 2, Color.BLACK)


func _draw_tabla(ci: Node2D, x: float) -> void:
	# Steel tray with three compartments
	Pix.r(ci, x - 33, 112, 66, 16, Pix.C_STEEL_LO)
	for i in CUTS.size():
		var cut: String = CUTS[i]
		var cx := x - 32 + i * 22
		Pix.r(ci, cx + 1, 113, 20, 14, Pix.C_STEEL)
		var n: int = tray[cut].size()
		var cols := Pix.filling_colors(cut)
		var pile := mini(n, 10)
		for k in pile:
			Pix.r(ci, cx + 3 + (k % 4) * 4, 124 - (k / 4) * 3, 4, 3, cols[0] if k % 3 != 0 else cols[1])
		if i == sel:
			Pix.frame(ci, Rect2(cx, 112, 22, 16), Color("ffcc00"), 1.5)
		Pix.text(ci, Vector2(cx, 110), tr("%s %d") % [DB.recipe_name(cut).substr(0, 3).to_upper(), n], 5, Color("1d1410") if n > 0 else Color("c1121f"), HORIZONTAL_ALIGNMENT_CENTER, 22)
	# Cutting board and knife
	Pix.r(ci, x - 22, 128, 44, 9, Color("d9b382"))
	Pix.r(ci, x - 22, 135, 44, 2, Color("b08a5a"))
	Pix.r(ci, x + 6, 130, 14, 2, Color("dfe4e8"))
	Pix.r(ci, x + 20, 130, 6, 2, Color("2b1a12"))


func draw_hud_extra(ci: Control) -> void:
	var rect := Rect2(4, 294, 168, 46)
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color(0.06, 0.03, 0.02, 0.82))
	Pix.r(ci, rect.position.x, rect.position.y, 2, rect.size.y, Color("ffcc00"))
	var cut: String = CUTS[sel]
	Pix.text(ci, Vector2(10, 306), "CORTE [Q]:", 7, Color("cdbfa8"))
	Pix.text(ci, Vector2(60, 307), DB.recipe_name(cut).to_upper(), 10, Color("ffcc00"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	var y := 319.0
	Pix.text(ci, Vector2(10, y), "Charola:", 7, Color("cdbfa8"))
	Pix.text(ci, Vector2(10, y + 11), "Cruda:", 7, Color("cdbfa8"))
	for i in CUTS.size():
		var c: String = CUTS[i]
		var x := 54 + i * 38
		var col := Color("ffcc00") if i == sel else Color("fff3d6")
		Pix.text(ci, Vector2(x, y), tr("%s %d") % [DB.recipe_name(c).substr(0, 3), tray[c].size()], 7, col if tray[c].size() > 0 else Color("ff6b6b"))
		Pix.text(ci, Vector2(x, y + 11), tr("%s %d") % [DB.recipe_name(c).substr(0, 3), raw[c]], 7, col if raw[c] > 0 else Color("ff6b6b"))
	if EventManager.is_active("domingo_carnitas"):
		Pix.text(ci, Vector2(470, 300), tr("DOMINGO DE CARNITAS %s") % Pix.fmt_time(EventManager.remaining("domingo_carnitas")), 8, Color("ffcc00"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
