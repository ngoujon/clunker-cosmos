class_name QuestScreen
extends GameScreen
## Journal : histoire (chapitres, quêtes principales — mode Histoire), commandes facultatives
## (proposées / en cours), quêtes terminées, objectifs, récompenses, choix de fin et historique.

var selected_quest: String = ""


func select(id: String) -> void:
	selected_quest = id
	dirty = true


func rebuild() -> void:
	UIKit.clear(self)
	split(186)
	var gm: GameModel = m()
	var list: VBoxContainer = UIKit.vbox([], 2)
	if gm.story_mode:
		var ch: int = maxi(1, gm.chapter)
		list.add_child(section(t("ui.quests.chapter", {"n": ch, "title": t("chapter.%d.title" % ch)})))
		var mains: Array[String] = QuestSystem.ids_with_status(gm, "active", "main")
		if mains.is_empty():
			list.add_child(backdrop(UIKit.label(t("ui.quests.no_main") if gm.ending.is_empty() else t("ending.%s.title" % gm.ending), UIKit.C_DIM)))
		for id: String in mains:
			list.add_child(_quest_row(id))
	else:
		list.add_child(backdrop(UIKit.wrap_label(t("ui.quests.classic"), 170 + list_grow, UIKit.C_DIM)))
	var avail: Array[String] = QuestSystem.ids_with_status(gm, "available", "side")
	list.add_child(section(t("ui.quests.offers", {"n": avail.size()})))
	if avail.is_empty():
		list.add_child(backdrop(UIKit.label(t("ui.quests.no_offers"), UIKit.C_DIM)))
	for id: String in avail:
		list.add_child(_quest_row(id))
	var active_side: Array[String] = QuestSystem.ids_with_status(gm, "active", "side")
	if not active_side.is_empty():
		list.add_child(section(t("ui.quests.active_side")))
		for id: String in active_side:
			list.add_child(_quest_row(id))
	var done: Array[String] = QuestSystem.ids_with_status(gm, "done")
	var failed: Array[String] = QuestSystem.ids_with_status(gm, "failed")
	list.add_child(section(t("ui.quests.done", {"n": done.size(), "f": failed.size()})))
	var finished: Array[String] = []
	finished.append_array(done)
	finished.append_array(failed)
	finished.reverse()
	for id: String in finished.slice(0, 6):
		list.add_child(_quest_row(id))
	make_scroll("quest_list", list, Rect2(2, 2, 186 + list_grow, size.y - 4))
	if not selected_quest.is_empty() and db().quests.has(selected_quest):
		_detail(selected_quest)
	else:
		_journal()


func _quest_row(id: String) -> Control:
	var gm: GameModel = m()
	var st: String = QuestSystem.status(gm, id)
	var icon_id: String = {"active": "ui_quests", "available": "ui_warning", "done": "ui_check", "failed": "ui_lock"}.get(st, "ui_quests")
	var row: HBoxContainer = UIKit.hbox([UIKit.icon_rect(icon_id, 16)], 2)
	var col: Color = UIKit.C_TEXT
	if st == "done" or st == "failed":
		col = UIKit.C_DIM
	elif st == "available":
		col = UIKit.C_BLUE
	row.add_child(UIKit.wrap_label(t("quest.%s.title" % id), 150 + list_grow, col))
	var c: PanelContainer = card(row, id == selected_quest)
	clickable(c, func() -> void:
		selected_quest = id
		dirty = true)
	return c


static func reward_text(gm: GameModel, r: Dictionary) -> String:
	match str(r.get("type", "")):
		"credits":
			return "+" + UIKit.credits(int(r.get("amount", 0)))
		"rp":
			return I18n.t("ui.reward.rp", {"n": int(r.get("amount", 0))})
		"reputation":
			return I18n.t("ui.reward.rep", {"n": int(r.get("amount", 0))})
		"item":
			return I18n.t("ui.reward.item", {"name": I18n.t("item.%s.name" % str(r.get("id", "")))})
		"special_lot":
			return I18n.t("ui.reward.special", {"name": I18n.t("special.%s.name" % str(r.get("id", "")))})
		"rare_wreck":
			return I18n.t("ui.reward.rare_wreck")
		"employee":
			var tpl: Dictionary = gm.db.staff_templates.get(str(r.get("template", "")), {})
			return I18n.t("ui.reward.employee", {"name": str(tpl.get("name", "?")), "role": I18n.t("role.%s.name" % str(tpl.get("role", "mechanic")))})
		"unlock":
			return ResearchScreen.effect_text(gm, {"op": "unlock", "target": str(r.get("target", ""))})
		"tech":
			return I18n.t("ui.reward.tech", {"name": I18n.t("tech.%s.name" % str(r.get("id", "")))})
		"debt_reduction":
			return I18n.t("ui.reward.debt", {"amount": UIKit.credits(int(r.get("amount", 0)))})
		"modifier":
			return ResearchScreen.effect_text(gm, r)
		"flag", "ending":
			return ""
	return ""


func _detail(id: String) -> void:
	var gm: GameModel = m()
	var q: Dictionary = QuestSystem.quest(gm, id)
	var st: Dictionary = gm.quest_state.get(id, {})
	var status: String = QuestSystem.status(gm, id)
	var v: VBoxContainer = UIKit.vbox([], 3)
	var head: HBoxContainer = UIKit.hbox([], 4)
	var giver: String = str(q.get("giver", ""))
	if not giver.is_empty():
		var info: Dictionary = DialogueBox.speaker_info(giver)
		if not str(info["portrait"]).is_empty():
			head.add_child(UIKit.portrait_rect(str(info["portrait"])))
	var hv: VBoxContainer = UIKit.vbox([UIKit.wrap_label(t("quest.%s.title" % id), 200 + detail_grow, UIKit.C_ACCENT)], 1)
	var kind_key: String = "ui.quests.kind_main" if str(q.get("kind", "")) == "main" else "ui.quests.kind_side"
	hv.add_child(UIKit.label(t(kind_key) + " · " + t("ui.quests.status_" + status), UIKit.C_DIM))
	if not giver.is_empty():
		hv.add_child(UIKit.label(str(DialogueBox.speaker_info(giver)["name"]), UIKit.C_BLUE))
	head.add_child(hv)
	v.add_child(head)
	v.add_child(UIKit.wrap_label(t("quest.%s.desc" % id), 260 + detail_grow))
	var objs: Array = q.get("objectives", [])
	if not objs.is_empty():
		v.add_child(section(t("ui.quests.objectives")))
	for i: int in objs.size():
		var o: Dictionary = objs[i]
		var key: String = "quest.%s.obj%d" % [id, i]
		var text: String = t(key) if o.has("text") else str(o.get("type", ""))
		var row: HBoxContainer = UIKit.hbox([], 3)
		if status == "active" or status == "done":
			var vals: Array[float] = [1.0, 1.0]
			if status == "active":
				vals = QuestSystem.objective_values(gm, id, i)
			var ok: bool = vals[0] + 0.0001 >= vals[1]
			row.add_child(UIKit.label("●" if ok else "○", UIKit.C_GOOD if ok else UIKit.C_DIM))
			row.add_child(UIKit.wrap_label(text, 170 + detail_grow, UIKit.C_TEXT))
			if vals[1] > 1.0:
				row.add_child(UIKit.label("%s/%s" % [_num(minf(vals[0], vals[1])), _num(vals[1])], UIKit.C_DIM))
		else:
			row.add_child(UIKit.label("○", UIKit.C_DIM))
			row.add_child(UIKit.wrap_label(text, 220 + detail_grow))
		v.add_child(row)
		if str(o.get("type", "")) == "deliver_order":
			var crit: Dictionary = o.get("criteria", {})
			v.add_child(UIKit.wrap_label(SalesScreen.criteria_text(crit), 240 + detail_grow, UIKit.C_DIM))
	var dl: int = int(st.get("deadline", 0))
	var days: int = int(q.get("deadline_days", 0))
	if status == "active" and dl > 0:
		v.add_child(UIKit.label(t("ui.quests.deadline", {"day": dl, "n": dl - gm.day}), UIKit.C_ORANGE))
	elif status == "available" and days > 0:
		v.add_child(UIKit.label(t("ui.quests.duration", {"n": days}), UIKit.C_ORANGE))
	var rewards: Array[String] = []
	for r: Variant in q.get("rewards", []):
		var rt: String = reward_text(gm, r as Dictionary)
		if not rt.is_empty():
			rewards.append(rt)
	if not rewards.is_empty():
		v.add_child(section(t("ui.quests.rewards")))
		v.add_child(UIKit.wrap_label(" · ".join(rewards), 260 + detail_grow, UIKit.C_GOOD))
	if status == "available":
		v.add_child(UIKit.button(t("ui.quests.accept"), func() -> void:
			act(m().act_accept_quest(id), t("ui.quests.accepted")), "ui_check"))
		v.add_child(UIKit.label(t("ui.quests.optional"), UIKit.C_DIM))
	var choices: Array = q.get("choices", [])
	if status == "active" and not choices.is_empty():
		v.add_child(section(t("ui.quests.choose")))
		for ci: int in choices.size():
			var idx: int = ci
			var b: Button = UIKit.button(t("quest.%s.choice%d" % [id, ci]), func() -> void:
				main.confirm(t("ui.quests.choose_confirm"), func() -> void: act(m().act_choose(id, idx))))
			v.add_child(b)
	if status == "active" and int(st.get("client", -1)) >= 0 and gm.find_client(int(st.get("client", -1))) != null:
		v.add_child(UIKit.button(t("ui.quests.see_client"), func() -> void:
			(main.screen("sales") as SalesScreen).selected_client = int(st.get("client", -1))
			main.show_screen("sales"), "ui_sales"))
	v.add_child(UIKit.button(t("ui.quests.journal"), func() -> void:
		selected_quest = ""
		dirty = true))
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	make_scroll("quest_detail", p, Rect2(192 + list_grow, 2, size.x - 194 - list_grow, size.y - 4))


static func _num(v: float) -> String:
	if v >= 1000.0:
		return UIKit.credits(int(v)).replace(" ¢", "")
	return str(int(v))


func _journal() -> void:
	var gm: GameModel = m()
	var v: VBoxContainer = UIKit.vbox([], 2)
	v.add_child(UIKit.label(t("ui.quests.journal"), UIKit.C_ACCENT))
	if gm.story_mode:
		v.add_child(UIKit.wrap_label(t("ui.quests.story_intro"), 260 + detail_grow, UIKit.C_DIM))
	var entries: Array[Dictionary] = gm.journal.duplicate()
	entries.reverse()
	if entries.is_empty():
		v.add_child(UIKit.label(t("ui.quests.journal_empty"), UIKit.C_DIM))
	for e: Dictionary in entries.slice(0, 14):
		var ev: String = str(e.get("event", ""))
		var col: Color = UIKit.C_GOOD if ev == "completed" else (UIKit.C_BAD if ev == "failed" else UIKit.C_TEXT)
		v.add_child(UIKit.wrap_label(t("ui.quests.journal_line", {"day": int(e.get("day", 0)), "event": t("ui.quests.ev_" + ev), "title": t("quest.%s.title" % str(e.get("quest", "")))}), 260 + detail_grow, col))
	var items: Array[String] = []
	for it: String in gm.items:
		items.append(t("item.%s.name" % it))
	if not items.is_empty():
		v.add_child(section(t("ui.quests.items")))
		v.add_child(UIKit.wrap_label(", ".join(items), 260 + detail_grow, UIKit.C_ACCENT))
	var p: PanelContainer = UIKit.panel(v, "DarkPanel")
	make_scroll("journal", p, Rect2(192 + list_grow, 2, size.x - 194 - list_grow, size.y - 4))
