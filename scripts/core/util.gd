class_name Util
extends RefCounted
## Fonctions utilitaires pures (aucune dépendance à l'arbre de scènes).


static func str_array(a: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(a) == TYPE_ARRAY or typeof(a) == TYPE_PACKED_STRING_ARRAY:
		for v: Variant in a:
			out.append(str(v))
	return out


static func int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(a) == TYPE_ARRAY:
		for v: Variant in a:
			out.append(int(v))
	return out


static func pick(rng: RandomNumberGenerator, a: Array) -> Variant:
	if a.is_empty():
		return null
	return a[rng.randi_range(0, a.size() - 1)]


static func pick_str(rng: RandomNumberGenerator, a: Array[String]) -> String:
	if a.is_empty():
		return ""
	return a[rng.randi_range(0, a.size() - 1)]


## Tire une clé selon des poids {clé: poids}.
static func pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for k: Variant in weights:
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return str(weights.keys()[0]) if not weights.is_empty() else ""
	var r: float = rng.randf() * total
	for k: Variant in weights:
		r -= maxf(0.0, float(weights[k]))
		if r <= 0.0:
			return str(k)
	return str(weights.keys()[weights.size() - 1])


## Bruit déterministe dans [0,1) à partir de deux entiers (stable entre sessions).
static func hash01(a: int, b: int, salt: int = 0) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0


static func roundi_to(v: float, step: int) -> int:
	if step <= 1:
		return roundi(v)
	return int(round(v / float(step))) * step


static func fmt_credits(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	var n: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if v < 0 else "") + out + " ¢"


static func shuffle_with(rng: RandomNumberGenerator, a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
