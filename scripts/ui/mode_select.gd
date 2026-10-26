extends Control
## Business selection: Tacos de Canasta, Carnitas, Tacos al Pastor, plus locked future taquerías.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Pix = preload("res://scripts/art/pix.gd")

const ORDER := ["canasta", "carnitas", "pastor"]

var cards: Array = []
var _t := 0.0
var preview: Node2D


func _ready() -> void:
	theme = UiTheme.get_theme()
	size = Vector2(640, 360)
	var bg := ColorRect.new()
	bg.color = Color("2b1a12")
	bg.size = size
	add_child(bg)
	var t := UiTheme.title_label("ELIGE TU TAQUERÍA", 24)
	t.position = Vector2(0, 6)
	t.size = Vector2(640, 30)
	add_child(t)
	var sub := UiTheme.label("Tres turnos: viernes, sábado y domingo. Llega a la meta de cada día para volverte leyenda.", 8, Color("cdbfa8"))
	sub.position = Vector2(0, 36)
	sub.size = Vector2(640, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	for i in ORDER.size():
		var id: String = ORDER[i]
		var m := DB.mode(id)
		var x := 18 + i * 206
		var b := Button.new()
		b.position = Vector2(x, 52)
		b.size = Vector2(194, 238)
		b.text = ""
		b.pressed.connect(_choose.bind(id))
		b.focus_entered.connect(func(): AudioManager.play("ui_move", -6.0))
		add_child(b)
		cards.append(b)
		var name_l := UiTheme.title_label(m.get("name", id).to_upper(), 15, Color("ffcc00"))
		name_l.position = Vector2(0, 98)
		name_l.size = Vector2(194, 20)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_l)
		var tag := UiTheme.label(tr("“%s”") % tr(m.get("tagline", "")), 8, Color("ff9ccc"))
		tag.position = Vector2(0, 118)
		tag.size = Vector2(194, 12)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		var desc := UiTheme.label(m.get("description", ""), 8)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(178, 0)
		desc.position = Vector2(8, 132)
		desc.size = Vector2(178, 70)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(desc)
		var hood := UiTheme.label(tr("Col. %s\nMeta del viernes: %s") % [m.get("neighborhood", ""), Economy.money(int(m.get("shift_targets", [0])[0]))], 7, Color("cdbfa8"))
		hood.custom_minimum_size = Vector2(194, 0)
		hood.position = Vector2(0, 206)
		hood.size = Vector2(194, 24)
		hood.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hood.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hood)
	preview = Node2D.new()
	preview.draw.connect(_draw_previews)
	add_child(preview)
	for i in cards.size():
		cards[i].focus_neighbor_left = cards[(i + cards.size() - 1) % cards.size()].get_path()
		cards[i].focus_neighbor_right = cards[(i + 1) % cards.size()].get_path()
	var soon := []
	for f in DB.future:
		soon.append(f.get("name", "?"))
	var future_l := UiTheme.label(tr("PRÓXIMAMENTE: ") +"  ·  ".join(soon), 8, Color("8a7a6e"))
	future_l.position = Vector2(0, 296)
	future_l.size = Vector2(640, 12)
	future_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(future_l)
	var back := UiTheme.button("Regresar", func(): GameManager.goto("menu"), 120)
	back.position = Vector2(260, 318)
	add_child(back)
	for c in cards:
		c.focus_neighbor_bottom = back.get_path()
	back.focus_neighbor_top = cards[0].get_path()
	cards[0].grab_focus()
	AudioManager.play_music("day")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		GameManager.goto("menu")


func _process(delta: float) -> void:
	_t += delta
	preview.queue_redraw()


func _choose(id: String) -> void:
	AudioManager.play("ui_ok")
	GameManager.start_new_run(id)


func _draw_previews() -> void:
	for i in ORDER.size():
		var cx := 18 + i * 206 + 97
		var top := 58.0
		Pix.r(preview, cx - 90, top, 180, 88, Color("1d4e89") if i != 2 else Color("0d1b2a"))
		Pix.r(preview, cx - 90, top + 64, 180, 24, Color("b9b4aa").darkened(0.4 if i == 2 else 0.0))
		match ORDER[i]:
			"canasta":
				_bike(preview, Vector2(cx + sin(_t * 2.0) * 20.0, top + 80))
				for k in 3:
					Pix.taco_canasta(preview, Vector2(cx - 60 + k * 18, top + 18 + sin(_t * 3.0 + k) * 2.0), ["papa", "frijol", "chicharron"][k], 1.0)
			"carnitas":
				var pts := PackedVector2Array([Vector2(cx - 40, top + 30), Vector2(cx + 40, top + 30), Vector2(cx + 30, top + 66), Vector2(cx - 30, top + 66)])
				preview.draw_colored_polygon(pts, Color("b87333"))
				Pix.r(preview, cx - 40, top + 29, 80, 3, Color("e2a066"))
				for k in 8:
					Pix.r(preview, cx - 32 + k * 8, top + 31 + (k % 2), 6, 3, Color("b9773c") if k % 2 == 0 else Color("94552b"))
				for k in 7:
					Pix.r(preview, cx - 26 + k * 8, top + 70 - absf(sin(_t * 16.0 + k)) * 6, 3, 6, Color("ff7a00"))
				Pix.taco_open(preview, Vector2(cx + 62, top + 20), "surtida", {"verdura": true, "salsa": "verde"}, 1.4)
			"pastor":
				Pix.r(preview, cx + 14, top + 22, 8, 42, Color("ff7a00").lerp(Color("ffcc00"), 0.5 + 0.5 * sin(_t * 7.0)))
				var tp := PackedVector2Array([Vector2(cx - 18, top + 24), Vector2(cx + 12, top + 24), Vector2(cx + 6, top + 62), Vector2(cx - 12, top + 62)])
				preview.draw_colored_polygon(tp, Color("c4471d"))
				for k in 6:
					var yy := top + 26 + fmod(k * 6.0 + _t * 14.0, 36.0)
					Pix.r(preview, cx - 16, yy, 26, 1, Color("8f2d12"))
				Pix.r(preview, cx - 12, top + 14, 20, 10, Pix.C_PINA)
				Pix.r(preview, cx - 7, top + 8, 3, 6, Pix.C_CILANTRO)
				Pix.taco_open(preview, Vector2(cx - 58, top + 22), "pastor", {"verdura": true, "salsa": "roja", "pina": true}, 1.4)
				Pix.taco_open(preview, Vector2(cx + 60, top + 26), "pastor", {"verdura": true, "salsa": "verde", "pina": true}, 1.2)


func _bike(ci: CanvasItem, f: Vector2) -> void:
	ci.draw_arc(f + Vector2(-14, -6), 7, 0, TAU, 14, Color("1b1b1b"), 2.0)
	ci.draw_arc(f + Vector2(14, -6), 7, 0, TAU, 14, Color("1b1b1b"), 2.0)
	ci.draw_line(f + Vector2(-14, -6), f + Vector2(0, -14), Color("c1121f"), 2.0)
	ci.draw_line(f + Vector2(0, -14), f + Vector2(14, -6), Color("c1121f"), 2.0)
	ci.draw_line(f + Vector2(0, -14), f + Vector2(-2, -20), Color("c1121f"), 2.0)
	Pix.r(ci, f.x - 26, f.y - 24, 16, 12, Color("a8763e"))
	Pix.r(ci, f.x - 27, f.y - 27, 18, 4, Color("1d6fd6"))
	Pix.taquero(ci, f + Vector2(-2, -12), _t, false, 1)
