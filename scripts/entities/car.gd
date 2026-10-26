extends Node2D
## Street traffic for the canasta map: pink taxis, peseros, vochos and delivery motos.
## Drives along a horizontal lane and wraps around the map edges.

const Pix = preload("res://scripts/art/pix.gd")

var kind := "taxi"
var dir := 1
var speed := 70.0
var length := 52.0
var honk_cd := 0.0


func setup(p_kind: String, lane_y: float, p_dir: int, x: float, p_speed: float) -> void:
	kind = p_kind
	dir = p_dir
	speed = p_speed
	position = Vector2(x, lane_y + 6)
	length = {"taxi": 52.0, "pesero": 70.0, "vocho": 40.0, "moto": 22.0}.get(kind, 50.0)


func hitbox() -> Rect2:
	return Rect2(position.x - length / 2.0, position.y - 12, length, 12)


func step(delta: float, world_w: float) -> void:
	honk_cd = maxf(0.0, honk_cd - delta)
	position.x += dir * speed * delta
	if dir > 0 and position.x > world_w + 90:
		position.x = -90
	elif dir < 0 and position.x < -90:
		position.x = world_w + 90


func _draw() -> void:
	var x0 := -length / 2.0
	Pix.r(self, x0 + 2, -2, length - 4, 3, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1))
	match kind:
		"taxi":
			Pix.taxi(self, x0, 0, false, false)
		"pesero":
			Pix.pesero(self, x0, 0, false)
		"vocho":
			var body := Color("f3f3f3")
			Pix.r(self, x0, -12, 40, 8, body)
			Pix.r(self, x0 + 8, -19, 22, 8, body)
			Pix.r(self, x0 + 11, -17, 8, 5, Color("9fd3ff"))
			Pix.r(self, x0 + 20, -17, 8, 5, Color("9fd3ff"))
			Pix.r(self, x0 + 36, -11, 4, 2, Color("ffe08a"))
			draw_circle(Vector2(x0 + 9, -3), 4, Color("1b1b1b"))
			draw_circle(Vector2(x0 + 31, -3), 4, Color("1b1b1b"))
		"moto":
			Pix.moto(self, x0, 0)
			Pix.r(self, x0 + 4, -22, 6, 8, Color("2a9d8f"))
			Pix.r(self, x0 + 4, -26, 6, 4, Color("222222"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Labels drawn unmirrored
	match kind:
		"taxi":
			var tx := (x0 + 20.5) if dir > 0 else (-x0 - 30.0)
			Pix.text(self, Vector2(tx, -20.5), "TAXI", 4, Color("111111"))
		"pesero":
			var px := (x0 + 3.0) if dir > 0 else (-x0 - 28.0)
			Pix.text(self, Vector2(px, -25.5), "METRO", 5, Color("ffcc00"))
