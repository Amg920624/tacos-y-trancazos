extends Node
## Balance simulation: a bot plays full shifts of every mode with real movement, real
## interaction timings and a human-ish reaction delay, then reports revenue vs. targets.
## Run: godot --headless --path . res://tests/sim_runner.tscn

const Customer = preload("res://scripts/entities/customer_controller.gd")
const DT := 1.0 / 30.0

var m = null
var think := 0.0
var skill := 0.85   # chance a timing action lands well
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameManager.test_mode = true
	GameManager.set_language("es", false)
	SaveManager.save_path = "user://sim_save.json"
	rng.seed = 7
	await get_tree().process_frame
	for mode_id in ["carnitas", "pastor", "canasta"]:
		for shift in 3:
			for run in 2:
				await _sim(mode_id, shift, 0.85 if run == 0 else 0.6)
	get_tree().quit()


func _sim(mode_id: String, shift: int, p_skill: float) -> void:
	skill = p_skill
	GameManager.start_new_run(mode_id)
	GameManager.shift_index = shift
	Economy.reset(600)
	var s = load(GameManager.SCENES[mode_id]).instantiate()
	add_child(s)
	await get_tree().process_frame
	m = s
	var steps := int(m.shift_time / DT) + 10
	for i in steps:
		if m.ended:
			break
		_bot(DT)
		m._process(DT)
		_step_others(DT)
	var st: Dictionary = GameManager.last_shift
	print("SIM %-9s dia=%d habilidad=%.2f ventas=$%d meta=$%d atendidos=%d perfectos=%d enojados=%d equivocados=%d aura=%d %s" % [
		mode_id, shift + 1, skill, int(st.get("revenue", 0)), int(st.get("target", 0)), int(st.get("served", 0)),
		int(st.get("perfect", 0)), int(st.get("angry", 0)), int(st.get("wrong", 0)), int(st.get("aura_delta", 0)),
		"OK" if st.get("met", false) else "NO"])
	s.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _step_others(dt: float) -> void:
	var holder: Node = m.actors if m.get("actors") != null else m.entities
	for c in holder.get_children():
		if c is Customer:
			c.step(dt)


# ---------------------------------------------------------------- generic helpers

func _go(p: Vector2) -> bool:
	var body: Node2D = m.player if m.get("player") != null else m.bike
	var d := p - body.position
	if d.length() < 3.0:
		body.input_override = Vector2.ZERO
		return true
	body.input_override = d.normalized()
	return false


func _use_station(id: String) -> bool:
	if _go(m.station_pos(id) + Vector2(0, 2)):
		m._update_near()
		if not m.near.is_empty() and m.near.get("id", "") == id and m.player.is_free():
			m.interact()
			think = rng.randf_range(0.15, 0.35)
			return true
	return false


func _serve_slot(slot: int) -> bool:
	if _go(Vector2(m.orders.slot_xs[slot], m.SERVE_Y)):
		m._update_near()
		if not m.near.is_empty() and m.near.get("slot", -1) == slot and m.player.is_free():
			m.interact()
			think = rng.randf_range(0.2, 0.4)
			return true
	return false


func _bot(dt: float) -> void:
	think -= dt
	if m.get("bike") != null:
		_bot_canasta(dt)
		return
	if think > 0.0 or not m.player.is_free():
		m.player.input_override = Vector2.ZERO
		return
	if not m.tortillas_ok:
		_use_station("tortillas")
		return
	if m.mode_id == "carnitas":
		_bot_carnitas()
	else:
		_bot_pastor()


func _target_customer():
	var best = null
	for i in m.orders.slot_xs.size():
		var c = m.orders.customer_at(i)
		if c != null and c.is_waiting():
			if m.mode_id == "carnitas" and m.tray[c.order["filling"]].size() < int(c.order["qty"]):
				continue
			if best == null or c.patience < best.patience:
				best = c
	return best


func _garnish_and_serve(c) -> void:
	var o: Dictionary = c.order
	if o.has("pina") and o["pina"] and not m.plate["pina"]:
		_use_station("pina")
	elif o.get("verdura", false) and not m.plate["verdura"]:
		_use_station("verdura")
	elif o.get("salsa", "") != "" and m.plate["salsa"] == "":
		_use_station("salsa_" + o["salsa"])
	else:
		_serve_slot(c.slot)


# ---------------------------------------------------------------- carnitas

var _target = null


func _bot_carnitas() -> void:
	# Cazo management first
	if m.cazo["state"] == "done":
		_use_station("cazo")
		return
	if m.cazo["state"] == "cooking" and m.heat > m.good_hi - 0.1:
		_use_station("cazo")
		return
	if m.cazo["state"] == "idle" and m.plate["tacos"].is_empty():
		for i in m.CUTS.size():
			var cut: String = m.CUTS[i]
			if m.tray[cut].size() < 4 and m.raw[cut] > 0:
				m.sel = i
				_use_station("cazo")
				return
	if _target == null or not is_instance_valid(_target) or not _target.is_waiting():
		if not m.plate["tacos"].is_empty():
			_use_station("basura")
			return
		_target = _target_customer()
		if _target == null:
			m.player.input_override = Vector2.ZERO
			return
	var o: Dictionary = _target.order
	var cut: String = o["filling"]
	if m.plate["tacos"].size() < int(o["qty"]):
		if m.tray[cut].size() == 0:
			_target = null
			return
		m.sel = m.CUTS.find(cut)
		_use_station("tabla")
		return
	_garnish_and_serve(_target)


# ---------------------------------------------------------------- pastor

func _bot_pastor() -> void:
	if m.gorron != null and is_instance_valid(m.gorron) and m.gorron.is_active() and m.plate["tacos"].is_empty():
		m.player.input_override = Vector2.ZERO
		if m.throw_cd <= 0.0:
			m.throw_lime()
			think = 0.3
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_waiting():
		if not m.plate["tacos"].is_empty():
			_use_station("basura")
			return
		_target = _target_customer()
		if _target == null:
			m.player.input_override = Vector2.ZERO
			return
	var o: Dictionary = _target.order
	if m.plate["tacos"].size() < int(o["qty"]):
		if _go(m.station_pos("trompo") + Vector2(0, 2)):
			m._update_near()
			var aim: float = m.perfect_zone * 0.8 if rng.randf() < skill else m.good_zone * 0.9
			if absf(m.slice_pos - 0.5) < aim and m.slice_cd <= 0.0:
				m.interact()
				think = 0.05
		return
	_garnish_and_serve(_target)


# ---------------------------------------------------------------- canasta

var _route: Array = []
var _goal_zone := ""


func _bot_canasta(_dt: float) -> void:
	var b = m.bike
	if think > 0.0:
		b.input_override = Vector2.ZERO
		return
	if m.inspection.is_blocking():
		m.inspection.choose("pay")
		return
	# Sell to anyone waiting
	var c = m.nearest_waiting()
	if c != null:
		b.input_override = Vector2.ZERO
		var want: int = m.VARIETIES.find(c.order["filling"])
		if m.inventory[c.order["filling"]] > 0:
			m.sel = want
		m.sell_to(c)
		think = rng.randf_range(0.3, 0.6)
		return
	if m.waiting_customers().size() > 0:
		b.input_override = Vector2.ZERO
		return
	# Low stock: go home and refill
	if m.total_tacos() <= 4 and m.time_left > 25.0:
		if _travel_to("base"):
			m.refill()
			_goal_zone = ""
			think = 0.5
		return
	if _goal_zone == "" or (_goal_zone == "metro" and m.suspicion > 60.0):
		var tn: float = m.t_norm()
		if tn > 0.33 and tn < 0.66:
			_goal_zone = "oficinas"
		elif m.suspicion < 40.0 and rng.randf() < 0.6:
			_goal_zone = "metro"
		else:
			_goal_zone = "parque"
		_route.clear()
	if _travel_to(_goal_zone):
		if m.bell_cd <= 0.0:
			m.ring_bell()
			think = 0.4
			if rng.randf() < 0.15:
				_goal_zone = ""


const SPOTS := {"base": Vector2(192, 456), "metro": Vector2(520, 200), "oficinas": Vector2(1080, 440), "parque": Vector2(560, 600)}
const NODES := {"base": [Vector2(192, 512)], "metro": [Vector2(416, 512), Vector2(416, 256), Vector2(520, 256)],
	"oficinas": [Vector2(864, 512), Vector2(1080, 512)], "parque": [Vector2(560, 512)]}


func _travel_to(zone: String) -> bool:
	var b = m.bike
	if m.map.zone_at(b.position) == zone and b.position.distance_to(SPOTS[zone]) < 40.0:
		b.input_override = Vector2.ZERO
		return true
	if _route.is_empty():
		_route = [Vector2(b.position.x, 512)]
		if b.position.y < 300:
			_route = [Vector2(416, b.position.y), Vector2(416, 512)]
		elif b.position.x > 860:
			_route = [Vector2(b.position.x, 512)]
		_route.append_array(NODES[zone])
		_route.append(SPOTS[zone])
	var p: Vector2 = _route[0]
	var d: Vector2 = p - b.position
	if d.length() < 8.0:
		_route.pop_front()
		return false
	b.input_override = d.normalized()
	if b.velocity.length() < 5.0 and rng.randf() < 0.02:
		_route.clear()
	return false
