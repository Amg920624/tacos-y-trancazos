extends Node
## Dev-only visual QA: walks through every screen, stages some gameplay and saves PNGs.
## Run (windowed): godot --path . -- --tour=C:/ruta/salida
## Never active in normal play (GameManager only adds it when --tour is passed).

const Customer = preload("res://scripts/entities/customer_controller.gd")

var out_dir := "user://tour"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_path = "user://tour_save.json"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--tour="):
			out_dir = str(a).substr(7)
		if str(a).begins_with("--lang="):
			GameManager.set_language(str(a).substr(7), false)
			get_tree().call_deferred("reload_current_scene")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_tour()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("TOUR_SHOT ", name)


func _close_overlay() -> void:
	var s := get_tree().current_scene
	for ch in s.get_children():
		if ch.has_method("_close") and ch.get("lines") != null:
			ch._close()


func _tour() -> void:
	await _wait(1.2)
	await _shot("01_menu")
	GameManager.goto("select")
	await _wait(0.9)
	await _shot("02_select")

	# Carnitas
	GameManager.start_new_run("carnitas")
	await _wait(0.9)
	await _shot("03_carnitas_instructions")
	_close_overlay()
	await _wait(0.2)
	var m = get_tree().current_scene
	for i in 4:
		var c = m.orders.spawn()
		c.modulate.a = 1.0
		c.position = Vector2(m.orders.slot_xs[c.slot], 272)
		c.state = Customer.State.ORDERING
	m.orders.spawn()
	m.sel = 1
	m.chop()
	m.chop()
	m.add_verdura()
	m.player.position = Vector2(170, 170)
	m._cazo_interact()
	m.heat = 0.6
	await _wait(2.4)
	await _shot("04_carnitas")

	# Pastor
	GameManager.start_new_run("pastor")
	await _wait(0.9)
	_close_overlay()
	await _wait(0.2)
	m = get_tree().current_scene
	for i in 4:
		var c = m.orders.spawn()
		c.modulate.a = 1.0
		c.position = Vector2(m.orders.slot_xs[c.slot], 272)
		c.state = Customer.State.ORDERING
	m.player.position = Vector2(m.TROMPO_X, 160)
	m.slice_pos = 0.5
	m.cut()
	m.combo = 3
	EventManager.try_start("gorron", true)
	await _wait(2.6)
	await _shot("05_pastor")
	m.hud.show_review(3, "Una experiencia que redefine la tortilla.", 100)
	await _wait(0.3)
	await _shot("06_pastor_review")

	# Canasta
	GameManager.start_new_run("canasta")
	await _wait(0.9)
	await _shot("07_canasta_instructions")
	_close_overlay()
	await _wait(0.3)
	m = get_tree().current_scene
	m.bike.position = Vector2(560, 610)
	await _wait(0.8)
	m.ring_bell()
	await _wait(2.2)
	await _shot("08_canasta_park")
	m.bike.position = Vector2(560, 170)
	await _wait(0.6)
	m.ring_bell()
	await _wait(1.0)
	EventManager.try_start("inspeccion", true)
	await _wait(1.0)
	await _shot("09_canasta_metro_inspector")

	# Results, shop, end
	GameManager.last_shift = {"day": "Viernes", "revenue": 412, "target": 250, "met": true, "tacos": 27, "served": 14, "perfect": 6, "angry": 1, "wrong": 0,
		"cost_items": {"ingredientes": 0, "gastos_fijos": 30}, "profit": 382, "aura_delta": 120, "daily_cost_label": "Mantenimiento de la bici y bolsas",
		"highlights": ["Zonas donde vendiste: 3/3", "Recargas: 1", "Sobraron 4 tacos"], "critic_stars": -1}
	GameManager.goto("results")
	await _wait(0.9)
	await _shot("10_results")
	Economy.add_sale(400)
	GameManager.shift_index = 1
	GameManager.goto("shop")
	await _wait(0.9)
	await _shot("11_shop")
	GameManager.run_result = "win"
	GameManager.goto("end")
	await _wait(0.9)
	await _shot("12_end_win")
	print("TOUR_DONE")
	get_tree().quit()
