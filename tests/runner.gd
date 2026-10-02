extends Node
## Point d'entrée des vérifications headless :
##   godot --headless --path . res://tests/runner.tscn -- --suite=unit [--filter=xxx]
##   ... --suite=sim --days=30 --seed=7 --mode=classic
##   ... --suite=story --max-days=90 --seed=11
##   ... --suite=assets
## Chaque suite imprime une ligne « ##RESULT {json} » et quitte avec 0 (succès) ou 1.

var UNIT_DIR: String = "res://tests/unit"


func _ready() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())
	call_deferred("_run", opts)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var d: Dictionary = {"suite": "unit"}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1]
	return d


func _run(opts: Dictionary) -> void:
	var code: int = 1
	UNIT_DIR = str(opts.get("dir", UNIT_DIR))
	match str(opts.get("suite", "unit")):
		"unit":
			code = _run_unit(str(opts.get("filter", "")))
		"sim":
			code = SimRunner.run_sim(int(opts.get("days", "30")), int(opts.get("seed", "7")), str(opts.get("mode", "classic")))
		"story":
			code = SimRunner.run_story(int(opts.get("max-days", "90")), int(opts.get("seed", "11")), int(opts.get("chapters", "2")))
		"assets":
			code = AssetCheck.run()
		_:
			print("suite inconnue")
	get_tree().quit(code)


func _run_unit(filter: String) -> int:
	var files: PackedStringArray = DirAccess.get_files_at(UNIT_DIR)
	var total: int = 0
	var passed: int = 0
	var failed_names: Array[String] = []
	var suites: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	for f: String in files:
		if not f.begins_with("test_") or not f.ends_with(".gd"):
			continue
		var script: GDScript = load(UNIT_DIR + "/" + f)
		var suite_name: String = f.get_basename()
		var suite_pass: int = 0
		var suite_total: int = 0
		print("== %s" % suite_name)
		var probe: Object = script.new()
		var methods: Array[String] = []
		for md: Dictionary in probe.get_method_list():
			var n: String = str(md["name"])
			if n.begins_with("test_") and not n in methods:
				methods.append(n)
		for n: String in methods:
			if not filter.is_empty() and not n.contains(filter) and not suite_name.contains(filter):
				continue
			var inst: TestCase = script.new()
			inst.before_each()
			inst.call(n)
			total += 1
			suite_total += 1
			if inst.failures.is_empty():
				passed += 1
				suite_pass += 1
				print("  ok    %s" % n)
			else:
				failed_names.append("%s.%s" % [suite_name, n])
				print("  FAIL  %s" % n)
				for msg: String in inst.failures:
					print("        - %s" % msg)
		suites[suite_name] = {"passed": suite_pass, "total": suite_total}
	var result: Dictionary = {"passed": passed, "failed": total - passed, "total": total, "suites": suites, "failures": failed_names, "ms": Time.get_ticks_msec() - t0}
	print("TESTS: %d/%d réussis" % [passed, total])
	print("##RESULT " + JSON.stringify(result))
	return 0 if passed == total and total > 0 else 1
