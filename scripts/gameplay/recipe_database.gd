extends Node
## Autoload "DB": loads every data-driven definition from res://data/*.json.
## Gameplay code reads modes, recipes, customers, upgrades, events and dialogue from here.

var modes: Dictionary = {}
var recipes: Dictionary = {}
var future: Array = []
var customers: Array = []
var upgrades: Array = []
var events: Array = []
var dialogue: Dictionary = {}
var load_errors: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	load_errors.clear()
	var r := _load_json("res://data/recipes.json")
	modes = r.get("modes", {})
	recipes = r.get("recipes", {})
	future = r.get("future", [])
	customers = _load_json("res://data/customers.json").get("archetypes", [])
	upgrades = _load_json("res://data/upgrades.json").get("upgrades", [])
	events = _load_json("res://data/events.json").get("events", [])
	dialogue = _load_json("res://data/dialogue.json")
	for err in load_errors:
		push_error(err)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("Falta el archivo de datos: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("JSON inválido: " + path)
		return {}
	return parsed


func mode(id: String) -> Dictionary:
	return modes.get(id, {})


func recipe(id: String) -> Dictionary:
	return recipes.get(id, {"name": id, "price": 15, "cost": 5, "color": "#c08040"})


func recipe_name(id: String, short := false) -> String:
	var r := recipe(id)
	if short and r.has("short"):
		return r["short"]
	return r.get("name", id)


func price(id: String) -> int:
	return int(recipe(id).get("price", 15))


func archetype(id: String) -> Dictionary:
	for a in customers:
		if a.get("id", "") == id:
			return a
	return customers[0] if customers.size() > 0 else {"id": "generico", "patience": 20, "lines": []}


## Weighted random archetype for a business mode (critic has weight 0 and only appears by event).
func pick_archetype(mode_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for a in customers:
		total += float(a.get("weight", {}).get(mode_id, 1))
	if total <= 0.0:
		return archetype("")
	var roll := rng.randf() * total
	for a in customers:
		roll -= float(a.get("weight", {}).get(mode_id, 1))
		if roll <= 0.0:
			return a
	return customers[0]


## Random line for a dialogue key; returns fallback when the key is missing.
func line(key: String, fallback := "") -> String:
	var lines = dialogue.get(key, [])
	if typeof(lines) == TYPE_ARRAY and lines.size() > 0:
		return lines[randi() % lines.size()]
	if typeof(lines) == TYPE_STRING:
		return lines
	return fallback


func critic_review(stars: int) -> String:
	var all: Dictionary = dialogue.get("critic_reviews", {})
	var lines = all.get(str(clampi(stars, 0, 3)), [])
	if lines.size() == 0:
		return "Sin comentarios."
	return lines[randi() % lines.size()]


func event_def(id: String) -> Dictionary:
	for e in events:
		if e.get("id", "") == id:
			return e
	return {}
