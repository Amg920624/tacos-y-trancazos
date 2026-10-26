extends Node2D
## Reusable customer driven by a finite state machine.
## Stationary taquerías queue them at counter slots; canasta mode lets them wander a hotspot.
## SPAWNING → APPROACHING → ORDERING → WAITING → RECEIVING → LEAVING (or WAITING → ANGRY → LEAVING).

const Pix = preload("res://scripts/art/pix.gd")

signal arrived(c)
signal became_angry(c)
signal left_scene(c)

enum State { SPAWNING, WANDERING, APPROACHING, ORDERING, WAITING, RECEIVING, LEAVING, ANGRY }
const STATE_NAMES := ["SPAWNING", "WANDERING", "APPROACHING", "ORDERING", "WAITING", "RECEIVING", "LEAVING", "ANGRY"]

var customer_id := 0
var archetype: Dictionary = {}
var archetype_id := ""
var order: Dictionary = {}
var patience_max := 20.0
var patience := 20.0
var payment := 0
var satisfaction := 0.0
var modifier := ""            # "", "critic", "difficult"
var state: int = State.SPAWNING
var target := Vector2.ZERO
var exit_point := Vector2(700, 300)
var speed := 40.0
var look: Dictionary = {}
var anim_t := 0.0
var state_t := 0.0
var speech := ""
var speech_t := 0.0
var speech_below := true
var mood := 0
var facing := 1
var patience_rate := 1.0      # set by the mode each frame (line, Gorrón nearby, far away...)
var in_line := false
var slot := -1
var wander_rect := Rect2()
var zone := ""
var interested := false
var revealed_critic := false
var bubble_drawer: Callable   # mode draws the order bubble: f(ci: CanvasItem, c: Customer)
var show_patience := true
var fade_on_leave := false
var rng := RandomNumberGenerator.new()
var _wander_pause := 0.0
var _after_arrive_state: int = State.ORDERING


func setup(id: int, arch: Dictionary, p_patience: float, seed_value: int) -> void:
	customer_id = id
	archetype = arch
	archetype_id = arch.get("id", "")
	rng.seed = seed_value
	look = Pix.random_look(arch.get("look", {}), rng)
	speed = float(arch.get("speed", 40)) * rng.randf_range(0.9, 1.15)
	patience_max = maxf(4.0, p_patience)
	patience = patience_max
	modulate.a = 0.0


func state_name() -> String:
	return STATE_NAMES[state]


func patience_ratio() -> float:
	return clampf(patience / patience_max, 0.0, 1.0)


func is_waiting() -> bool:
	return state == State.WAITING and not in_line


func go_to(p: Vector2, then_state: int = State.ORDERING) -> void:
	target = p
	_after_arrive_state = then_state
	if state != State.SPAWNING:
		state = State.APPROACHING
		state_t = 0.0


func wander_in(rect: Rect2) -> void:
	wander_rect = rect
	target = _random_point(rect)
	if state != State.SPAWNING:
		state = State.WANDERING


func say(text: String, duration := 2.4) -> void:
	speech = text
	speech_t = duration


func receive(happy: bool, line: String, p_mood := 1) -> void:
	state = State.RECEIVING
	state_t = 0.0
	mood = p_mood if happy else -1
	if line != "":
		say(line, 2.0)


func get_angry(line: String) -> void:
	if state == State.LEAVING or state == State.ANGRY:
		return
	state = State.ANGRY
	state_t = 0.0
	mood = -1
	say(line, 2.0)
	became_angry.emit(self)


func leave() -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	state_t = 0.0
	target = exit_point


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	anim_t += delta
	state_t += delta
	speech_t = maxf(0.0, speech_t - delta)
	match state:
		State.SPAWNING:
			modulate.a = minf(1.0, modulate.a + delta * 4.0)
			if modulate.a >= 1.0:
				state = State.APPROACHING if (wander_rect.size == Vector2.ZERO or interested) else State.WANDERING
		State.WANDERING:
			if _wander_pause > 0.0:
				_wander_pause -= delta
			elif _move(target, delta, 0.5):
				_wander_pause = rng.randf_range(0.4, 2.0)
				target = _random_point(wander_rect)
		State.APPROACHING:
			if _move(target, delta):
				if in_line:
					state = State.WAITING
				else:
					state = _after_arrive_state
				state_t = 0.0
				arrived.emit(self)
		State.ORDERING:
			if state_t > 0.6:
				state = State.WAITING
				state_t = 0.0
		State.WAITING:
			patience -= delta * patience_rate * (0.4 if in_line else 1.0)
			if patience <= 0.0:
				patience = 0.0
				get_angry(DB.line("angry", "¡Ya me voy!"))
		State.RECEIVING:
			if state_t > 1.0:
				leave()
		State.ANGRY:
			if state_t > 1.1:
				leave()
		State.LEAVING:
			if fade_on_leave:
				modulate.a = maxf(0.0, 1.0 - state_t / 1.6)
			if _move(target, delta, 1.25) or (fade_on_leave and modulate.a <= 0.0):
				left_scene.emit(self)
				queue_free()
	queue_redraw()


func _move(p: Vector2, delta: float, speed_mult := 1.0) -> bool:
	var d := p - position
	var dist := d.length()
	if dist < 1.5:
		position = p
		return true
	if absf(d.x) > 0.5:
		facing = 1 if d.x > 0 else -1
	position += d / dist * minf(dist, speed * speed_mult * delta)
	return false


func _random_point(rect: Rect2) -> Vector2:
	return Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))


func is_moving() -> bool:
	return state in [State.APPROACHING, State.LEAVING] or (state == State.WANDERING and _wander_pause <= 0.0)


func _draw() -> void:
	Pix.person(self, Vector2.ZERO, look, anim_t, is_moving(), mood, facing)
	if state == State.ANGRY:
		var j := sin(anim_t * 40.0)
		Pix.text(self, Vector2(-3 + j, -33), "#!", 8, Color("ff4d4d"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	var speaking_above := speech_t > 0.0 and speech != "" and not speech_below
	if (state == State.WAITING or state == State.ORDERING) and not in_line and bubble_drawer.is_valid() and not speaking_above:
		bubble_drawer.call(self, self)
	if in_line and state == State.WAITING:
		var dots := ".".repeat(1 + int(anim_t * 2.0) % 3)
		Pix.text(self, Vector2(-6, -32), dots, 9, Color("fff3d6"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	if speech_t > 0.0 and speech != "":
		if speech_below:
			Pix.speech(self, Vector2(0, 2), speech, 92.0, 7, true)
		else:
			Pix.speech(self, Vector2(0, -32), speech, 92.0, 7, false)
