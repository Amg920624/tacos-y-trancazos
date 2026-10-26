extends Node
## Autoload "EventManager": reusable, data-driven city events (data/events.json).
## Each event defines compatible modes, trigger, cooldown, duration and AURA reward/penalty.
## Modes listen to event_started / event_timeout and call resolve() with the outcome.

signal event_started(ev: Dictionary)
signal event_timeout(id: String)
signal event_ended(id: String, success: bool)

var mode := ""
var shift := 0
var active: Dictionary = {}      # id -> {"def": Dictionary, "remaining": float}
var cooldowns: Dictionary = {}   # id -> seconds
var fired: Dictionary = {}       # id -> times fired this shift
var scheduled: Array = []        # [{"id": String, "at": float}] sorted by normalized time
var history: Array = []          # [{"id", "success"}] this shift
var rng := RandomNumberGenerator.new()
var enabled := true


func begin_shift(p_mode: String, p_shift: int) -> void:
	mode = p_mode
	shift = p_shift
	active.clear()
	cooldowns.clear()
	fired.clear()
	scheduled.clear()
	history.clear()
	rng.randomize()
	for ev in DB.events:
		if not compatible(ev):
			continue
		var trig: Dictionary = ev.get("trigger", {})
		if trig.get("type", "") == "scheduled":
			var by_shift: Array = trig.get("times_by_shift", [])
			if shift < by_shift.size():
				for t in by_shift[shift]:
					scheduled.append({"id": ev["id"], "at": clampf(float(t) + rng.randf_range(-0.03, 0.03), 0.02, 0.95)})
	scheduled.sort_custom(func(a, b): return a["at"] < b["at"])


func end_shift() -> void:
	active.clear()
	scheduled.clear()


func compatible(ev: Dictionary) -> bool:
	return mode in ev.get("modes", [])


func update(delta: float, t_norm: float) -> void:
	if not enabled:
		return
	for id in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
	for id in active.keys():
		if not active.has(id):
			continue
		active[id]["remaining"] = float(active[id]["remaining"]) - delta
		if active[id]["remaining"] <= 0.0:
			event_timeout.emit(id)
			if active.has(id):
				resolve(id, false)
	while scheduled.size() > 0 and t_norm >= float(scheduled[0]["at"]):
		var s: Dictionary = scheduled.pop_front()
		if not try_start(s["id"], true):
			# Busy or cooling down: retry a little later in the shift.
			if t_norm < 0.9:
				scheduled.append({"id": s["id"], "at": t_norm + 0.05})
				scheduled.sort_custom(func(a, b): return a["at"] < b["at"])
			break
	for ev in DB.events:
		var trig: Dictionary = ev.get("trigger", {})
		if trig.get("type", "") != "random" or not compatible(ev):
			continue
		if not (shift in trig.get("shifts", [0, 1, 2])):
			continue
		if t_norm < float(trig.get("min_t", 0.0)) or t_norm > float(trig.get("max_t", 1.0)):
			continue
		if int(fired.get(ev["id"], 0)) >= int(trig.get("max_per_shift", 1)):
			continue
		if rng.randf() < float(trig.get("chance_per_sec", 0.0)) * delta:
			try_start(ev["id"])


## Starts an event if it is compatible, not active and not cooling down.
func try_start(id: String, ignore_cooldown := false) -> bool:
	var def := DB.event_def(id)
	if def.is_empty() or not compatible(def) or active.has(id):
		return false
	if not ignore_cooldown and float(cooldowns.get(id, 0.0)) > 0.0:
		return false
	active[id] = {"def": def, "remaining": float(def.get("duration", 20.0))}
	fired[id] = int(fired.get(id, 0)) + 1
	event_started.emit(def)
	return true


func is_active(id: String) -> bool:
	return active.has(id)


func remaining(id: String) -> float:
	if not active.has(id):
		return 0.0
	return float(active[id]["remaining"])


## Ends an event, applying its AURA reward or penalty.
func resolve(id: String, success: bool, world_pos := Vector2.ZERO, has_pos := false) -> void:
	if not active.has(id):
		return
	var def: Dictionary = active[id]["def"]
	active.erase(id)
	cooldowns[id] = float(def.get("cooldown", 10.0))
	history.append({"id": id, "success": success})
	var amount := int(def.get("reward_aura", 0)) if success else int(def.get("penalty_aura", 0))
	if amount != 0:
		var text: String = def.get("success_text" if success else "failure_text", "")
		Aura.add(amount, tr(text).to_upper() if text != "" else "", world_pos, has_pos)
	event_ended.emit(id, success)


func handled_count() -> int:
	var n := 0
	for h in history:
		if h["success"]:
			n += 1
	return n
