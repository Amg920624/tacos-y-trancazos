extends Node2D
## MODE A — TACOS DE CANASTA. Ride the bike around a compact fictional CDMX neighborhood,
## ring the bell to attract hungry pedestrians at the Metro, offices and park, sell papa,
## frijol and chicharrón prensado, keep the basket warm, refill at the vecindad and dodge
## traffic and the (fictional, comedic) inspector.

const Pix = preload("res://scripts/art/pix.gd")
const Customer = preload("res://scripts/entities/customer_controller.gd")
const Hud = preload("res://scripts/ui/hud_controller.gd")
const PopupText = preload("res://scripts/ui/popup_text.gd")
const Instructions = preload("res://scripts/ui/instructions_overlay.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const Map = preload("res://scripts/art/canasta_map.gd")
const Bike = preload("res://scripts/gameplay/bicycle_controller.gd")
const Car = preload("res://scripts/entities/car.gd")
const Inspection = preload("res://scripts/gameplay/inspection_controller.gd")

const VARIETIES := ["papa", "frijol", "chicharron"]
const SELL_ZONES := ["metro", "oficinas", "parque"]
const ZONE_PATIENCE := {"metro": 10.0, "oficinas": 13.0, "parque": 18.0}
const MAX_PEDS := {"metro": 7, "oficinas": 6, "parque": 5}
const SELL_RADIUS := 36.0
const MAX_WAITING := 5

var mode_id := "canasta"
var shift_time := 150.0
var time_left := 150.0
var running := false
var ended := false
var rng := RandomNumberGenerator.new()

var map: Map
var bike: Bike
var camera: Camera2D
var entities: Node2D
var fx: Node2D
var wires: Node2D
var hud: Hud
var pause_menu: PauseMenu
var inspection: Inspection
var cars: Array = []
var peds: Array = []
var spawn_t := {"metro": 0.3, "oficinas": 0.8, "parque": 1.2}
var inventory := {"papa": 0, "frijol": 0, "chicharron": 0}
var capacity := 40
var sel := 0
var warmth := 100.0
var warm_decay := 0.38
var bell_cd := 0.0
var bell_cooldown := 2.0
var bell_radius := 130.0
var passive_t := 2.5
var suspicion := 0.0
var permit := false
var current_zone := ""
var zones_sold := {}
var next_id := 1
var critic = null
var rush_sales := 0
var lunch_state := 0
var close_confirm_t := 0.0
var car_hit_cd := 0.0
var stats := {"served": 0, "perfect": 0, "wrong": 0, "angry": 0, "tacos": 0, "wasted": 0, "fines": 0, "critic_stars": -1, "refills": 0, "mismatch": 0}
var _t := 0.0


# ---------------------------------------------------------------- setup

func _ready() -> void:
	rng.randomize()
	shift_time = GameManager.shift_time()
	time_left = shift_time
	permit = Upgrades.stat("metro_permit", mode_id) > 0.0
	map = Map.new()
	map.permit = permit
	map.z_index = -10
	add_child(map)
	var canopies := Node2D.new()
	canopies.z_index = -5
	canopies.draw.connect(func(): map.draw_canopies(canopies))
	add_child(canopies)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	bike = Bike.new()
	bike.map = map
	bike.position = Vector2(192, 458)
	bike.max_speed = 105.0 * (1.0 + Upgrades.stat("bike_speed", mode_id))
	entities.add_child(bike)
	inspection = Inspection.new()
	inspection.mode = self
	entities.add_child(inspection)
	_spawn_cars()
	wires = Node2D.new()
	wires.z_index = 10
	wires.draw.connect(_draw_wires)
	add_child(wires)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(Map.W)
	camera.limit_bottom = int(Map.H)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	camera.position = bike.position
	camera.make_current()
	camera.reset_smoothing()
	hud = Hud.new()
	hud.mode_ref = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	capacity = int(DB.mode(mode_id).get("base_capacity", 40)) + int(Upgrades.stat("basket_capacity", mode_id))
	bell_radius = 130.0 + Upgrades.stat("bell_radius", mode_id)
	bell_cooldown = maxf(0.8, 2.0 + Upgrades.stat("bell_cooldown", mode_id))
	warm_decay = 0.38 * (1.0 - Upgrades.stat("insulation", mode_id))
	Aura.aura_changed.connect(_on_aura_changed)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_timeout.connect(_on_event_timeout)
	GameManager.begin_shift_snapshot()
	Economy.begin_shift()
	Aura.begin_shift()
	fill_basket(GameManager.shift_index == 0)
	for z in SELL_ZONES:
		for i in 3:
			spawn_ped(z)
	AudioManager.play_music("day")
	if GameManager.test_mode:
		start_shift()
	else:
		_show_instructions()


func _spawn_cars() -> void:
	var plan := [["taxi", 0, 1, 120.0, 70.0], ["vocho", 0, 1, 760.0, 58.0], ["pesero", 1, -1, 900.0, 55.0],
		["taxi", 1, -1, 260.0, 74.0], ["taxi", 2, 1, 320.0, 72.0], ["moto", 2, 1, 1040.0, 95.0], ["pesero", 3, -1, 560.0, 52.0]]
	for p in plan:
		var car := Car.new()
		car.setup(p[0], Map.LANES[p[1]], p[2], p[3], p[4])
		entities.add_child(car)
		cars.append(car)


func _show_instructions() -> void:
	var first: bool = not GameManager.tutorial_seen.get(mode_id, false)
	var lines: Array = []
	if first:
		lines = [
			"WASD: pedalear · ESPACIO: ¡pedalazo! (gasta energía) · ESC: pausa",
			"K: tocar el timbre para llamar clientes cerca · Q: cambiar de taco",
			"E: vender al cliente más cercano. Dale el taco que pidió (papa, frijol o chicharrón).",
			"Zonas: Metro (arriba, mucha gente, ZONA RESTRINGIDA), Oficinas (derecha,",
			"   ¡hora de la comida a medio turno!) y Parque (abajo, gente paciente).",
			"Los tacos se enfrían. En la BASE (vecindad): E recarga la canasta, J cierra el turno.",
			"Cuidado con los coches en la calle... y con el inspector si vendes sin permiso.",
		]
	else:
		lines = [tr("%s: hoy la meta es %s.") % [GameManager.day_name(), Economy.money(GameManager.shift_target())],
			tr("Gastos al cierre: %s (%s).") % [Economy.money(GameManager.daily_cost()), tr(DB.mode(mode_id).get("daily_cost_label", ""))],
			"K timbre · Q cambiar taco · E vender · ESPACIO pedalazo · Base: E recarga, J cierra"]
	lines.append("")
	lines.append(tr("META DEL %s: %s en ventas · Tiempo: %s · Canasta: %d tacos") % [GameManager.day_name().to_upper(), Economy.money(GameManager.shift_target()), Pix.fmt_time(shift_time), total_tacos()])
	var ov := Instructions.new()
	ov.setup(tr("%s — %s") % [DB.mode(mode_id).get("stand_name", "").to_upper(), GameManager.day_name().to_upper()], lines, "Presiona E o ENTER para salir a vender")
	ov.closed.connect(start_shift)
	add_child(ov)
	GameManager.tutorial_seen[mode_id] = true


func start_shift() -> void:
	if running or ended:
		return
	running = true
	EventManager.begin_shift(mode_id, GameManager.shift_index)
	hud.banner(DB.line("shift_start", "¡A vender!"), Color("ffcc00"), 2.5)


# ---------------------------------------------------------------- basket

func total_tacos() -> int:
	var n := 0
	for v in VARIETIES:
		n += int(inventory[v])
	return n


func _targets() -> Dictionary:
	var third := capacity / 3
	return {"papa": capacity - third * 2, "frijol": third, "chicharron": third}


## Fills the basket to capacity. Shift 1 starts with a free, pre-made basket.
## Returns what was paid. Buys as many as the cash allows.
func fill_basket(free := false) -> int:
	var targets := _targets()
	if free:
		for v in VARIETIES:
			inventory[v] = maxi(int(inventory[v]), int(targets[v]))
		warmth = 100.0
		return 0
	var cost := 0
	var budget := maxi(0, Economy.cash)
	var added := true
	while added:
		added = false
		for v in VARIETIES:
			var c := int(DB.recipe(v).get("cost", 5))
			if int(inventory[v]) < int(targets[v]) and cost + c <= budget:
				inventory[v] = int(inventory[v]) + 1
				cost += c
				added = true
	if cost > 0:
		Economy.spend(cost, "ingredientes")
	warmth = 100.0
	return cost


func refill_cost() -> int:
	var targets := _targets()
	var c := 0
	for v in VARIETIES:
		c += maxi(0, int(targets[v]) - int(inventory[v])) * int(DB.recipe(v).get("cost", 5))
	return c


func refill() -> void:
	if refill_cost() <= 0:
		if warmth < 99.0:
			warmth = 100.0
			popup_at(bike.position + Vector2(0, -44), "¡Tacos recalentados!", Color("ffcc00"))
		else:
			popup_at(bike.position + Vector2(0, -44), "La canasta ya está llena", Color("fff3d6"))
		return
	var paid := fill_basket(false)
	if paid <= 0:
		popup_at(bike.position + Vector2(0, -44), "No te alcanza para más tacos", Color("ffb3b3"))
		AudioManager.play("fail")
		return
	stats["refills"] += 1
	popup_at(bike.position + Vector2(0, -44), tr("¡Canasta recargada! -%s") % Economy.money(paid), Color("8ef58e"))
	AudioManager.play("cash", -4.0, 0.8)


# ---------------------------------------------------------------- pedestrians

func zone_demand(z: String, t_norm: float) -> float:
	var d := 0.0
	match z:
		"metro":
			d = 1.0 * (2.2 if EventManager.is_active("salida_metro") else 1.0)
		"oficinas":
			d = 1.7 if (t_norm >= 0.33 and t_norm <= 0.66) else 0.35
		"parque":
			d = 0.6
	return d * Aura.demand_bonus() * (1.0 + Upgrades.stat("demand", mode_id))


func t_norm() -> float:
	return clampf(1.0 - time_left / shift_time, 0.0, 1.0)


func spawn_ped(z: String, modifier := "") -> Node2D:
	var arch: Dictionary = DB.archetype("critico") if modifier == "critic" else DB.pick_archetype(mode_id, rng)
	var c := Customer.new()
	var pat: float = float(ZONE_PATIENCE.get(z, 12.0)) * (1.0 + Upgrades.stat("patience", mode_id)) * Aura.patience_bonus() * [1.0, 0.92, 0.85][clampi(GameManager.shift_index, 0, 2)]
	c.setup(next_id, arch, pat, rng.randi())
	next_id += 1
	c.zone = z
	c.modifier = modifier
	c.position = map.random_walkable(z, rng)
	c.wander_in(map.zones[z].grow(-10))
	c.speech_below = false
	c.fade_on_leave = true
	c.bubble_drawer = _draw_ped_bubble
	c.set_meta("life", rng.randf_range(18.0, 32.0) if modifier == "" else 999.0)
	c.became_angry.connect(_on_ped_angry)
	c.arrived.connect(_on_ped_arrived)
	entities.add_child(c)
	peds.append(c)
	return c


func count_in_zone(z: String) -> int:
	var n := 0
	for c in peds:
		if is_instance_valid(c) and c.zone == z and c.state != Customer.State.LEAVING:
			n += 1
	return n


func waiting_customers() -> Array:
	var out := []
	for c in peds:
		if is_instance_valid(c) and c.interested and c.state in [Customer.State.APPROACHING, Customer.State.ORDERING, Customer.State.WAITING]:
			out.append(c)
	return out


func make_customer(c) -> bool:
	if c.interested or c.state in [Customer.State.LEAVING, Customer.State.ANGRY, Customer.State.RECEIVING]:
		return false
	if waiting_customers().size() >= MAX_WAITING:
		return false
	c.interested = true
	var r := rng.randf()
	var v := "papa" if r < 0.4 else ("frijol" if r < 0.7 else "chicharron")
	c.order = {"filling": v, "qty": [1, 2, 2, 3][rng.randi() % 4]}
	c.patience = c.patience_max
	var ang := rng.randf() * TAU
	c.go_to(bike.position + Vector2(cos(ang) * 22.0, sin(ang) * 9.0 + 3.0), Customer.State.ORDERING)
	return true


func _on_ped_arrived(c) -> void:
	if not c.interested:
		return
	var lines: Array = c.archetype.get("lines", [])
	var s: String = lines[rng.randi() % lines.size()] if lines.size() > 0 else "¡Jefe! Écheme {qty} de {item}."
	c.say(tr(s).replace("{qty}", str(c.order["qty"])).replace("{item}", DB.recipe_name(c.order["filling"], true).to_lower()), 2.4)
	AudioManager.play("order", -5.0)


func _on_ped_angry(c) -> void:
	if not c.interested:
		return
	stats["angry"] += 1
	Aura.record_satisfaction(0.0)
	Aura.add(-10, "", c.position + Vector2(0, -44), true)
	AudioManager.play("angry", -3.0)
	if c == critic:
		_critic_review(c, false, false, 0.0, 0.0, 0.0)


func ring_bell() -> void:
	if bell_cd > 0.0:
		return
	bell_cd = bell_cooldown
	bike.ring()
	AudioManager.play("bell")
	popup_at(bike.position + Vector2(0, -48), DB.line("bell", "¡Tacos de canasta!"), Color("fff3d6"))
	var attracted := 0
	for c in peds:
		if not is_instance_valid(c) or c.interested or c.state != Customer.State.WANDERING:
			continue
		if c.position.distance_to(bike.position) > bell_radius:
			continue
		var chance := clampf(0.5 * zone_demand(c.zone, t_norm()), 0.15, 0.95)
		if c.modifier == "critic" or rng.randf() < chance:
			if make_customer(c):
				attracted += 1
	if attracted == 0 and current_zone == "":
		popup_at(bike.position + Vector2(0, -60), "Aquí no hay gente... ve al Metro, oficinas o parque", Color("cdbfa8"))


func nearest_waiting():
	var best = null
	var bd := SELL_RADIUS
	for c in peds:
		if is_instance_valid(c) and c.interested and c.state == Customer.State.WAITING:
			var d: float = c.position.distance_to(bike.position)
			if d < bd:
				bd = d
				best = c
	return best


## Sells the selected variety to a waiting customer. Never lets inventory go below zero.
func sell_to(c) -> bool:
	if c == null or not is_instance_valid(c) or c.state != Customer.State.WAITING:
		return false
	var want: String = c.order.get("filling", "papa")
	var qty := int(c.order.get("qty", 1))
	var v: String = VARIETIES[sel]
	if int(inventory[v]) <= 0:
		popup_at(bike.position + Vector2(0, -44), tr("¡Ya no traes de %s! (Q para cambiar)") % DB.recipe_name(v, true).to_lower(), Color("ffb3b3"))
		AudioManager.play("fail", -6.0)
		return false
	var n := mini(qty, int(inventory[v]))
	inventory[v] = maxi(0, int(inventory[v]) - n)
	var mismatch := v != want
	var speed: float = c.patience_ratio()
	var warm_q := clampf(warmth / 70.0, 0.0, 1.0)
	var price := DB.price(v) * (1.0 + Upgrades.stat("price", mode_id))
	var tip := float(c.archetype.get("tip", 0.0)) + Aura.tip_bonus() + 0.15 * speed
	var pay := price * n * (1.0 if warmth >= 40.0 else 0.8) * (0.75 if mismatch else 1.0) * (1.0 + tip)
	var got := Economy.add_sale(pay)
	var aura := 0
	var line := ""
	var sat := 0.75 + 0.25 * speed
	if mismatch:
		aura = -5
		line = DB.line("mismatch", "Bueno, ya qué...")
		sat = 0.5
		stats["mismatch"] += 1
	elif n < qty:
		line = DB.line("short", "Faltan tacos.")
		sat = 0.55
	else:
		aura = 5
		if speed > 0.6:
			aura += 5
		if warmth >= 70.0:
			aura += 3
			line = DB.line("warm", "¡Calientitos!")
		elif warmth < 40.0:
			line = DB.line("cold", "Están fríos...")
			sat = 0.6
		else:
			line = DB.line("happy", "¡Qué ricos!")
		if speed > 0.6 and warmth >= 70.0:
			stats["perfect"] += 1
	stats["served"] += 1
	stats["tacos"] += n
	var z: String = c.zone if c.zone != "" else current_zone
	zones_sold[z] = true
	if zones_sold.has("metro") and zones_sold.has("oficinas") and zones_sold.has("parque"):
		GameManager.unlock("canastero")
	if EventManager.is_active("salida_metro") and z == "metro":
		rush_sales += 1
	Aura.record_satisfaction(sat)
	PopupText.spawn(fx, c.position + Vector2(0, -30), "+" + Economy.money(got), Color("8ef58e"), 9, 1.2)
	AudioManager.play("cash", -3.0)
	if aura != 0:
		Aura.add(aura, "", c.position + Vector2(0, -42), true)
	c.receive(not mismatch, line)
	if c == critic:
		_critic_review(c, not mismatch, n >= qty, warm_q, speed, sat)
	if (z == "metro" or current_zone == "metro") and not permit:
		suspicion = minf(100.0, suspicion + 26.0 + rng.randf() * 10.0)
		if suspicion >= 100.0 and not inspection.is_busy():
			EventManager.try_start("inspeccion")
	return true


func _critic_review(c, correct: bool, full: bool, warm_q: float, speed: float, sat: float) -> void:
	if c.revealed_critic:
		return
	c.revealed_critic = true
	var score := (40.0 if correct else 0.0) + (10.0 if full else 0.0) + 25.0 * warm_q + 20.0 * speed + 5.0 * sat
	var stars := 0
	if score >= 85.0:
		stars = 3
	elif score >= 60.0:
		stars = 2
	elif score >= 35.0:
		stars = 1
	var aura: int = [-20, 10, 50, 100][stars]
	stats["critic_stars"] = stars
	Aura.add(aura, "RESEÑA DEL CRÍTICO", c.position + Vector2(0, -54), true)
	hud.show_review(stars, DB.critic_review(stars), aura)
	if stars == 3:
		GameManager.unlock("comal_oro")
	EventManager.resolve("critico", stars >= 2)
	critic = null


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_t += delta
	camera.position = bike.position
	if not running or ended:
		return
	if inspection.is_blocking():
		inspection.step(delta)
		hud.prompt = tr("E: Pagar la multa (%s)  ·  K: ¡Echarse la carrera!") % Economy.money(Inspection.FINE)
		return
	time_left = maxf(0.0, time_left - delta)
	var tn := t_norm()
	EventManager.update(delta, tn)
	close_confirm_t = maxf(0.0, close_confirm_t - delta)
	bell_cd = maxf(0.0, bell_cd - delta)
	car_hit_cd = maxf(0.0, car_hit_cd - delta)
	bike.step(delta, Input.is_action_pressed("dash"))
	bike.basket_fill = float(total_tacos()) / maxf(1.0, capacity)
	current_zone = map.zone_at(bike.position)
	warmth = maxf(0.0, warmth - warm_decay * delta)
	_update_cars(delta)
	_update_peds(delta, tn)
	_update_lunch(tn)
	inspection.step(delta)
	if current_zone != "metro":
		suspicion = maxf(0.0, suspicion - 4.0 * delta)
	hud.prompt = _prompt_text()
	if time_left <= 0.0:
		end_shift("")


func _update_cars(delta: float) -> void:
	for car in cars:
		car.step(delta, Map.W)
	if car_hit_cd > 0.0:
		return
	var hb := bike.hitbox()
	for car in cars:
		if car.hitbox().intersects(hb):
			car_hit_cd = 1.2
			var push := -1.0 if bike.position.y < car.position.y - 6.0 else 1.0
			bike.bump(Vector2(car.dir * 60.0, push * 170.0))
			AudioManager.play("honk")
			AudioManager.play("hit", -6.0)
			var lost := ""
			for v in VARIETIES:
				if int(inventory[v]) > 0 and (lost == "" or rng.randf() < 0.5):
					lost = v
			if lost != "":
				inventory[lost] = int(inventory[lost]) - 1
				stats["wasted"] += 1
			var who: String = {"taxi": "taxi", "pesero": "pesero", "vocho": "vocho", "moto": "repartidor"}.get(car.kind, "coche")
			popup_at(bike.position + Vector2(0, -46), tr("¡Aguas con el %s!%s") % [tr(who), tr(" -1 taco") if lost != "" else ""], Color("ffb3b3"))
			break


func _update_peds(delta: float, tn: float) -> void:
	for z in SELL_ZONES:
		spawn_t[z] = float(spawn_t[z]) - delta * zone_demand(z, tn)
		if spawn_t[z] <= 0.0:
			spawn_t[z] = rng.randf_range(2.5, 4.5)
			var cap: int = int(MAX_PEDS[z]) + (4 if z == "metro" and EventManager.is_active("salida_metro") else 0)
			if count_in_zone(z) < cap:
				spawn_ped(z)
	if bike.speed() < 14.0 and current_zone in SELL_ZONES:
		passive_t -= delta * zone_demand(current_zone, tn)
		if passive_t <= 0.0:
			passive_t = rng.randf_range(2.8, 4.2)
			var best = null
			var bd := 150.0
			for c in peds:
				if is_instance_valid(c) and not c.interested and c.state == Customer.State.WANDERING:
					var d: float = c.position.distance_to(bike.position)
					if d < bd:
						bd = d
						best = c
			if best != null:
				make_customer(best)
	for i in range(peds.size() - 1, -1, -1):
		var c = peds[i]
		if not is_instance_valid(c):
			peds.remove_at(i)
			continue
		if c.interested and c.state == Customer.State.WAITING:
			var d: float = c.position.distance_to(bike.position)
			if d > 90.0:
				c.patience_rate = 3.0
				if not c.has_meta("far_said"):
					c.set_meta("far_said", true)
					c.say(DB.line("far", "¡No se vaya!"), 1.6)
			else:
				c.patience_rate = 1.0
		elif not c.interested and c.state == Customer.State.WANDERING:
			var life: float = float(c.get_meta("life", 20.0)) - delta
			c.set_meta("life", life)
			if life <= 0.0:
				c.exit_point = c.position + Vector2(rng.randf_range(-40, 40), rng.randf_range(10, 30))
				c.leave()


func _update_lunch(tn: float) -> void:
	if lunch_state == 0 and tn >= 0.33:
		lunch_state = 1
		hud.banner("¡Hora de la comida en Narvarte! Las oficinas tienen hambre", Color("8fb8e8"), 3.0)
	elif lunch_state == 1 and tn > 0.66:
		lunch_state = 2
		hud.banner("Se acabó la hora de la comida en las oficinas", Color("cdbfa8"), 2.5)


func bike_in_metro() -> bool:
	return map.zones["metro"].has_point(bike.position)


func at_base() -> bool:
	return map.zones["base"].has_point(bike.position)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not running or ended:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
		return
	if inspection.is_blocking():
		if event.is_action_pressed("interact"):
			inspection.choose("pay")
		elif event.is_action_pressed("special"):
			inspection.choose("run")
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("special"):
		ring_bell()
	elif event.is_action_pressed("switch"):
		sel = (sel + 1) % VARIETIES.size()
		popup_at(bike.position + Vector2(0, -44), tr("Taco: %s (%d)") % [DB.recipe_name(VARIETIES[sel]), inventory[VARIETIES[sel]]], Color("ffcc00"))
		AudioManager.play("ui_move")
	elif event.is_action_pressed("attack"):
		if at_base():
			if close_confirm_t > 0.0:
				end_shift("")
			else:
				close_confirm_t = 2.0
				hud.banner("¿Cerrar el turno ya? Presiona J otra vez", Color("ffcc00"), 2.0)
	elif event.is_action_pressed("dev_event"):
		EventManager.try_start("inspeccion", true)
	elif event.is_action_pressed("dev_critic"):
		EventManager.try_start("critico", true)
	elif event.is_action_pressed("dev_end"):
		time_left = minf(time_left, 3.0)


func interact() -> void:
	var c = nearest_waiting()
	if c != null:
		sell_to(c)
	elif at_base():
		refill()
	else:
		popup_at(bike.position + Vector2(0, -44), "Nadie te está esperando · K: tocar el timbre", Color("cdbfa8"))


func _prompt_text() -> String:
	var c = nearest_waiting()
	var v: String = VARIETIES[sel]
	if c != null:
		var want: String = c.order["filling"]
		if want != v:
			return tr("Pidió de %s y traes %s · Q: cambiar · E: vender así") % [DB.recipe_name(want, true).to_lower(), DB.recipe_name(v, true).to_lower()]
		return tr("E: Vender %d de %s") % [int(c.order["qty"]), DB.recipe_name(v, true).to_lower()]
	if at_base():
		var rc := refill_cost()
		return (tr("E: Recargar canasta (%s)") % Economy.money(rc) if rc > 0 else tr("E: Recalentar tacos")) + tr(" · J: Cerrar el turno")
	if current_zone in SELL_ZONES:
		return "K: Tocar el timbre · Q: cambiar taco · ESPACIO: pedalazo"
	if total_tacos() == 0:
		return "¡Se acabaron los tacos! Regresa a la BASE (vecindad, a la izquierda)"
	return "Pedalea a una zona: Metro (arriba) · Oficinas (derecha) · Parque (abajo)"


func popup_at(pos: Vector2, text: String, color := Color("fff3d6")) -> void:
	PopupText.spawn(fx, pos, text, color, 8, 1.2)


# ---------------------------------------------------------------- events

func _on_event_started(ev: Dictionary) -> void:
	var id: String = ev.get("id", "")
	match id:
		"inspeccion":
			if permit:
				EventManager.resolve(id, true)
				return
			hud.banner(tr(ev.get("banner", "¡Aguas!")) + tr(" Sal de la zona del Metro."), Color("ff6b6b"), 3.0)
			inspection.start()
		"salida_metro":
			rush_sales = 0
			hud.banner(ev.get("banner", ""), Color("ffcc00"), 3.0)
			for i in 6:
				var p = spawn_ped("metro")
				p.position = Vector2(640 + rng.randf_range(-30, 30), 116 + rng.randf_range(0, 10))
		"critico":
			critic = spawn_ped("parque" if rng.randf() < 0.5 else "oficinas", "critic")
			GameManager.critic_done = true
			hud.banner("Dicen que anda un crítico gastronómico por la colonia...", Color("cdbfa8"), 3.0)


func _on_event_timeout(id: String) -> void:
	match id:
		"inspeccion":
			inspection.force_leave()
		"salida_metro":
			EventManager.resolve(id, rush_sales >= 4, bike.position + Vector2(0, -60), true)
		"critico":
			if critic != null and is_instance_valid(critic):
				critic.leave()
			critic = null


func _on_aura_changed(_total: int, delta: int, message: String, pos: Vector2, has_pos: bool) -> void:
	if delta == 0 or not is_inside_tree():
		return
	var at: Vector2 = pos if has_pos else bike.position + Vector2(0, -50)
	PopupText.spawn(fx, at, Aura.popup_text(delta, message), Color("ffd34d") if delta > 0 else Color("ff6b6b"), 8, 1.5)
	if delta >= 20:
		AudioManager.play("aura", -4.0)


# ---------------------------------------------------------------- end

func end_shift(failed_reason := "") -> void:
	if ended:
		return
	ended = true
	running = false
	hud.prompt = ""
	AudioManager.play("shift_end")
	var s := stats.duplicate()
	s["wasted"] = int(s["wasted"]) + total_tacos()
	s["failed_reason"] = failed_reason
	s["mode"] = mode_id
	s["events_ok"] = EventManager.handled_count()
	s["highlights"] = [tr("Zonas donde vendiste: %d/3") % zones_sold.size(), tr("Recargas: %d") % stats["refills"], tr("Sobraron %d tacos") % total_tacos()]
	if int(stats["fines"]) > 0:
		s["highlights"].append(tr("Multas: %s") % Economy.money(int(stats["fines"])))
	if GameManager.test_mode:
		GameManager.finish_shift(s)
		return
	hud.banner("¡SE ACABÓ EL TURNO!", Color("ffcc00"), 2.0)
	get_tree().create_timer(1.8).timeout.connect(GameManager.finish_shift.bind(s))


# ---------------------------------------------------------------- drawing

func _draw_wires() -> void:
	# Utility poles on the sidewalks with sagging cables across the avenues
	var poles := [Vector2(378, 120), Vector2(454, 132), Vector2(826, 120), Vector2(902, 132),
		Vector2(378, 380), Vector2(454, 392), Vector2(826, 380), Vector2(902, 392),
		Vector2(378, 650), Vector2(454, 662), Vector2(826, 650), Vector2(902, 662)]
	for i in range(0, poles.size(), 2):
		var a: Vector2 = poles[i] + Vector2(0, -38)
		var b: Vector2 = poles[i + 1] + Vector2(0, -38)
		Pix.wire(wires, a, b, 9)
		Pix.wire(wires, a + Vector2(0, 4), b + Vector2(0, 4), 12)
	for p in poles:
		Pix.r(wires, p.x - 1, p.y - 40, 3, 40, Color("3a3f44"))
		Pix.r(wires, p.x - 4, p.y - 40, 9, 2, Color("3a3f44"))
		Pix.r(wires, p.x - 3, p.y - 1, 7, 2, Color(0, 0, 0, 0.25))


func _draw_ped_bubble(ci: CanvasItem, c) -> void:
	if not c.interested or c.order.is_empty():
		return
	var label := tr("%d de %s") % [int(c.order["qty"]), DB.recipe_name(c.order["filling"], true).to_lower()]
	var w := Pix.text_width(label, 7) + 18
	var y := -48.0
	var hl: bool = nearest_waiting() == c
	Pix.r(ci, -w / 2.0 - 1, y - 1, w + 2, 18, Color("ffcc00") if hl else Color("1d1410"))
	Pix.r(ci, -w / 2.0, y, w, 16, Color("fffaf0"))
	var cols := Pix.filling_colors(c.order["filling"])
	ci.draw_circle(Vector2(-w / 2.0 + 7, y + 7), 4, cols[0])
	Pix.text(ci, Vector2(-w / 2.0 + 13, y + 10), label, 7, Color("1d1410"))
	Pix.patience_bar(ci, -w / 2.0 + 1, y + 12.5, w - 2, c.patience_ratio())


func draw_hud_extra(ci: Control) -> void:
	# Basket panel
	var rect := Rect2(4, 282, 196, 58)
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color(0.06, 0.03, 0.02, 0.84))
	Pix.r(ci, rect.position.x, rect.position.y, 2, rect.size.y, Color("1d6fd6"))
	Pix.text(ci, Vector2(10, 293), tr("CANASTA %d/%d  [Q cambia]") % [total_tacos(), capacity], 7, Color("cdbfa8"))
	for i in VARIETIES.size():
		var v: String = VARIETIES[i]
		var x := 12 + i * 62
		if i == sel:
			Pix.r(ci, x - 4, 296, 60, 22, Color(1, 0.8, 0, 0.25))
			Pix.frame(ci, Rect2(x - 4, 296, 60, 22), Color("ffcc00"))
		Pix.taco_canasta(ci, Vector2(x + 6, 306), v, 0.9)
		Pix.text(ci, Vector2(x + 16, 305), DB.recipe_name(v, true), 6, Color("fff3d6"))
		Pix.text(ci, Vector2(x + 16, 315), tr("x%d") % int(inventory[v]), 8, Color("ffcc00") if int(inventory[v]) > 0 else Color("ff6b6b"))
	var wc := Color("ff7a00") if warmth >= 70.0 else (Color("f4c430") if warmth >= 40.0 else Color("8fb8e8"))
	Pix.text(ci, Vector2(10, 329), "Calor", 7, Color("cdbfa8"))
	Pix.r(ci, 38, 324, 60, 5, Color(0, 0, 0, 0.6))
	Pix.r(ci, 38, 324, 60 * warmth / 100.0, 5, wc)
	Pix.text(ci, Vector2(104, 329), "Pedalazo", 7, Color("cdbfa8"))
	Pix.r(ci, 140, 324, 54, 5, Color(0, 0, 0, 0.6))
	Pix.r(ci, 140, 324, 54 * bike.stamina, 5, Color("3fbf5a"))
	Pix.text(ci, Vector2(10, 338), tr("Timbre (K): %s") % (tr("listo") if bell_cd <= 0.0 else tr("%.1fs") % bell_cd), 6, Color("ffcc00") if bell_cd <= 0.0 else Color("8a7a6e"))
	# Zone label + clock
	var hour := 8.0 + 8.0 * t_norm()
	var clock := tr("%d:%02d") % [int(hour), int(fmod(hour, 1.0) * 60.0)]
	var zl: String = tr("Calle") if current_zone == "" else map.zone_names.get(current_zone, current_zone)
	var extra := ""
	if current_zone == "metro":
		extra = tr(" — PERMISO EN REGLA") if permit else tr(" — ZONA RESTRINGIDA")
	elif current_zone == "oficinas" and lunch_state == 1:
		extra = tr(" — ¡HORA DE LA COMIDA!")
	var zt := tr("%s  ·  %s%s") % [clock, zl, extra]
	var zw := Pix.text_width(zt, 8) + 14
	Pix.r(ci, 636 - zw, 268, zw, 12, Color(0.06, 0.03, 0.02, 0.78))
	Pix.text(ci, Vector2(636 - zw, 277), zt, 8, Color("ff6b6b") if (current_zone == "metro" and not permit) else Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, zw)
	if not permit and (current_zone == "metro" or suspicion > 0.0):
		Pix.r(ci, 470, 252, 166, 14, Color(0.06, 0.03, 0.02, 0.78))
		Pix.text(ci, Vector2(474, 262), "Sospecha del inspector", 6, Color("ff8a8a"))
		Pix.r(ci, 568, 256, 64, 6, Color(0, 0, 0, 0.6))
		Pix.r(ci, 568, 256, 64 * suspicion / 100.0, 6, Color("e63946"))
	# Minimap
	_draw_minimap(ci, Rect2(538, 282, 98, 59))
	# Inspection overlays
	if inspection.state == Inspection.S.CAUGHT:
		var pr := Rect2(190, 120, 260, 70)
		Pix.r(ci, pr.position.x - 2, pr.position.y - 2, pr.size.x + 4, pr.size.y + 4, Color("1d1410"))
		Pix.r(ci, pr.position.x, pr.position.y, pr.size.x, pr.size.y, Color("3b1f14"))
		Pix.r(ci, pr.position.x, pr.position.y, pr.size.x, 16, Color("c1121f"))
		Pix.text(ci, Vector2(pr.position.x, pr.position.y + 12), "¡TE CACHÓ EL INSPECTOR!", 10, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		Pix.text(ci, Vector2(pr.position.x, pr.position.y + 34), tr("E: Pagar la multa (%s)") % Economy.money(Inspection.FINE), 9, Color("ffcc00"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		Pix.text(ci, Vector2(pr.position.x, pr.position.y + 50), "K: ¡Echarse la carrera! (si te alcanza, multa x1.5)", 8, Color("ff9ccc"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		Pix.text(ci, Vector2(pr.position.x, pr.position.y + 64), "Inspección ficticia y en son de broma", 6, Color("8a7a6e"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	elif inspection.state == Inspection.S.CHASE:
		Pix.text(ci, Vector2(250, 64), tr("¡CORRE! %.1fs") % inspection.t, 11, Color("ff7a00"), HORIZONTAL_ALIGNMENT_CENTER, 140, 2, Color.BLACK)
	elif inspection.state == Inspection.S.WARNING:
		Pix.text(ci, Vector2(200, 64), tr("¡Sal de la zona del Metro! %.1fs") % maxf(0.0, inspection.t), 10, Color("ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER, 240, 2, Color.BLACK)


func _draw_minimap(ci: Control, r: Rect2) -> void:
	var s := r.size.x / Map.W
	Pix.r(ci, r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, Color("1d1410"))
	Pix.r(ci, r.position.x, r.position.y, r.size.x, r.size.y, Color("4a4c52"))
	var colors := {"shops": Color("8c877e"), "metro": Color("ff7a00"), "oficinas": Color("5c7ea3"), "parque": Color("5a9e4b"), "base": Color("f28482")}
	for b in map.blocks:
		var br: Rect2 = b["rect"]
		Pix.r(ci, r.position.x + br.position.x * s + 1, r.position.y + br.position.y * s + 1, br.size.x * s - 2, br.size.y * s - 2, colors.get(b["kind"], Color.GRAY))
	for c in waiting_customers():
		Pix.r(ci, r.position.x + c.position.x * s - 1, r.position.y + c.position.y * s - 1, 2, 2, Color("ffcc00"))
	if inspection.is_busy():
		Pix.r(ci, r.position.x + inspection.position.x * s - 1.5, r.position.y + inspection.position.y * s - 1.5, 3, 3, Color("ff2d2d"))
	if int(_t * 4.0) % 2 == 0:
		Pix.r(ci, r.position.x + bike.position.x * s - 2, r.position.y + bike.position.y * s - 2, 4, 4, Color("ffffff"))
