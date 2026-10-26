extends Node
## Autoload "Upgrades": data-driven upgrades (data/upgrades.json).
## Gameplay asks for summed modifiers with stat(); every listed upgrade feeds a real stat.

signal upgrade_purchased(id: String, level: int)

var levels: Dictionary = {}


func reset() -> void:
	levels.clear()


func get_def(id: String) -> Dictionary:
	for u in DB.upgrades:
		if u.get("id", "") == id:
			return u
	return {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


func applies_to(def: Dictionary, mode_id: String) -> bool:
	var m = def.get("mode", "all")
	if typeof(m) == TYPE_ARRAY:
		return mode_id in m
	return m == "all" or m == mode_id


func list_for_mode(mode_id: String) -> Array:
	var out := []
	for u in DB.upgrades:
		if applies_to(u, mode_id):
			out.append(u)
	return out


func max_level(id: String) -> int:
	return int(get_def(id).get("max_level", 1))


## Cost of the next level, or -1 when maxed or unknown.
func next_cost(id: String) -> int:
	var def := get_def(id)
	if def.is_empty():
		return -1
	var lvl := level(id)
	if lvl >= max_level(id):
		return -1
	var costs: Array = def.get("cost", [100])
	return int(costs[mini(lvl, costs.size() - 1)])


func can_buy(id: String, mode_id: String) -> Dictionary:
	var def := get_def(id)
	if def.is_empty():
		return {"ok": false, "reason": "Mejora desconocida"}
	if not applies_to(def, mode_id):
		return {"ok": false, "reason": "No aplica a este negocio"}
	var cost := next_cost(id)
	if cost < 0:
		return {"ok": false, "reason": "Nivel máximo"}
	var req := int(def.get("aura_required", 0))
	if Aura.aura < req:
		return {"ok": false, "reason": tr("Requiere %d de AURA") % req}
	if not Economy.can_afford(cost):
		return {"ok": false, "reason": "Te falta lana"}
	return {"ok": true, "reason": ""}


func buy(id: String, mode_id: String) -> bool:
	if not can_buy(id, mode_id)["ok"]:
		return false
	var cost := next_cost(id)
	if not Economy.spend(cost, "mejoras"):
		return false
	levels[id] = level(id) + 1
	upgrade_purchased.emit(id, levels[id])
	return true


## Sum of a modifier across owned upgrades that apply to the mode.
func stat(stat_name: String, mode_id: String) -> float:
	var total := 0.0
	for id in levels.keys():
		var lvl := level(id)
		if lvl <= 0:
			continue
		var def := get_def(id)
		if def.is_empty() or not applies_to(def, mode_id):
			continue
		for eff in def.get("effects", []):
			if eff.get("stat", "") == stat_name:
				total += float(eff.get("per_level", 0.0)) * lvl
	return total


func to_dict() -> Dictionary:
	return levels.duplicate()


func from_dict(d: Dictionary) -> void:
	levels.clear()
	for id in d.keys():
		var def := get_def(str(id))
		if def.is_empty():
			continue
		levels[str(id)] = clampi(int(d[id]), 0, int(def.get("max_level", 1)))
