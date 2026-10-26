extends Node2D
## Comedic, fictional municipal inspection for the canasta mode.
## Selling in the restricted Metro zone without a permit raises "sospecha"; when it fills, an
## exaggerated inspector walks over. Options: leave the zone in time, pay the fine, or
## (if caught) try a cartoon escape challenge. Not a simulation of real enforcement.

const Pix = preload("res://scripts/art/pix.gd")

enum S { NONE, WARNING, CAUGHT, CHASE, LEAVING }

const FINE := 80
const WARN_TIME := 6.0
const CHASE_TIME := 8.0

var state: int = S.NONE
var mode = null
var t := 0.0
var anim_t := 0.0
var speed := 72.0
var facing := 1
var speech := ""
var speech_t := 0.0
var home := Vector2(640, 128)
var look := {"skin": Color("c68642"), "hair": Color("2e1d12"), "shirt": Color("c8b48a"), "pants": Color("4a4a3a"), "acc": "cap", "acc_color": Color("2b3a55")}


func _ready() -> void:
	visible = false


func is_busy() -> bool:
	return state != S.NONE


func is_blocking() -> bool:
	return state == S.CAUGHT


func say(text: String, dur := 2.2) -> void:
	speech = text
	speech_t = dur


func start() -> void:
	state = S.WARNING
	t = WARN_TIME
	position = home
	visible = true
	speed = 72.0
	say(DB.line("inspector_warning", "¡Alto ahí!"))
	AudioManager.play("whistle")


func step(delta: float) -> void:
	anim_t += delta
	speech_t = maxf(0.0, speech_t - delta)
	if state == S.NONE:
		return
	var bike: Node2D = mode.bike
	match state:
		S.WARNING:
			t -= delta
			_walk_to(bike.position, delta)
			if not mode.bike_in_metro():
				_success("¡Te moviste a tiempo!")
			elif position.distance_to(bike.position) < 16.0:
				state = S.CAUGHT
				say(DB.line("inspector_caught", "Va a tener que pagar su multa."))
				AudioManager.play("whistle")
		S.CHASE:
			t -= delta
			speed = 128.0
			_walk_to(bike.position, delta)
			var far := position.distance_to(bike.position) > 120.0
			if position.distance_to(bike.position) < 14.0:
				_pay(true)
			elif (not mode.bike_in_metro() and far) or t <= 0.0:
				if mode.bike_in_metro():
					_pay(true)
				else:
					_success("¡Ni te vio! " + DB.line("inspector_escape", ""))
		S.LEAVING:
			if _walk_to(home, delta, 0.8):
				state = S.NONE
				visible = false
	queue_redraw()


## Player choice while CAUGHT: "pay" or "run".
func choose(option: String) -> void:
	if state != S.CAUGHT:
		return
	if option == "pay":
		_pay(false)
	else:
		state = S.CHASE
		t = CHASE_TIME
		say("¡Párele, joven!", 1.5)
		AudioManager.play("whistle")
		mode.hud.banner("¡ÉCHATE LA CARRERA! Sal de la zona del Metro (ESPACIO = pedalazo)", Color("ff7a00"), 3.0)


func _pay(after_chase: bool) -> void:
	var fine := int(FINE * (1.5 if after_chase else 1.0))
	Economy.charge(fine, "multas")
	mode.stats["fines"] = int(mode.stats.get("fines", 0)) + fine
	mode.popup_at(mode.bike.position + Vector2(0, -40), tr("Multa: -%s") % Economy.money(fine), Color("ff6b6b"))
	AudioManager.play("fail")
	if after_chase:
		Aura.add(-10, "¡TE CACHARON!", mode.bike.position + Vector2(0, -52), true)
	EventManager.resolve("inspeccion", false, mode.bike.position + Vector2(0, -60), true)
	mode.suspicion = 0.0
	say("Aquí está su papelito.", 1.8)
	state = S.LEAVING


func _success(text: String) -> void:
	EventManager.resolve("inspeccion", true, mode.bike.position + Vector2(0, -60), true)
	mode.hud.banner(text, Color("8ef58e"), 2.0)
	mode.suspicion = 0.0
	state = S.LEAVING


## Called by the mode if the event times out unexpectedly.
func force_leave() -> void:
	if state != S.NONE:
		state = S.LEAVING


func _walk_to(p: Vector2, delta: float, mult := 1.0) -> bool:
	var d := p - position
	var dist := d.length()
	if dist < 2.0:
		return true
	if absf(d.x) > 0.5:
		facing = 1 if d.x > 0 else -1
	position += d / dist * minf(dist, speed * mult * delta)
	return false


func _draw() -> void:
	if state == S.NONE:
		return
	Pix.person(self, Vector2.ZERO, look, anim_t, state != S.CAUGHT, -1 if state == S.CHASE else 0, facing)
	Pix.r(self, -5, -18, 10, 1, Color("8a7a4a"))
	Pix.r(self, facing * 6, -16, 4, 6, Color("f4f4f4"))
	Pix.r(self, facing * 6, -16, 4, 1, Color("c1121f"))
	Pix.r(self, -1, -16, 2, 2, Color("ffcc00"))
	if state == S.WARNING or state == S.CHASE:
		if int(anim_t * 6.0) % 2 == 0:
			Pix.text(self, Vector2(-18, -34), "¡PRIIIT!", 7, Color("ffcc00"), HORIZONTAL_ALIGNMENT_CENTER, 36, 2, Color.BLACK)
	Pix.text(self, Vector2(-30, -44), "INSPECTOR", 6, Color("ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER, 60, 2, Color.BLACK)
	if speech_t > 0.0:
		Pix.speech(self, Vector2(0, 2), speech, 100.0, 7, true)
