extends Control

var reg: Node = preload("res://scripts/data_registry.gd").new()
var sim: Node = preload("res://scripts/combat_sim.gd").new()
var econ: Node = preload("res://scripts/economy_stub.gd").new()

var mode_opt: OptionButton = null
var attacker_opt: OptionButton = null
var defender_opt: OptionButton = null

var atk_tech_opt: OptionButton = null
var def_tech_opt: OptionButton = null
var hom_opt: OptionButton = null

var item_e1: OptionButton = null
var item_e2: OptionButton = null
var item_s1: OptionButton = null
var item_s2: OptionButton = null

var start_btn: Button = null
var surrender_btn: Button = null
var swap_btn: Button = null
var swap_ei: OptionButton = null
var swap_si: OptionButton = null

var log_box: TextEdit = null
var res_label: Label = null

var pending_swap_request: Dictionary = {}
var last_round_winner := ""

func _ready() -> void:
	# resolve scene nodes (use stable scene paths)
	if mode_opt == null:
		mode_opt = get_node_or_null("Scroll/VBox/Grid/Mode")
	if attacker_opt == null:
		attacker_opt = get_node_or_null("Scroll/VBox/Grid/Attacker")
	if defender_opt == null:
		defender_opt = get_node_or_null("Scroll/VBox/Grid/Defender")
	if atk_tech_opt == null:
		atk_tech_opt = get_node_or_null("Scroll/VBox/Grid/AtkTech")
	if def_tech_opt == null:
		def_tech_opt = get_node_or_null("Scroll/VBox/Grid/DefTech")
	if hom_opt == null:
		hom_opt = get_node_or_null("Scroll/VBox/Grid/Homunculus")
	if item_e1 == null:
		item_e1 = get_node_or_null("Scroll/VBox/Grid/ItemEquip1")
	if item_e2 == null:
		item_e2 = get_node_or_null("Scroll/VBox/Grid/ItemEquip2")
	if item_s1 == null:
		item_s1 = get_node_or_null("Scroll/VBox/Grid/ItemSide1")
	if item_s2 == null:
		item_s2 = get_node_or_null("Scroll/VBox/Grid/ItemSide2")
	if swap_ei == null:
		swap_ei = get_node_or_null("Scroll/VBox/Grid/SwapBox/SwapEquipIdx")
	if swap_si == null:
		swap_si = get_node_or_null("Scroll/VBox/Grid/SwapBox/SwapSideIdx")
	if swap_btn == null:
		swap_btn = get_node_or_null("Scroll/VBox/Grid/SwapBox/SwapAfterWin")
	if start_btn == null:
		start_btn = get_node_or_null("Scroll/VBox/Buttons/Start")
	if surrender_btn == null:
		surrender_btn = get_node_or_null("Scroll/VBox/Buttons/Surrender")
	if log_box == null:
		log_box = get_node_or_null("Scroll/VBox/Log")
	if res_label == null:
		res_label = get_node_or_null("Scroll/VBox/Resources")
	add_child(reg)
	add_child(sim)
	add_child(econ)
	reg.load_all()

	_populate()
	_update_resources()

	start_btn.pressed.connect(_on_start)
	surrender_btn.pressed.connect(_on_surrender)
	swap_btn.pressed.connect(_on_set_swap)

	surrender_btn.disabled = true

func _populate() -> void:
	mode_opt.clear()
	mode_opt.add_item("Batalla (Open / Farm)", 0)
	mode_opt.add_item("Competitivo (Fair)", 1)

	attacker_opt.clear()
	defender_opt.clear()
	for eid in reg.entities.keys():
		var e = reg.entities[eid]
		attacker_opt.add_item("%s [%s]" % [e.name, e.type], attacker_opt.item_count)
		attacker_opt.set_item_metadata(attacker_opt.item_count - 1, eid)
		defender_opt.add_item("%s [%s]" % [e.name, e.type], defender_opt.item_count)
		defender_opt.set_item_metadata(defender_opt.item_count - 1, eid)

	atk_tech_opt.clear()
	for t in reg.techniques.get("attack", []):
		atk_tech_opt.add_item(t.name, atk_tech_opt.item_count)
		atk_tech_opt.set_item_metadata(atk_tech_opt.item_count - 1, t.id)

	def_tech_opt.clear()
	for t in reg.techniques.get("defense", []):
		def_tech_opt.add_item(t.name, def_tech_opt.item_count)
		def_tech_opt.set_item_metadata(def_tech_opt.item_count - 1, t.id)

	hom_opt.clear()
	for hid in reg.homunculi.keys():
		var h = reg.homunculi[hid]
		hom_opt.add_item(h.name, hom_opt.item_count)
		hom_opt.set_item_metadata(hom_opt.item_count - 1, hid)

	for ob in [item_e1,item_e2,item_s1,item_s2]:
		ob.clear()
		for iid in reg.items.keys():
			var it = reg.items[iid]
			ob.add_item(it.name, ob.item_count)
			ob.set_item_metadata(ob.item_count - 1, iid)

	swap_ei.clear()
	swap_ei.add_item("Equip 1", 0)
	swap_ei.add_item("Equip 2", 1)
	swap_si.clear()
	swap_si.add_item("Side 1", 0)
	swap_si.add_item("Side 2", 1)

func _get_meta(ob: OptionButton) -> String:
	return str(ob.get_item_metadata(ob.selected))

func _build_loadout(entity_id: String) -> Dictionary:
	return {
		"entity_id": entity_id,
		"equipped_items": [_get_meta(item_e1), _get_meta(item_e2)],
		"sideboard_items": [_get_meta(item_s1), _get_meta(item_s2)],
		"homunculus_id": _get_meta(hom_opt),
		"atk_tech_id": _get_meta(atk_tech_opt),
		"def_tech_id": _get_meta(def_tech_opt),
		"item_levels": {}, # beta: all level 1
		"hom_level": 1,
		"carry_tempo": 0,
		"incoming_mult_next": 1.0,
	}

func _mode_cost() -> Dictionary:
	if mode_opt.selected == 0:
		return {"silver": 5, "copper": 5}
	return {"silver": 3}

func _mode_rewards(win: bool) -> Dictionary:
	# Placeholder; will be refined via remote config later
	if mode_opt.selected == 0:
		# Batalla: more resources + season points
		if win:
			econ.season_points += 10
			return {"player_xp": 8, "silver": 8, "copper": 6}
		else:
			econ.season_points += 2
			return {"player_xp": 3, "silver": 2, "copper": 1}
	else:
		# Competitivo: prestige + more player xp
		if win:
			econ.prestige_points += 12
			return {"player_xp": 12, "silver": 4}
		else:
			econ.prestige_points += 2
			return {"player_xp": 5, "silver": 1}

func _on_start() -> void:
	log_box.text = ""
	pending_swap_request = {}
	last_round_winner = ""

	var cost = _mode_cost()
	if not econ.can_pay(cost):
		log_box.text = "Not enough resources to queue.\nCost: %s\n" % [str(cost)]
		return
	econ.pay(cost)

	var a_id = _get_meta(attacker_opt)
	var b_id = _get_meta(defender_opt)

	var la = _build_loadout(a_id)
	var lb = _build_loadout(b_id)

	# Allow 1 winner-only swap: user can pre-select indices; applied only if A wins a round.
	# This is a simplification for beta UI.
	la.swap_request = null
	lb.swap_request = null
	if not pending_swap_request.is_empty():
		la.swap_request = pending_swap_request

	surrender_btn.disabled = false

	var res = sim.simulate_bo3(reg, la, lb)
	surrender_btn.disabled = true

	var win = (res.winner == "A")
	var rewards = _mode_rewards(win)
	# First win of day bonus
	if win and not econ.daily_first_win_claimed:
		econ.daily_first_win_claimed = true
		for k in rewards.keys():
			rewards[k] = int(round(rewards[k] * 2.0))

	econ.grant(rewards)

	# Print
	log_box.text += "Mode: %s\n" % (mode_opt.get_item_text(mode_opt.selected))
	log_box.text += "Result: %s  Score %d-%d\n" % [("WIN" if win else "LOSS"), res.score_a, res.score_b]
	log_box.text += "Prestige: %d | SeasonPts: %d\n\n" % [econ.prestige_points, econ.season_points]
	for line in res.log:
		log_box.text += line + "\n"
	log_box.text += "\nRewards: %s\n" % str(rewards)
	_update_resources()

func _on_surrender() -> void:
	# Treat as immediate loss; extra penalty
	var penalty = {"silver": 2, "copper": 2}
	if econ.can_pay(penalty):
		econ.pay(penalty)
	econ.season_points += 0
	econ.prestige_points += 0
	log_box.text = "You surrendered. Penalty: %s\n" % str(penalty)
	surrender_btn.disabled = true
	_update_resources()

func _on_set_swap() -> void:
	# Store swap indices for next match (A only, beta simplification)
	pending_swap_request = {"equip_idx": swap_ei.selected, "side_idx": swap_si.selected}
	log_box.text = "Swap set: equip %d <-> side %d (applies only if you win a round)\n" % [swap_ei.selected, swap_si.selected]

func _update_resources() -> void:
	res_label.text = "XP:%d  Silver:%d  Gold:%d  Copper:%d  Diamonds:%d  |  Prestige:%d  Season:%d" % [
		econ.resources.player_xp,
		econ.resources.silver,
		econ.resources.gold,
		econ.resources.copper,
		econ.resources.diamonds,
		econ.prestige_points,
		econ.season_points
	]
