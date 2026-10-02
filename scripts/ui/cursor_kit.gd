class_name CursorKit
extends RefCounted
## Curseur de souris du jeu en pixel art (remplace celui de Windows dans la fenêtre) : flèche dorée, main
## gantée sur les boutons, flèche « ? » sur les éléments à infobulle. Motifs dessinés ici, avec les couleurs
## de la palette, puis agrandis au plus proche voisin selon l'échelle de la fenêtre. Ce sont des curseurs
## « matériels » (Input.set_custom_mouse_cursor) : aucune latence par rapport à la souris.

## X contour sombre, W crème, Y jaune, O orange, S ombre ; « . » transparent.
const ARROW: PackedStringArray = [
	"X..........",
	"XX.........",
	"XWX........",
	"XWYX.......",
	"XWYYX......",
	"XWYYYX.....",
	"XWYYYYX....",
	"XWYYYYYX...",
	"XWYYYYYYX..",
	"XWYYYYYYYX.",
	"XWYYYYXXXXX",
	"XWYXYOX....",
	"XWX.XYOX...",
	"XX..XYOX...",
	"X....XYOX..",
	".....XYOX..",
	"......XX...",
]
const HAND: PackedStringArray = [
	"....XX.......",
	"...XWSX......",
	"...XWSX......",
	"...XWSX......",
	"...XWSXXXX...",
	"...XWSXWSXXX.",
	".XXXWSXWSXWSX",
	"XWWXWWWWWWWSX",
	"XWWWWWWWWWWSX",
	".XWWWWWWWWWSX",
	"..XWWWWWWWWSX",
	"...XWWWWWWSX.",
	"...XYYYYYYYX.",
	"...XXXXXXXXX.",
]
## Point d'interrogation (pixels « # »), contour sombre ajouté automatiquement.
const QUESTION: PackedStringArray = [
	".###.",
	"#...#",
	"....#",
	"..##.",
	"..#..",
	".....",
	"..#..",
]
const HOTSPOTS: Dictionary = {"arrow": Vector2i(0, 0), "hand": Vector2i(4, 0), "help": Vector2i(0, 0)}


static func colors() -> Dictionary:
	return {"X": UIKit.C_DARK, "W": UIKit.C_TEXT, "Y": UIKit.C_ACCENT, "O": UIKit.C_ORANGE, "S": UIKit.C_DIM}


## Motif d'un curseur : "arrow", "hand" ou "help" (flèche + point d'interrogation en bas à droite).
static func pattern(id: String) -> PackedStringArray:
	match id:
		"hand":
			return HAND
		"help":
			return _with_question()
	return ARROW


static func _with_question() -> PackedStringArray:
	var w: int = ARROW[0].length() + QUESTION[0].length() + 1
	var h: int = ARROW.size()
	var rows: Array[String] = []
	for y: int in h:
		rows.append(ARROW[y] + ".".repeat(w - ARROW[y].length()))
	var ox: int = ARROW[0].length() - 1
	var oy: int = h - QUESTION.size() - 2
	# Contour : toute case voisine d'un pixel du « ? » devient sombre, puis le « ? » en jaune par-dessus.
	for pass_i: int in 2:
		for qy: int in QUESTION.size():
			for qx: int in QUESTION[qy].length():
				if QUESTION[qy][qx] != "#":
					continue
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						if pass_i == 1 and (dx != 0 or dy != 0):
							continue
						var x: int = ox + qx + dx
						var y: int = oy + qy + dy
						if y < 0 or y >= h or x < 0 or x >= w:
							continue
						var row: String = rows[y]
						rows[y] = row.substr(0, x) + ("Y" if pass_i == 1 else "X") + row.substr(x + 1)
	return PackedStringArray(rows)


## Image du curseur, chaque pixel du motif devenant un carré de k × k.
static func image(id: String, k: int) -> Image:
	var pat: PackedStringArray = pattern(id)
	var w: int = pat[0].length()
	var img: Image = Image.create(w * k, pat.size() * k, false, Image.FORMAT_RGBA8)
	var cols: Dictionary = colors()
	for y: int in pat.size():
		for x: int in w:
			var ch: String = pat[y][x]
			if cols.has(ch):
				img.fill_rect(Rect2i(x * k, y * k, k, k), cols[ch] as Color)
	return img


## Taille des pixels du curseur : celle des pixels du jeu, un cran en dessous au-delà de ×2 (sinon la
## flèche paraît énorme en plein écran).
static func scale_for(window_size: Vector2i) -> int:
	var k: int = maxi(1, mini(window_size.x / 480, window_size.y / 270))
	return k if k <= 2 else k - 1


## Installe les curseurs pour la taille actuelle de la fenêtre (à rappeler quand elle change).
static func apply(win: Window) -> void:
	if DisplayServer.get_name() == "headless" or win == null:
		return
	var k: int = scale_for(win.size)
	var arrow: Image = image("arrow", k)
	var arrow_shapes: Array[Input.CursorShape] = [
		Input.CURSOR_ARROW, Input.CURSOR_IBEAM, Input.CURSOR_WAIT, Input.CURSOR_BUSY, Input.CURSOR_CROSS,
		Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN, Input.CURSOR_MOVE,
		Input.CURSOR_VSIZE, Input.CURSOR_HSIZE, Input.CURSOR_BDIAGSIZE, Input.CURSOR_FDIAGSIZE,
		Input.CURSOR_VSPLIT, Input.CURSOR_HSPLIT,
	]
	for shape: Input.CursorShape in arrow_shapes:
		Input.set_custom_mouse_cursor(arrow, shape, Vector2(HOTSPOTS["arrow"]) * float(k))
	Input.set_custom_mouse_cursor(image("hand", k), Input.CURSOR_POINTING_HAND, Vector2(HOTSPOTS["hand"]) * float(k))
	Input.set_custom_mouse_cursor(image("help", k), Input.CURSOR_HELP, Vector2(HOTSPOTS["help"]) * float(k))
