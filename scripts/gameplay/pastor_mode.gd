extends "res://scripts/gameplay/stationary_mode.gd"
## MODE C — TACOS AL PASTOR (night). Timing mini-game on the vertical trompo, the pineapple
## trick, service combos, and El Gorrón: an arcade disruption handled without leaving the shift.

const Enemy = preload("res://scripts/entities/enemy_controller.gd")
const Combat = preload("res://scripts/gameplay/combat_manager.gd")

const TROMPO_X := 70.0

var slice_pos := 0.5
var slice_dir := 1.0
var slice_speed := 1.6
var slice_cd := 0.0
var slice_recover := 0.32
var perfect_zone := 0.06
var good_zone := 0.18
var last_cut := ""
var last_cut_t := 0.0
var perfect_streak := 0
var dorado := 0.45
var dorado_rate := 0.05
var pina_throw: Dictionary = {}
var aguante := 100.0
var combat: Combat
var gorron: Enemy = null
var gorrones_defeated := 0
var perfect_cuts := 0
var has_dog := false
var dog_pos := Vector2(596, 300)
var dog_cd := 3.0
var throw_cd := 0.0
var swing_cd := 0.0
var rush_angry_start := 0


func _mode_id() -> String:
	return "pastor"


func _mode_signature_event() -> String:
	return "gorron"


func _mode_setup() -> void:
	combo_enabled = true
	stations = [
		{"id": "trompo", "x": TROMPO_X, "label": "Trompo"},
		{"id": "pina", "x": 150.0, "label": "Piña"},
		{"id": "verdura", "x": 210.0, "label": "Verdura"},
		{"id": "salsa_verde", "x": 265.0, "label": "Verde"},
		{"id": "salsa_roja", "x": 315.0, "label": "Roja"},
		{"id": "tortillas", "x": 385.0, "label": "Tortillas"},
		{"id": "basura", "x": 445.0, "label": "Basura"},
	]
	backdrop.night = true
	backdrop.wall_color = Color("2a9d8f")
	backdrop.trim_color = Color("e4007c")
	backdrop.stand_name = "TAQUERÍA EL TROMPO LOCO"
	backdrop.sign_bg = Color("ffcc00")
	backdrop.sign_fg = Color("c1121f")
	backdrop.menu_title = "TACOS AL PASTOR · NOCHE"
	backdrop.menu_lines = ["Pastor ............. $16", "Con queso ........ $22", "Horchata .......... $20"]
	backdrop.neighborhood = "Doctores"
	backdrop.seed_value = 23
	var tol := Upgrades.stat("slice_tolerance", mode_id)
	perfect_zone = 0.06 * (1.0 + tol)
	good_zone = 0.18 * (1.0 + tol)
	slice_recover = 0.32 * (1.0 - Upgrades.stat("slice_speed", mode_id))
	slice_speed = 1.6 * (1.0 + 0.1 * GameManager.shift_index)
	dorado_rate = 0.05 * (1.0 - Upgrades.stat("heat_control", mode_id))
	has_dog = Upgrades.stat("guard_dog", mode_id) > 0.0
	combat = Combat.new()
	combat.z_index = 15
	combat.player = player
	add_child(combat)
	combat.lime_hit.connect(_on_lime_hit)
	combat.can_hit_player.connect(_on_can_hit)


func _mode_buy_ingredients() -> void:
	if GameManager.shift_index == 0:
		return
	var cost := int(DB.mode(mode_id).get("trompo_cost", 110))
	if Economy.can_afford(cost):
		Economy.spend(cost, "ingredientes")
	else:
		# Not enough cash for a full trompo: buy what you can and slice slower meat.
		Economy.spend(maxi(0, Economy.cash), "ingredientes")
		slice_speed *= 1.2


func _mode_instructions() -> Array:
	return [
		"WASD: moverte · E: usar estación · ESPACIO: esquivar · ESC: pausa",
		"TROMPO: párate enfrente y presiona E cuando la aguja esté en lo VERDE (¡PERFECTO!)",
		"   Cortes perfectos seguidos dan racha y AURA. Si tardas, el trompo se quema.",
		"PIÑAZO: con tacos en el plato, K en el trompo y otra vez K para cacharla.",
		"Verdura y salsa como diga la comanda · E frente al cliente para entregar.",
		"Pedidos perfectos seguidos = COMBO (cobras más). Un error lo rompe.",
		"EL GORRÓN: K le avientas limones, J trapazo si está cerca, ESPACIO esquiva latas.",
	]


func generate_order(c) -> Dictionary:
	var qty: int = [1, 2, 2, 3, 3, 3][rng.randi() % 6]
	if c.modifier == "difficult":
		qty = 3
	var s := rng.randf()
	var salsa := "verde" if s < 0.45 else ("roja" if s < 0.86 else "")
	return {"filling": "pastor", "qty": qty, "verdura": rng.randf() < 0.75, "salsa": salsa, "pina": rng.randf() < 0.7}


func patience_rate_for(c) -> float:
	if gorron != null and is_instance_valid(gorron) and gorron.is_active():
		var near_g: bool = absf(c.position.x - gorron.position.x) < 90.0
		return (1.7 if near_g else 1.3) * (0.7 if has_dog else 1.0)
	return 1.0


# ---------------------------------------------------------------- loop

func _mode_process(delta: float) -> void:
	slice_pos += slice_dir * slice_speed * delta
	if slice_pos >= 1.0:
		slice_pos = 1.0
		slice_dir = -1.0
	elif slice_pos <= 0.0:
		slice_pos = 0.0
		slice_dir = 1.0
	slice_cd = maxf(0.0, slice_cd - delta)
	last_cut_t = maxf(0.0, last_cut_t - delta)
	throw_cd = maxf(0.0, throw_cd - delta)
	swing_cd = maxf(0.0, swing_cd - delta)
	dorado = minf(1.0, dorado + dorado_rate * delta)
	if not pina_throw.is_empty():
		pina_throw["t"] += delta
		if pina_throw["t"] >= pina_throw["dur"]:
			pina_throw = {}
			popup("¡Pa'l piso!", Color("ffb3b3"))
			AudioManager.play("fail", -10.0, 1.5)
	if gorron != null and not is_instance_valid(gorron):
		gorron = null
	if gorron != null:
		gorron.step(delta)
		if has_dog and gorron.is_active():
			dog_pos = dog_pos.move_toward(gorron.position + Vector2(18, 4), 90.0 * delta)
			dog_cd -= delta
			if dog_cd <= 0.0:
				dog_cd = 4.0
				AudioManager.play("dog")
				popup("¡Guau guau!", Color("fff3d6"), dog_pos + Vector2(0, -16))
				gorron.take_hit(1)
	elif has_dog:
		dog_pos = dog_pos.move_toward(Vector2(596, 300), 60.0 * delta)
	combat.target_enemy = gorron
	combat.step(delta)


func near_trompo() -> bool:
	return not near.is_empty() and near["kind"] == "station" and near["id"] == "trompo"


func _mode_station(id: String) -> void:
	if id == "trompo":
		cut()


## The trompo timing cut. Returns "perfect", "good", "miss" or "" if not possible.
func cut() -> String:
	if slice_cd > 0.0:
		return ""
	if plate["tacos"].size() >= max_plate:
		popup("¡Ya no cabe otro taco!", Color("ffb3b3"))
		return ""
	if not tortillas_ok:
		popup("¡No hay tortillas!", Color("ffb3b3"))
		return ""
	var d := absf(slice_pos - 0.5)
	var result := "miss"
	if d <= perfect_zone:
		result = "perfect"
	elif d <= good_zone:
		result = "good"
	slice_cd = slice_recover
	player.do_action("slice", 0.16)
	last_cut = result
	last_cut_t = 0.6
	var dq := dorado_quality()
	match result:
		"perfect":
			plate_add_taco("pastor", dq)
			perfect_streak += 1
			perfect_cuts += 1
			popup("¡PERFECTO!", Color("ffd34d"), Vector2(TROMPO_X, 64))
			AudioManager.play("perfect", -5.0, 1.0 + 0.05 * mini(perfect_streak, 8))
			if perfect_streak == 3:
				Aura.add(10, "¡RACHA DE CORTES!", Vector2(TROMPO_X + 30, 56), true)
			elif perfect_streak == 5:
				Aura.add(20, "¡EL REY DEL TROMPO!", Vector2(TROMPO_X + 30, 56), true)
				GameManager.unlock("rey_trompo")
			elif perfect_streak > 5 and perfect_streak % 5 == 0:
				Aura.add(20, "", Vector2(TROMPO_X + 30, 56), true)
		"good":
			plate_add_taco("pastor", 0.75 * dq)
			perfect_streak = 0
			popup("Bien", Color("fff3d6"), Vector2(TROMPO_X, 64))
			AudioManager.play("chop")
		"miss":
			perfect_streak = 0
			popup("¡Puro aire!", Color("ffb3b3"), Vector2(TROMPO_X, 64))
			AudioManager.play("fail", -10.0, 1.6)
	if result != "miss":
		dorado = maxf(0.1, dorado - 0.18)
	return result


func dorado_quality() -> float:
	if dorado > 0.85:
		return 0.6
	if dorado < 0.2:
		return 0.85
	return 1.0


func _mode_special() -> void:
	if near_trompo() and (gorron == null or not gorron.is_active() or not plate["tacos"].is_empty()):
		_pina_trick()
	else:
		throw_lime()


func _pina_trick() -> void:
	if not pina_throw.is_empty():
		var k: float = pina_throw["t"] / pina_throw["dur"]
		pina_throw = {}
		if k >= 0.86:
			if add_pina():
				Aura.add(10, "¡PIÑAZO PERFECTO!", player.position + Vector2(0, -40), true)
		elif k >= 0.7:
			if add_pina():
				Aura.add(5, "¡PIÑAZO!", player.position + Vector2(0, -40), true)
		else:
			popup("¡Muy pronto!", Color("ffb3b3"))
			AudioManager.play("fail", -10.0, 1.5)
		return
	if plate["tacos"].is_empty():
		popup("Primero corta un taco")
		return
	if plate["pina"]:
		popup("Ya tiene piña")
		return
	pina_throw = {"t": 0.0, "dur": 0.85}
	AudioManager.play("pina")


func throw_lime() -> void:
	if throw_cd > 0.0 or not player.is_free():
		return
	throw_cd = 0.4
	var from: Vector2 = player.position + Vector2(0, -16)
	var to: Vector2
	if gorron != null and is_instance_valid(gorron) and gorron.is_active():
		to = gorron.position + Vector2(0, -16)
	else:
		to = from + Vector2(player.facing * 40, 70)
	player.do_action("throw", 0.18)
	combat.throw_lime(from, to)


func _mode_attack() -> void:
	if swing_cd > 0.0 or not player.is_free():
		return
	swing_cd = 0.45
	player.do_action("swing", 0.22)
	AudioManager.play("attack")
	if gorron != null and is_instance_valid(gorron) and gorron.is_active():
		if player.position.distance_to(gorron.position) < 68.0:
			if gorron.take_hit(1):
				AudioManager.play("hit")
				popup("¡TRAPAZO!", Color("ffcc00"), gorron.position + Vector2(0, -50))


func _on_lime_hit(target) -> void:
	if target != null and is_instance_valid(target) and target.take_hit(1):
		AudioManager.play("hit")
		popup("¡LIMONAZO!", Color("c8ea85"), target.position + Vector2(0, -50))


func _on_can_hit() -> void:
	AudioManager.play("hit")
	player.stun(0.9)
	if not plate["tacos"].is_empty():
		stats["wasted"] += plate["tacos"].size()
		clear_plate()
		popup("¡Se te cayó el plato!", Color("ffb3b3"))
	Aura.add(-5, "¡AY, MI CABEZA!", player.position + Vector2(0, -44), true)


func gorron_throw(g) -> void:
	combat.throw_can(g.position + Vector2(0, -24), player.position + Vector2(0, -12))


func gorron_steal(g) -> void:
	var best = null
	var bd := 9999.0
	for c in orders.all_customers():
		if c.is_waiting():
			var d: float = absf(c.position.x - g.position.x)
			if d < bd:
				bd = d
				best = c
	if best != null:
		best.patience = maxf(0.5, best.patience - best.patience_max * 0.25)
		best.say("¡Oiga! ¡Ese señor se comió mi taco!", 1.8)
	damage_stand(6.0)
	AudioManager.play("can", -6.0, 0.7)


func damage_stand(amount: float) -> void:
	aguante = maxf(0.0, aguante - amount * (0.5 if has_dog else 1.0))
	popup(tr("-%d aguante") % int(amount * (0.5 if has_dog else 1.0)), Color("ff8a8a"), Vector2(320, 214))
	if aguante <= 0.0 and running:
		end_shift("¡El Gorrón te desmanteló el puesto!")


func spawn_gorron() -> void:
	if gorron != null and is_instance_valid(gorron):
		if gorron.is_active():
			return
		gorron.queue_free()
	gorron = Enemy.new()
	gorron.setup(self, 3 + GameManager.shift_index)
	gorron.defeated.connect(_on_gorron_defeated)
	actors.add_child(gorron)
	dog_cd = 2.5


func _on_gorron_defeated(_g) -> void:
	gorrones_defeated += 1
	EventManager.resolve("gorron", true, Vector2(320, 200), true)
	GameManager.unlock("gorron")
	hud.banner("¡AHÍ TE VES, GORRÓN!", Color("8ef58e"), 2.5)


func _mode_event_started(id: String) -> void:
	match id:
		"gorron":
			spawn_gorron()
		"hora_pico":
			orders.rush_mult = 2.8
			rush_angry_start = stats["angry"]
			for i in 2:
				orders.spawn()


func _mode_event_timeout(id: String) -> void:
	match id:
		"gorron":
			if gorron != null and is_instance_valid(gorron):
				gorron.leave_laughing()
			damage_stand(15.0)
			hud.banner("El Gorrón se fue con la panza llena...", Color("ffb3b3"), 2.5)
		"hora_pico":
			orders.rush_mult = 1.0
			var ok: bool = stats["angry"] - rush_angry_start <= 2
			EventManager.resolve(id, ok, Vector2(320, 120), true)


func _mode_highlights() -> Array:
	return [tr("Cortes perfectos: %d") % perfect_cuts, tr("Gorrones corridos: %d") % gorrones_defeated, tr("Aguante final: %d%%") % int(aguante)]


func _mode_station_prompt(id: String) -> String:
	if id == "trompo":
		var t := "E: ¡Cortar! (aguja en lo verde)"
		if not plate["tacos"].is_empty() and not plate["pina"]:
			t = tr(t) + tr(" · K: ¡piñazo!")
		return t
	return ""


func _prompt_text() -> String:
	if gorron != null and is_instance_valid(gorron) and gorron.is_active() and not near_trompo():
		return "¡EL GORRÓN! K: limonazo · J: trapazo (de cerca) · ESPACIO: esquivar latas"
	return super._prompt_text()


# ---------------------------------------------------------------- drawing

func _mode_draw_equipment(ci: Node2D) -> void:
	# String lights over the stand
	for i in 30:
		var x := 14 + i * 21
		var on := int(_t * 3.0 + i) % 4 != 0
		var col: Color = [Pix.C_AMARILLO, Pix.C_ROSA, Pix.C_VERDE, Pix.C_NARANJA][i % 4]
		ci.draw_circle(Vector2(x, 99 + sin(i * 0.9) * 2), 1.8, col if on else col.darkened(0.6))
	_draw_trompo(ci, TROMPO_X)
	# Warm light from the stand onto the sidewalk
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, 240), Vector2(628, 240), Vector2(660, 320), Vector2(-20, 320)]), Color(1.0, 0.8, 0.4, 0.06))
	if near_trompo() and running:
		_draw_slice_bar(ci, TROMPO_X)
	if not pina_throw.is_empty():
		var k: float = pina_throw["t"] / pina_throw["dur"]
		var a := Vector2(TROMPO_X, 64)
		var b: Vector2 = player.position + Vector2(player.facing * 9, -16)
		var p := a.lerp(b, k)
		p.y -= 40.0 * 4.0 * k * (1.0 - k)
		Pix.r(ci, p.x - 3, p.y - 3, 6, 6, Pix.C_PINA)
		Pix.r(ci, p.x - 3, p.y + 1, 6, 2, Color("d9a92a"))
		var ring := lerpf(18.0, 4.0, k)
		ci.draw_arc(b, ring, 0, TAU, 16, Color(1, 0.8, 0.0, 0.8) if k >= 0.7 else Color(1, 1, 1, 0.5), 1.5)
	if has_dog:
		_draw_dog(ci, dog_pos)


func _draw_trompo(ci: Node2D, x: float) -> void:
	# Vertical heat panel behind the meat
	var glow := 0.5 + 0.5 * sin(_t * 6.0)
	Pix.r(ci, x + 16, 78, 10, 58, Color("3a2a20"))
	for k in 6:
		Pix.r(ci, x + 17, 80 + k * 9, 8, 6, Color("ff7a00").lerp(Color("ffcc00"), glow * 0.6))
	# Skewer and base
	Pix.r(ci, x - 1, 60, 2, 82, Color("dfe4e8"))
	Pix.r(ci, x - 12, 136, 24, 4, Color("8a9096"))
	# Meat cone with rotating marinated layers
	var top := 76.0
	var bottom := 134.0
	var burnt := clampf((dorado - 0.75) * 3.0, 0.0, 1.0)
	var meat := Color("c4471d").lerp(Color("5a1f0c"), burnt)
	var pts := PackedVector2Array([Vector2(x - 16, top), Vector2(x + 16, top), Vector2(x + 19, top + 12),
		Vector2(x + 13, bottom - 4), Vector2(x + 9, bottom), Vector2(x - 9, bottom), Vector2(x - 13, bottom - 4), Vector2(x - 19, top + 12)])
	ci.draw_colored_polygon(pts, meat)
	# Rotating marinated layers
	for k in 10:
		var yy := top + 2 + fmod(k * 5.8 + _t * 10.0, bottom - top - 4)
		var f := (yy - top) / (bottom - top)
		var half := lerpf(18.0, 10.0, f)
		Pix.r(ci, x - half + 1, yy, half * 2 - 2, 1, Color("8f2d12").lerp(Color("2a0f05"), burnt))
	# Caramelized edges and the freshly sliced face
	Pix.r(ci, x - 18, top + 8, 3, 30, Color("7a2410").lerp(Color("1a0703"), burnt))
	Pix.r(ci, x + 15, top + 8, 3, 30, Color("7a2410").lerp(Color("1a0703"), burnt))
	Pix.r(ci, x - 6, top + 6, 4, bottom - top - 12, Color("e07b39").lerp(Color("6a2a10"), burnt))
	Pix.r(ci, x + 6, top + 4, 2, bottom - top - 14, Color(1, 0.85, 0.6, 0.35))
	for k in 5:
		Pix.r(ci, x - 13 + (k % 2) * 4, top + 6 + k * 10, 3, 2, Color("f0a050"))
	ci.draw_circle(Vector2(x, top + 1), 15, Color("d9592c").lerp(Color("4a1a08"), burnt))
	Pix.r(ci, x - 14, top - 1, 28, 2, Color("e2683a"))
	# Pineapple on top
	Pix.r(ci, x - 9, 64, 18, 12, Pix.C_PINA)
	Pix.r(ci, x - 9, 72, 18, 4, Color("d9a92a"))
	for k in 3:
		Pix.r(ci, x - 7 + k * 6, 66, 2, 2, Color("b8860b"))
	Pix.r(ci, x - 6, 56, 3, 8, Pix.C_CILANTRO)
	Pix.r(ci, x - 1, 54, 3, 10, Pix.C_CILANTRO_D)
	Pix.r(ci, x + 4, 57, 3, 7, Pix.C_CILANTRO)
	if dorado > 0.85:
		for i in 3:
			var sy := fmod(_t * 16.0 + i * 8.0, 26.0)
			Pix.r(ci, x - 12 + i * 10, 76 - sy, 5, 4, Color(0.2, 0.2, 0.2, 0.5 * (1.0 - sy / 26.0)))
		if int(_t * 4.0) % 2 == 0:
			Pix.text(ci, Vector2(x - 40, 52), "¡SE QUEMA! ¡CORTA!", 6, Color("ff4d4d"), HORIZONTAL_ALIGNMENT_CENTER, 80, 2, Color.BLACK)
	# Dorado meter
	Pix.r(ci, x - 26, 80, 4, 50, Color("1d1410"))
	Pix.r(ci, x - 25, 81 + 48 * (1.0 - dorado), 2, 48 * dorado, Color("ffcc00") if dorado <= 0.85 else Color("ff4d4d"))


func _draw_slice_bar(ci: Node2D, x: float) -> void:
	var w := 84.0
	var bx := x - 10.0
	var by := 40.0
	Pix.r(ci, bx - 2, by - 2, w + 4, 12, Color("1d1410"))
	Pix.r(ci, bx, by, w, 8, Color("e63946"))
	Pix.r(ci, bx + w * (0.5 - good_zone), by, w * good_zone * 2.0, 8, Color("f4c430"))
	Pix.r(ci, bx + w * (0.5 - perfect_zone), by, w * perfect_zone * 2.0, 8, Color("3fbf5a"))
	var nx := bx + w * slice_pos
	Pix.r(ci, nx - 1, by - 3, 3, 14, Color("ffffff"))
	Pix.text(ci, Vector2(bx, by - 4), "CORTE (E)", 6, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, w, 2, Color.BLACK)
	if perfect_streak >= 2:
		Pix.text(ci, Vector2(bx, by + 18), tr("RACHA x%d") % perfect_streak, 7, Color("ffd34d"), HORIZONTAL_ALIGNMENT_CENTER, w, 2, Color.BLACK)


func _draw_dog(ci: Node2D, p: Vector2) -> void:
	var run := gorron != null and is_instance_valid(gorron) and gorron.is_active()
	var bob := absf(sin(_t * 14.0)) * 2.0 if run else 0.0
	Pix.r(ci, p.x - 8, p.y - 1, 16, 2, Color(0, 0, 0, 0.25))
	Pix.r(ci, p.x - 7, p.y - 8 - bob, 14, 6, Color("c08a4a"))
	Pix.r(ci, p.x + 5, p.y - 12 - bob, 6, 6, Color("c08a4a"))
	Pix.r(ci, p.x + 9, p.y - 10 - bob, 3, 2, Color("8a5a2a"))
	Pix.r(ci, p.x + 6, p.y - 14 - bob, 2, 3, Color("8a5a2a"))
	Pix.r(ci, p.x + 8, p.y - 11 - bob, 1, 1, Color("111111"))
	Pix.r(ci, p.x - 9, p.y - 10 - bob + sin(_t * 20.0), 3, 2, Color("c08a4a"))
	for k in 4:
		Pix.r(ci, p.x - 6 + k * 4, p.y - 2 - (bob if k % 2 == 0 else 0.0), 2, 3, Color("a8763e"))
	Pix.r(ci, p.x - 2, p.y - 8 - bob, 6, 1, Color("c1121f"))
	if not run:
		Pix.text(ci, Vector2(p.x + 8, p.y - 16), "z", 6, Color("fff3d6"))


func draw_hud_extra(ci: Control) -> void:
	var rect := Rect2(4, 294, 176, 46)
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color(0.06, 0.03, 0.02, 0.82))
	Pix.r(ci, rect.position.x, rect.position.y, 2, rect.size.y, Color("e4007c"))
	var mult := combo_mult()
	Pix.text(ci, Vector2(10, 307), "COMBO", 7, Color("cdbfa8"))
	Pix.text(ci, Vector2(44, 309), tr("x%.2f") % mult, 12 if combo > 0 else 9, Color("ffd34d") if combo > 0 else Color("8a7a6e"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	Pix.text(ci, Vector2(100, 307), tr("(%d seguidos)") % combo, 7, Color("cdbfa8"))
	Pix.text(ci, Vector2(10, 322), "Aguante del puesto", 7, Color("cdbfa8"))
	Pix.r(ci, 92, 316, 82, 6, Color(0, 0, 0, 0.6))
	var ac := Color("3fbf5a") if aguante > 50.0 else (Color("f4c430") if aguante > 25.0 else Color("e63946"))
	Pix.r(ci, 92, 316, 82 * aguante / 100.0, 6, ac)
	Pix.text(ci, Vector2(10, 335), tr("Racha de cortes: %d") % perfect_streak, 7, Color("ffd34d") if perfect_streak >= 3 else Color("cdbfa8"))
	if EventManager.is_active("hora_pico"):
		Pix.text(ci, Vector2(470, 300), tr("HORA PICO %s") % Pix.fmt_time(EventManager.remaining("hora_pico")), 8, Color("ffcc00"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	if gorron != null and is_instance_valid(gorron) and gorron.is_active():
		Pix.text(ci, Vector2(470, 312), tr("EL GORRÓN %s") % Pix.fmt_time(EventManager.remaining("gorron")), 8, Color("ff6b6b"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
