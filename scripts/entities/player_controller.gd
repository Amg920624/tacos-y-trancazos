extends Node2D
## The taquero behind the counter (stationary modes). WASD move, SPACE dash/dodge.
## The owning mode calls step(delta) only while the shift is running.

const Pix = preload("res://scripts/art/pix.gd")

var bounds := Rect2(24, 156, 592, 50)
var speed := 130.0
var facing := 1
var face_dir := Vector2.UP
var moving := false
var anim_t := 0.0
var busy_t := 0.0
var action := ""
var action_t := 0.0
var stun_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var invuln_t := 0.0
var dash_dir := Vector2.RIGHT
var plate: Dictionary = {}
var show_plate := true
var input_override = null   # tests can inject a Vector2


func step(delta: float) -> void:
	anim_t += delta
	busy_t = maxf(0.0, busy_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	if busy_t <= 0.0 and action != "":
		action = ""
	if action != "":
		action_t += delta
	var input := Vector2.ZERO
	if input_override != null:
		input = input_override
	elif stun_t <= 0.0 and busy_t <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := speed
	if dash_t > 0.0:
		dash_t -= delta
		input = dash_dir
		spd = speed * 2.8
	position += input * spd * delta
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	moving = input.length() > 0.1
	if moving:
		face_dir = input.normalized()
		if absf(input.x) > 0.1:
			facing = 1 if input.x > 0 else -1
	queue_redraw()


func is_free() -> bool:
	return busy_t <= 0.0 and stun_t <= 0.0


func do_action(kind: String, duration: float) -> void:
	action = kind
	action_t = 0.0
	busy_t = duration


func dash() -> bool:
	if dash_cd > 0.0 or stun_t > 0.0:
		return false
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dash_dir = input.normalized() if input.length() > 0.1 else Vector2(facing, 0)
	dash_t = 0.14
	dash_cd = 0.55
	invuln_t = 0.4
	busy_t = 0.0
	action = ""
	return true


func stun(sec: float) -> void:
	stun_t = sec
	busy_t = 0.0
	action = ""


func _draw() -> void:
	if invuln_t > 0.0 and dash_t > 0.0:
		for i in 3:
			var ghost := Vector2(-dash_dir.x * (i + 1) * 5, -dash_dir.y * (i + 1) * 3)
			draw_set_transform(ghost, 0.0, Vector2.ONE)
			Pix.r(self, -5, -27, 10, 26, Color(1, 1, 1, 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Pix.taquero(self, Vector2.ZERO, anim_t, moving, facing, action, action_t, stun_t > 0.0)
	if show_plate and plate.get("tacos", []).size() > 0:
		Pix.plate(self, Vector2(facing * 9, -14), plate, 0.75)
