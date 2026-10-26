extends RefCounted
## Builds the shared Theme for menus: dark brown panels, rosa mexicano / amarillo accents.

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 10
	t.set_color("font_color", "Label", Color("fff3d6"))
	t.set_color("font_outline_color", "Label", Color("1d1410"))
	t.set_constant("outline_size", "Label", 2)
	t.set_stylebox("normal", "Button", _box(Color("3b1f14"), Color("ffcc00"), 1))
	t.set_stylebox("hover", "Button", _box(Color("8c2f39"), Color("ffcc00"), 1))
	t.set_stylebox("focus", "Button", _box(Color("e4007c"), Color("ffffff"), 2))
	t.set_stylebox("pressed", "Button", _box(Color("ff7a00"), Color("ffffff"), 1))
	t.set_stylebox("disabled", "Button", _box(Color("2a221e"), Color("5a4a40"), 1))
	t.set_color("font_color", "Button", Color("fff3d6"))
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_focus_color", "Button", Color("ffffff"))
	t.set_color("font_pressed_color", "Button", Color("1d1410"))
	t.set_color("font_disabled_color", "Button", Color("7a6a60"))
	t.set_color("font_outline_color", "Button", Color("1d1410"))
	t.set_constant("outline_size", "Button", 2)
	t.set_font_size("font_size", "Button", 10)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.05, 0.035, 0.94), Color("ffcc00"), 1, 4))
	t.set_stylebox("panel", "Panel", _box(Color(0.1, 0.05, 0.035, 0.94), Color("ffcc00"), 1, 4))
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int, radius := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


static func title_label(text: String, size := 28, color := Color("ffcc00")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://scripts/art/pix.gd").display_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1d1410"))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func label(text: String, size := 10, color := Color("fff3d6")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w := 160.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 20)
	b.pressed.connect(cb)
	b.focus_entered.connect(func(): AudioManager.play("ui_move", -6.0))
	return b
