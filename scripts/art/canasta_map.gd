extends Node2D
## Compact fictional CDMX neighborhood (inspired by Portales / Narvarte) for tacos de canasta.
## 3x3 blocks: vecindad (base), Metro plaza (restricted), corporate offices, park, storefronts.
## Holds the collision rects and zone rects used by canasta_mode.gd, and draws everything static.

const Pix = preload("res://scripts/art/pix.gd")

const W := 1280.0
const H := 768.0
const COLS := [[0.0, 384.0], [448.0, 832.0], [896.0, 1280.0]]
const ROWS := [[0.0, 224.0], [288.0, 480.0], [544.0, 768.0]]
const SIDEWALK := 12.0
const LANES := [240.0, 272.0, 496.0, 528.0]

var solids: Array = []
var zones := {}
var zone_names := {
	"metro": "Salida del Metro Portales",
	"oficinas": "Corporativo Narvarte",
	"parque": "Parque de los Venados",
	"base": "Vecindad de Doña Lupe",
}
var blocks: Array = []
var trees: Array = []
var permit := false
var _shops := [
	["TORTILLERÍA", "e9a23b", "c1121f"], ["FARMACIA", "2a9d8f", "ffffff"], ["ABARROTES LA GÜERA", "f4d35e", "1d4e89"],
	["ESTÉTICA UNISEX", "e4007c", "ffffff"], ["PAPELERÍA", "8fb8e8", "1d1410"], ["CERRAJERÍA", "c1121f", "ffcc00"],
	["LAVANDERÍA", "a8dadc", "1d4e89"], ["MISCELÁNEA", "f28482", "1d1410"], ["REFACCIONARIA", "3d5a80", "ffcc00"],
	["POLLOS ROSTIZADOS", "ff7a00", "ffffff"], ["MERCERÍA", "cdb4db", "1d1410"], ["FONDA DOÑA MARY", "90be6d", "1d1410"],
]


func _init() -> void:
	_build()


func _build() -> void:
	solids.clear()
	blocks.clear()
	trees.clear()
	for c in 3:
		for r in 3:
			var rect := Rect2(COLS[c][0], ROWS[r][0], COLS[c][1] - COLS[c][0], ROWS[r][1] - ROWS[r][0])
			var inner := rect.grow(-SIDEWALK)
			var kind := "shops"
			if c == 1 and r == 0:
				kind = "metro"
			elif c == 2 and r == 1:
				kind = "oficinas"
			elif c == 1 and r == 2:
				kind = "parque"
			elif c == 0 and r == 1:
				kind = "base"
			blocks.append({"rect": rect, "inner": inner, "kind": kind, "c": c, "r": r})
			match kind:
				"shops":
					solids.append(inner)
				"metro":
					solids.append(Rect2(596, 64, 88, 46))
					solids.append(Rect2(470, 28, 40, 14))
					solids.append(Rect2(770, 28, 40, 14))
					zones["metro"] = rect
				"oficinas":
					solids.append(Rect2(inner.position.x, inner.position.y, inner.size.x, 96))
					zones["oficinas"] = Rect2(rect.position.x, 396, rect.size.x, rect.end.y - 396 + 12)
				"parque":
					zones["parque"] = rect
					var rng := RandomNumberGenerator.new()
					rng.seed = 42
					for i in 14:
						var p := Vector2(rng.randf_range(rect.position.x + 28, rect.end.x - 28), rng.randf_range(rect.position.y + 30, rect.end.y - 20))
						if absf(p.x - 640.0) < 46.0 or absf(p.y - 650.0) < 22.0:
							continue
						trees.append(p)
						solids.append(Rect2(p.x - 4, p.y - 6, 8, 6))
					solids.append(Rect2(614, 630, 52, 28))
				"base":
					solids.append(Rect2(inner.position.x, inner.position.y, inner.size.x, 128))
					zones["base"] = Rect2(150, 436, 84, 40)


func is_blocked(r: Rect2) -> bool:
	if r.position.x < 0 or r.position.y < 0 or r.end.x > W or r.end.y > H:
		return true
	for s in solids:
		if r.intersects(s):
			return true
	return false


func zone_at(p: Vector2) -> String:
	for z in ["base", "metro", "oficinas", "parque"]:
		if zones.has(z) and zones[z].has_point(p):
			return z
	return ""


func random_walkable(zone: String, rng: RandomNumberGenerator) -> Vector2:
	var rect: Rect2 = zones.get(zone, Rect2(0, 0, W, H))
	for i in 30:
		var p := Vector2(rng.randf_range(rect.position.x + 8, rect.end.x - 8), rng.randf_range(rect.position.y + 10, rect.end.y - 6))
		if not is_blocked(Rect2(p.x - 4, p.y - 3, 8, 4)):
			return p
	return rect.get_center()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_draw_roads()
	for b in blocks:
		match b["kind"]:
			"shops":
				_draw_sidewalk(b["rect"])
				_draw_building(b["inner"], b["c"] * 3 + b["r"])
			"metro":
				_draw_metro(b["rect"])
			"oficinas":
				_draw_sidewalk(b["rect"])
				_draw_offices(b["rect"], b["inner"])
			"parque":
				_draw_park(b["rect"])
			"base":
				_draw_sidewalk(b["rect"])
				_draw_base(b["rect"], b["inner"])


func _draw_roads() -> void:
	Pix.r(self, 0, 0, W, H, Color("4a4c52"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 160:
		Pix.r(self, rng.randf_range(0, W), rng.randf_range(0, H), 2, 1, Color("55575d"))
	# Lane dashes
	for y in [256.0, 512.0]:
		var x := 0.0
		while x < W:
			Pix.r(self, x, y - 1, 18, 2, Color("e8e2cf"))
			x += 36.0
	for x in [416.0, 864.0]:
		var y := 0.0
		while y < H:
			Pix.r(self, x - 1, y, 2, 18, Color("e8e2cf"))
			y += 36.0
	# Crosswalks at intersections
	for cx in [416.0, 864.0]:
		for cy in [256.0, 512.0]:
			Pix.r(self, cx - 32, cy - 32, 64, 64, Color("45474d"))
			for k in 6:
				Pix.r(self, cx - 30 + k * 10, cy - 34, 6, 6, Color("e8e2cf"))
				Pix.r(self, cx - 30 + k * 10, cy + 28, 6, 6, Color("e8e2cf"))
	# Baches (potholes) and a tope (speed bump)
	for p in [Vector2(200, 262), Vector2(1010, 500), Vector2(430, 640), Vector2(700, 530)]:
		Pix.r(self, p.x - 6, p.y - 3, 12, 6, Color("2d2e32"))
		Pix.r(self, p.x - 4, p.y - 2, 8, 3, Color("38393e"))
	for i in 8:
		Pix.r(self, 600 + i * 4, 226, 2, 60, Color("f4c430") if i % 2 == 0 else Color("1b1b1b"))


func _draw_sidewalk(rect: Rect2) -> void:
	Pix.r(self, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("b9b4aa"))
	Pix.frame(self, rect, Color("8c877e"), 2.0)
	var x := rect.position.x + 24
	while x < rect.end.x:
		Pix.r(self, x, rect.end.y - SIDEWALK, 1, SIDEWALK, Color("a29d94"))
		Pix.r(self, x, rect.position.y, 1, SIDEWALK, Color("a29d94"))
		x += 24.0


func _draw_building(inner: Rect2, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 97 + 5
	var facade_h := 52.0
	var roof := Rect2(inner.position.x, inner.position.y, inner.size.x, inner.size.y - facade_h)
	Pix.r(self, roof.position.x, roof.position.y, roof.size.x, roof.size.y, Color("9a9890"))
	Pix.frame(self, roof, Color("6f6d66"), 2.0)
	# Rooftop clutter: tinacos, antennas, clotheslines
	for i in 4:
		var tx := roof.position.x + 20 + rng.randf_range(0, roof.size.x - 50)
		var ty := roof.position.y + 10 + rng.randf_range(0, maxf(4.0, roof.size.y - 34))
		Pix.r(self, tx, ty, 16, 14, Color("1f1f1f"))
		Pix.r(self, tx, ty, 16, 3, Color("3a3a3a"))
		Pix.r(self, tx + 2, ty + 14, 12, 3, Color(0, 0, 0, 0.25))
	for i in 2:
		var lx := roof.position.x + 40 + i * 150.0
		var ly := roof.position.y + roof.size.y - 18
		draw_line(Vector2(lx, ly), Vector2(lx + 70, ly - 4), Color("eeeeee"), 1.0)
		for k in 5:
			Pix.r(self, lx + 6 + k * 13, ly - 1 - k * 0.6, 6, 7, [Pix.C_ROSA, Pix.C_AZUL, Pix.C_AMARILLO, Color("ffffff"), Pix.C_VERDE][k])
	# Storefronts
	var fy := inner.end.y - facade_h
	var n := int(inner.size.x / 90.0)
	var w := inner.size.x / n
	for i in n:
		var shop: Array = _shops[(seed_value * 3 + i) % _shops.size()]
		var x := inner.position.x + i * w
		var wall := Color(shop[1])
		Pix.r(self, x, fy, w, facade_h, wall)
		Pix.r(self, x, fy, 2, facade_h, wall.darkened(0.25))
		for k in 6:
			Pix.r(self, x + rng.randf_range(4, w - 10), fy + rng.randf_range(4, facade_h - 8), rng.randf_range(3, 9), 2, wall.darkened(0.1))
		# Hand-painted sign band
		Pix.r(self, x + 6, fy + 4, w - 12, 12, Color("fff3d6"))
		Pix.text(self, Vector2(x + 6, fy + 13.5), shop[0], 8, Color(shop[2]) if shop[2] != "ffffff" else Color("c1121f"), HORIZONTAL_ALIGNMENT_CENTER, w - 12, 0, Color.BLACK, Pix.display_font())
		# Metal shutter (half up) and door
		var sx := x + 10
		var sw := w - 20
		Pix.r(self, sx, fy + 20, sw, facade_h - 20, Color("2b2b2b"))
		var up := rng.randf_range(0.3, 0.9)
		Pix.r(self, sx, fy + 20, sw, (facade_h - 20) * up, Color("8d949a"))
		for k in int((facade_h - 20) * up / 3.0):
			Pix.r(self, sx, fy + 21 + k * 3, sw, 1, Color("6d747a"))
		if rng.randf() < 0.5:
			Pix.r(self, sx + sw * 0.5 - 6, fy + facade_h - 12, 12, 10, Color("4a3a2a"))
	Pix.r(self, inner.position.x, inner.end.y - 2, inner.size.x, 2, Color(0, 0, 0, 0.3))


func _draw_metro(rect: Rect2) -> void:
	Pix.r(self, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("cbb8ad"))
	var x := rect.position.x
	while x < rect.end.x:
		Pix.r(self, x, rect.position.y, 1, rect.size.y, Color("b9a598"))
		x += 16.0
	var y := rect.position.y
	while y < rect.end.y:
		Pix.r(self, rect.position.x, y, rect.size.x, 1, Color("b9a598"))
		y += 16.0
	# Planters
	for p in [Vector2(470, 28), Vector2(770, 28)]:
		Pix.r(self, p.x, p.y, 40, 14, Color("8c877e"))
		Pix.r(self, p.x + 2, p.y - 4, 36, 8, Color("3f8f3a"))
	# Entrance: orange canopy, stairs going down
	Pix.r(self, 596, 64, 88, 46, Color("2b2b2b"))
	for k in 6:
		Pix.r(self, 604, 72 + k * 6, 72, 3, Color("55575d"))
	Pix.r(self, 590, 52, 100, 14, Color("ff7a00"))
	Pix.r(self, 590, 52, 100, 2, Color("ffb366"))
	Pix.text(self, Vector2(590, 63), "METRO  PORTALES", 9, Color("ffffff"), HORIZONTAL_ALIGNMENT_CENTER, 100, 0, Color.BLACK, Pix.display_font())
	Pix.r(self, 590, 66, 4, 44, Color("ff7a00"))
	Pix.r(self, 686, 66, 4, 44, Color("ff7a00"))
	# Restricted zone outline (or permit)
	var col := Color("3fbf5a") if permit else Color("e63946")
	_dashed_rect(rect.grow(-3), col)
	Pix.r(self, 470, 150, 120, 26, Color("fff3d6"))
	Pix.r(self, 470, 150, 120, 4, col)
	Pix.text(self, Vector2(470, 164), "ZONA RESTRINGIDA" if not permit else "PERMISO EN REGLA", 8, col.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, 120, 0, Color.BLACK, Pix.display_font())
	Pix.text(self, Vector2(470, 173), "Sin permiso no hay venta (ficticio)" if not permit else "Aquí vendes tranquilo", 5, Color("333333"), HORIZONTAL_ALIGNMENT_CENTER, 120)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var x := r.position.x
	while x < r.end.x:
		Pix.r(self, x, r.position.y, 8, 2, col)
		Pix.r(self, x, r.end.y - 2, 8, 2, col)
		x += 14.0
	var y := r.position.y
	while y < r.end.y:
		Pix.r(self, r.position.x, y, 2, 8, col)
		Pix.r(self, r.end.x - 2, y, 2, 8, col)
		y += 14.0


func _draw_offices(rect: Rect2, inner: Rect2) -> void:
	var tower := Rect2(inner.position.x, inner.position.y, inner.size.x, 96)
	Pix.r(self, tower.position.x, tower.position.y, tower.size.x, tower.size.y, Color("5c7ea3"))
	for i in int(tower.size.x / 16.0):
		for j in 4:
			Pix.r(self, tower.position.x + 4 + i * 16, tower.position.y + 6 + j * 18, 12, 14, Color("9fc3e6") if (i + j) % 5 != 0 else Color("e8f1fa"))
	Pix.r(self, tower.position.x, tower.end.y - 4, tower.size.x, 4, Color("3d5a80"))
	Pix.sign_board(self, Rect2(tower.get_center().x - 90, tower.position.y + 70, 180, 18), "CORPORATIVO NARVARTE", Color("1d4e89"), Color("ffffff"), 11)
	# Plaza
	var plaza := Rect2(rect.position.x, tower.end.y, rect.size.x, rect.end.y - tower.end.y)
	Pix.r(self, plaza.position.x, plaza.position.y, plaza.size.x, plaza.size.y - SIDEWALK, Color("d6d2c4"))
	for k in 5:
		Pix.r(self, rect.position.x + 40 + k * 70, plaza.position.y + 34, 24, 6, Color("8b5a2b"))
	_dashed_rect(zones["oficinas"].grow(-2), Color(0.2, 0.45, 0.85, 0.7))


func _draw_park(rect: Rect2) -> void:
	Pix.r(self, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("5a9e4b"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in 90:
		Pix.r(self, rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y), 3, 2, Color("4c8c3f"))
	Pix.r(self, rect.position.x, 640, rect.size.x, 20, Color("d8c39a"))
	Pix.r(self, 630, rect.position.y, 20, rect.size.y, Color("d8c39a"))
	Pix.frame(self, rect, Color("8c877e"), 2.0)
	# Fountain
	Pix.r(self, 614, 630, 52, 28, Color("9a9890"))
	Pix.r(self, 618, 634, 44, 20, Color("6fb7e0"))
	Pix.r(self, 637, 622, 6, 14, Color("9a9890"))
	# Deer statue
	Pix.r(self, 520, 600, 18, 8, Color("7a5230"))
	Pix.r(self, 534, 592, 6, 10, Color("7a5230"))
	Pix.r(self, 522, 608, 2, 6, Color("7a5230"))
	Pix.r(self, 534, 608, 2, 6, Color("7a5230"))
	draw_line(Vector2(537, 592), Vector2(533, 586), Color("7a5230"), 1.0)
	draw_line(Vector2(538, 592), Vector2(542, 586), Color("7a5230"), 1.0)
	Pix.sign_board(self, Rect2(470, 552, 140, 16), "PARQUE DE LOS VENADOS", Color("2f6b2a"), Color("fff3d6"), 9)
	for k in 3:
		Pix.r(self, 700 + k * 40, 600, 22, 5, Color("8b5a2b"))
	for t in trees:
		Pix.r(self, t.x - 6, t.y - 1, 12, 3, Color(0, 0, 0, 0.25))
		Pix.r(self, t.x - 2, t.y - 14, 4, 14, Color("6b4423"))


## Tree canopies are drawn on their own layer between the ground and the characters.
func draw_canopies(ci: CanvasItem) -> void:
	for t in trees:
		ci.draw_circle(t + Vector2(0, -20), 13, Color(0.18, 0.42, 0.18, 0.92))
		ci.draw_circle(t + Vector2(-5, -24), 8, Color(0.25, 0.52, 0.22, 0.92))
		ci.draw_circle(t + Vector2(5, -17), 7, Color(0.15, 0.36, 0.15, 0.92))


func _draw_base(rect: Rect2, inner: Rect2) -> void:
	var b := Rect2(inner.position.x, inner.position.y, inner.size.x, 128)
	Pix.r(self, b.position.x, b.position.y, b.size.x, b.size.y - 52, Color("9a9890"))
	Pix.r(self, b.position.x + 30, b.position.y + 14, 16, 14, Color("1f1f1f"))
	Pix.r(self, b.position.x + 290, b.position.y + 20, 16, 14, Color("1f1f1f"))
	var fy := b.end.y - 52
	Pix.r(self, b.position.x, fy, b.size.x, 52, Color("f28482"))
	for i in 6:
		var wx := b.position.x + 12 + i * 58
		if i == 2 or i == 3:
			continue
		Pix.r(self, wx, fy + 18, 28, 20, Color("2b3a4a"))
		for k in 4:
			Pix.r(self, wx + k * 7, fy + 18, 1, 20, Color("222222"))
		Pix.r(self, wx + 4, fy + 34, 8, 4, Color("b5542f"))
		Pix.r(self, wx + 3, fy + 30, 10, 4, Color("3f8f3a"))
	Pix.r(self, 150, fy + 8, 84, 44, Color("1d4e89"))
	Pix.r(self, 154, fy + 12, 76, 40, Color("2a6fb0"))
	Pix.r(self, 191, fy + 12, 2, 40, Color("1d4e89"))
	Pix.sign_board(self, Rect2(110, fy - 6, 164, 14), "VECINDAD DE DOÑA LUPE", Color("fff3d6"), Color("c1121f"), 9)
	var pad: Rect2 = zones["base"]
	_dashed_rect(pad, Color("ffcc00"))
	Pix.text(self, Vector2(pad.position.x, pad.position.y + 26), "BASE", 10, Color("ffcc00"), HORIZONTAL_ALIGNMENT_CENTER, pad.size.x, 2, Color.BLACK, Pix.display_font())
