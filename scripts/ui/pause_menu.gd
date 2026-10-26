extends CanvasLayer
## ESC pause menu: continue, sound toggle, restart shift, back to main menu.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var root: Control
var sound_btn: Button
var continue_btn: Button
var is_open := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiTheme.get_theme()
	root.size = Vector2(640, 360)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(640, 360)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(220, 80)
	panel.custom_minimum_size = Vector2(200, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.title_label("PAUSA", 22))
	continue_btn = UiTheme.button("Continuar", close)
	box.add_child(continue_btn)
	sound_btn = UiTheme.button("", _toggle_sound)
	box.add_child(sound_btn)
	box.add_child(UiTheme.button("Reiniciar turno", _restart))
	box.add_child(UiTheme.button("Salir al menú principal", _quit_menu))
	var hint := UiTheme.label("M: silenciar en cualquier momento", 7, Color("cdbfa8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func open() -> void:
	if is_open:
		return
	is_open = true
	root.visible = true
	_refresh()
	get_tree().paused = true
	continue_btn.grab_focus()


func close() -> void:
	is_open = false
	root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	sound_btn.text = tr("Sonido: %s") % (tr("NO") if AudioManager.muted else tr("SÍ"))


func _toggle_sound() -> void:
	AudioManager.toggle_mute()
	_refresh()


func _restart() -> void:
	close()
	GameManager.restart_shift()


func _quit_menu() -> void:
	close()
	SaveManager.save_game()
	GameManager.goto("menu")
