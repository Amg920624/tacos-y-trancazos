extends Node
## Customer queue for stationary taquerías: counter slots plus a waiting line on the sidewalk.
## Spawns customers over time (scaled by AURA demand and rush events) and frees slots when they leave.

const Customer = preload("res://scripts/entities/customer_controller.gd")

signal customer_angry(c)
signal customer_arrived(c)

const SLOT_FEET_Y := 272.0

var mode = null
var slot_xs: Array = []
var slots: Array = []
var line: Array = []
var interval := 6.5
var spawn_t := 1.2
var rush_mult := 1.0
var next_id := 1
var max_line := 6
var spawned := 0
var auto_spawn := true


func setup(xs: Array, p_interval: float) -> void:
	slot_xs = xs.duplicate()
	slots.clear()
	for i in slot_xs.size():
		slots.append(null)
	interval = p_interval
	spawn_t = 1.2


func update(delta: float, _t_norm: float) -> void:
	if auto_spawn:
		spawn_t -= delta * rush_mult * Aura.demand_bonus()
		if spawn_t <= 0.0:
			spawn_t = interval * mode.rng.randf_range(0.75, 1.25)
			if line.size() < max_line:
				spawn()
	for c in all_customers():
		c.patience_rate = mode.patience_rate_for(c)


func all_customers() -> Array:
	var out := []
	for c in slots:
		if c != null and is_instance_valid(c):
			out.append(c)
	for c in line:
		if is_instance_valid(c):
			out.append(c)
	return out


func spawn(arch: Dictionary = {}, modifier := "") -> Node2D:
	if arch.is_empty():
		arch = DB.pick_archetype(mode.mode_id, mode.rng)
	var c := Customer.new()
	var pat: float = float(arch.get("patience", 20)) * (1.0 + Upgrades.stat("patience", mode.mode_id)) * Aura.patience_bonus() * mode.patience_scale()
	pat *= float(DB.mode(mode.mode_id).get("patience_mult", 1.0))
	if modifier == "difficult":
		pat *= 0.8
	c.setup(next_id, arch, pat, mode.rng.randi())
	next_id += 1
	c.modifier = modifier
	c.order = mode.generate_order(c)
	var from_left: bool = mode.rng.randf() < 0.3
	c.position = Vector2(-16.0 if from_left else 656.0, 300.0 + mode.rng.randf_range(-4, 12))
	c.exit_point = Vector2(-30.0 if mode.rng.randf() < 0.5 else 670.0, 296.0 + mode.rng.randf_range(0, 16))
	c.speech_below = true
	c.became_angry.connect(_on_angry)
	c.arrived.connect(_on_arrived)
	mode.actors.add_child(c)
	var i := free_slot()
	if i >= 0:
		_assign(c, i)
	else:
		line.append(c)
		c.in_line = true
		c.go_to(_line_pos(line.size() - 1))
	spawned += 1
	return c


func free_slot() -> int:
	for i in slots.size():
		if slots[i] == null or not is_instance_valid(slots[i]):
			slots[i] = null
			return i
	return -1


func add_slot(x: float) -> void:
	slot_xs.append(x)
	slots.append(null)
	_promote()


func _assign(c, i: int) -> void:
	slots[i] = c
	c.slot = i
	c.in_line = false
	c.go_to(Vector2(slot_xs[i] + mode.rng.randf_range(-3, 3), SLOT_FEET_Y))


func _line_pos(k: int) -> Vector2:
	return Vector2(566.0 + k * 17.0, 302.0 + k * 3.0)


func _on_arrived(c) -> void:
	if c.in_line:
		return
	c.say(mode.order_speech(c), 2.6)
	AudioManager.play("order", -4.0)
	customer_arrived.emit(c)


func _on_angry(c) -> void:
	customer_angry.emit(c)
	release(c)


## Frees the customer's slot (or line spot) and moves the line forward.
func release(c) -> void:
	for i in slots.size():
		if slots[i] == c:
			slots[i] = null
	line.erase(c)
	_promote()


func _promote() -> void:
	var i := free_slot()
	while i >= 0 and line.size() > 0:
		var c = line.pop_front()
		if is_instance_valid(c) and c.state != Customer.State.LEAVING and c.state != Customer.State.ANGRY:
			_assign(c, i)
		i = free_slot()
	for k in line.size():
		if is_instance_valid(line[k]):
			line[k].go_to(_line_pos(k))


func customer_at(i: int) -> Customer:
	if i < 0 or i >= slots.size():
		return null
	var c = slots[i]
	if c == null or not is_instance_valid(c):
		return null
	return c


func waiting_count() -> int:
	var n := 0
	for c in all_customers():
		if c.state == Customer.State.WAITING or c.state == Customer.State.ORDERING or c.state == Customer.State.APPROACHING:
			n += 1
	return n
