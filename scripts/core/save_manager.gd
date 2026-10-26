extends Node
## Autoload "SaveManager": versioned JSON save in user://.
## Missing, corrupt or incompatible files are ignored gracefully (the game simply offers a new run).

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://tacos_y_trancazos_save.json"

var save_path := DEFAULT_PATH
var last_error := ""


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"game": GameManager.to_dict(),
		"economy": Economy.to_dict(),
		"aura": Aura.to_dict(),
		"upgrades": Upgrades.to_dict(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		last_error = "No se pudo escribir el guardado (%s)" % error_string(FileAccess.get_open_error())
		push_warning(last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Returns validated save data, or {} when there is no usable save.
func load_data() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(save_path):
		return {}
	var txt := FileAccess.get_file_as_string(save_path)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Guardado dañado"
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		last_error = "Guardado de otra versión"
		return {}
	for key in ["game", "economy", "aura", "upgrades"]:
		if typeof(parsed.get(key)) != TYPE_DICTIONARY:
			last_error = "Guardado incompleto"
			return {}
	var mode_id := str(parsed["game"].get("mode", ""))
	if parsed["game"].get("run_active", false) and DB.mode(mode_id).is_empty():
		last_error = "Negocio desconocido en el guardado"
		return {}
	return parsed


func has_continuable_run() -> bool:
	var d := load_data()
	return not d.is_empty() and bool(d["game"].get("run_active", false))


## Applies a save to the autoloads. Returns false if there was nothing valid to load.
func load_game() -> bool:
	var d := load_data()
	if d.is_empty():
		return false
	Economy.from_dict(d["economy"])
	Aura.from_dict(d["aura"])
	Upgrades.from_dict(d["upgrades"])
	GameManager.from_dict(d["game"])
	return true
