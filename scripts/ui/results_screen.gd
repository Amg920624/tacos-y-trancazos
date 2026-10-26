extends Control
## End-of-shift summary: sales, costs, profit, AURA, goal check and highlights.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Pix = preload("res://scripts/art/pix.gd")

var s: Dictionary = {}
var art: Node2D
var _t := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	size = Vector2(640, 360)
	s = GameManager.last_shift
	var bg := ColorRect.new()
	bg.color = Color("2b1a12")
	bg.size = size
	add_child(bg)
	art = Node2D.new()
	art.draw.connect(_draw_art)
	add_child(art)
	var m := GameManager.mode_data()
	var title := UiTheme.title_label(tr("CIERRE DEL %s") % str(s.get("day", "")).to_upper(), 24)
	title.position = Vector2(0, 8)
	title.size = Vector2(640, 30)
	add_child(title)
	var sub := UiTheme.label(tr("%s · Col. %s") % [m.get("stand_name", ""), m.get("neighborhood", "")], 9, Color("ff9ccc"))
	sub.position = Vector2(0, 38)
	sub.size = Vector2(640, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var left := VBoxContainer.new()
	left.position = Vector2(40, 64)
	left.size = Vector2(260, 180)
	left.add_theme_constant_override("separation", 2)
	add_child(left)
	_row(left, "Ventas del día", Economy.money(int(s.get("revenue", 0))), Color("8ef58e"))
	_row(left, "Tacos vendidos", str(s.get("tacos", 0)))
	_row(left, "Clientes atendidos", str(s.get("served", 0)))
	_row(left, "Pedidos perfectos", str(s.get("perfect", 0)), Color("ffcc00"))
	_row(left, "Clientes enojados", str(s.get("angry", 0)), Color("ff8a8a"))
	_row(left, "Pedidos equivocados", str(s.get("wrong", 0)), Color("ff8a8a"))
	if int(s.get("best_combo", 0)) > 1:
		_row(left, "Mejor combo", tr("x%d") % int(s.get("best_combo", 0)), Color("e4a3ff"))
	if int(s.get("critic_stars", -1)) >= 0:
		_row(left, "Guía Comal de Oro", tr("%d de 3 comales") % int(s.get("critic_stars", 0)), Color("ffcc00"))
	var right := VBoxContainer.new()
	right.position = Vector2(340, 64)
	right.size = Vector2(260, 180)
	right.add_theme_constant_override("separation", 2)
	add_child(right)
	var items: Dictionary = s.get("cost_items", {})
	var labels := {"ingredientes": "Ingredientes", "multas": "Multas", "gastos_fijos": str(s.get("daily_cost_label", "Gastos fijos"))}
	for k in items.keys():
		if int(items[k]) == 0:
			continue
		_row(right, "– " + tr(labels.get(k, str(k).capitalize())), Economy.money(-int(items[k])), Color("ff8a8a"))
	_row(right, "Ganancia del día", Economy.money(int(s.get("profit", 0))), Color("8ef58e") if int(s.get("profit", 0)) >= 0 else Color("ff6b6b"))
	_row(right, "AURA del turno", "%+d" % int(s.get("aura_delta", 0)), Color("e4a3ff"))
	_row(right, "AURA total", tr("%d · %s") % [Aura.aura, Aura.title()], Color("e4a3ff"))
	_row(right, "Caja", Economy.money(Economy.cash), Color("8ef58e") if Economy.cash >= 0 else Color("ff6b6b"))
	var met: bool = s.get("met", false)
	var goal := UiTheme.title_label((tr("¡META CUMPLIDA! ") if met else tr("META NO CUMPLIDA ")) + tr("%s / %s") % [Economy.money(int(s.get("revenue", 0))), Economy.money(int(s.get("target", 0)))], 16, Color("8ef58e") if met else Color("ff6b6b"))
	goal.position = Vector2(0, 236)
	goal.size = Vector2(640, 22)
	add_child(goal)
	var hl: Array = s.get("highlights", [])
	if hl.size() > 0:
		var h := UiTheme.label(" · ".join(hl), 8, Color("cdbfa8"))
		h.position = Vector2(0, 262)
		h.size = Vector2(640, 12)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(h)
	var label := "Continuar a la tiendita ▶"
	if GameManager.run_result == "win":
		label = "¡Ver el final! ▶"
	elif GameManager.run_result == "lose":
		label = "Ver qué pasó ▶"
	var btn := UiTheme.button(label, func(): GameManager.after_results(), 200)
	btn.position = Vector2(220, 300)
	add_child(btn)
	btn.grab_focus()
	AudioManager.play("shift_end")
	if met:
		AudioManager.play("cash", -2.0)


func _row(box: VBoxContainer, name: String, value: String, col := Color("fff3d6")) -> void:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(260, 14)
	var a := UiTheme.label(name, 9, Color("cdbfa8"))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := UiTheme.label(value, 10, col)
	h.add_child(b)
	box.add_child(h)


func _process(delta: float) -> void:
	_t += delta
	art.queue_redraw()


func _draw_art() -> void:
	for i in 16:
		var col: Color = [Pix.C_ROSA, Pix.C_AMARILLO, Pix.C_VERDE, Pix.C_NARANJA][i % 4]
		var y := 52 + sin(_t * 2.0 + i) * 1.5
		Pix.r(art, 20 + i * 38, y, 26, 6, col)
	for i in 5:
		var x := 60 + i * 130
		Pix.taco_open(art, Vector2(x, 286 + sin(_t * 3.0 + i) * 2.0), ["pastor", "maciza", "papa", "surtida", "pastor"][i], {"verdura": true, "salsa": "verde" if i % 2 == 0 else "roja", "pina": i % 2 == 0}, 1.3)
