extends Node
## Loads every script and scene in the project and reports which ones fail to compile.
## Run: godot --headless --path . res://tests/compile_check.tscn

func _ready() -> void:
	var failed := []
	var paths := []
	_collect("res://scripts", ".gd", paths)
	_collect("res://scenes", ".tscn", paths)
	_collect("res://tests", ".gd", paths)
	for p in paths:
		var res = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			failed.append(p)
		elif res is GDScript and not res.can_instantiate():
			failed.append(p)
	print("COMPILE_CHECK checked=%d failed=%d" % [paths.size(), failed.size()])
	for f in failed:
		print("COMPILE_FAIL ", f)
	get_tree().quit(1 if failed.size() > 0 else 0)


func _collect(dir: String, ext: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_collect(dir + "/" + sub, ext, out)
