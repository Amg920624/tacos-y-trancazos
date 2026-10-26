extends Node2D
## Animated night street for the menus: a pastor stand with a spinning trompo,
## string lights, steam and a pink taxi driving by.

const Pix = preload("res://scripts/art/pix.gd")
const Backdrop = preload("res://scripts/art/street_backdrop.gd")

var _t := 0.0
var _taxi_x := -80.0


func _ready() -> void:
	var b := Backdrop.new()
	b.night = true
	b.wall_color = Color("2a9d8f")
	b.stand_name = "TACOS & TRANCAZOS"
	b.sign_bg = Color("ffcc00")
	b.sign_fg = Color("c1121f")
	b.menu_title = "HOY"
	b.menu_lines = ["Pastor ............. $16", "Carnitas ......... $20", "Canasta .......... $15"]
	b.neighborhood = "Doctores"
	b.show_roof = true
	b.z_index = -1
	add_child(b)


func _process(delta: float) -> void:
	_t += delta
	_taxi_x += delta * 70.0
	if _taxi_x > 760.0:
		_taxi_x = -120.0
	queue_redraw()


func _draw() -> void:
	# String lights (foquitos)
	for i in 30:
		var x := 14 + i * 21
		var y := 98 + sin(i * 0.9) * 2
		var on := int(_t * 3.0 + i) % 4 != 0
		var col: Color = [Pix.C_AMARILLO, Pix.C_ROSA, Pix.C_VERDE, Pix.C_NARANJA][i % 4]
		draw_circle(Vector2(x, y), 1.8, col if on else col.darkened(0.6))
	# Trompo on the left with glowing heat panel
	var tx := 70.0
	Pix.r(self, tx + 18, 110, 8, 30, Color("ff7a00").lerp(Color("ffcc00"), 0.5 + 0.5 * sin(_t * 7.0)))
	var pts := PackedVector2Array([Vector2(tx - 16, 112), Vector2(tx + 16, 112), Vector2(tx + 10, 140), Vector2(tx - 10, 140)])
	draw_colored_polygon(pts, Color("c4471d"))
	for k in 6:
		var yy := 114 + fmod(k * 5.0 + _t * 12.0, 26.0)
		Pix.r(self, tx - 14 + (yy - 112) * 0.2, yy, 28 - (yy - 112) * 0.4, 1, Color("8f2d12"))
	Pix.r(self, tx - 9, 103, 18, 9, Pix.C_PINA)
	Pix.r(self, tx - 5, 97, 3, 6, Pix.C_CILANTRO)
	Pix.r(self, tx + 2, 98, 3, 5, Pix.C_CILANTRO_D)
	Pix.r(self, tx - 1, 92, 2, 50, Color("dfe4e8"))
	for i in 3:
		var sy := fmod(_t * 10.0 + i * 8.0, 24.0)
		Pix.r(self, tx - 8 + i * 8, 96 - sy, 4, 3, Color(1, 1, 1, 0.22 * (1.0 - sy / 24.0)))
	# Street lamp glow
	var glow := PackedVector2Array([Vector2(604, 155), Vector2(560, 322), Vector2(650, 322)])
	draw_colored_polygon(glow, Color(1.0, 0.85, 0.45, 0.08))
	Pix.taxi(self, _taxi_x, 352)
	Pix.moto(self, 520, 318)
