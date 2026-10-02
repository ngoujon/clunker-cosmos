class_name ResearchScreen
extends GameScreen
## Arbre technologique en graphe : 6 branches (colonnes), nœuds placés selon `pos` (rang, voie),
## liens de prérequis, états (fait / prêt / en attente de ressources / verrouillé) et fiche du nœud.

const COL_W: int = 54
const ROW_H: int = 33
const LANE: int = 13
const TOP: int = 34
const INFO_W: int = 150

var selected_node: String = ""
var _graph: TechGraph = null


func background() -> Array:
	return ["res://assets/backgrounds/garage.png", 0.8]


func node_center(id: String) -> Vector2:
	var n: Dictionary = db().tech.get(id, {})
	var col: int = 0
	for i: int in db().branches.size():
		if str(db().branches[i]["id"]) == str(n.get("branch", "")):
			col = i
	var pos: Array = n.get("pos", [0, 0])
	return Vector2(col * COL_W + COL_W / 2 + int(pos[1]) * LANE, TOP + int(pos[0]) * ROW_H)


func rebuild() -> void:
	UIKit.clear(self)
	var gm: GameModel = m()
	if selected_node.is_empty() or not db().tech.has(selected_node):
		var avail: Array[String] = ResearchSystem.available(gm)
		selected_node = avail[0] if not avail.is_empty() else str(db().tech.keys()[0])
	var gp: PanelContainer = PanelContainer.new()
	gp.theme_type_variation = "DarkPanel"
	place(gp, Rect2(2, 2, size.x - INFO_W - 6, size.y - 4))
	_graph = TechGraph.new()
	_graph.screen = self
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(_graph, Rect2(2, 2, size.x - INFO_W - 6, size.y - 4))
	for i: int in db().branches.size():
		var b: Dictionary = db().branches[i]
		var ic: TextureRect = UIKit.icon_rect(str(b.get("icon", "")), 16)
		ic.tooltip_text = t("branch.%s" % str(b["id"]))
		place(ic, Rect2(2 + i * COL_W + COL_W / 2 - 8, 4, 16, 16))
	for id: String in db().tech:
		_node_button(id)
	_info(selected_node)


func _node_button(id: String) -> void:
	var gm: GameModel = m()
	var state: String = ResearchSystem.node_state(gm, id)
	var c: Vector2 = node_center(id) + Vector2(2, 2)
	var b: TechNode = TechNode.new()
	b.state = state
	b.selected = id == selected_node
	b.icon_tex = UIKit.icon(str(db().tech[id].get("icon", "")))
	b.tooltip_text = "%s\n%s" % [t("tech.%s.name" % id), t("ui.research.state_" + state)]
	place(b, Rect2(c - Vector2(10, 10), Vector2(20, 20)))
	clickable(b, func() -> void:
		selected_node = id
		dirty = true)


static func effect_text(gm: GameModel, e: Dictionary) -> String:
	var op: String = str(e.get("op", ""))
	if op == "unlock":
		var target: String = str(e.get("target", ""))
		var kind: String = target.get_slice(":", 0)
		var id: String = target.get_slice(":", 1)
		var name: String = id
		match kind:
			"paint":
				name = I18n.t("paint.%s" % id)
			"option":
				name = I18n.t("option.%s.name" % id)
			"location":
				name = I18n.t("location.%s.name" % id)
		return I18n.t("ui.research.unlock_" + kind, {"name": name})
	var st: String = str(e.get("stat", ""))
	var v: float = float(e.get("value", 0.0))
	var amount: String = ""
	if op == "mul":
		var p: int = int(round((v - 1.0) * 100.0))
		amount = ("+" if p >= 0 else "") + "%d %%" % p
	elif absf(v) < 1.0:
		amount = ("+" if v >= 0.0 else "") + "%d %%" % int(round(v * 100.0))
	else:
		amount = ("+" if v >= 0.0 else "") + str(int(v))
	return I18n.t("stat.%s" % st) + " " + amount


func _info(id: String) -> void:
	var gm: GameModel = m()
	var n: Dictionary = db().tech[id]
	var v: VBoxContainer = UIKit.vbox([], 2)
	v.add_child(UIKit.label(t("ui.research.rp", {"rp": "%.1f" % gm.research_points}), UIKit.C_BLUE))
	var head: HBoxContainer = UIKit.hbox([UIKit.icon_rect(str(n.get("icon", "")), 16), UIKit.wrap_label(t("tech.%s.name" % id), INFO_W - 40, UIKit.C_ACCENT)], 3)
	v.add_child(head)
	v.add_child(UIKit.label(t("branch.%s" % str(n.get("branch", ""))), UIKit.C_DIM))
	v.add_child(UIKit.wrap_label(t("tech.%s.desc" % id), INFO_W - 16))
	v.add_child(section(t("ui.research.effects")))
	for e: Variant in n.get("effects", []):
		v.add_child(UIKit.wrap_label("• " + effect_text(gm, e as Dictionary), INFO_W - 16, UIKit.C_GOOD))
	var prereqs: Array = n.get("prereqs", [])
	if not prereqs.is_empty():
		v.add_child(section(t("ui.research.prereqs")))
		for p: Variant in prereqs:
			var done: bool = str(p) in gm.researched
			v.add_child(UIKit.wrap_label(("● " if done else "○ ") + t("tech.%s.name" % str(p)), INFO_W - 16, UIKit.C_GOOD if done else UIKit.C_BAD))
	var cost_ok_rp: bool = gm.research_points + 0.0001 >= float(n.get("rp", 0))
	var cost_ok_cr: bool = gm.credits >= int(n.get("credits", 0))
	v.add_child(section(t("ui.research.cost")))
	v.add_child(UIKit.hbox([UIKit.icon_rect("ui_rp", 16), UIKit.label("%d" % int(n.get("rp", 0)), UIKit.C_TEXT if cost_ok_rp else UIKit.C_BAD), UIKit.icon_rect("ui_credits", 16), UIKit.label(UIKit.credits(int(n.get("credits", 0))), UIKit.C_TEXT if cost_ok_cr else UIKit.C_BAD)], 2))
	var state: String = ResearchSystem.node_state(gm, id)
	if state == "done":
		v.add_child(UIKit.label(t("ui.research.state_done"), UIKit.C_GOOD))
	else:
		var b: Button = UIKit.button(t("ui.research.do"), func() -> void:
			act(m().act_research(id), t("ui.research.done_toast", {"node": t("tech.%s.name" % id)})), "ui_research")
		b.disabled = state != "ready"
		if b.disabled:
			b.tooltip_text = t("reason." + ResearchSystem.can_research(gm, id))
		v.add_child(b)
	var p2: PanelContainer = UIKit.panel(v, "DarkPanel")
	make_scroll("tech_info", p2, Rect2(size.x - INFO_W - 2, 2, INFO_W, size.y - 4))


## Liens de prérequis dessinés en lignes orthogonales (pixels nets).
class TechGraph extends Control:
	var screen: ResearchScreen = null

	func _draw() -> void:
		if screen == null or Game.model == null:
			return
		var gm: GameModel = Game.model
		var db: ContentDB = Content.db
		for i: int in range(1, db.branches.size()):
			draw_rect(Rect2(i * ResearchScreen.COL_W, 2, 1, size.y - 4), Color(UIKit.C_SLATE, 0.9))
		for id: String in db.tech:
			var to: Vector2 = screen.node_center(id)
			for p: Variant in db.tech[id].get("prereqs", []):
				var from: Vector2 = screen.node_center(str(p))
				var col: Color = UIKit.C_GOOD if str(p) in gm.researched else Color(UIKit.C_DIM, 0.7)
				var mid_y: float = floorf(to.y - ResearchScreen.ROW_H / 2.0)
				_vline(from.x, from.y + 9, mid_y, col)
				_hline(from.x, to.x, mid_y, col)
				_vline(to.x, mid_y, to.y - 9, col)

	func _hline(x0: float, x1: float, y: float, c: Color) -> void:
		draw_rect(Rect2(minf(x0, x1), y, absf(x1 - x0) + 1, 1), c)

	func _vline(x: float, y0: float, y1: float, c: Color) -> void:
		draw_rect(Rect2(x, minf(y0, y1), 1, absf(y1 - y0) + 1), c)


## Nœud cliquable : cadre coloré selon l'état, icône assombrie si verrouillé.
class TechNode extends Control:
	var state: String = "locked"
	var selected: bool = false
	var icon_tex: Texture2D = null
	var _t: float = 0.0

	func _process(delta: float) -> void:
		if state == "ready":
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var frame: Color = UIKit.C_DIM
		var fill: Color = UIKit.C_DARK
		match state:
			"done":
				frame = UIKit.C_GOOD
				fill = Color("#1d4a32")
			"ready":
				frame = UIKit.C_ACCENT if fmod(_t, 1.0) < 0.6 else UIKit.C_ORANGE
				fill = UIKit.C_PANEL
			"available":
				frame = UIKit.C_BLUE
				fill = UIKit.C_SLATE
		draw_rect(r, fill, true)
		draw_rect(r.grow(-0.5), frame, false, 1.0)
		if selected:
			draw_rect(r.grow(1.5), UIKit.C_TEXT, false, 1.0)
		if icon_tex != null:
			var mod: Color = Color(0.35, 0.35, 0.4) if state == "locked" else Color.WHITE
			draw_texture(icon_tex, Vector2(2, 2), mod)
