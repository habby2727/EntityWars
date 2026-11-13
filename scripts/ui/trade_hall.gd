extends Control
class_name TradeHall

@export var backend_path: NodePath
@export var panel_path: NodePath
@export var back_button_path: NodePath
@export var tabs_path: NodePath

@export var market_filter_path: NodePath
@export var market_refresh_path: NodePath
@export var market_orders_list_path: NodePath
@export var sell_resource_path: NodePath
@export var sell_amount_path: NodePath
@export var sell_price_path: NodePath
@export var sell_create_button_path: NodePath
@export var sell_error_label_path: NodePath
@export var my_orders_list_path: NodePath

@export var jobs_list_path: NodePath
@export var runs_list_path: NodePath
@export var trade_refresh_path: NodePath
@export var job_input_option_path: NodePath
@export var job_input_amount_path: NodePath
@export var job_output_option_path: NodePath
@export var job_output_min_path: NodePath
@export var job_output_max_path: NodePath
@export var job_duration_path: NodePath
@export var job_commission_option_path: NodePath
@export var job_commission_amount_path: NodePath
@export var job_queue_limit_path: NodePath
@export var job_create_button_path: NodePath
@export var job_error_label_path: NodePath

const RUNS_PATH := "user://trade_runs.json"
const MenuArt := preload("res://scripts/ui/menu_art.gd")

var _backend: BackendClient = null
var _panel: Panel = null
var _back_button: Button = null
var _tabs: TabContainer = null

var _market_filter: OptionButton = null
var _market_refresh: Button = null
var _market_orders_list: VBoxContainer = null
var _sell_resource: OptionButton = null
var _sell_amount: LineEdit = null
var _sell_price: LineEdit = null
var _sell_create_button: Button = null
var _sell_error_label: Label = null
var _my_orders_list: VBoxContainer = null

var _jobs_list: VBoxContainer = null
var _runs_list: VBoxContainer = null
var _trade_refresh: Button = null
var _job_input_option: OptionButton = null
var _job_input_amount: LineEdit = null
var _job_output_option: OptionButton = null
var _job_output_min: LineEdit = null
var _job_output_max: LineEdit = null
var _job_duration: LineEdit = null
var _job_commission_option: OptionButton = null
var _job_commission_amount: LineEdit = null
var _job_queue_limit: LineEdit = null
var _job_create_button: Button = null
var _job_error_label: Label = null

var _catalog := AssetCatalog.new()
var _db := StaticDB.new()
var _state: Dictionary = {}
var _npc_list: VBoxContainer
var _npc_status: Label
var _npc_daily_timer: Label
var _npc_weekly_timer: Label
var _npc_confirm: ConfirmationDialog
var _npc_offers: Array = []
var _npc_selected: Dictionary = {}
var _npc_buttons: Array[Button] = []
var _npc_server_ms := 0
var _npc_received_tick := 0
var _npc_next_daily := 0
var _npc_next_weekly := 0
var _npc_fetch_pending := false
var _npc_rotation_requested := false
var _npc_expired := false
var _npc_elapsed := 0.0
var _npc_feedback := ""
var _npc_preview := false
var _player_id: String = ""
var _ui_scale := 1.0

const CONTENT_BASE_SIZE := Vector2(1400, 660)

var _requests: Dictionary = {}
var _busy := false
var _api_queue: Array = []

var _orders: Array = []
var _my_orders: Array = []
var _jobs: Array = []
var _runs: Dictionary = {}
var _run_rows: Dictionary = {}

func _ready() -> void:
	_ui_scale = _compute_panel_scale()
	UIThemeFactory.apply_theme_scaled(self, _ui_scale)
	_resolve_nodes()
	_apply_panel_background()
	_apply_trade_layout()
	_connect_backend()
	_connect_buttons()
	_build_resource_options()
	_build_npc_exchange()
	_load_state()
	_load_runs()
	_request_market_orders()
	_request_my_orders()
	_request_trade_jobs()
	_request_npc_offers()
	_refresh_runs()

func _process(_delta: float) -> void:
	_update_run_countdowns()
	_npc_elapsed += _delta
	if _npc_elapsed >= 1.0:
		_npc_elapsed = 0.0
		_update_npc_timers()

func _resolve_nodes() -> void:
	_backend = get_node_or_null(backend_path) as BackendClient
	_panel = get_node_or_null(panel_path) as Panel
	_back_button = get_node_or_null(back_button_path) as Button
	_tabs = get_node_or_null(tabs_path) as TabContainer

	_market_filter = get_node_or_null(market_filter_path) as OptionButton
	_market_refresh = get_node_or_null(market_refresh_path) as Button
	_market_orders_list = get_node_or_null(market_orders_list_path) as VBoxContainer
	_sell_resource = get_node_or_null(sell_resource_path) as OptionButton
	_sell_amount = get_node_or_null(sell_amount_path) as LineEdit
	_sell_price = get_node_or_null(sell_price_path) as LineEdit
	_sell_create_button = get_node_or_null(sell_create_button_path) as Button
	_sell_error_label = get_node_or_null(sell_error_label_path) as Label
	_my_orders_list = get_node_or_null(my_orders_list_path) as VBoxContainer

	_jobs_list = get_node_or_null(jobs_list_path) as VBoxContainer
	_runs_list = get_node_or_null(runs_list_path) as VBoxContainer
	_trade_refresh = get_node_or_null(trade_refresh_path) as Button
	_job_input_option = get_node_or_null(job_input_option_path) as OptionButton
	_job_input_amount = get_node_or_null(job_input_amount_path) as LineEdit
	_job_output_option = get_node_or_null(job_output_option_path) as OptionButton
	_job_output_min = get_node_or_null(job_output_min_path) as LineEdit
	_job_output_max = get_node_or_null(job_output_max_path) as LineEdit
	_job_duration = get_node_or_null(job_duration_path) as LineEdit
	_job_commission_option = get_node_or_null(job_commission_option_path) as OptionButton
	_job_commission_amount = get_node_or_null(job_commission_amount_path) as LineEdit
	_job_queue_limit = get_node_or_null(job_queue_limit_path) as LineEdit
	_job_create_button = get_node_or_null(job_create_button_path) as Button
	_job_error_label = get_node_or_null(job_error_label_path) as Label
	_apply_input_scaling()

func _apply_input_scaling() -> void:
	var small = int(round(70.0 * _ui_scale))
	var medium = int(round(80.0 * _ui_scale))
	if _job_input_amount != null:
		_job_input_amount.custom_minimum_size = Vector2(medium, 0)
	if _job_output_min != null:
		_job_output_min.custom_minimum_size = Vector2(small, 0)
	if _job_output_max != null:
		_job_output_max.custom_minimum_size = Vector2(small, 0)
	if _job_commission_amount != null:
		_job_commission_amount.custom_minimum_size = Vector2(medium, 0)

func _apply_panel_background() -> void:
	if _panel == null:
		return
	var tex: Texture2D = load(MenuArt.DIR + "fondo-menus-edificios-laboratorio.png")
	if tex == null:
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_panel.add_theme_stylebox_override("panel", sb)

func _apply_trade_layout() -> void:
	var margin := _panel.get_node_or_null("Margin") as MarginContainer
	if margin:
		for side in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 110)
		for side in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 78)
	var header := _panel.get_node_or_null("Margin/RootVBox/Header") as HBoxContainer
	if header:
		var title := header.get_node("Title") as Label
		var spacer := header.get_node("Spacer") as Control
		spacer.hide()
		var left := Control.new()
		left.custom_minimum_size.x = 140
		header.add_child(left)
		header.move_child(left, 0)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_button.custom_minimum_size = Vector2(140, 44)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.045, 0.78)
	_tabs.add_theme_stylebox_override("panel", panel_style)
	var tab_bar := _tabs.get_tab_bar()
	if tab_bar.has_method("set_tab_alignment"):
		tab_bar.call("set_tab_alignment", 1)
	if _tabs.get_tab_count() > 1:
		_tabs.set_tab_title(1, "Trade Jobs")
	for path in ["Market/Scroll", "TradeJobs/Scroll"]:
		var scroll := _tabs.get_node_or_null(path) as ScrollContainer
		if scroll == null or scroll.get_child_count() == 0:
			continue
		var content := scroll.get_child(0) as Control
		if content == null:
			continue
		scroll.remove_child(content)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var centered := HBoxContainer.new()
		centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(centered)
		var left_space := Control.new()
		left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		centered.add_child(left_space)
		content.custom_minimum_size.x = 900
		content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		centered.add_child(content)
		var right_space := Control.new()
		right_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		centered.add_child(right_space)
	for button in [_sell_create_button, _job_create_button]:
		if button:
			button.custom_minimum_size.x = 230
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in find_children("*", "Button", true, false):
		if child is Button and not child is OptionButton:
			MenuArt.button(child)
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 42)

func _connect_backend() -> void:
	if _backend == null:
		return
	_backend.api_completed.connect(_on_api_completed)
	_backend.state_updated.connect(_on_state_updated)
	_backend.auth_changed.connect(_npc_auth_changed)

func _connect_buttons() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _market_refresh != null:
		_market_refresh.pressed.connect(_on_refresh_market_pressed)
	if _sell_create_button != null:
		_sell_create_button.pressed.connect(_on_create_sell_pressed)
	if _job_create_button != null:
		_job_create_button.pressed.connect(_on_create_job_pressed)
	if _trade_refresh != null:
		_trade_refresh.pressed.connect(_on_refresh_trade_pressed)
	if _market_filter != null:
		_market_filter.item_selected.connect(_on_market_filter_changed)

func _load_state() -> void:
	_state = {}
	if _backend != null:
		_state = _backend.load_cached_state()
	if typeof(_state) != TYPE_DICTIONARY:
		_state = {}
	_player_id = str(_state.get("player_id", ""))

func _build_resource_options() -> void:
	var resources = _get_resource_entries()
	_setup_option(_market_filter, resources, true)
	_setup_option(_sell_resource, resources, false)
	_setup_option(_job_input_option, resources, false)
	_setup_option(_job_output_option, resources, false)
	_setup_option(_job_commission_option, resources, false)

func _setup_option(option: OptionButton, resources: Array, include_all: bool) -> void:
	if option == null:
		return
	option.clear()
	var idx := 0
	if include_all:
		option.add_item("All")
		option.set_item_metadata(idx, "")
		idx += 1
	for entry in resources:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var display_name = str(entry.get("name", entry.get("id", "")))
		var id = str(entry.get("id", ""))
		if id == "":
			continue
		option.add_item(display_name)
		option.set_item_metadata(idx, id)
		idx += 1
	option.select(0)

func _get_resource_entries() -> Array:
	var out: Array = []
	if typeof(_db.resources) == TYPE_DICTIONARY:
		for id in _db.resources.keys():
			var entry = _db.resources[id]
			if typeof(entry) != TYPE_DICTIONARY:
				entry = {"id": id, "name": str(id)}
			var display_name = str(entry.get("display_name", entry.get("name", id)))
			out.append({"id": id, "name": display_name})
	out.sort_custom(Callable(self, "_sort_by_name"))
	return out

func _sort_by_name(a: Variant, b: Variant) -> bool:
	return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()

func _on_back_pressed() -> void:
	if _back_button != null:
		_back_button.disabled = true
	SceneRouter.go_to_lab()

func _on_refresh_market_pressed() -> void:
	_request_market_orders()

func _on_refresh_trade_pressed() -> void:
	_request_trade_jobs()

func _on_market_filter_changed(_idx: int) -> void:
	_request_market_orders()

func _request_market_orders() -> void:
	if _backend == null:
		return
	var resource_id := _get_option_id(_market_filter)
	var path := "/market/orders?status=OPEN"
	if resource_id != "":
		path += "&resource_id=%s" % resource_id
	_send_api_request("GET", path, null, "market_orders", false)

func _request_my_orders() -> void:
	if _backend == null:
		return
	if _player_id == "":
		return
	var path := "/market/orders?status=OPEN&seller_id=%s" % _player_id
	_send_api_request("GET", path, null, "market_my_orders", false)

func _request_trade_jobs() -> void:
	if _backend == null:
		return
	var path := "/trade/jobs?status=OPEN"
	_send_api_request("GET", path, null, "trade_jobs", false)

func _build_npc_exchange() -> void:
	if _tabs == null:
		return
	var scroll := ScrollContainer.new()
	scroll.name = "NPC Exchange"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	_npc_list = VBoxContainer.new()
	_npc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_list.add_theme_constant_override("separation", 8)
	margin.add_child(_npc_list)
	_npc_confirm = ConfirmationDialog.new()
	_npc_confirm.title = "Confirm NPC exchange"
	_npc_confirm.confirmed.connect(_confirm_npc_buy)
	add_child(_npc_confirm)
	_render_npc_offers()

func _npc_auth_changed(token: String) -> void:
	_npc_offers.clear()
	_npc_expired = true
	if token == "":
		if not _show_debug_npc_preview("Backend sign-in required") and is_instance_valid(_npc_status):
			_npc_status.text = "Sign in to use NPC Exchange."
		_update_npc_buttons()
	else:
		_request_npc_offers()

func _request_npc_offers() -> void:
	if _npc_fetch_pending:
		return
	if _backend == null or _backend.token == "":
		_show_debug_npc_preview("Backend sign-in required")
		return
	_npc_fetch_pending = true
	_send_api_request("GET", "/trade/npc/offers", null, "npc_offers", false)

func _show_debug_npc_preview(reason: String) -> bool:
	var debug := DebugFlags.new()
	var enabled := debug.unlock_all_buildings
	debug.free()
	if not enabled:
		return false
	var daily: Variant = _db.get_balance("npc_trade_daily", [])
	var weekly: Variant = _db.get_balance("npc_trade_weekly", [])
	if not daily is Array or daily.size() != 8 or not weekly is Array or weekly.size() != 6:
		return false
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	var day := int(floor(float(now) / 86400000.0))
	var week := int(floor(float(day + 3) / 7.0))
	_npc_offers.clear()
	for i in range(3):
		var offer: Dictionary = daily[(day + 3 * i) % daily.size()].duplicate(true)
		offer.merge({"period": "daily", "period_key": day, "max": 2, "remaining": 0}, true)
		_npc_offers.append(offer)
	for i in range(2):
		var offer: Dictionary = weekly[(week + 2 * i) % weekly.size()].duplicate(true)
		offer.merge({"period": "weekly", "period_key": week, "max": 1, "remaining": 0}, true)
		_npc_offers.append(offer)
	_npc_preview = true
	_npc_expired = true
	_npc_feedback = "Local debug preview: %s. Connect an updated backend to purchase; availability is unverified." % reason
	_npc_server_ms = now
	_npc_received_tick = Time.get_ticks_msec()
	_npc_next_daily = (day + 1) * 86400000
	_npc_next_weekly = ((week + 1) * 7 - 3) * 86400000
	_npc_rotation_requested = false
	_render_npc_offers()
	_update_npc_timers()
	return true

func _npc_amount_text(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	for id in amounts:
		var resource: Dictionary = _db.resources.get(id, {})
		parts.append("%d %s" % [int(amounts[id]), str(resource.get("display_name", resource.get("name", id)))])
	return ", ".join(parts)

func _render_npc_offers() -> void:
	if not is_instance_valid(_npc_list):
		return
	for child in _npc_list.get_children():
		_npc_list.remove_child(child)
		child.queue_free()
	_npc_buttons.clear()
	_npc_status = Label.new()
	_npc_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_status.text = _npc_feedback if _npc_feedback != "" else ("" if not _npc_offers.is_empty() else ("Loading offers..." if _backend != null and _backend.token != "" else "Sign in to use NPC Exchange."))
	_npc_list.add_child(_npc_status)
	for period in ["daily", "weekly"]:
		var heading := Label.new()
		heading.text = "Daily offers" if period == "daily" else "Weekly offers"
		heading.add_theme_font_size_override("font_size", 20)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_npc_list.add_child(heading)
		var timer := Label.new()
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_npc_list.add_child(timer)
		if period == "daily":
			_npc_daily_timer = timer
		else:
			_npc_weekly_timer = timer
		for offer in _npc_offers:
			if not offer is Dictionary or str(offer.get("period", "")) != period:
				continue
			var background := PanelContainer.new()
			var row_style := StyleBoxFlat.new()
			row_style.bg_color = Color(0.02, 0.09, 0.10, 0.88)
			row_style.border_color = Color(0.42, 0.47, 0.32, 0.85)
			row_style.set_border_width_all(1)
			row_style.set_content_margin_all(8)
			background.add_theme_stylebox_override("panel", row_style)
			_npc_list.add_child(background)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			background.add_child(row)
			var label := Label.new()
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.text = "%s -> %s   |   %s" % [_npc_amount_text(offer.get("pay", {})), _npc_amount_text(offer.get("receive", {})), "Availability unverified" if _npc_preview else "%d / %d remaining" % [int(offer.get("remaining", 0)), int(offer.get("max", 0))]]
			row.add_child(label)
			var button := Button.new()
			button.text = "Buy"
			button.custom_minimum_size = Vector2(120, 42)
			MenuArt.button(button)
			button.set_meta("offer", offer)
			button.pressed.connect(_request_npc_buy.bind(offer))
			row.add_child(button)
			_npc_buttons.append(button)
	_update_npc_buttons()

func _update_npc_buttons() -> void:
	var wallet: Dictionary = _state.get("wallet", {})
	for button in _npc_buttons:
		if not is_instance_valid(button):
			continue
		var offer: Dictionary = button.get_meta("offer", {})
		var affordable := true
		for resource in offer.get("pay", {}):
			if int(wallet.get(resource, 0)) < int(offer.pay[resource]):
				affordable = false
		var lab: Dictionary = _state.get("lab", {})
		var available := int(lab.get("hqLevel", 0)) >= 2 and int(lab.get("buildings", {}).get("trade_hall", {}).get("level", 0)) >= 1
		button.disabled = _busy or _npc_fetch_pending or _npc_expired or _backend == null or _backend.token == "" or int(offer.get("remaining", 0)) <= 0 or not affordable or not available

func _update_npc_timers() -> void:
	if _npc_server_ms <= 0:
		return
	var now := _npc_server_ms + Time.get_ticks_msec() - _npc_received_tick
	if is_instance_valid(_npc_daily_timer):
		_npc_daily_timer.text = ("Local rotation in " if _npc_preview else "Rotation in ") + _npc_clock(maxi(0, _npc_next_daily - now))
	if is_instance_valid(_npc_weekly_timer):
		_npc_weekly_timer.text = ("Local rotation in " if _npc_preview else "Rotation in ") + _npc_clock(maxi(0, _npc_next_weekly - now))
	if (_npc_next_daily > 0 and now >= _npc_next_daily) or (_npc_next_weekly > 0 and now >= _npc_next_weekly):
		_npc_expired = true
		_update_npc_buttons()
		if not _npc_rotation_requested:
			_npc_rotation_requested = true
			if _npc_preview and (_backend == null or _backend.token == ""):
				_show_debug_npc_preview("Backend sign-in required")
			else:
				_request_npc_offers()

func _npc_clock(milliseconds: int) -> String:
	var seconds := int(ceil(float(milliseconds) / 1000.0))
	return "%02d:%02d:%02d" % [int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]

func _request_npc_buy(offer: Dictionary) -> void:
	if _busy or _npc_expired or _npc_fetch_pending:
		return
	_npc_selected = offer.duplicate(true)
	_npc_confirm.dialog_text = "Exchange %s for %s?" % [_npc_amount_text(offer.get("pay", {})), _npc_amount_text(offer.get("receive", {}))]
	_npc_confirm.popup_centered()

func _confirm_npc_buy() -> void:
	_update_npc_buttons()
	for button in _npc_buttons:
		if button.get_meta("offer", {}) == _npc_selected and not button.disabled:
			var body := {"client_action_id": _backend._make_uuid(), "action_type": "NPC_TRADE", "payload": {"offer_id": _npc_selected.get("id", ""), "period_key": _npc_selected.get("period_key", -1)}}
			_send_api_request("POST", "/player/action", body, "npc_buy", true)
			return

func _send_api_request(method: String, path: String, body: Variant, kind: String, expect_state: bool, extra: Dictionary = {}) -> void:
	if _backend == null:
		return
	if _busy:
		_api_queue.append({
			"method": method,
			"path": path,
			"body": body,
			"kind": kind,
			"expect_state": expect_state,
			"extra": extra
		})
		return
	var request_id = _backend.request_api(method, path, body, expect_state)
	if request_id == "":
		if kind == "npc_offers":
			_npc_fetch_pending = false
			if _show_debug_npc_preview("Backend unavailable"):
				return
		if kind.begins_with("npc_") and is_instance_valid(_npc_status):
			_npc_status.text = "Request busy or offline."
		_set_error(kind, "Request busy or offline.")
		return
	var info = {"kind": kind}
	for key in extra.keys():
		info[key] = extra[key]
	_requests[request_id] = info
	_set_busy(true)

func _on_api_completed(request_id: String, ok: bool, data: Dictionary) -> void:
	var info = _requests.get(request_id, {})
	var request_kind := str(info.get("kind", ""))
	_requests.erase(request_id)
	if request_kind == "npc_offers":
		_npc_fetch_pending = false
	_set_busy(false)
	_flush_api_queue()
	if not ok:
		var msg = str(data.get("error", "Request failed"))
		if request_kind == "npc_offers" and _show_debug_npc_preview("NPC exchange unavailable on backend"):
			return
		if request_kind.begins_with("npc_") and is_instance_valid(_npc_status):
			_npc_feedback = "Exchange: " + msg
			_npc_status.text = "Exchange: " + msg
		_set_error(str(info.get("kind", "")), msg)
		return
	var kind = str(info.get("kind", ""))
	if kind == "market_orders":
		_orders = data.get("orders", [])
		_refresh_orders()
	elif kind == "market_my_orders":
		_my_orders = data.get("orders", [])
		_refresh_my_orders()
	elif kind == "market_order_create" or kind == "market_order_cancel" or kind == "market_buy":
		_orders = data.get("orders", _orders)
		_request_market_orders()
		_request_my_orders()
	elif kind == "trade_jobs":
		_jobs = data.get("jobs", [])
		_refresh_jobs()
	elif kind == "trade_job_create" or kind == "trade_submit" or kind == "trade_claim":
		if kind == "trade_submit":
			_on_trade_submit_success(data, info)
		if kind == "trade_claim":
			_on_trade_claim_success(data, info)
		_request_trade_jobs()
		_refresh_runs()
	elif kind == "npc_offers":
		_npc_offers = data.get("offers", [])
		_npc_preview = false
		_npc_server_ms = int(data.get("server_time_unix_ms", 0))
		_npc_received_tick = Time.get_ticks_msec()
		_npc_next_daily = int(data.get("next_daily_at", 0))
		_npc_next_weekly = int(data.get("next_weekly_at", 0))
		_npc_rotation_requested = false
		_npc_expired = false
		if _npc_feedback.begins_with("Exchange:"):
			_npc_feedback = ""
		_render_npc_offers()
		_update_npc_timers()
	elif kind == "npc_buy":
		_npc_feedback = "Exchange confirmed."
		_npc_status.text = "Exchange confirmed."
		_request_npc_offers()

func _set_busy(value: bool) -> void:
	_busy = value
	_apply_busy_to_buttons()

func _flush_api_queue() -> void:
	if _busy:
		return
	if _api_queue.is_empty():
		return
	var next = _api_queue.pop_front()
	if typeof(next) != TYPE_DICTIONARY:
		return
	_send_api_request(
		str(next.get("method", "GET")),
		str(next.get("path", "")),
		next.get("body", null),
		str(next.get("kind", "")),
		bool(next.get("expect_state", false)),
		next.get("extra", {})
	)

func _apply_busy_to_buttons() -> void:
	if _market_refresh != null:
		_market_refresh.disabled = _busy
	if _trade_refresh != null:
		_trade_refresh.disabled = _busy
	if _sell_create_button != null:
		_sell_create_button.disabled = _busy
	if _job_create_button != null:
		_job_create_button.disabled = _busy
	_update_dynamic_buttons()
	_update_npc_buttons()

func _update_dynamic_buttons() -> void:
	# Dynamic buttons are rebuilt in refresh methods using current busy flag.
	_refresh_orders()
	_refresh_jobs()
	_refresh_runs()

func _on_create_sell_pressed() -> void:
	_clear_error("market")
	if _backend == null:
		return
	var resource_id := _get_option_id(_sell_resource)
	if resource_id == "":
		_set_error("market", "Choose a resource.")
		return
	var amount = _parse_int(_sell_amount, 1, 1_000_000)
	if amount <= 0:
		_set_error("market", "Invalid amount.")
		return
	var price = _parse_int(_sell_price, 1, 1_000_000_000)
	if price <= 0:
		_set_error("market", "Invalid price.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"type": "SELL",
		"resource_id": resource_id,
		"amount": amount,
		"price_resource_id": "essence",
		"price_amount": price
	}
	_send_api_request("POST", "/market/order", body, "market_order_create", true)

func _on_create_job_pressed() -> void:
	_clear_error("trade")
	if _backend == null:
		return
	var input_id := _get_option_id(_job_input_option)
	var output_id := _get_option_id(_job_output_option)
	var commission_id := _get_option_id(_job_commission_option)
	if input_id == "" or output_id == "" or commission_id == "":
		_set_error("trade", "Select resources.")
		return
	var input_amount = _parse_int(_job_input_amount, 1, 1_000_000)
	var output_min = _parse_int(_job_output_min, 1, 1_000_000)
	var output_max = _parse_int(_job_output_max, 1, 1_000_000)
	var duration = _parse_int(_job_duration, 0, 604800)
	var commission_amount = _parse_int(_job_commission_amount, 0, 1_000_000)
	var queue_limit = _parse_int(_job_queue_limit, 1, 100)
	if input_amount <= 0:
		_set_error("trade", "Invalid input amount.")
		return
	if output_min <= 0 or output_max <= 0 or output_min > output_max:
		_set_error("trade", "Invalid output range.")
		return
	if queue_limit <= 0:
		_set_error("trade", "Invalid queue limit.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"input_resource_id": input_id,
		"input_amount": input_amount,
		"output_resource_id": output_id,
		"output_min": output_min,
		"output_max": output_max,
		"duration_sec": duration,
		"commission_resource_id": commission_id,
		"commission_amount": commission_amount,
		"queue_limit": queue_limit
	}
	_send_api_request("POST", "/trade/jobs", body, "trade_job_create", true)

func _refresh_orders() -> void:
	if _market_orders_list == null:
		return
	_clear_container(_market_orders_list)
	var orders = _orders if typeof(_orders) == TYPE_ARRAY else []
	for entry in orders:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var slot := UIThemeFactory.make_icon_slot()
		var slot_size = int(round(26.0 * _ui_scale))
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var icon = slot.get_node_or_null("Icon")
		var res_id = str(entry.get("resource_id", ""))
		if icon is TextureRect and res_id != "":
			icon.texture = _catalog.get_tex(res_id)
		var amount = int(entry.get("remaining", entry.get("amount", 0)))
		var price = int(entry.get("price_amount", 0))
		var price_res = str(entry.get("price_resource_id", "essence"))
		var info := Label.new()
		info.text = "%s x%s @ %s %s" % [res_id, amount, price, price_res]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qty := LineEdit.new()
		qty.custom_minimum_size = Vector2(int(round(60.0 * _ui_scale)), 0)
		qty.placeholder_text = "Qty"
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		MenuArt.button(buy_btn)
		buy_btn.disabled = _busy
		buy_btn.pressed.connect(_on_buy_pressed.bind(entry, qty))
		row.add_child(slot)
		row.add_child(info)
		row.add_child(qty)
		row.add_child(buy_btn)
		_market_orders_list.add_child(row)
	_refresh_my_orders()

func _refresh_my_orders() -> void:
	if _my_orders_list == null:
		return
	_clear_container(_my_orders_list)
	if _player_id == "":
		return
	var source = _my_orders if typeof(_my_orders) == TYPE_ARRAY and _my_orders.size() > 0 else _orders
	for entry in source:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("seller_id", "")) != _player_id:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = "%s x%s @ %s" % [
			str(entry.get("resource_id", "")),
			str(entry.get("remaining", entry.get("amount", 0))),
			str(entry.get("price_amount", 0))
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		MenuArt.button(cancel_btn)
		cancel_btn.disabled = _busy
		cancel_btn.pressed.connect(_on_cancel_order_pressed.bind(entry))
		row.add_child(label)
		row.add_child(cancel_btn)
		_my_orders_list.add_child(row)

func _refresh_jobs() -> void:
	if _jobs_list == null:
		return
	_clear_container(_jobs_list)
	for entry in _jobs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var out_res = str(entry.get("output_resource_id", ""))
		var out_min = int(entry.get("output_min", 0))
		var out_max = int(entry.get("output_max", 0))
		var duration = int(entry.get("duration_sec", 0))
		var commission = int(entry.get("commission_amount", 0))
		var commission_res = str(entry.get("commission_resource_id", "essence"))
		var label := Label.new()
		label.text = "%s %s-%s | %ss | Fee %s %s" % [out_res, out_min, out_max, duration, commission, commission_res]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var submit_btn := Button.new()
		submit_btn.text = "Submit"
		MenuArt.button(submit_btn)
		submit_btn.disabled = _busy or not _can_submit_job(entry)
		submit_btn.pressed.connect(_on_submit_job_pressed.bind(entry))
		row.add_child(label)
		row.add_child(submit_btn)
		_jobs_list.add_child(row)

func _refresh_runs() -> void:
	if _runs_list == null:
		return
	_clear_container(_runs_list)
	_run_rows.clear()
	for run_id in _runs.keys():
		var entry = _runs[run_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var claim_btn := Button.new()
		claim_btn.text = "Claim"
		MenuArt.button(claim_btn)
		claim_btn.disabled = _busy
		claim_btn.pressed.connect(_on_claim_run_pressed.bind(run_id))
		row.add_child(claim_btn)
		_runs_list.add_child(row)
		_run_rows[run_id] = {"label": label, "button": claim_btn}
	_update_run_countdowns()

func _update_run_countdowns() -> void:
	var now = Time.get_unix_time_from_system() * 1000
	for run_id in _run_rows.keys():
		var row = _run_rows[run_id]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var label: Label = row.get("label", null)
		var button: Button = row.get("button", null)
		var entry = _runs.get(run_id, {})
		var completes_at = int(entry.get("completes_at", 0))
		var remaining = max(0, completes_at - now)
		var output_res = str(entry.get("output_resource_id", ""))
		var title = output_res if output_res != "" else run_id
		if label != null:
			if remaining > 0:
				label.text = "%s | Ready in %s" % [title, _format_seconds(remaining)]
			else:
				label.text = "%s | Ready" % title
		if button != null:
			button.disabled = _busy or remaining > 0

func _on_buy_pressed(order: Dictionary, qty_input: LineEdit) -> void:
	_clear_error("market")
	if _backend == null:
		return
	var order_id = str(order.get("order_id", ""))
	if order_id == "":
		_set_error("market", "Invalid order.")
		return
	var remaining = int(order.get("remaining", order.get("amount", 0)))
	var qty = _parse_int(qty_input, 1, remaining)
	if qty <= 0:
		_set_error("market", "Invalid quantity.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"order_id": order_id,
		"amount": qty
	}
	_send_api_request("POST", "/market/buy", body, "market_buy", true)

func _on_cancel_order_pressed(order: Dictionary) -> void:
	_clear_error("market")
	if _backend == null:
		return
	var order_id = str(order.get("order_id", ""))
	if order_id == "":
		_set_error("market", "Invalid order.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"order_id": order_id
	}
	_send_api_request("POST", "/market/cancel", body, "market_order_cancel", true)

func _on_submit_job_pressed(job: Dictionary) -> void:
	_clear_error("trade")
	if _backend == null:
		return
	var job_id = str(job.get("job_id", ""))
	if job_id == "":
		_set_error("trade", "Invalid job.")
		return
	var body = {
		"client_action_id": _make_client_id(),
		"job_id": job_id
	}
	_send_api_request("POST", "/trade/submit", body, "trade_submit", true, {"job_id": job_id})

func _on_claim_run_pressed(run_id: String) -> void:
	_clear_error("trade")
	if _backend == null:
		return
	if run_id == "":
		return
	var body = {
		"client_action_id": _make_client_id(),
		"run_id": run_id
	}
	_send_api_request("POST", "/trade/claim", body, "trade_claim", true, {"run_id": run_id})

func _on_trade_submit_success(data: Dictionary, info: Dictionary) -> void:
	var run_id = str(data.get("run_id", ""))
	if run_id == "":
		return
	var completes_at = int(data.get("completes_at", 0))
	var job_id := str(info.get("job_id", ""))
	if job_id == "":
		job_id = _last_job_id()
	var job_info := _find_job(job_id)
	var output_res := ""
	if typeof(job_info) == TYPE_DICTIONARY:
		output_res = str(job_info.get("output_resource_id", ""))
	_runs[run_id] = {
		"job_id": job_id,
		"completes_at": completes_at,
		"output_resource_id": output_res
	}
	_save_runs()

func _on_trade_claim_success(_data: Dictionary, info: Dictionary) -> void:
	var run_id = str(info.get("run_id", ""))
	if run_id == "":
		return
	if _runs.has(run_id):
		_runs.erase(run_id)
		_save_runs()

func _last_job_id() -> String:
	if _jobs.size() == 0:
		return ""
	var last = _jobs[_jobs.size() - 1]
	if typeof(last) == TYPE_DICTIONARY:
		return str(last.get("job_id", ""))
	return ""

func _find_job(job_id: String) -> Dictionary:
	for entry in _jobs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("job_id", "")) == job_id:
			return entry
	return {}

func _load_runs() -> void:
	_runs.clear()
	if not FileAccess.file_exists(RUNS_PATH):
		return
	var f = FileAccess.open(RUNS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var run_id = str(entry.get("run_id", ""))
		if run_id == "":
			continue
		_runs[run_id] = entry

func _save_runs() -> void:
	var list: Array = []
	for run_id in _runs.keys():
		var entry = _runs[run_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data = entry.duplicate(true)
		data["run_id"] = run_id
		list.append(data)
	var f = FileAccess.open(RUNS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(list))
	f.close()

func _can_submit_job(job: Dictionary) -> bool:
	if typeof(job) != TYPE_DICTIONARY:
		return false
	var wallet = _state.get("wallet", {})
	if typeof(wallet) != TYPE_DICTIONARY:
		return true
	var input_id = str(job.get("input_resource_id", ""))
	var input_amount = int(job.get("input_amount", 0))
	var commission_id = str(job.get("commission_resource_id", ""))
	var commission_amount = int(job.get("commission_amount", 0))
	if input_id != "" and int(wallet.get(input_id, 0)) < input_amount:
		return false
	if commission_amount > 0 and commission_id != "" and int(wallet.get(commission_id, 0)) < commission_amount:
		return false
	return true

func _on_state_updated(state: Dictionary) -> void:
	var previous_player := _player_id
	_state = state
	_player_id = str(state.get("player_id", ""))
	if previous_player != "" and previous_player != _player_id:
		_npc_offers.clear()
		_npc_expired = true
		_npc_feedback = ""
		_render_npc_offers()
		_request_npc_offers()
	_refresh_jobs()
	_refresh_orders()
	_request_my_orders()
	_update_npc_buttons()

func _get_option_id(option: OptionButton) -> String:
	if option == null or option.item_count == 0:
		return ""
	return str(option.get_item_metadata(option.selected))

func _parse_int(line_edit: LineEdit, min_value: int, max_value: int) -> int:
	if line_edit == null:
		return 0
	var raw = str(line_edit.text).strip_edges()
	if raw == "":
		return 0
	if not raw.is_valid_int():
		return 0
	var value = int(raw)
	value = clamp(value, min_value, max_value)
	return value

func _make_client_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x" % rng.randi()

func _set_error(kind: String, message: String) -> void:
	if kind.begins_with("market"):
		if _sell_error_label != null:
			_sell_error_label.text = message
	elif kind.begins_with("trade"):
		if _job_error_label != null:
			_job_error_label.text = message

func _clear_error(kind: String) -> void:
	if kind == "market" and _sell_error_label != null:
		_sell_error_label.text = ""
	if kind == "trade" and _job_error_label != null:
		_job_error_label.text = ""

func _clear_container(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _format_seconds(ms: float) -> String:
	var total = int(ceil(ms / 1000.0))
	if total < 0:
		total = 0
	var minutes = int(total / 60.0)
	var seconds = total % 60
	if minutes > 0:
		return "%dm %02ds" % [minutes, seconds]
	return "%ds" % total

func _compute_panel_scale() -> float:
	var view = get_viewport_rect().size
	var content = Vector2(max(1.0, view.x - 200.0), max(1.0, view.y - 240.0))
	var ui_scale = min(content.x / CONTENT_BASE_SIZE.x, content.y / CONTENT_BASE_SIZE.y)
	return clamp(ui_scale, 0.9, 1.35)
