extends Node
## Automated gameplay tests. Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Prints one line per check and a summary; exit code 1 if anything failed.

const Customer = preload("res://scripts/entities/customer_controller.gd")

var passed := 0
var failed := 0
var failures: Array = []
var current := ""


func _ready() -> void:
	GameManager.test_mode = true
	GameManager.set_language("es", false)
	SaveManager.save_path = "user://test_save.json"
	await get_tree().process_frame
	await _run("data_and_resources", t_data_and_resources)
	await _run("menus_load", t_menus_load)
	await _run("economy_rules", t_economy)
	await _run("aura_rules", t_aura)
	await _run("upgrades", t_upgrades)
	await _run("save_load", t_save_load)
	await _run("events_schedule", t_events)
	await _run("carnitas_mode", t_carnitas)
	await _run("pastor_mode", t_pastor)
	await _run("canasta_mode", t_canasta)
	await _run("upgrade_effects_in_modes", t_upgrade_effects)
	await _run("shift_completion", t_shift_completion)
	await _run("win_lose_states", t_win_lose)
	print("")
	print("TEST SUMMARY: %d passed, %d failed" % [passed, failed])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failed > 0 else 0)


func _run(name: String, fn: Callable) -> void:
	current = name
	print("== ", name)
	await fn.call()
	await get_tree().process_frame


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  PASS ", what)
	else:
		failed += 1
		failures.append(current + ": " + what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func spawn_scene(path: String) -> Node:
	var s = load(path).instantiate()
	add_child(s)
	await frames(2)
	return s


func waiting_customer(mode, order: Dictionary):
	var c = mode.orders.spawn()
	c.order = order
	c.position = Vector2(mode.orders.slot_xs[c.slot], 272)
	c.modulate.a = 1.0
	c.state = Customer.State.WAITING
	return c


# ---------------------------------------------------------------- tests

func t_data_and_resources() -> void:
	check(DB.load_errors.is_empty(), "all data JSON files load without errors")
	for id in ["canasta", "carnitas", "pastor"]:
		check(DB.mode(id).get("unlocked", false), "mode %s is defined and unlocked" % id)
	check(DB.future.size() == 5, "5 future taquerías defined as data")
	for f in DB.future:
		check(not f.get("unlocked", true), "future taquería %s is locked (no broken menu option)" % f.get("id", "?"))
	for key in GameManager.SCENES.keys():
		check(ResourceLoader.exists(GameManager.SCENES[key]), "scene exists: %s" % key)
	var known_stats := ["basket_capacity", "bike_speed", "bell_radius", "bell_cooldown", "demand", "metro_permit", "insulation",
		"batch_portions", "prep_speed", "extra_batches", "heat_control", "slice_tolerance", "slice_speed", "combo_cap",
		"guard_dog", "extra_slot", "patience", "price"]
	for u in DB.upgrades:
		for e in u.get("effects", []):
			check(e.get("stat", "") in known_stats, "upgrade %s uses an implemented stat (%s)" % [u["id"], e.get("stat", "")])
	for ev in DB.events:
		check(ev.has("modes") and ev.has("trigger") and ev.has("cooldown") and ev.has("duration"), "event %s has required fields" % ev.get("id", "?"))


func t_menus_load() -> void:
	for key in ["menu", "select"]:
		var s = await spawn_scene(GameManager.SCENES[key])
		var has_button := false
		for ch in s.get_children():
			if ch is Button or (ch is VBoxContainer and ch.get_child_count() > 0):
				has_button = true
		check(has_button, "%s scene loads with buttons" % key)
		s.queue_free()
		await frames(1)
	GameManager.start_new_run("carnitas")
	var shop = await spawn_scene(GameManager.SCENES["shop"])
	check(shop.rows.size() > 0, "upgrade shop lists upgrades for the mode")
	shop.queue_free()
	GameManager.last_shift = {"day": "Viernes", "revenue": 300, "target": 250, "met": true, "cost_items": {"gastos_fijos": 40}, "highlights": ["x"]}
	var res = await spawn_scene(GameManager.SCENES["results"])
	check(res.get_child_count() > 5, "results screen builds")
	res.queue_free()
	GameManager.run_result = "win"
	var end = await spawn_scene(GameManager.SCENES["end"])
	check(end.get_child_count() > 3, "end screen builds")
	end.queue_free()
	GameManager.run_result = ""
	await frames(1)


func t_economy() -> void:
	Economy.reset(100)
	check(Economy.cash == 100, "reset sets starting cash")
	check(Economy.add_sale(50) == 50 and Economy.cash == 150, "valid sale adds money")
	check(Economy.add_sale(-20) == 0 and Economy.cash == 150, "negative sale rejected")
	check(Economy.add_sale(NAN) == 0 and Economy.cash == 150, "NaN sale rejected")
	check(Economy.add_sale(INF) == 0 and Economy.cash == 150, "infinite sale rejected")
	check(Economy.add_sale("cien") == 0 and Economy.cash == 150, "non-numeric sale rejected")
	check(Economy.add_sale(49.6) == 50, "fractional sale rounds to whole pesos")
	check(Economy.sanitize(1e12) == Economy.MAX_SINGLE_TRANSACTION, "huge amounts are clamped")
	check(not Economy.spend(1000), "cannot spend more than cash")
	check(Economy.cash == 200, "failed spend leaves cash untouched")
	check(Economy.spend(30, "ingredientes") and Economy.cash == 170, "spend deducts money")
	check(Economy.shift_costs == 30, "ingredient spend counts as shift cost")
	Economy.charge(500, "gastos_fijos")
	check(Economy.is_bankrupt(), "mandatory charge can bankrupt")
	check(Economy.money(1234) == "$1,234" and Economy.money(-50) == "-$50", "money formatting")


func t_aura() -> void:
	Aura.reset()
	Aura.add(25, "¡QUÉ CHULADA!")
	check(Aura.aura == 25, "AURA adds")
	Aura.add(-100)
	check(Aura.aura == 0, "AURA never goes below zero")
	Aura.add(150)
	check(Aura.level() == 1 and Aura.title() == "Taquero de Barrio", "AURA level thresholds")
	check(Aura.demand_bonus() > 1.0, "AURA level raises demand")
	check(Aura.popup_text(50, "¡SE MAMÓ!") == "+50 AURA — ¡SE MAMÓ!", "popup format")
	check(Aura.popup_text(-15, "¡TE PASASTE DE LANZA!") == "-15 AURA — ¡TE PASASTE DE LANZA!", "negative popup format")


func t_upgrades() -> void:
	GameManager.start_new_run("canasta")
	check(Economy.cash == 150 and Upgrades.levels.is_empty(), "new run starts clean")
	check(Upgrades.can_buy("canasta_grande", "canasta")["ok"], "can buy affordable upgrade")
	check(Upgrades.buy("canasta_grande", "canasta"), "buy succeeds")
	check(Economy.cash == 0 and Upgrades.level("canasta_grande") == 1, "purchase deducts money and raises level")
	check(not Upgrades.buy("canasta_grande", "canasta"), "insufficient cash blocks purchase")
	check(Upgrades.level("canasta_grande") == 1 and Economy.cash == 0, "blocked purchase changes nothing")
	check(Upgrades.stat("basket_capacity", "canasta") == 15.0, "upgrade modifies its stat")
	check(not Upgrades.can_buy("cazo_grande", "canasta")["ok"], "other mode upgrades are not purchasable")
	Economy.reset(1000)
	var chk := Upgrades.can_buy("permiso_metro", "canasta")
	check(not chk["ok"] and "AURA" in chk["reason"], "AURA requirement blocks purchase")
	Upgrades.levels["aislante"] = 1
	check(not Upgrades.can_buy("aislante", "canasta")["ok"], "max level blocks purchase")
	check(Upgrades.can_buy("bocina", "canasta")["ok"] and Upgrades.can_buy("bocina", "pastor")["ok"], "shared upgrade applies to all modes")


func t_save_load() -> void:
	GameManager.start_new_run("pastor")
	Economy.add_sale(627)
	Aura.add(123)
	Upgrades.levels["trompo_pro"] = 1
	GameManager.shift_index = 1
	check(SaveManager.save_game(), "save writes file")
	Economy.reset(0)
	Aura.reset()
	Upgrades.reset()
	GameManager.shift_index = 0
	GameManager.mode = ""
	check(SaveManager.load_game(), "load succeeds")
	check(Economy.cash == 777, "cash restored")
	check(Aura.aura == 123, "AURA restored")
	check(Upgrades.level("trompo_pro") == 1, "upgrades restored")
	check(GameManager.mode == "pastor" and GameManager.shift_index == 1, "mode and shift restored")
	check(SaveManager.has_continuable_run(), "run is continuable")
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{ esto no es json")
	f.close()
	check(SaveManager.load_data().is_empty() and not SaveManager.load_game(), "corrupt save handled gracefully")
	f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "game": {}, "economy": {}, "aura": {}, "upgrades": {}}))
	f.close()
	check(SaveManager.load_data().is_empty(), "other-version save ignored")
	f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "game": {"mode": "pastor", "run_active": true, "shift_index": 99}, "economy": {"cash": 10}, "aura": {"aura": -50}, "upgrades": {"inventada": 3, "trompo_pro": 9}}))
	f.close()
	check(SaveManager.load_game(), "partially odd save still loads")
	check(GameManager.shift_index == 2 and Aura.aura == 0 and Upgrades.level("trompo_pro") == 2 and not Upgrades.levels.has("inventada"), "save values are clamped/validated")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	check(not SaveManager.has_continuable_run(), "missing save handled")


func t_events() -> void:
	EventManager.begin_shift("carnitas", 2)
	var ids := []
	for s in EventManager.scheduled:
		ids.append(s["id"])
	check("domingo_carnitas" in ids, "Domingo de Carnitas scheduled on Sunday")
	EventManager.begin_shift("pastor", 0)
	ids.clear()
	for s in EventManager.scheduled:
		ids.append(s["id"])
	check("gorron" in ids and not ("domingo_carnitas" in ids), "events filtered by mode")
	check(EventManager.try_start("hora_pico"), "event can start")
	check(not EventManager.try_start("hora_pico"), "active event cannot start twice")
	Aura.reset()
	Aura.add(100)
	EventManager.resolve("hora_pico", true)
	check(Aura.aura == 140 and not EventManager.is_active("hora_pico"), "resolve applies reward")
	check(not EventManager.try_start("hora_pico"), "cooldown blocks restart")
	check(not EventManager.try_start("inspeccion"), "incompatible event rejected")
	EventManager.end_shift()


func t_carnitas() -> void:
	GameManager.start_new_run("carnitas")
	var m = await spawn_scene("res://scenes/carnitas_mode.tscn")
	check(m.running, "carnitas shift starts")
	m.orders.auto_spawn = false
	EventManager.enabled = false
	var x0: float = m.player.position.x
	m.player.input_override = Vector2(1, 0)
	await frames(12)
	m.player.input_override = null
	check(m.player.position.x > x0 + 5.0, "player moves with input")
	m.player.position = Vector2(2000, 2000)
	m.player.step(0.016)
	check(m.player.bounds.has_point(m.player.position) or m.player.position == m.player.bounds.end, "player stays inside the kitchen")
	# Correct order
	var c = waiting_customer(m, {"filling": "maciza", "qty": 2, "verdura": true, "salsa": "verde"})
	m.sel = 0
	check(m.chop() and m.chop(), "chopping maciza adds tacos")
	m.add_verdura()
	m.add_salsa("verde")
	var rev0 := Economy.shift_revenue
	var aura0 := Aura.aura
	check(m.serve(c.slot), "serve succeeds")
	check(Economy.shift_revenue > rev0, "sale adds revenue")
	check(Aura.aura > aura0, "good order adds AURA")
	check(c.state == Customer.State.RECEIVING, "customer goes to RECEIVING")
	check(m.stats["served"] == 1 and m.stats["tacos"] == 2, "stats track served tacos")
	check(m.plate["tacos"].is_empty(), "plate cleared after serving")
	# Wrong cut
	var c2 = waiting_customer(m, {"filling": "surtida", "qty": 1, "verdura": false, "salsa": ""})
	m.sel = 0
	m.chop()
	rev0 = Economy.shift_revenue
	aura0 = Aura.aura
	m.serve(c2.slot)
	check(Economy.shift_revenue == rev0, "wrong cut is not paid")
	check(Aura.aura < aura0 and m.stats["wrong"] == 1, "wrong cut costs AURA")
	# Wrong garnish pays less
	var c3 = waiting_customer(m, {"filling": "maciza", "qty": 1, "verdura": true, "salsa": "roja"})
	m.chop()
	m.add_salsa("verde")
	var res: Dictionary = m.evaluate(c3.order, m.plate, 1.0)
	check(res["verdict"] == "garnish", "wrong garnish detected")
	m.clear_plate()
	# Inventory never negative
	m.tray["maciza"] = []
	check(not m.chop(), "cannot chop an empty cut")
	check(m.tray["maciza"].size() == 0, "tray never goes below zero")
	# Cazo cooking
	m.sel = 1
	var raw0: int = m.raw["surtida"]
	var tray0: int = m.tray["surtida"].size()
	m._cazo_interact()
	check(m.cazo["state"] == "cooking" and m.raw["surtida"] == raw0 - 1, "cazo starts a batch and uses raw meat")
	m._mode_process(30.0)
	check(m.cazo["state"] == "done", "batch finishes cooking")
	m.collect_batch()
	check(m.tray["surtida"].size() == tray0 + m.batch_portions, "collected batch fills the tray")
	m.raw["cuerito"] = 0
	m.sel = 2
	m._cazo_interact()
	check(m.cazo["state"] == "idle" and m.raw["cuerito"] == 0, "no raw meat, no cooking (never negative)")
	# Heat burns quality
	m.sel = 0
	m.raw["maciza"] = 1
	m._cazo_interact()
	m.heat = 1.0
	m._mode_process(3.0)
	check(m.cazo["quality"] < 1.0, "overheating lowers quality")
	# Angry customer
	var c4 = waiting_customer(m, {"filling": "maciza", "qty": 1, "verdura": false, "salsa": ""})
	Aura.add(100)
	aura0 = Aura.aura
	c4.patience = 0.01
	c4.step(0.1)
	await frames(1)
	check(c4.state == Customer.State.ANGRY and m.stats["angry"] == 1, "impatient customer gets ANGRY")
	check(Aura.aura < aura0, "angry customer costs AURA")
	# Tortilla shortage event
	EventManager.enabled = true
	EventManager.try_start("sin_tortillas", true)
	check(not m.tortillas_ok, "tortilla shortage blocks tacos")
	check(not m.plate_add_taco("maciza", 1.0), "no tortillas, no taco")
	for i in 4:
		m._tortillas_interact()
	check(m.tortillas_ok and not EventManager.is_active("sin_tortillas"), "warming tortillas resolves the event")
	# Domingo de Carnitas
	EventManager.try_start("domingo_carnitas", true)
	check(m.orders.rush_mult > 1.0, "Domingo de Carnitas boosts the queue")
	EventManager.active["domingo_carnitas"]["remaining"] = 0.0
	EventManager.update(0.1, 0.5)
	check(not EventManager.is_active("domingo_carnitas") and m.orders.rush_mult == 1.0, "Domingo ends and is resolved")
	EventManager.enabled = true
	m.queue_free()
	await frames(2)


func t_pastor() -> void:
	GameManager.start_new_run("pastor")
	var m = await spawn_scene("res://scenes/pastor_mode.tscn")
	check(m.running, "pastor shift starts")
	m.orders.auto_spawn = false
	EventManager.enabled = false
	m.slice_pos = 0.5
	check(m.cut() == "perfect", "cut at the center is PERFECT")
	check(m.plate["tacos"].size() == 1, "perfect cut adds a taco")
	m.slice_cd = 0.0
	m.slice_pos = 0.0
	check(m.cut() == "miss", "cut at the edge misses")
	check(m.plate["tacos"].size() == 1, "missed cut adds nothing")
	m.slice_cd = 0.0
	m.slice_pos = 0.5 + m.good_zone * 0.9
	check(m.cut() == "good", "cut near the zone is GOOD")
	m.clear_plate()
	# Two perfect orders build a combo
	for i in 2:
		var c = waiting_customer(m, {"filling": "pastor", "qty": 1, "verdura": true, "salsa": "roja", "pina": true})
		m.slice_cd = 0.0
		m.slice_pos = 0.5
		m.dorado = 0.5
		m.cut()
		m.add_verdura()
		m.add_salsa("roja")
		m.add_pina()
		m.serve(c.slot)
	check(m.combo == 2 and is_equal_approx(m.combo_mult(), 1.5), "consecutive perfect orders build the combo")
	var c2 = waiting_customer(m, {"filling": "pastor", "qty": 2, "verdura": true, "salsa": "roja", "pina": false})
	m.slice_cd = 0.0
	m.slice_pos = 0.5
	m.cut()
	m.serve(c2.slot)
	check(m.combo == 0, "a short order breaks the combo")
	# Pineapple trick
	m.slice_cd = 0.0
	m.slice_pos = 0.5
	m.cut()
	m.player.position = Vector2(m.TROMPO_X, 160)
	m._update_near()
	m._mode_special()
	check(not m.pina_throw.is_empty(), "K at the trompo launches the pineapple")
	m.pina_throw["t"] = m.pina_throw["dur"] * 0.9
	var aura0 := Aura.aura
	m._mode_special()
	check(m.plate["pina"] and Aura.aura > aura0, "catching the pineapple adds piña and AURA")
	m.clear_plate()
	# El Gorrón
	EventManager.enabled = true
	check(EventManager.try_start("gorron", true), "Gorrón event starts")
	check(m.gorron != null, "Gorrón spawns")
	var hp: int = m.gorron.hp
	for i in hp:
		m.gorron.take_hit(1)
	check(not EventManager.is_active("gorron"), "driving him off resolves the event")
	check("gorron" in GameManager.achievements, "achievement unlocked for the Gorrón")
	# Stand damage can end the shift
	m.aguante = 5.0
	m.damage_stand(20.0)
	check(m.ended and GameManager.last_shift.get("failed_reason", "") != "", "destroyed stand fails the shift")
	m.queue_free()
	await frames(2)


func t_canasta() -> void:
	GameManager.start_new_run("canasta")
	var m = await spawn_scene("res://scenes/canasta_mode.tscn")
	check(m.running, "canasta shift starts")
	check(m.total_tacos() == 40, "basket starts with 40 tacos")
	check(Economy.cash == 150, "starts with MXN 150")
	EventManager.enabled = false
	var x0: float = m.bike.position.x
	m.bike.input_override = Vector2(1, 0)
	for i in 30:
		m.bike.step(0.016, false)
	check(m.bike.position.x > x0 + 5.0, "bike moves")
	m.bike.input_override = Vector2(0, -1)
	for i in 60:
		m.bike.step(0.05, true)
	check(not m.map.is_blocked(m.bike.hitbox()), "bike never ends inside a building")
	m.bike.input_override = null
	# Sell to a customer
	m.bike.position = Vector2(640, 600)
	m.bike.velocity = Vector2.ZERO
	var c = m.spawn_ped("parque")
	c.modulate.a = 1.0
	m.make_customer(c)
	c.order = {"filling": "frijol", "qty": 2}
	c.position = m.bike.position + Vector2(10, 0)
	c.state = Customer.State.WAITING
	m.sel = 1
	var before: int = m.inventory["frijol"]
	var cash0 := Economy.cash
	check(m.sell_to(c), "sale to pedestrian works")
	check(m.inventory["frijol"] == before - 2, "inventory decreases by the order")
	check(Economy.cash > cash0, "sale adds cash")
	# No stock -> no sale, no negatives
	for v in m.VARIETIES:
		m.inventory[v] = 0
	var c2 = m.spawn_ped("parque")
	m.make_customer(c2)
	c2.position = m.bike.position + Vector2(8, 0)
	c2.state = Customer.State.WAITING
	check(not m.sell_to(c2), "cannot sell without tacos")
	var neg := false
	for v in m.VARIETIES:
		if m.inventory[v] < 0:
			neg = true
	check(not neg, "inventory never negative")
	# Refill at base costs money
	m.bike.position = Vector2(192, 456)
	check(m.at_base(), "base pad detected")
	Economy.reset(500)
	m.refill()
	check(m.total_tacos() == m.capacity and Economy.cash < 500, "refill fills the basket and costs money")
	# Inspection
	EventManager.enabled = true
	m.bike.position = Vector2(520, 190)
	check(m.bike_in_metro(), "metro zone detected")
	check(EventManager.try_start("inspeccion", true), "inspection starts")
	check(m.inspection.state == m.Inspection.S.WARNING, "inspector warns")
	m.bike.position = Vector2(192, 456)
	m.inspection.step(0.1)
	check(not EventManager.is_active("inspeccion"), "leaving the zone resolves the inspection")
	# Caught -> pay the fine
	m.inspection.state = m.Inspection.S.NONE
	EventManager.cooldowns.clear()
	m.bike.position = Vector2(520, 190)
	EventManager.try_start("inspeccion", true)
	m.inspection.position = m.bike.position
	m.inspection.step(0.05)
	check(m.inspection.state == m.Inspection.S.CAUGHT, "inspector catches you in the zone")
	var cash1 := Economy.cash
	m.inspection.choose("pay")
	check(Economy.cash == cash1 - m.Inspection.FINE, "paying the fine deducts it")
	# Critic review
	EventManager.cooldowns.clear()
	check(EventManager.try_start("critico", true) and m.critic != null, "critic appears disguised")
	var cr = m.critic
	m.inventory["papa"] = 10
	m.make_customer(cr)
	cr.order = {"filling": "papa", "qty": 1}
	cr.position = m.bike.position + Vector2(6, 0)
	cr.state = Customer.State.WAITING
	m.sel = 0
	m.warmth = 100.0
	m.sell_to(cr)
	check(m.stats["critic_stars"] >= 2, "a perfect sale earns a good review")
	m.queue_free()
	await frames(2)


func t_upgrade_effects() -> void:
	GameManager.start_new_run("canasta")
	Upgrades.levels = {"canasta_grande": 1, "bici_rapida": 1, "aislante": 1, "timbre_pro": 1}
	var m = await spawn_scene("res://scenes/canasta_mode.tscn")
	check(m.capacity == 55, "bigger basket raises capacity")
	check(m.bike.max_speed > 105.0, "faster bike")
	check(m.warm_decay < 0.38, "insulation slows cooling")
	check(m.bell_radius > 130.0 and m.bell_cooldown < 2.0, "better bell")
	m.queue_free()
	await frames(2)
	GameManager.start_new_run("carnitas")
	Upgrades.levels = {"cazo_grande": 1, "cuchillo_afilado": 1, "refri": 1, "mostrador": 1}
	m = await spawn_scene("res://scenes/carnitas_mode.tscn")
	check(m.batch_portions == 9, "bigger cazo yields more portions")
	check(m.chop_time < 0.42, "sharper knife chops faster")
	check(m.raw["maciza"] == 4, "bigger fridge adds batches")
	check(m.orders.slot_xs.size() == 5, "extended counter adds a slot")
	m.queue_free()
	await frames(2)
	GameManager.start_new_run("pastor")
	Upgrades.levels = {"trompo_pro": 1, "firulais": 1, "combo_mayor": 1}
	m = await spawn_scene("res://scenes/pastor_mode.tscn")
	check(m.perfect_zone > 0.06, "better trompo widens the perfect zone")
	check(m.has_dog, "Firulais guards the stand")
	check(m.combo_cap() == 6, "combo cap raised")
	m.queue_free()
	await frames(2)


func t_shift_completion() -> void:
	for mode_id in ["canasta", "carnitas", "pastor"]:
		GameManager.start_new_run(mode_id)
		var m = await spawn_scene(GameManager.SCENES[mode_id])
		Economy.add_sale(GameManager.shift_target() + 5)
		m.time_left = 0.01
		await frames(3)
		check(m.ended, "%s shift ends when the timer runs out" % mode_id)
		check(GameManager.last_goto == "results", "%s goes to results" % mode_id)
		check(GameManager.shift_history.size() == 1 and GameManager.last_shift["met"], "%s shift recorded as met" % mode_id)
		check(GameManager.shift_index == 1 and GameManager.run_result == "", "%s advances to the next day" % mode_id)
		m.queue_free()
		await frames(2)


func t_win_lose() -> void:
	GameManager.start_new_run("pastor")
	Economy.begin_shift()
	GameManager.finish_shift({})
	check(GameManager.run_result == "lose" and GameManager.lose_reason != "", "missing the goal loses the run")
	GameManager.start_new_run("carnitas")
	for i in 3:
		Economy.begin_shift()
		Economy.add_sale(GameManager.shift_target() + 1)
		GameManager.finish_shift({})
	check(GameManager.run_result == "win", "three met shifts win the run")
	check("legendario" in GameManager.achievements, "victory achievement")
	check(not GameManager.run_active, "run closes after victory")
	GameManager.start_new_run("canasta")
	Economy.begin_shift()
	Economy.add_sale(GameManager.shift_target())
	Economy.charge(5000, "multas")
	GameManager.finish_shift({})
	check(GameManager.run_result == "lose" and "quiebra" in GameManager.lose_reason, "bankruptcy loses the run")
	GameManager.start_new_run("pastor")
	Economy.begin_shift()
	Economy.add_sale(9999)
	GameManager.finish_shift({"failed_reason": "¡Te desmantelaron el puesto!"})
	check(GameManager.run_result == "lose", "failed survival objective loses the run")
	GameManager.start_new_run("carnitas")
	check(GameManager.run_result == "" and GameManager.run_active and Economy.cash == 150, "restart gives a clean run")
