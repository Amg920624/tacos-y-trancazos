extends Node2D
## The canastero's bicycle: arcade acceleration, SPACE "pedalazo" boost with stamina,
## axis-separated collision against the map, bumps from traffic. Drawn side-view with the basket.

const Pix = preload("res://scripts/art/pix.gd")

var map = null
var velocity := Vector2.ZERO
var max_speed := 105.0
var accel := 460.0
var friction := 420.0
var stamina := 1.0
var boosting := false
var facing := 1
var stun_t := 0.0
var anim_t := 0.0
var bell_t := 0.0
var basket_fill := 1.0
var input_override = null


func hitbox(p: Vector2 = position) -> Rect2:
	return Rect2(p.x - 10, p.y - 5, 20, 7)


func step(delta: float, want_boost: bool) -> void:
	anim_t += delta
	bell_t = maxf(0.0, bell_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	var input := Vector2.ZERO
	if input_override != null:
		input = input_override
	elif stun_t <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	boosting = want_boost and stamina > 0.05 and input.length() > 0.1 and stun_t <= 0.0
	var top := max_speed * (1.75 if boosting else 1.0)
	if boosting:
		stamina = maxf(0.0, stamina - 0.5 * delta)
	else:
		stamina = minf(1.0, stamina + 0.22 * delta)
	if input.length() > 0.1:
		velocity = velocity.move_toward(input.normalized() * top, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	_move_axis(Vector2(velocity.x * delta, 0.0))
	_move_axis(Vector2(0.0, velocity.y * delta))
	if absf(velocity.x) > 5.0:
		facing = 1 if velocity.x > 0 else -1
	queue_redraw()


func _move_axis(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	var np := position + d
	if map != null and map.is_blocked(hitbox(np)):
		if d.x != 0.0:
			velocity.x = 0.0
		else:
			velocity.y = 0.0
		return
	position = np


func speed() -> float:
	return velocity.length()


func bump(push: Vector2) -> void:
	velocity = push
	stun_t = 0.6


func ring() -> void:
	bell_t = 0.5


func _draw() -> void:
	Pix.r(self, -14, -1, 28, 3, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	var spin := anim_t * velocity.length() * 0.12
	for wx in [-11.0, 11.0]:
		draw_arc(Vector2(wx, -6), 6.0, 0, TAU, 14, Color("1b1b1b"), 2.0)
		draw_line(Vector2(wx, -6), Vector2(wx + cos(spin) * 5.0, -6 + sin(spin) * 5.0), Color("9a9a9a"), 1.0)
		draw_line(Vector2(wx, -6), Vector2(wx - cos(spin) * 5.0, -6 - sin(spin) * 5.0), Color("9a9a9a"), 1.0)
	var frame := Color("c1121f")
	draw_line(Vector2(-11, -6), Vector2(-2, -14), frame, 2.0)
	draw_line(Vector2(-2, -14), Vector2(9, -14), frame, 2.0)
	draw_line(Vector2(9, -14), Vector2(11, -6), frame, 2.0)
	draw_line(Vector2(-2, -14), Vector2(1, -6), frame, 2.0)
	draw_line(Vector2(9, -14), Vector2(10, -19), Color("777777"), 1.5)
	Pix.r(self, 8, -21, 6, 2, Color("333333"))
	# Rear rack + basket of tacos de canasta wrapped in blue cloth and plastic
	Pix.r(self, -22, -13, 14, 2, Color("555555"))
	Pix.r(self, -24, -25, 18, 12, Color("a8763e"))
	for k in 4:
		Pix.r(self, -24, -24 + k * 3, 18, 1, Color("8a5a2a"))
	for k in 5:
		Pix.r(self, -23 + k * 4, -25, 1, 12, Color("c79a5e"))
	var cloth := Color("1d6fd6")
	Pix.r(self, -25, -28 - basket_fill * 2.0, 20, 4 + basket_fill * 2.0, cloth)
	Pix.r(self, -25, -29 - basket_fill * 2.0, 20, 2, Color(1, 1, 1, 0.35))
	Pix.r(self, -22, -21, 12, 5, Color("fff3d6"))
	# Rider
	var ped := sin(anim_t * (6.0 + velocity.length() * 0.08))
	var look := {"skin": Color("a86b3c"), "hair": Color("1b1b1b"), "shirt": Color("f4f1e8"), "pants": Color("2d3047")}
	Pix.r(self, -2 + ped * 2, -12, 3, 7, look["pants"])
	Pix.r(self, 1 - ped * 2, -12, 3, 6, look["pants"].darkened(0.2))
	Pix.r(self, -5, -27, 9, 13, look["shirt"])
	Pix.r(self, -4, -22, 7, 7, Color("e8e2cf"))
	Pix.r(self, 3, -24, 7, 2, look["shirt"].darkened(0.1))
	Pix.r(self, 9, -24, 2, 2, look["skin"])
	Pix.r(self, -3, -35, 8, 8, look["skin"])
	Pix.r(self, -3, -37, 8, 3, Color("c1121f"))
	Pix.r(self, 4, -35, 4, 1, Color("8a0c16"))
	Pix.r(self, 2, -31, 1, 1, Color("1a1210"))
	Pix.r(self, 1, -29, 4, 1, Color("1b1b1b"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if bell_t > 0.0:
		var rr := 10.0 + (0.5 - bell_t) * 50.0
		draw_arc(Vector2(10 * facing, -20), rr, -1.0, 1.0, 8, Color(1, 0.9, 0.3, bell_t * 2.0), 1.5)
		draw_arc(Vector2(10 * facing, -20), rr * 0.6, -1.0, 1.0, 8, Color(1, 0.9, 0.3, bell_t * 2.0), 1.5)
	if boosting:
		for i in 3:
			Pix.r(self, -facing * (16 + i * 6), -12 + i * 3, 5, 1, Color(1, 1, 1, 0.5))
	if stun_t > 0.0:
		for i in 3:
			var a := anim_t * 7.0 + i * TAU / 3.0
			Pix.r(self, cos(a) * 8 - 1, -40 + sin(a) * 2, 2, 2, Pix.C_AMARILLO)
