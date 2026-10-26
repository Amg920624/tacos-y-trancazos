extends Node2D
## Floating text that rises and fades ("+25 AURA — ¡QUÉ CHULADA!", "+$48").

const Pix = preload("res://scripts/art/pix.gd")

var label := ""
var color := Color.WHITE
var size := 9
var life := 1.4
var t := 0.0
var rise := 22.0


static func spawn(parent: Node, pos: Vector2, p_text: String, p_color := Color.WHITE, p_size := 9, p_life := 1.4) -> Node2D:
	var p = load("res://scripts/ui/popup_text.gd").new()
	p.label = p_text
	p.color = p_color
	p.size = p_size
	p.life = p_life
	p.position = pos
	p.z_index = 50
	parent.add_child(p)
	return p


func _process(delta: float) -> void:
	t += delta
	position.y -= rise * delta * (1.0 - t / life)
	modulate.a = clampf(1.6 * (1.0 - t / life), 0.0, 1.0)
	if t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var w := Pix.text_width(label, size) + 4
	var pop := 1.0 + maxf(0.0, 0.25 - t) * 1.2
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
	Pix.text(self, Vector2(-w / 2.0, 0), label, size, color, HORIZONTAL_ALIGNMENT_CENTER, w, 3, Color("1d1410"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
