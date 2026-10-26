extends Node
## Autoload "Aura": arcade prestige. AURA levels raise demand and tips and unlock upgrades.
## Reputation (0-100) follows customer satisfaction and tweaks patience.

signal aura_changed(total: int, delta: int, message: String, world_pos: Vector2, has_pos: bool)
signal level_up(level: int, title: String)

const LEVELS := [
	{"min": 0, "title": "Taquero de Banqueta"},
	{"min": 150, "title": "Taquero de Barrio"},
	{"min": 400, "title": "Taquero Reconocido"},
	{"min": 750, "title": "Ídolo de la Colonia"},
	{"min": 1200, "title": "Taquero Legendario"},
]
const GOOD_SHOUTS := ["¡QUÉ CHULADA!", "¡SE MAMÓ!", "¡ESO, MI REY!", "¡DE CAMPEONATO!", "¡QUÉ BÁRBARO!", "¡NIVEL DIOS!", "¡AY, PAPÁ!"]
const BAD_SHOUTS := ["¡TE PASASTE DE LANZA!", "¡NO MANCHES!", "¡QUÉ OSO!", "¡CHALE!", "¡YA VALIÓ!"]

var aura: int = 0
var shift_aura: int = 0
var reputation: float = 50.0


func reset() -> void:
	aura = 0
	shift_aura = 0
	reputation = 50.0
	aura_changed.emit(aura, 0, "", Vector2.ZERO, false)


func begin_shift() -> void:
	shift_aura = 0


## Adds (or removes) AURA. Message "" picks a random Mexican shout.
func add(amount: int, message := "", world_pos := Vector2.ZERO, has_pos := false) -> void:
	if amount == 0:
		return
	var before := level()
	var old := aura
	aura = maxi(0, aura + amount)
	var real_delta := aura - old
	shift_aura += real_delta
	if message == "":
		message = shout(amount > 0)
	message = tr(message)
	aura_changed.emit(aura, amount, message, world_pos, has_pos)
	var after := level()
	if after > before:
		level_up.emit(after, title())


func shout(good: bool) -> String:
	var pool: Array = GOOD_SHOUTS if good else BAD_SHOUTS
	return pool[randi() % pool.size()]


static func popup_text(amount: int, message: String) -> String:
	return "%s%d AURA — %s" % ["+" if amount > 0 else "", amount, message]


func level() -> int:
	var lvl := 0
	for i in LEVELS.size():
		if aura >= int(LEVELS[i]["min"]):
			lvl = i
	return lvl


func title() -> String:
	return tr(LEVELS[level()]["title"])


## Progress (0..1) toward the next AURA level.
func level_progress() -> float:
	var lvl := level()
	if lvl >= LEVELS.size() - 1:
		return 1.0
	var lo := float(LEVELS[lvl]["min"])
	var hi := float(LEVELS[lvl + 1]["min"])
	return clampf((aura - lo) / (hi - lo), 0.0, 1.0)


func demand_bonus() -> float:
	return 1.0 + 0.1 * level()


func tip_bonus() -> float:
	return 0.05 * level()


func patience_bonus() -> float:
	return 1.0 + (reputation - 50.0) / 250.0


## Satisfaction 0..1 nudges reputation toward it.
func record_satisfaction(s: float) -> void:
	reputation = clampf(lerpf(reputation, clampf(s, 0.0, 1.0) * 100.0, 0.08), 0.0, 100.0)


func to_dict() -> Dictionary:
	return {"aura": aura, "reputation": reputation}


func from_dict(d: Dictionary) -> void:
	aura = maxi(0, int(d.get("aura", 0)))
	reputation = clampf(float(d.get("reputation", 50.0)), 0.0, 100.0)
	shift_aura = 0
	aura_changed.emit(aura, 0, "", Vector2.ZERO, false)
