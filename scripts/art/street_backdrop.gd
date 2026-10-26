extends Node2D
## Static CDMX storefront for stationary taquerías: painted facade, hand-painted sign,
## metal shutter, tiled back wall, terracotta floor, sidewalk, curb and street.
## A child "StreetLife" layer animates taxis, peseros and the night lights.

const Pix = preload("res://scripts/art/pix.gd")

var night := false
var wall_color := Color("e9a23b")
var trim_color := Color("1d4e89")
var stand_name := "TAQUERÍA"
var sign_bg := Color("ffcc00")
var sign_fg := Color("c1121f")
var menu_title := "MENÚ"
var menu_lines: Array = []
var neighborhood := ""
var seed_value := 7
var show_roof := false


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_sky()
	_facade(rng)
	_stand_interior()
	_floor()
	_sidewalk(rng)
	_street()


func _sky() -> void:
	if night:
		Pix.r(self, 0, 0, 640, 40, Color("0d1b2a"))
		Pix.r(self, 0, 0, 640, 14, Color("091320"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 26:
			Pix.r(self, rng.randf_range(0, 640), rng.randf_range(20, 36), 1, 1, Color(1, 1, 0.9, rng.randf_range(0.3, 0.8)))
	else:
		Pix.r(self, 0, 0, 640, 40, Color("a8c8dc"))
		Pix.r(self, 0, 30, 640, 10, Color("c9d6d6"))


func _facade(rng: RandomNumberGenerator) -> void:
	var wall := wall_color.darkened(0.45) if night else wall_color
	Pix.r(self, 0, 22, 640, 84, wall)
	# Worn paint and grime
	for i in 70:
		var c := wall.darkened(rng.randf_range(0.05, 0.15))
		Pix.r(self, rng.randf_range(0, 636), rng.randf_range(22, 100), rng.randf_range(2, 8), rng.randf_range(1, 3), c)
	# Roof line, tinaco and antenna (only visible when no HUD covers the top)
	Pix.r(self, 0, 20, 640, 3, Color("8a8f94").darkened(0.4 if night else 0.0))
	if show_roof:
		Pix.r(self, 520, 4, 22, 17, Color("1f1f1f"))
		Pix.r(self, 520, 4, 22, 3, Color("3a3a3a"))
		Pix.r(self, 523, 9, 16, 1, Color("2e2e2e"))
		draw_line(Vector2(80, 20), Vector2(80, 4), Color("555555"), 1.0)
		draw_line(Vector2(72, 8), Vector2(88, 8), Color("555555"), 1.0)
		draw_line(Vector2(75, 12), Vector2(85, 12), Color("555555"), 1.0)
	# Upper windows with herrería
	for wx in [36, 470, 560]:
		var lit: bool = night and wx != 470
		Pix.r(self, wx, 30, 36, 30, Color("1c1c1c"))
		Pix.r(self, wx + 2, 32, 32, 26, Color("ffd27a") if lit else (Color("2b3a4a") if night else Color("7fa8c0")))
		for k in 5:
			Pix.r(self, wx + 2 + k * 8, 32, 1, 26, Color("222222"))
		Pix.r(self, wx + 2, 44, 32, 1, Color("222222"))
		Pix.r(self, wx - 2, 60, 40, 3, trim_color.darkened(0.3 if night else 0.0))
		# Macetas
		Pix.r(self, wx + 4, 54, 6, 5, Color("b5542f"))
		Pix.r(self, wx + 3, 50, 8, 4, Color("3f8f3a"))
	# Painted side ad
	Pix.r(self, 112, 30, 70, 30, Color("f2efe4").darkened(0.5 if night else 0.0))
	Pix.text(self, Vector2(112, 41), "SE HACEN", 7, Color("1d4e89").darkened(0.4 if night else 0.0), HORIZONTAL_ALIGNMENT_CENTER, 70)
	Pix.text(self, Vector2(112, 52), "FIESTAS", 9, Color("c1121f").darkened(0.4 if night else 0.0), HORIZONTAL_ALIGNMENT_CENTER, 70, 0, Color.BLACK, Pix.display_font())
	Pix.text(self, Vector2(112, 59), "Informes aquí abajo", 5, Color("333333"), HORIZONTAL_ALIGNMENT_CENTER, 70)
	# Big hand-painted sign
	var sr := Rect2(200, 64, 260, 30)
	Pix.sign_board(self, sr, stand_name, sign_bg.darkened(0.15 if night else 0.0), sign_fg, 17)
	if neighborhood != "":
		Pix.text(self, Vector2(sr.position.x, sr.end.y - 1), "Col. " + neighborhood, 6, Color("1d1410"), HORIZONTAL_ALIGNMENT_RIGHT, sr.size.x - 4)
	# Shutter (cortina) rolled up over the stand opening
	Pix.r(self, 10, 98, 620, 8, Color("8d949a").darkened(0.35 if night else 0.0))
	for k in 4:
		Pix.r(self, 10, 99 + k * 2, 620, 1, Color("5d6469").darkened(0.35 if night else 0.0))
	# Pillars
	Pix.r(self, 0, 98, 12, 54, wall.darkened(0.1))
	Pix.r(self, 628, 98, 12, 54, wall.darkened(0.1))


func _stand_interior() -> void:
	var tile_a := Color("eef3f5")
	var grout := Color("6d8fb3")
	if night:
		tile_a = Color("c9c2a8")
		grout = Color("5a6a7a")
	Pix.r(self, 12, 106, 616, 34, grout)
	for ty in 4:
		for tx in 52:
			var x := 13 + tx * 12
			var y := 107 + ty * 8.5
			Pix.r(self, x, y, 11, 7.5, tile_a if (tx + ty) % 7 != 0 else Color("3f6fa6"))
	# Menu board
	if menu_lines.size() > 0:
		Pix.r(self, 496, 108, 124, 30, Color("2b2b2b"))
		Pix.r(self, 498, 110, 120, 26, Color("fbf8ef"))
		Pix.text(self, Vector2(498, 117), menu_title, 6, Color("c1121f"), HORIZONTAL_ALIGNMENT_CENTER, 120)
		var y := 124.0
		for l in menu_lines:
			Pix.text(self, Vector2(504, y), str(l), 5, Color("1d1410"))
			y += 5.5
	# Back steel counter
	Pix.steel(self, Rect2(12, 138, 616, 14))


func _floor() -> void:
	var a := Color("b5542f")
	var b := Color("9c4527")
	if night:
		a = a.darkened(0.35)
		b = b.darkened(0.35)
	for ty in 5:
		for tx in 40:
			Pix.r(self, 12 + tx * 16, 152 + ty * 13, 16, 13, a if (tx + ty) % 2 == 0 else b)
	Pix.r(self, 12, 152, 616, 2, Color(0, 0, 0, 0.3))


func _sidewalk(rng: RandomNumberGenerator) -> void:
	var base := Color("b9b4aa").darkened(0.4 if night else 0.0)
	Pix.r(self, 0, 240, 640, 82, base)
	for k in 9:
		Pix.r(self, k * 80, 240, 1, 82, base.darkened(0.15))
	Pix.r(self, 0, 281, 640, 1, base.darkened(0.12))
	for i in 25:
		Pix.r(self, rng.randf_range(0, 640), rng.randf_range(244, 318), 2, 1, base.darkened(rng.randf_range(0.08, 0.2)))
	# Plastic stools and a folding table
	Pix.stool(self, 26, 316, Color("d62828").darkened(0.3 if night else 0.0))
	Pix.stool(self, 46, 318, Color("1d6fd6").darkened(0.3 if night else 0.0))
	Pix.r(self, 4, 286, 40, 3, Color("e8e2cf").darkened(0.3 if night else 0.0))
	Pix.r(self, 8, 289, 2, 16, Color("777777"))
	Pix.r(self, 38, 289, 2, 16, Color("777777"))
	Pix.r(self, 12, 282, 6, 4, Color("d62828"))
	Pix.r(self, 22, 283, 5, 3, Color("f6f4ea"))
	# Lamp post on the right
	Pix.r(self, 618, 150, 3, 172, Color("3a3f44"))
	Pix.r(self, 606, 150, 16, 3, Color("3a3f44"))
	Pix.r(self, 604, 152, 8, 3, Color("ffe08a") if night else Color("cfd6d9"))


func _street() -> void:
	Pix.r(self, 0, 320, 640, 4, Color("e0b400").darkened(0.4 if night else 0.0))
	Pix.r(self, 0, 324, 640, 36, Color("3b3d42").darkened(0.3 if night else 0.0))
	for k in 12:
		Pix.r(self, 10 + k * 56, 344, 26, 2, Color("e8e2cf").darkened(0.4 if night else 0.1))
	# Overhead wires across the top
	Pix.wire(self, Vector2(0, 26), Vector2(640, 30), 14)
	Pix.wire(self, Vector2(0, 32), Vector2(640, 24), 10)
