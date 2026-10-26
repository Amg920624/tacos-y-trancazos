extends Control
## Main menu: new game, continue, achievements, sound toggle, quit.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const MenuBackdrop = preload("res://scripts/art/menu_backdrop.gd")

var continue_btn: Button
var sound_btn: Button
var logros_panel: PanelContainer
var main_box: VBoxContainer
var _t := 0.0
var title: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	size = Vector2(640, 360)
	var bg := MenuBackdrop.new()
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.0, 0.35)
	shade.size = Vector2(640, 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	title = UiTheme.title_label("TACOS & TRANCAZOS", 40, Color("ffcc00"))
	title.position = Vector2(0, 150)
	title.size = Vector2(640, 50)
	title.pivot_offset = Vector2(320, 25)
	add_child(title)
	var tag := UiTheme.title_label("De la banqueta a la gloria", 14, Color("ff4fa8"))
	tag.position = Vector2(0, 196)
	tag.size = Vector2(640, 20)
	add_child(tag)
	main_box = VBoxContainer.new()
	main_box.position = Vector2(240, 222)
	main_box.size = Vector2(160, 120)
	main_box.add_theme_constant_override("separation", 4)
	add_child(main_box)
	var new_btn := UiTheme.button("Nuevo juego", _on_new)
	main_box.add_child(new_btn)
	continue_btn = UiTheme.button("Continuar partida", _on_continue)
	main_box.add_child(continue_btn)
	main_box.add_child(UiTheme.button("Logros", _on_logros))
	sound_btn = UiTheme.button("", _on_sound)
	main_box.add_child(sound_btn)
	main_box.add_child(UiTheme.button("Salir", _on_quit))
	var foot := UiTheme.label("WASD/flechas + E · M silencia · Hecho en un hackatón de 24 horas", 7, Color("cdbfa8"))
	foot.position = Vector2(6, 348)
	add_child(foot)
	var lang_btn := UiTheme.button("English" if GameManager.language == "es" else "Español", _on_language, 96)
	lang_btn.position = Vector2(536, 6)
	lang_btn.tooltip_text = "Language / Idioma"
	add_child(lang_btn)
	_build_logros()
	var saved := SaveManager.load_data()
	if not saved.is_empty():
		for a in saved["game"].get("achievements", []):
			if not (a in GameManager.achievements) and GameManager.ACHIEVEMENTS.has(a):
				GameManager.achievements.append(a)
	continue_btn.disabled = not SaveManager.has_continuable_run()
	_refresh()
	new_btn.grab_focus()
	AudioManager.play_music("night")


func _process(delta: float) -> void:
	_t += delta
	title.scale = Vector2.ONE * (1.0 + sin(_t * 2.2) * 0.025)
	title.rotation = sin(_t * 1.3) * 0.015


func _refresh() -> void:
	sound_btn.text = tr("Sonido: %s") % (tr("NO") if AudioManager.muted else tr("SÍ"))


func _on_language() -> void:
	AudioManager.play("ui_ok")
	GameManager.toggle_language()
	get_tree().reload_current_scene()


func _on_new() -> void:
	AudioManager.play("ui_ok")
	GameManager.goto("select")


func _on_continue() -> void:
	AudioManager.play("ui_ok")
	if not GameManager.continue_run():
		continue_btn.disabled = true
		GameManager.toast("No hay partida para continuar", Color("ffb3b3"))


func _on_sound() -> void:
	AudioManager.toggle_mute()
	_refresh()


func _on_quit() -> void:
	get_tree().quit()


func _build_logros() -> void:
	logros_panel = PanelContainer.new()
	logros_panel.position = Vector2(150, 40)
	logros_panel.custom_minimum_size = Vector2(340, 0)
	logros_panel.visible = false
	add_child(logros_panel)


func _on_logros() -> void:
	for ch in logros_panel.get_children():
		ch.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	logros_panel.add_child(box)
	box.add_child(UiTheme.title_label("LOGROS", 18))
	for id in GameManager.ACHIEVEMENTS.keys():
		var a: Dictionary = GameManager.ACHIEVEMENTS[id]
		var got: bool = id in GameManager.achievements
		var l := UiTheme.label(("★ " if got else "· ") + tr(a["title"]) + " — " + tr(a["desc"]), 8, Color("ffcc00") if got else Color("9c8f84"))
		box.add_child(l)
	var close := UiTheme.button("Cerrar", func():
		logros_panel.visible = false
		main_box.get_child(2).grab_focus())
	box.add_child(close)
	logros_panel.visible = true
	close.grab_focus()
