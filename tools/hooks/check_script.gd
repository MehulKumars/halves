extends SceneTree
## Compiles GDScript files inside the full project context (autoloads and class_names
## registered), so it reports real errors only. Plain `--check-only` reports false
## "Identifier not found" errors for autoload names, which is why this exists.
## Used by tools/hooks/gd_check.ps1. Usage:
##   godot --headless --path . -s tools/hooks/check_script.gd -- res://core/x.gd [more.gd...]
## Godot prints compile errors as "SCRIPT ERROR" lines but can still return a script
## object, so callers must read the output; the exit code (1) only covers scripts that
## fail to load at all.


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("check_script: pass one or more res:// paths after --")
		quit(2)
		return
	var failed := 0
	for path: String in paths:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
		if script == null:
			printerr("check_script: FAILED %s" % path)
			failed += 1
	quit(1 if failed > 0 else 0)
