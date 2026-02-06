extends Button
class_name BuildingCard

@export var icon_frame_path: NodePath
@export var icon_path: NodePath
@export var name_label_path: NodePath
@export var level_label_path: NodePath
@export var pending_label_path: NodePath
@export var lock_label_path: NodePath

var building_id: String = ""

@onready var _icon_frame: TextureRect = get_node_or_null(icon_frame_path) as TextureRect
@onready var _icon: TextureRect = get_node_or_null(icon_path) as TextureRect
@onready var _name_label: Label = get_node_or_null(name_label_path) as Label
@onready var _level_label: Label = get_node_or_null(level_label_path) as Label
@onready var _pending_label: Label = get_node_or_null(pending_label_path) as Label
@onready var _lock_label: Label = get_node_or_null(lock_label_path) as Label

func _ready() -> void:
	text = ""
	if _icon_frame != null:
		_icon_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _icon != null:
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _pending_label != null:
		_pending_label.visible = false
	if _lock_label != null:
		_lock_label.visible = false

func set_icon_frame(texture: Texture2D) -> void:
	if _icon_frame == null:
		return
	_icon_frame.texture = texture

func set_icon(texture: Texture2D) -> void:
	if _icon == null:
		return
	_icon.texture = texture

func set_title(text_value: String) -> void:
	if _name_label != null:
		_name_label.text = text_value

func set_level(level: int) -> void:
	if _level_label != null:
		_level_label.text = "Lv %s" % level

func set_pending(is_pending: bool) -> void:
	if _pending_label != null:
		_pending_label.visible = is_pending

func set_locked(locked: bool, unlock_level: int) -> void:
	disabled = locked
	if _lock_label != null:
		_lock_label.visible = locked
		if locked:
			_lock_label.text = "Unlock at HQ Lv %s" % unlock_level
