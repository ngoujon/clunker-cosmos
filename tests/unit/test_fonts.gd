extends TestCase
## Polices : chaque caractère des textes du jeu (FR et EN, contenu, interface, tutoriel) est dessiné par
## la police de texte ou son repli de symboles ; le logo (Lilita One) couvre le nom du jeu.


func _covered(f: Font, c: int) -> bool:
	var ff: FontFile = f as FontFile
	if ff != null and ff.has_char(c):
		return true
	for fb: Font in f.fallbacks:
		if _covered(fb, c):
			return true
	return false


func test_all_text_characters_covered() -> void:
	var chars: Dictionary = {}
	for key: String in db.texts:
		var d: Dictionary = db.texts[key]
		for loc: String in ["fr", "en"]:
			var s: String = str(d.get(loc, ""))
			for i: int in s.length():
				chars[s.unicode_at(i)] = true
	var font: Font = UIKit.font()
	var missing: Array[String] = []
	for c: int in chars:
		if c < 32 or c == 0x0A:
			continue
		if not _covered(font, c):
			missing.append("U+%04X %s" % [c, String.chr(c)])
	gt(float(chars.size()), 80.0, "caractères analysés")
	eq(missing.size(), 0, "caractères sans glyphe : %s" % str(missing))


func test_ui_symbols_covered() -> void:
	var font: Font = UIKit.font()
	for ch: String in ["●", "○", "→", "≈", "×", "¢", "«", "»", "…", "•", "·", "’", "‹", "›"]:
		check(_covered(font, ch.unicode_at(0)), "symbole %s" % ch)


func test_logo_font_covers_title() -> void:
	var title: String = db.text("ui.title", "fr") + db.text("ui.title", "en")
	var f: FontFile = UIKit.display_font()
	for i: int in title.length():
		var c: int = title.unicode_at(i)
		check(c == 32 or f.has_char(c), "logo : %s" % String.chr(c))


func test_symbol_fallback_does_not_grow_lines() -> void:
	# Le repli ne doit pas agrandir la hauteur de ligne (Godot prend le maximum des polices de la chaîne).
	var body: FontFile = load(UIKit.FONT_PATH) as FontFile
	near(UIKit.font().get_height(16), body.get_height(16), 0.6, "hauteur de ligne inchangée par le repli")
