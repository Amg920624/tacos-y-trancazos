extends CanvasLayer
## Gameplay HUD: cash, AURA, day/shift, goal progress, timer, banners, context prompt and
## the critic review card. Mode-specific panels are drawn by the mode via draw_hud_extra(ci).

const Pix = preload("res://scripts/art/pix.gd")

var mode_ref = null
var banner_text := ""
var banner_color := Color("ffcc00")
var banner_t := 0.0
var prompt := ""
var review: Dictionary = {}
var review_t := 0.0
var flash_t := 0.0
var _t := 0.0
var ctl: Control


func _ready() -> void:
	layer = 10
	ctl = Control.new()
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.size = Vector2(640, 360)
	add_child(ctl)
	ctl.draw.connect(_on_draw)


func banner(text: String, color := Color("ffcc00"), duration := 3.0) -> void:
	banner_text = text
	banner_color = color
	banner_t = duration


func show_review(stars: int, quote: String, aura_delta: int) -> void:
	review = {"stars": stars, "quote": quote, "aura": aura_delta}
	review_t = 7.0


func _process(delta: float) -> void:
	_t += delta
	banner_t = maxf(0.0, banner_t - delta)
	review_t = maxf(0.0, review_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	ctl.queue_redraw()


func _on_draw() -> void:
	var ci := ctl
	_draw_top_bar(ci)
	if mode_ref != null and mode_ref.has_method("draw_hud_extra"):
		mode_ref.draw_hud_extra(ci)
	if prompt != "":
		var w := Pix.text_width(prompt, 9) + 16
		Pix.r(ci, 320 - w / 2.0, 343, w, 15, Color(0.06, 0.03, 0.02, 0.82))
		Pix.text(ci, Vector2(320 - w / 2.0, 354), prompt, 9, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, w)
	if banner_t > 0.0:
		var a := clampf(banner_t * 3.0, 0.0, 1.0)
		var bw := minf(600.0, Pix.text_width(banner_text, 11) + 24)
		var pulse := 1.0 + sin(_t * 10.0) * 0.04
		Pix.r(ci, 320 - bw / 2.0, 26, bw, 20, Color(0.08, 0.03, 0.02, 0.88 * a))
		Pix.r(ci, 320 - bw / 2.0, 26, bw, 2, Color(banner_color, a))
		Pix.r(ci, 320 - bw / 2.0, 44, bw, 2, Color(banner_color, a))
		ci.draw_set_transform(Vector2(320, 36), 0.0, Vector2(pulse, pulse))
		Pix.text(ci, Vector2(-bw / 2.0, 4), banner_text, 11, Color(banner_color, a), HORIZONTAL_ALIGNMENT_CENTER, bw, 2, Color(0, 0, 0, a))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if review_t > 0.0:
		_draw_review(ci)


func _draw_top_bar(ci: Control) -> void:
	Pix.r(ci, 0, 0, 640, 19, Color(0.06, 0.03, 0.02, 0.85))
	Pix.r(ci, 0, 19, 640, 1, Color("e4007c"))
	Pix.coin(ci, Vector2(9, 9.5))
	var cash_col := Color("8ef58e") if Economy.cash >= 0 else Color("ff6b6b")
	Pix.text(ci, Vector2(17, 14), Economy.money(Economy.cash), 11, cash_col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	Pix.aura_icon(ci, Vector2(86, 11), _t)
	Pix.text(ci, Vector2(93, 10), tr("AURA %d") % Aura.aura, 9, Color("e4a3ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
	Pix.text(ci, Vector2(93, 17.5), Aura.title(), 6, Color("cdbad6"))
	Pix.r(ci, 150, 6, 50, 4, Color(0, 0, 0, 0.6))
	Pix.r(ci, 150, 6, 50 * Aura.level_progress(), 4, Color("b14aed"))
	Pix.text(ci, Vector2(208, 13.5), tr("%s · Turno %d/%d") % [GameManager.day_name(), GameManager.shift_index + 1, GameManager.SHIFTS_PER_RUN], 9, Color("fff3d6"))
	var target := GameManager.shift_target()
	var prog := clampf(float(Economy.shift_revenue) / maxf(1.0, target), 0.0, 1.0)
	Pix.text(ci, Vector2(340, 10), "Meta del turno", 6, Color("ffcc00"))
	Pix.r(ci, 340, 12, 110, 5, Color(0, 0, 0, 0.6))
	Pix.r(ci, 340, 12, 110 * prog, 5, Color("3fbf5a") if prog >= 1.0 else Color("ff7a00"))
	Pix.text(ci, Vector2(455, 17), tr("%s / %s") % [Economy.money(Economy.shift_revenue), Economy.money(target)], 8, Color("fff3d6"))
	if mode_ref != null:
		var tl: float = mode_ref.get("time_left") if mode_ref.get("time_left") != null else 0.0
		var col := Color("fff3d6")
		if tl < 20.0 and int(_t * 4.0) % 2 == 0:
			col = Color("ff4d4d")
		Pix.text(ci, Vector2(588, 15), Pix.fmt_time(tl), 13, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color.BLACK)
		ci.draw_arc(Vector2(580, 10), 5, 0, TAU, 12, Color("fff3d6"), 1.0)
		ci.draw_line(Vector2(580, 10), Vector2(580, 6.5), Color("fff3d6"), 1.0)
		ci.draw_line(Vector2(580, 10), Vector2(582.5, 10), Color("fff3d6"), 1.0)


func _draw_review(ci: Control) -> void:
	var a := clampf(review_t * 2.0, 0.0, 1.0)
	var rect := Rect2(160, 70, 320, 92)
	Pix.r(ci, rect.position.x - 2, rect.position.y - 2, rect.size.x + 4, rect.size.y + 4, Color(0.1, 0.06, 0.02, a))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color(1.0, 0.95, 0.84, a))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, 16, Color(0.55, 0.36, 0.05, a))
	Pix.text(ci, Vector2(rect.position.x, rect.position.y + 12), DB.line("critic_reveal", "¡Era el crítico!"), 9, Color(1, 0.95, 0.7, a), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	var stars := int(review.get("stars", 0))
	for i in 3:
		var c := Vector2(rect.position.x + 130 + i * 30, rect.position.y + 32)
		ci.draw_circle(c, 9, Color(0.12, 0.1, 0.1, a))
		ci.draw_circle(c, 7, Color(1.0, 0.8, 0.2, a) if i < stars else Color(0.35, 0.33, 0.3, a))
		ci.draw_circle(c, 3, Color(0.12, 0.1, 0.1, a))
	Pix.text(ci, Vector2(rect.position.x, rect.position.y + 52), tr("Guía Comal de Oro: %d de 3 comales") % stars, 8, Color(0.35, 0.2, 0.05, a), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	Pix.text(ci, Vector2(rect.position.x + 6, rect.position.y + 68), "\"%s\"" % tr(review.get("quote", "")), 9, Color(0.15, 0.08, 0.04, a), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12)
	var ad := int(review.get("aura", 0))
	Pix.text(ci, Vector2(rect.position.x, rect.position.y + 84), tr("%s%d AURA") % ["+" if ad >= 0 else "", ad], 8, Color(0.5, 0.2, 0.7, a), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
