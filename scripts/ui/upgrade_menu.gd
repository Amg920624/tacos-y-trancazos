extends Control
## Upgrade shop between shifts. Every listed upgrade is data-driven and feeds a real gameplay stat.
## Purchases are blocked when cash or AURA are insufficient.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var rows: Array = []
var cash_l: Label
var info_l: Label
var next_btn: Button
var list: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	size = Vector2(640, 360)
	var bg := ColorRect.new()
	bg.color = Color("24160f")
	bg.size = size
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color("e4007c")
	stripe.size = Vector2(640, 3)
	stripe.position = Vector2(0, 40)
	add_child(stripe)
	var title := UiTheme.title_label("LA TIENDITA DE MEJORAS", 22)
	title.position = Vector2(0, 6)
	title.size = Vector2(640, 28)
	add_child(title)
	cash_l = UiTheme.label("", 10, Color("8ef58e"))
	cash_l.position = Vector2(16, 46)
	add_child(cash_l)
	info_l = UiTheme.label(tr("Siguiente: %s · Meta %s") % [GameManager.day_name(), Economy.money(GameManager.shift_target())], 9, Color("ffcc00"))
	info_l.position = Vector2(380, 46)
	info_l.size = Vector2(244, 12)
	info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(info_l)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 62)
	scroll.size = Vector2(616, 252)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(604, 0)
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for def in Upgrades.list_for_mode(GameManager.mode):
		_add_row(def)
	next_btn = UiTheme.button(tr("Abrir el puesto: %s ▶") % GameManager.day_name(), _on_next, 200)
	next_btn.position = Vector2(330, 326)
	add_child(next_btn)
	var save_btn := UiTheme.button("Guardar y salir al menú", _on_save_quit, 180)
	save_btn.position = Vector2(130, 326)
	add_child(save_btn)
	_refresh()
	next_btn.grab_focus()
	AudioManager.play_music("day")


func _add_row(def: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 28)
	list.add_child(panel)
	var h := HBoxContainer.new()
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name_l := UiTheme.label("", 10, Color("ffcc00"))
	v.add_child(name_l)
	var desc := UiTheme.label(def.get("description", ""), 8, Color("e8dcc8"))
	v.add_child(desc)
	var btn := UiTheme.button("", _buy.bind(def["id"]), 150)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btn)
	rows.append({"id": def["id"], "name": name_l, "btn": btn, "def": def})


func _refresh() -> void:
	cash_l.text = tr("Caja: %s   ·   AURA %d (%s)") % [Economy.money(Economy.cash), Aura.aura, Aura.title()]
	for r in rows:
		var id: String = r["id"]
		var lvl := Upgrades.level(id)
		var mx := Upgrades.max_level(id)
		var tag := ""
		var m = r["def"].get("mode", "all")
		if typeof(m) == TYPE_STRING and m == "all":
			tag = tr("  [para todos]")
		r["name"].text = tr("%s  (nivel %d/%d)%s") % [tr(r["def"].get("name", id)), lvl, mx, tag]
		var chk := Upgrades.can_buy(id, GameManager.mode)
		var btn: Button = r["btn"]
		if chk["ok"]:
			btn.text = tr("Comprar %s") % Economy.money(Upgrades.next_cost(id))
			btn.disabled = false
		else:
			var cost := Upgrades.next_cost(id)
			btn.text = chk["reason"] if cost < 0 else tr("%s (%s)") % [tr(chk["reason"]), Economy.money(cost)]
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
		if not btn.disabled:
			btn.focus_mode = Control.FOCUS_ALL


func _buy(id: String) -> void:
	if Upgrades.buy(id, GameManager.mode):
		AudioManager.play("cash")
		GameManager.toast(tr("¡Compraste %s!") % tr(Upgrades.get_def(id).get("name", id)), Color("8ef58e"))
		SaveManager.save_game()
	else:
		AudioManager.play("fail")
	_refresh()
	var f := get_viewport().gui_get_focus_owner()
	if f == null or (f is Button and (f as Button).disabled):
		next_btn.grab_focus()


func _on_next() -> void:
	AudioManager.play("ui_ok")
	GameManager.start_next_shift()


func _on_save_quit() -> void:
	SaveManager.save_game()
	GameManager.goto("menu")
