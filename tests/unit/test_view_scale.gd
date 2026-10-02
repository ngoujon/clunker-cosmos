extends TestCase
## Taille de l'interface (ViewScale) : facteurs proposés selon l'écran, réglage automatique, résolution
## logique, cycle du réglage et échelles entières des images (pixels nets).

const QHD: Vector2i = Vector2i(2560, 1440)
const FHD: Vector2i = Vector2i(1920, 1080)


func test_auto_scale_by_screen() -> void:
	eq(ViewScale.auto_scale(QHD), 3, "1440p : ×3")
	eq(ViewScale.logical_size(QHD, 3), Vector2i(853, 480), "1440p : 853×480")
	eq(ViewScale.auto_scale(FHD), 3, "1080p : ×3")
	eq(ViewScale.logical_size(FHD, 3), Vector2i(640, 360), "1080p : 640×360")
	eq(ViewScale.auto_scale(Vector2i(3840, 2160)), 5, "4K : ×5")
	eq(ViewScale.auto_scale(Vector2i(1440, 810)), 2, "fenêtre par défaut : ×2")
	eq(ViewScale.auto_scale(Vector2i(1366, 768)), 2, "portable 768p : ×2")
	eq(ViewScale.auto_scale(Vector2i(800, 450)), 1, "petite fenêtre : ×1")


func test_choices_keep_minimum_resolution() -> void:
	var c: Array[int] = ViewScale.choices(QHD)
	eq(c, [5, 4, 3, 2] as Array[int], "1440p : ×5 à ×2")
	eq(ViewScale.choices(FHD), [4, 3, 2] as Array[int], "1080p : ×4 à ×2")
	eq(ViewScale.choices(Vector2i(960, 540)), [2] as Array[int], "960×540 : ×2 seulement")
	eq(ViewScale.choices(Vector2i(700, 400)), [1] as Array[int], "fenêtre minuscule : ×1")
	for win: Vector2i in [QHD, FHD, Vector2i(3440, 1440), Vector2i(1280, 1024), Vector2i(3840, 2160)]:
		for k: int in ViewScale.choices(win):
			var l: Vector2i = ViewScale.logical_size(win, k)
			check(l.x >= 480 and l.y >= 270, "%s ×%d : au moins 480×270" % [win, k])
			check(l.x * k <= win.x and l.y * k <= win.y, "%s ×%d : tient dans la fenêtre" % [win, k])
			check(l.y <= ViewScale.MAX_HEIGHT, "%s ×%d : texte lisible" % [win, k])


func test_resolve_clamps_setting() -> void:
	eq(ViewScale.resolve(QHD, 0), 3, "automatique")
	eq(ViewScale.resolve(QHD, 2), 2, "réglage respecté")
	eq(ViewScale.resolve(QHD, 9), 5, "trop grand : borné")
	eq(ViewScale.resolve(FHD, 5), 4, "écran plus petit : borné")
	eq(ViewScale.resolve(FHD, 1), 2, "trop fin : borné")


func test_next_setting_cycles_through_choices() -> void:
	var seen: Array[int] = []
	var s: int = 0
	for i: int in 6:
		s = ViewScale.next_setting(FHD, s)
		seen.append(s)
	eq(seen, [2, 4, 0, 2, 4, 0] as Array[int], "1080p : Auto → plus fin (×2) → plus grand (×4) → Auto")
	seen.clear()
	for i: int in 4:
		s = ViewScale.next_setting(QHD, s)
		seen.append(s)
	eq(seen, [2, 5, 4, 0] as Array[int], "1440p : Auto (×3) → ×2 → ×5 → ×4 → Auto")
	eq(ViewScale.next_setting(FHD, 7), 0, "réglage hors liste : retour à Auto")


func test_art_scales_are_whole_screen_pixels() -> void:
	# 1440p, interface ×3 : le garage (480×230 pixels d'image) tient dans 853×440 → ×5 à l'écran.
	var s: float = ViewScale.fit_scale(Vector2(853, 440), Vector2(480, 230), 3)
	near(s * 3.0, 5.0, 0.0001, "garage : 5 pixels d'écran par pixel d'image")
	check(480.0 * s <= 853.0 and 230.0 * s <= 440.0, "garage entièrement visible")
	var c: float = ViewScale.cover_scale(Vector2(853, 480), Vector2(480, 270), 3)
	near(c * 3.0, 6.0, 0.0001, "fond : 6 pixels d'écran par pixel d'image")
	check(480.0 * c >= 853.0 and 270.0 * c >= 480.0, "fond couvrant")
	near(ViewScale.cover_scale(Vector2(480, 270), Vector2(480, 270), 4), 1.0, 0.0001, "taille exacte : ×1")
	near(ViewScale.fit_scale(Vector2(480, 230), Vector2(480, 230), 4), 1.0, 0.0001, "jamais plus petit qu'un pixel d'interface")
	eq(ViewScale.snap(Vector2(10.4, 3.9), 3), Vector2(31.0 / 3.0, 11.0 / 3.0), "arrondi au pixel d'écran")
