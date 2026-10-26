extends RefCounted
## Procedural pixel-art library. Every sprite in the game is drawn with these helpers
## from inside a node's _draw(), using the node's local coordinates.

const C_TORTILLA := Color("ecc873")
const C_TORTILLA_DARK := Color("cfa349")
const C_TORTILLA_SPOT := Color("b7863a")
const C_ONION := Color("f6f4ea")
const C_CILANTRO := Color("3f9b3a")
const C_CILANTRO_D := Color("2a6b27")
const C_SALSA_VERDE := Color("5f9e3c")
const C_SALSA_ROJA := Color("b3261e")
const C_PINA := Color("f7cf45")
const C_LIME := Color("74b83a")
const C_LIME_IN := Color("c8ea85")
const C_STEEL := Color("b9bfc5")
const C_STEEL_HI := Color("e4e8eb")
const C_STEEL_LO := Color("858c93")
const C_INK := Color("1d1410")
const C_CREAM := Color("fff3d6")
const C_ROSA := Color("e4007c")
const C_AMARILLO := Color("ffcc00")
const C_VERDE := Color("00a859")
const C_NARANJA := Color("ff7a00")
const C_AZUL := Color("1d4e89")

const FILLINGS := {
	"pastor": [Color("c4471d"), Color("8f2d12")],
	"maciza": [Color("b9773c"), Color("8d552a")],
	"surtida": [Color("94552b"), Color("e0b77a")],
	"cuerito": [Color("dcae6a"), Color("f1d39a")],
	"papa": [Color("e3b04b"), Color("c98f2c")],
	"frijol": [Color("4a2416"), Color("6b3a24")],
	"chicharron": [Color("8a3a1e"), Color("b5582f")],
}
const SKINS := ["8d5524", "a86b3c", "c68642", "e0ac69", "6b4226", "b97a56", "9c6644"]
const HAIRS := ["1b1b1b", "2e1d12", "4a2c17", "6b4f2a", "8a8a8a", "1b1b1b"]

static var _display_font: Font = null


static func display_font() -> Font:
	if _display_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Impact", "Arial Black", "Haettenschweiler", "Arial"])
		f.font_weight = 800
		_display_font = f
	return _display_font


static func r(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), c)


static func frame(ci: CanvasItem, rect: Rect2, c: Color, width := 1.0) -> void:
	ci.draw_rect(rect, c, false, width)


static func text(ci: CanvasItem, pos: Vector2, s: String, size := 8, color := Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, outline_color := Color.BLACK,
		font: Font = null) -> void:
	var f: Font = font if font != null else ThemeDB.fallback_font
	s = tl(s)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, size, outline, outline_color)
	ci.draw_string(f, pos, s, align, width, size, color)


static func text_width(s: String, size := 8, font: Font = null) -> float:
	var f: Font = font if font != null else ThemeDB.fallback_font
	return f.get_string_size(tl(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Translates an exact UI string for the current language (Spanish is the source language).
static func tl(s: String) -> String:
	if s == "":
		return s
	return String(TranslationServer.translate(s))


static func fmt_time(sec: float) -> String:
	var s := maxi(0, int(ceil(sec)))
	return "%d:%02d" % [s / 60, s % 60]


static func filling_colors(filling: String) -> Array:
	return FILLINGS.get(filling, [Color("a0603a"), Color("704020")])


# ---------------------------------------------------------------- food

## Open taco seen from above: small doubled corn tortilla, chopped meat and toppings.
static func taco_open(ci: CanvasItem, c: Vector2, filling: String, opts: Dictionary = {}, s := 1.0) -> void:
	var rad := 7.0 * s
	ci.draw_circle(c + Vector2(1.5, 1.0) * s, rad, C_TORTILLA_DARK)
	ci.draw_circle(c, rad, C_TORTILLA)
	for p in [Vector2(-5, -2), Vector2(3, 4), Vector2(4, -4), Vector2(-3, 4), Vector2(5, 1)]:
		r(ci, c.x + p.x * s, c.y + p.y * s, maxf(1.0, s), maxf(1.0, s), C_TORTILLA_SPOT)
	var cols := filling_colors(filling)
	var fc: Color = cols[0]
	var fc2: Color = cols[1]
	var q := float(opts.get("quality", 1.0))
	if q < 0.6:
		fc = fc.darkened(0.4)
		fc2 = fc2.darkened(0.4)
	var chunks := [Vector2(-3, -2), Vector2(0, -3), Vector2(2, -1), Vector2(-2, 1), Vector2(1, 1), Vector2(-4, 0), Vector2(3, 1), Vector2(0, 0)]
	for i in chunks.size():
		var p: Vector2 = chunks[i]
		r(ci, c.x + p.x * s, c.y + p.y * s, 2.5 * s, 2.0 * s, fc if i % 3 != 0 else fc2)
	if opts.get("verdura", false):
		for p in [Vector2(-2, -3), Vector2(1, -2), Vector2(-3, 1), Vector2(2, 2), Vector2(0, 0)]:
			r(ci, c.x + p.x * s, c.y + p.y * s, 1.2 * s, 1.2 * s, C_ONION)
		for p in [Vector2(-1, -1), Vector2(2, -3), Vector2(-4, -1), Vector2(1, 3)]:
			r(ci, c.x + p.x * s, c.y + p.y * s, 1.2 * s, 1.0 * s, C_CILANTRO)
	var salsa: String = opts.get("salsa", "")
	if salsa != "":
		var sc := C_SALSA_VERDE if salsa == "verde" else C_SALSA_ROJA
		for p in [Vector2(-1, -2), Vector2(2, 0), Vector2(-3, 2), Vector2(0, 2)]:
			r(ci, c.x + p.x * s, c.y + p.y * s, 1.6 * s, 1.2 * s, sc)
	if opts.get("pina", false):
		for p in [Vector2(-2, -4), Vector2(3, -2), Vector2(1, 3)]:
			r(ci, c.x + p.x * s, c.y + p.y * s, 2.0 * s, 2.0 * s, C_PINA)


## Folded, oily taco de canasta (side view).
static func taco_canasta(ci: CanvasItem, c: Vector2, variety: String, s := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(c + Vector2(cos(a) * 8.0 * s, sin(a) * 6.0 * s + 2.0 * s))
	ci.draw_colored_polygon(pts, Color("d89a3c"))
	var cols := filling_colors(variety)
	r(ci, c.x - 6 * s, c.y + 1 * s, 12 * s, 1.5 * s, cols[0])
	r(ci, c.x - 7 * s, c.y + 2 * s, 14 * s, 1.0 * s, Color("b97a2a"))
	r(ci, c.x - 3 * s, c.y - 3 * s, 3 * s, 1 * s, Color(1, 1, 1, 0.35))


static func icon_verdura(ci: CanvasItem, c: Vector2, crossed := false) -> void:
	ci.draw_circle(c, 5, Color("ddd6c4"))
	for p in [Vector2(-2, -2), Vector2(1, -1), Vector2(-1, 1), Vector2(2, 2)]:
		r(ci, c.x + p.x - 1, c.y + p.y - 1, 2, 2, C_ONION)
	for p in [Vector2(0, -3), Vector2(-3, 0), Vector2(2, 0), Vector2(0, 2)]:
		r(ci, c.x + p.x - 1, c.y + p.y, 2, 1, C_CILANTRO)
	if crossed:
		_cross(ci, c, 5)


static func icon_salsa(ci: CanvasItem, c: Vector2, kind: String) -> void:
	if kind == "":
		ci.draw_circle(c, 4, Color("cccccc"))
		_cross(ci, c, 5)
		return
	var col := C_SALSA_VERDE if kind == "verde" else C_SALSA_ROJA
	var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(3, 3), c + Vector2(0, 4), c + Vector2(-3, 3), c + Vector2(-4, 0)])
	ci.draw_colored_polygon(pts, col)
	r(ci, c.x - 2, c.y - 1, 1, 2, Color(1, 1, 1, 0.5))


static func icon_pina(ci: CanvasItem, c: Vector2, crossed := false) -> void:
	r(ci, c.x - 4, c.y - 2, 8, 6, C_PINA)
	r(ci, c.x - 4, c.y + 2, 8, 2, Color("d9a92a"))
	r(ci, c.x - 3, c.y - 5, 2, 3, C_CILANTRO)
	r(ci, c.x + 1, c.y - 5, 2, 3, C_CILANTRO_D)
	if crossed:
		_cross(ci, c, 5)


static func icon_lime(ci: CanvasItem, c: Vector2, rad := 4.0) -> void:
	ci.draw_circle(c, rad, C_LIME)
	ci.draw_circle(c, rad * 0.6, C_LIME_IN)
	r(ci, c.x - 0.5, c.y - rad * 0.6, 1, rad * 1.2, C_LIME)


static func _cross(ci: CanvasItem, c: Vector2, size: float) -> void:
	ci.draw_line(c + Vector2(-size, -size), c + Vector2(size, size), Color("d62828"), 1.5)
	ci.draw_line(c + Vector2(-size, size), c + Vector2(size, -size), Color("d62828"), 1.5)


static func coin(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c, 5, Color("b8860b"))
	ci.draw_circle(c, 4, Color("ffd34d"))
	text(ci, c + Vector2(-3, 3), "$", 8, Color("8a5a00"))


static func aura_icon(ci: CanvasItem, c: Vector2, t: float) -> void:
	var flick := sin(t * 9.0) * 1.0
	var pts := PackedVector2Array([c + Vector2(0, -7 - flick), c + Vector2(4, -1), c + Vector2(3, 4), c + Vector2(-3, 4), c + Vector2(-4, -1)])
	ci.draw_colored_polygon(pts, Color("b14aed"))
	var pts2 := PackedVector2Array([c + Vector2(0, -3 - flick * 0.5), c + Vector2(2, 1), c + Vector2(1, 4), c + Vector2(-1, 4), c + Vector2(-2, 1)])
	ci.draw_colored_polygon(pts2, Color("ffd6ff"))


## Plastic plate wrapped in a bag (very chilango), holding the current order.
static func plate(ci: CanvasItem, c: Vector2, p: Dictionary, s := 1.0) -> void:
	ci.draw_circle(c + Vector2(0, 1), 11 * s, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, 11 * s, Color("8fcf9c"))
	ci.draw_circle(c, 9 * s, Color("a9dcb3"))
	var tacos: Array = p.get("tacos", [])
	var n := tacos.size()
	for i in n:
		var off := Vector2((i - (n - 1) / 2.0) * 7.0 * s, 0)
		var t: Dictionary = tacos[i]
		taco_open(ci, c + off, t.get("filling", "pastor"), {
			"verdura": p.get("verdura", false), "salsa": p.get("salsa", ""), "pina": p.get("pina", false),
			"quality": t.get("quality", 1.0)}, 0.62 * s)
	r(ci, c.x - 7 * s, c.y - 8 * s, 4 * s, 1 * s, Color(1, 1, 1, 0.45))


# ---------------------------------------------------------------- people

static func random_look(base: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	look["skin"] = Color(SKINS[rng.randi() % SKINS.size()])
	look["hair"] = Color(HAIRS[rng.randi() % HAIRS.size()])
	var shirt := Color(base.get("shirt", "#888888"))
	look["shirt"] = shirt.lightened(rng.randf_range(-0.08, 0.08))
	look["pants"] = Color(base.get("pants", "#333344"))
	look["acc"] = base.get("acc", "")
	look["acc_color"] = Color(base.get("acc_color", "#cc3333"))
	look["hair_long"] = base.get("hair_long", rng.randf() < 0.3)
	return look


## Generic pedestrian/customer. Feet at f, about 12x28 px.
static func person(ci: CanvasItem, f: Vector2, look: Dictionary, t: float, walking: bool, mood := 0, facing := 1) -> void:
	var x := f.x
	var y := f.y
	var skin: Color = look.get("skin", Color("c68642"))
	var hair: Color = look.get("hair", Color("1b1b1b"))
	var shirt: Color = look.get("shirt", Color("888888"))
	var pants: Color = look.get("pants", Color("333344"))
	var acc: String = look.get("acc", "")
	var accc: Color = look.get("acc_color", Color.RED)
	var bob := 0.0
	var l1 := 0.0
	var l2 := 0.0
	if walking:
		var sw := sin(t * 12.0)
		l1 = maxf(0.0, sw) * 2.0
		l2 = maxf(0.0, -sw) * 2.0
		bob = absf(sw) * 0.8
	r(ci, x - 6, y - 1, 12, 3, Color(0, 0, 0, 0.25))
	var by := y - bob
	if acc == "backpack":
		r(ci, x - facing * 6 - 3, by - 19, 6, 9, accc)
		r(ci, x - facing * 6 - 3, by - 15, 6, 1, accc.darkened(0.3))
	if acc == "helmet":
		r(ci, x - facing * 7 - 4, by - 22, 9, 10, accc.darkened(0.05))
		r(ci, x - facing * 7 - 4, by - 22, 9, 2, accc.lightened(0.2))
	r(ci, x - 4, y - 9, 3, 8 - l1, pants)
	r(ci, x + 1, y - 9, 3, 8 - l2, pants)
	r(ci, x - 5, y - 2 - l1, 4, 2, Color("2a211c"))
	r(ci, x + 1, y - 2 - l2, 4, 2, Color("2a211c"))
	r(ci, x - 5, by - 19, 10, 11, shirt)
	r(ci, x - 5, by - 9, 10, 1, shirt.darkened(0.3))
	r(ci, x - 7, by - 18, 2, 8, shirt.darkened(0.12))
	r(ci, x + 5, by - 18, 2, 8, shirt.darkened(0.12))
	r(ci, x - 7, by - 10, 2, 2, skin)
	r(ci, x + 5, by - 10, 2, 2, skin)
	r(ci, x - 1, by - 20, 3, 2, skin.darkened(0.12))
	r(ci, x - 4, by - 27, 8, 8, skin)
	r(ci, x - 4, by - 28, 8, 3, hair)
	if facing > 0:
		r(ci, x - 4, by - 26, 2, 3, hair)
	else:
		r(ci, x + 2, by - 26, 2, 3, hair)
	if look.get("hair_long", false) and acc != "cap" and acc != "helmet":
		r(ci, x - 5, by - 27, 2, 9, hair)
		r(ci, x + 3, by - 27, 2, 9, hair)
	var ex := x + facing
	var eye := Color("1a1210")
	r(ci, ex - 2, by - 24, 1, 1, eye)
	r(ci, ex + 1, by - 24, 1, 1, eye)
	if mood > 0:
		r(ci, ex - 1, by - 21, 3, 1, Color("7a2a1a"))
		r(ci, ex - 2, by - 22, 1, 1, Color("7a2a1a"))
		r(ci, ex + 2, by - 22, 1, 1, Color("7a2a1a"))
	elif mood < 0:
		r(ci, x - 4, by - 27, 8, 8, Color(1, 0.1, 0.05, 0.28))
		r(ci, ex - 3, by - 26, 2, 1, eye)
		r(ci, ex + 1, by - 26, 2, 1, eye)
		r(ci, ex - 1, by - 21, 3, 1, Color("5a1a10"))
	else:
		r(ci, ex - 1, by - 21, 2, 1, Color("6a3a2a"))
	match acc:
		"tie":
			r(ci, x - 1, by - 19, 2, 7, accc)
			r(ci, x + 2, by - 17, 2, 3, Color("ffffff"))
		"cap":
			r(ci, x - 5, by - 30, 10, 3, accc)
			r(ci, x + (2 if facing > 0 else -7), by - 28, 5, 1, accc.darkened(0.25))
		"helmet":
			r(ci, x - 5, by - 31, 10, 5, accc)
			r(ci, ex - 3, by - 26, 6, 1, Color("222222"))
		"mustache":
			r(ci, ex - 2, by - 22, 5, 1, accc)
		"purse":
			r(ci, x + facing * 7 - 2, by - 12, 5, 4, accc)
			ci.draw_line(Vector2(x + facing * 4, by - 18), Vector2(x + facing * 7, by - 12), accc.darkened(0.3), 1.0)
		"glasses":
			frame(ci, Rect2(ex - 3, by - 25, 3, 2), accc)
			frame(ci, Rect2(ex + 0.5, by - 25, 3, 2), accc)
			r(ci, x + facing * 6, by - 13, 3, 4, Color("f4f4f4"))


## The player taquero: white shirt, apron, red cap, mustache.
static func taquero(ci: CanvasItem, f: Vector2, t: float, walking: bool, facing := 1, action := "", action_t := 0.0, stunned := false) -> void:
	var look := {"skin": Color("a86b3c"), "hair": Color("1b1b1b"), "shirt": Color("f4f1e8"), "pants": Color("2d3047"), "acc": "", "acc_color": Color.RED}
	person(ci, f, look, t, walking, 1 if action == "" else 0, facing)
	var x := f.x
	var by := f.y
	if walking:
		by -= absf(sin(t * 12.0)) * 0.8
	r(ci, x - 4, by - 16, 8, 8, Color("e8e2cf"))
	r(ci, x - 2, by - 13, 2, 2, Color(0.77, 0.28, 0.11, 0.6))
	r(ci, x + 1, by - 11, 1, 1, Color(0.4, 0.6, 0.2, 0.6))
	r(ci, x - 5, by - 31, 10, 4, Color("c1121f"))
	r(ci, x + (2 if facing > 0 else -7), by - 28, 5, 1, Color("8a0c16"))
	r(ci, x + facing - 2, by - 22, 5, 1, Color("1b1b1b"))
	var hand := Vector2(x + facing * 7, by - 12)
	match action:
		"chop":
			var up := absf(sin(action_t * 28.0)) * 5.0
			r(ci, hand.x - 1, hand.y - 4 - up, 2, 6, Color("f4f1e8"))
			r(ci, hand.x - 3, hand.y - 8 - up, 6, 2, Color("d7dde2"))
		"stir":
			var sw := sin(action_t * 14.0) * 4.0
			ci.draw_line(Vector2(x, by - 18), Vector2(x - facing * 10 + sw, by - 2), Color("8b5a2b"), 2.0)
		"throw":
			r(ci, x + facing * 5, by - 20, 6, 2, Color("f4f1e8"))
		"swing":
			var a := action_t * 18.0
			ci.draw_arc(Vector2(x, by - 16), 12.0, -1.2 + a * 0.2, 0.8 + a * 0.2, 6, Color("e63946"), 3.0)
		"slice":
			r(ci, hand.x - 3, hand.y - 6, 7, 2, Color("d7dde2"))
	if stunned:
		for i in 3:
			var ang := t * 6.0 + i * TAU / 3.0
			r(ci, x + cos(ang) * 7 - 1, by - 34 + sin(ang) * 2, 2, 2, C_AMARILLO)


# ---------------------------------------------------------------- props

static func steel(ci: CanvasItem, rect: Rect2) -> void:
	r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, C_STEEL)
	r(ci, rect.position.x, rect.position.y, rect.size.x, 2, C_STEEL_HI)
	r(ci, rect.position.x, rect.end.y - 2, rect.size.x, 2, C_STEEL_LO)
	var xx := rect.position.x + 3.0
	var i := 0
	while xx < rect.end.x - 1:
		r(ci, xx, rect.position.y + 3, 1, rect.size.y - 6, Color(1, 1, 1, 0.12) if i % 2 == 0 else Color(0, 0, 0, 0.06))
		xx += 5.0
		i += 1


static func stool(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	r(ci, x - 7, y - 12, 14, 3, col)
	r(ci, x - 6, y - 9, 2, 9, col.darkened(0.15))
	r(ci, x + 4, y - 9, 2, 9, col.darkened(0.15))
	r(ci, x - 2, y - 9, 4, 6, col.darkened(0.3))
	r(ci, x - 6, y - 13, 12, 1, col.lightened(0.3))


static func wire(ci: CanvasItem, a: Vector2, b: Vector2, sag: float, col := Color("141414")) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(b, t)
		p.y += sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	ci.draw_polyline(pts, col, 1.0)


## Pink-and-white CDMX taxi, side view. x,y = bottom-left of wheels line.
static func taxi(ci: CanvasItem, x: float, y: float, flip := false, labels := true) -> void:
	r(ci, x, y - 12, 52, 8, Color("f3f3f3"))
	r(ci, x + 2, y - 10, 48, 3, C_ROSA)
	r(ci, x + 10, y - 20, 30, 8, C_ROSA)
	r(ci, x + 13, y - 18, 11, 6, Color("9fd3ff"))
	r(ci, x + 26, y - 18, 11, 6, Color("9fd3ff"))
	r(ci, x + 20, y - 23, 10, 3, Color("ffffff"))
	if labels:
		text(ci, Vector2(x + 20.5, y - 20.5), "TAXI", 4, Color("111111"))
	r(ci, x + (0 if not flip else 48), y - 11, 4, 2, Color("ffe08a"))
	ci.draw_circle(Vector2(x + 11, y - 3), 4.5, Color("1b1b1b"))
	ci.draw_circle(Vector2(x + 41, y - 3), 4.5, Color("1b1b1b"))
	ci.draw_circle(Vector2(x + 11, y - 3), 2, Color("9a9a9a"))
	ci.draw_circle(Vector2(x + 41, y - 3), 2, Color("9a9a9a"))


## Green-and-white microbús (pesero), side view.
static func pesero(ci: CanvasItem, x: float, y: float, labels := true) -> void:
	r(ci, x, y - 24, 70, 20, Color("f1f1e6"))
	r(ci, x, y - 12, 70, 6, Color("2f8f46"))
	for i in 5:
		r(ci, x + 6 + i * 12, y - 22, 9, 7, Color("8fc9e8"))
	r(ci, x + 2, y - 30, 26, 6, Color("1f1f1f"))
	if labels:
		text(ci, Vector2(x + 3, y - 25.5), "METRO", 5, Color("ffcc00"))
	ci.draw_circle(Vector2(x + 14, y - 3), 5, Color("1b1b1b"))
	ci.draw_circle(Vector2(x + 56, y - 3), 5, Color("1b1b1b"))


## Delivery motorcycle with a generic thermal box.
static func moto(ci: CanvasItem, x: float, y: float) -> void:
	ci.draw_circle(Vector2(x, y - 4), 4, Color("1b1b1b"))
	ci.draw_circle(Vector2(x + 18, y - 4), 4, Color("1b1b1b"))
	r(ci, x, y - 9, 18, 3, Color("b5121b"))
	r(ci, x + 3, y - 12, 8, 3, Color("222222"))
	r(ci, x - 2, y - 20, 11, 9, Color("f4a261"))
	r(ci, x - 2, y - 20, 11, 2, Color("ffd0a0"))
	ci.draw_line(Vector2(x + 16, y - 9), Vector2(x + 14, y - 16), Color("777777"), 1.5)


static func sign_board(ci: CanvasItem, rect: Rect2, label: String, bg: Color, fg: Color, size := 14, shadow := Color("1d1410")) -> void:
	r(ci, rect.position.x - 2, rect.position.y - 2, rect.size.x + 4, rect.size.y + 4, shadow)
	r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, bg)
	var f := display_font()
	var ty := rect.position.y + rect.size.y * 0.5 + size * 0.36
	text(ci, Vector2(rect.position.x + 1, ty + 1), label, size, shadow, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 0, Color.BLACK, f)
	text(ci, Vector2(rect.position.x, ty), label, size, fg, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 0, Color.BLACK, f)


static func patience_bar(ci: CanvasItem, x: float, y: float, w: float, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var col := Color("3fbf5a")
	if ratio < 0.33:
		col = Color("e63946")
	elif ratio < 0.6:
		col = Color("f4c430")
	r(ci, x, y, w, 3, Color(0, 0, 0, 0.6))
	r(ci, x + 0.5, y + 0.5, (w - 1) * ratio, 2, col)


## Rounded speech bubble with a little tail; returns nothing, draws text inside.
static func speech(ci: CanvasItem, anchor: Vector2, s: String, width := 96.0, size := 7, tail_up := true) -> void:
	var f := ThemeDB.fallback_font
	s = tl(s)
	var sz := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, width, size)
	var w := minf(width, sz.x) + 6
	var h := sz.y + 3
	var top := anchor.y + 4 if tail_up else anchor.y - h - 4
	var rect := Rect2(anchor.x - w / 2.0, top, w, h)
	r(ci, rect.position.x - 1, rect.position.y - 1, rect.size.x + 2, rect.size.y + 2, Color("1d1410"))
	r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("fffaf0"))
	var tail := PackedVector2Array()
	if tail_up:
		tail = PackedVector2Array([anchor + Vector2(-3, 4), anchor + Vector2(3, 4), anchor])
	else:
		tail = PackedVector2Array([anchor + Vector2(-3, -4), anchor + Vector2(3, -4), anchor])
	ci.draw_colored_polygon(tail, Color("fffaf0"))
	ci.draw_multiline_string(f, Vector2(rect.position.x + 3, rect.position.y + size + 0.5), s, HORIZONTAL_ALIGNMENT_CENTER, w - 6, size, -1, Color("2b1a12"))
