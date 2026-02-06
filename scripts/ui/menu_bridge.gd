extends Control
class_name MenuBridge

@export var lab_button_path: NodePath
@export var inventory_button_path: NodePath
@export var combat_button_path: NodePath

func _ready() -> void:
	_connect_button(_resolve_button(lab_button_path, ["lab", "laboratory"]))
	_connect_button(_resolve_button(inventory_button_path, ["inventory"]))
	_connect_button(_resolve_button(combat_button_path, ["combat", "loadout"]))

func _resolve_button(path: NodePath, text_hints: Array) -> Button:
	var node = get_node_or_null(path) if path != NodePath("") else null
	if node is Button:
		return node
	for button in _find_buttons_by_text(text_hints):
		return button
	return null

func _find_buttons_by_text(hints: Array) -> Array:
	var out: Array = []
	if hints.is_empty():
		return out
	for node in get_tree().get_nodes_in_group("_menu_bridge_buttons"):
		if node is Button:
			out.append(node)
	if out.size() > 0:
		return out
	var all_buttons = _find_all_buttons(self)
	for button in all_buttons:
		var text = button.text.to_lower()
		for hint in hints:
			if text.find(str(hint).to_lower()) != -1:
				out.append(button)
				break
	return out

func _find_all_buttons(root: Node) -> Array:
	var out: Array = []
	if root is Button:
		out.append(root)
	for child in root.get_children():
		if child is Node:
			out.append_array(_find_all_buttons(child))
	return out

func _connect_button(button: Button) -> void:
	if button == null:
		return
	if button.text.to_lower().find("lab") != -1 or button.text.to_lower().find("laboratory") != -1:
		button.pressed.connect(SceneRouter.go_to_lab_hub)
		return
	if button.text.to_lower().find("inventory") != -1:
		button.pressed.connect(SceneRouter.go_to_inventory)
		return
	if button.text.to_lower().find("combat") != -1 or button.text.to_lower().find("loadout") != -1:
		button.pressed.connect(SceneRouter.go_to_loadout)
		return
