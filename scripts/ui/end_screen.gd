extends Control
## Victory / defeat screen with run summary and restart options.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Pix = preload("res://scripts/art/pix.gd")

var win := false
var art: Node2D
var _t := 0.0
var confetti: Array = []


func _ready() -> void:
	theme = UiTheme.get_theme()
	size = Vector2(640, 360)
	win = GameManager.run_result == "win"
	var bg := ColorRect.new()
	bg.color = Color("1a2e1a") if win else Color("2e1414")
	bg.size = size
	add_child(bg)
	art = Node2D.new()
	art.draw.connect(_draw_art)
	add_child(art)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 60:
		confetti.append(Vector3(rng.randf_range(0, 640), rng.randf_range(-360, 0), rng.randf_range(30, 80)))
	var headline := "¡TAQUERO LEGENDARIO!" if win and Aura.level() >= 3 else ("¡LO LOGRASTE, TAQUERO!" if win else "¡SE TE QUEMARON LAS TORTILLAS!")
	var t := UiTheme.title_label(headline, 30, Color("ffcc00") if win else Color("ff6b6b"))
	t.position = Vector2(0, 30)
	t.size = Vector2(640, 40)
	add_child(t)
	var msg := "Sobreviviste el viernes, el sábado y el domingo. ¡La colonia ya habla de ti!" if win else GameManager.lose_reason
	var m := UiTheme.label(msg, 10)
	m.position = Vector2(40, 78)
	m.size = Vector2(560, 30)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(m)
	var box := VBoxContainer.new()
	box.position = Vector2(170, 112)
	box.size = Vector2(300, 120)
	add_child(box)
	var mode_name: String = GameManager.mode_data().get("name", "")
	_line(box, tr("Negocio: %s") % mode_name)
	_line(box, tr("Turnos jugados: %d de %d") % [GameManager.shift_history.size(), GameManager.SHIFTS_PER_RUN])
	_line(box, tr("Ventas totales: %s") % Economy.money(GameManager.total_revenue()), Color("8ef58e"))
	_line(box, tr("Caja final: %s · Invertido en mejoras: %s") % [Economy.money(Economy.cash), Economy.money(Economy.total_invested)], Color("8ef58e"))
	_line(box, tr("AURA: %d · %s") % [Aura.aura, Aura.title()], Color("e4a3ff"))
	var got := []
	for a in GameManager.achievements:
		got.append(GameManager.ACHIEVEMENTS[a]["title"])
	_line(box, tr("Logros: ") + (", ".join(got) if got.size() > 0 else tr("ninguno... todavía")), Color("ffcc00"))
	var again := UiTheme.button(tr("Jugar otra vez (%s)") % mode_name, func(): GameManager.start_new_run(GameManager.mode), 220)
	again.position = Vector2(210, 250)
	add_child(again)
	var other := UiTheme.button("Elegir otra taquería", func(): GameManager.goto("select"), 220)
	other.position = Vector2(210, 274)
	add_child(other)
	var menu := UiTheme.button("Menú principal", func(): GameManager.goto("menu"), 220)
	menu.position = Vector2(210, 298)
	add_child(menu)
	again.grab_focus()
	AudioManager.play("achievement" if win else "fail")
	AudioManager.play_music("night" if win else "day")


func _line(box: VBoxContainer, text: String, col := Color("fff3d6")) -> void:
	var l := UiTheme.label(text, 9, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	box.add_child(l)


func _process(delta: float) -> void:
	_t += delta
	art.queue_redraw()


func _draw_art() -> void:
	if win:
		for i in confetti.size():
			var c: Vector3 = confetti[i]
			var y := fmod(c.y + _t * c.z + 360.0, 380.0) - 10.0
			var col: Color = [Pix.C_ROSA, Pix.C_AMARILLO, Pix.C_VERDE, Pix.C_NARANJA, Color("1d9bf0")][i % 5]
			Pix.r(art, c.x + sin(_t * 3.0 + i) * 6.0, y, 3, 2, col)
		Pix.taquero(art, Vector2(80, 330), _t, false, 1)
		Pix.taco_open(art, Vector2(100, 300 + sin(_t * 4.0) * 3.0), "pastor", {"verdura": true, "salsa": "verde", "pina": true}, 1.6)
	else:
		for i in 3:
			var x := 90 + i * 230
			Pix.taco_open(art, Vector2(x, 330), "maciza", {"quality": 0.2}, 1.5)
			for k in 3:
				var sy := fmod(_t * 12.0 + k * 9.0, 30.0)
				Pix.r(art, x - 6 + k * 5, 320 - sy, 4, 4, Color(0.3, 0.3, 0.3, 0.5 * (1.0 - sy / 30.0)))
