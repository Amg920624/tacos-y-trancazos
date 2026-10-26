extends CanvasLayer
## Short instructional overlay shown before each shift. Pauses the game until E / ENTER.

signal closed

const Pix = preload("res://scripts/art/pix.gd")

var title := ""
var lines: Array = []
var footer := ""
var ctl: Control
var _t := 0.0
var _armed := false


func setup(p_title: String, p_lines: Array, p_footer: String) -> void:
	title = p_title
	lines = p_lines
	footer = p_footer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	ctl = Control.new()
	ctl.size = Vector2(640, 360)
	ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ctl)
	ctl.draw.connect(_on_draw)
	get_tree().paused = true


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.35:
		_armed = true
	ctl.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	AudioManager.play("ui_ok")
	closed.emit()
	queue_free()


func _on_draw() -> void:
	var ci := ctl
	Pix.r(ci, 0, 0, 640, 360, Color(0, 0, 0, 0.55))
	var h := 70.0 + lines.size() * 14.0
	var rect := Rect2(90, 180 - h / 2.0, 460, h)
	Pix.r(ci, rect.position.x - 3, rect.position.y - 3, rect.size.x + 6, rect.size.y + 6, Color("1d1410"))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, rect.size.y, Color("3b1f14"))
	Pix.r(ci, rect.position.x, rect.position.y, rect.size.x, 24, Color("e4007c"))
	for i in 12:
		var col: Color = [Pix.C_AMARILLO, Pix.C_VERDE, Pix.C_NARANJA, Color("1d9bf0")][i % 4]
		Pix.r(ci, rect.position.x + 8 + i * 38, rect.position.y + 24, 22, 3, col)
	Pix.text(ci, Vector2(rect.position.x, rect.position.y + 19), title, 16, Color("fff3d6"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 3, Color("1d1410"), Pix.display_font())
	var y := rect.position.y + 44
	for l in lines:
		Pix.text(ci, Vector2(rect.position.x + 16, y), str(l), 9, Color("fff3d6"))
		y += 14
	var blink := 0.6 + 0.4 * sin(_t * 5.0)
	Pix.text(ci, Vector2(rect.position.x, rect.end.y - 10), footer, 10, Color(1, 0.8, 0, blink), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 2, Color.BLACK)
