extends Control

## Entity/Homunculus card used by the Loadout grid.
signal picked(kind: String, id: String)

@export var kind: String = "entity" # "entity" or "homunculus" or "item"
@export var id: String = ""
@export var display_name: String = ""

@onready var _btn = null
@onready var _tex = null
@onready var _name = null
@onready var _overlay = null
var _payload_texture: Texture2D = null
var _last_emit_frame: int = -1

func _ready() -> void:
	# Resolve nodes: support both patterns where this script is on a
	# Button root or on a Control that contains a Button child.
	var maybe_btn = get_node_or_null("Button")
	if maybe_btn and maybe_btn.get_class() == "Button":
		_btn = maybe_btn
	elif _btn == null and self.get_class() == "Button":
		_btn = self

	if _btn:
		# Try to find children relative to the Button (Thumb or Icon, Name)
		_tex = _btn.get_node_or_null("Thumb")
		if _tex == null:
			_tex = _btn.get_node_or_null("Icon")
		_name = _btn.get_node_or_null("Name")
		_overlay = get_node_or_null("SelectedOverlay")
		if _overlay == null:
			_overlay = _btn.get_node_or_null("Glow")

		# Connect using Callable for clarity
		_btn.pressed.connect(Callable(self, "_emit_pick"))
		_btn.gui_input.connect(_on_gui_input)
		_btn.mouse_filter = Control.MOUSE_FILTER_STOP

		# Ensure decorative children don't intercept clicks meant for the Button
		if _tex:
			_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Name label should not intercept clicks
		if _name:
			_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Root should not block input if a Button child handles it.
		# If the Button is the root (self), do not set mouse_filter to IGNORE.
		if _btn != self:
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Apply any payload values that were set prior to _ready
		if display_name != "" and _name:
			_name.text = display_name
		if _payload_texture and _tex:
			_tex.texture = _payload_texture
	else:
		# No Button child: capture clicks on this Control itself.
		_tex = get_node_or_null("Thumb")
		_name = get_node_or_null("Name")
		_overlay = get_node_or_null("SelectedOverlay")
		if _overlay == null:
			_overlay = get_node_or_null("Glow")

		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)

func set_payload(p_kind: String, p_id: String, p_name: String, p_texture: Texture2D) -> void:
	kind = p_kind
	id = p_id
	display_name = p_name
	# store texture in case _ready() hasn't run yet
	_payload_texture = p_texture
	if _name:
		_name.text = p_name
	if _tex and p_texture:
		_tex.texture = p_texture

func set_selected(v: bool) -> void:
	if _overlay:
		_overlay.visible = v

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_emit_pick()

func _emit_pick() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_emit_frame:
		return
	_last_emit_frame = frame
	if id == "":
		return
	emit_signal("picked", kind, id)
