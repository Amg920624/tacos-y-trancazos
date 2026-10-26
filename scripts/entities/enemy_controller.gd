extends Node2D
## "El Gorrón": a fictional freeloader who bothers the stand. Cartoon, non-graphic.
## Walks in, mooches tacos (customers lose patience, the stand loses "aguante"),
## tosses empty cans at the taquero, and runs away when hit enough times.

const Pix = preload("res://scripts/art/pix.gd")

signal defeated(e)

enum S { ENTER, HARASS, WINDUP, HIT, FLEE, LEAVE }

var state: int = S.ENTER
var hp := 3
var max_hp := 3
var target := Vector2(275, 262)
var speed := 60.0
var anim_t := 0.0
var state_t := 0.0
var attack_cd := 2.2
var steal_cd := 3.0
var facing := -1
var mode = null
var hit_flash := 0.0
var speech := ""
var speech_t := 0.0
var rng := RandomNumberGenerator.new()
var look := {"skin": Color("b97a56"), "hair": Color("1b1b1b"), "shirt": Color("f2e8c9"), "pants": Color("3d5a80"), "acc": "cap", "acc_color": Color("2a9d8f")}
var _home_x := 275.0


func setup(p_mode, p_hp: int) -> void:
	mode = p_mode
	hp = p_hp
	max_hp = p_hp
	rng.randomize()
	position = Vector2(680, 296)
	_home_x = [165.0, 275.0, 385.0][rng.randi() % 3]
	target = Vector2(_home_x, 262)


func is_active() -> bool:
	return state != S.FLEE and state != S.LEAVE


func say(text: String, dur := 2.0) -> void:
	speech = text
	speech_t = dur


func step(delta: float) -> void:
	anim_t += delta
	state_t += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	speech_t = maxf(0.0, speech_t - delta)
	match state:
		S.ENTER:
			if _move(target, delta, 1.0):
				state = S.HARASS
				state_t = 0.0
				say(DB.line("gorron_enter", "¿Me regala uno?"))
		S.HARASS:
			attack_cd -= delta
			steal_cd -= delta
			var wob := Vector2(_home_x + sin(anim_t * 0.9) * 28.0, 262)
			_move(wob, delta, 0.4)
			if attack_cd <= 0.0:
				state = S.WINDUP
				state_t = 0.0
			elif steal_cd <= 0.0:
				steal_cd = rng.randf_range(3.0, 4.0)
				if mode != null:
					mode.gorron_steal(self)
		S.WINDUP:
			if state_t > 0.6:
				if mode != null:
					mode.gorron_throw(self)
				attack_cd = rng.randf_range(2.2, 3.4)
				state = S.HARASS
				state_t = 0.0
		S.HIT:
			if state_t > 0.35:
				state = S.HARASS
				state_t = 0.0
		S.FLEE, S.LEAVE:
			if _move(Vector2(700, 300), delta, 2.6):
				queue_free()
	queue_redraw()


func take_hit(dmg := 1) -> bool:
	if not is_active():
		return false
	hp -= dmg
	hit_flash = 0.2
	position.x += 6.0 * (1 if rng.randf() < 0.5 else -1)
	if hp <= 0:
		state = S.FLEE
		state_t = 0.0
		say(DB.line("gorron_flee", "¡Ya me voy!"))
		defeated.emit(self)
	else:
		state = S.HIT
		state_t = 0.0
		say(DB.line("gorron_hit", "¡Ay!"), 1.2)
	return true


func leave_laughing() -> void:
	if not is_active():
		return
	state = S.LEAVE
	state_t = 0.0
	say(DB.line("gorron_win", "¡Gracias por los taquitos!"))


func _move(p: Vector2, delta: float, mult: float) -> bool:
	var d := p - position
	var dist := d.length()
	if dist < 1.5:
		return true
	if absf(d.x) > 0.5:
		facing = 1 if d.x > 0 else -1
	position += d / dist * minf(dist, speed * mult * delta)
	return false


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.2, 1.2))
	var walking := state in [S.ENTER, S.FLEE, S.LEAVE]
	Pix.person(self, Vector2.ZERO, look, anim_t, walking, -1 if state == S.HIT else 1, facing)
	# Tank top stripes and belly
	Pix.r(self, -5, -18, 10, 1, Color("c1121f"))
	Pix.r(self, -5, -15, 10, 1, Color("c1121f"))
	Pix.r(self, -6, -13, 12, 4, Color("f2e8c9"))
	# Taco in hand (he always has one)
	Pix.taco_open(self, Vector2(facing * 8, -12), "pastor", {"verdura": true}, 0.4)
	if state == S.WINDUP:
		Pix.r(self, -facing * 6 - 2, -31, 4, 6, Color("c0c4c8"))
		Pix.r(self, -facing * 6 - 2, -29, 4, 2, Color("c1121f"))
		if int(anim_t * 10.0) % 2 == 0:
			Pix.text(self, Vector2(-3, -36), "!", 12, Color("ff4d4d"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	if hit_flash > 0.0:
		Pix.r(self, -6, -28, 12, 27, Color(1, 1, 1, 0.5))
		for i in 3:
			var a := anim_t * 8.0 + i * TAU / 3.0
			Pix.r(self, cos(a) * 7 - 1, -32 + sin(a) * 2, 2, 2, Pix.C_AMARILLO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# HP pips
	if is_active():
		for i in max_hp:
			Pix.r(self, -max_hp * 3 + i * 6, -42, 4, 3, Color("e63946") if i < hp else Color(0, 0, 0, 0.5))
		Pix.text(self, Vector2(-30, -46), "EL GORRÓN", 6, Color("ffcc00"), HORIZONTAL_ALIGNMENT_CENTER, 60, 2, Color.BLACK)
	if speech_t > 0.0:
		Pix.speech(self, Vector2(0, 2), speech, 100.0, 7, true)
