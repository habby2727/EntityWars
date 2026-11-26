extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check_style(style: StyleBox) -> void:
	assert(style is StyleBoxFlat)
	assert(style.bg_color.r < 0.05 and style.bg_color.g < 0.05 and style.bg_color.b < 0.05)
	assert(style.bg_color.a > 0.5 and style.bg_color.a < 1.0)
	assert(style.border_width_left == 0 and style.border_width_top == 0 and style.border_width_right == 0 and style.border_width_bottom == 0)

func _run() -> void:
	var host := Control.new()
	host.theme = UIThemeFactory.build_theme()
	root.add_child(host)
	var script = load("res://scripts/ui/expedition_combat.gd")
	var weapon: Button = script.WeaponButton.new()
	var enemy_weapon: Control = script.WeaponSlot.new()
	var spell := Button.new()
	var status: Control = load("res://scripts/ui/combat_status_icons.gd").new()
	var hom: Control = load("res://scripts/ui/combat_hom_status.gd").new()
	for control in [weapon, enemy_weapon, spell, status, hom]: host.add_child(control)
	await process_frame
	for control in [weapon, enemy_weapon, spell, status, hom]:
		_check_style(control.get_theme_stylebox("panel", "TooltipPanel"))
	for control in [weapon, enemy_weapon, hom]:
		var tooltip: Control = control._make_custom_tooltip("Test tooltip")
		host.add_child(tooltip)
		await process_frame
		assert(tooltip.get_theme_stylebox("panel") is StyleBoxEmpty)
		assert((tooltip.get_child(0) as Label).text == "Test tooltip")
		tooltip.queue_free()
	var combat := (load("res://scenes/Combat.tscn") as PackedScene).instantiate()
	_check_style(combat.get_node("ItemTooltip").get_theme_stylebox("panel"))
	root.add_child(combat)
	await process_frame
	var normal_style := combat.spell_buttons[0].get_theme_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	assert(normal_style != null and normal_style.bg_color.r < 0.05 and normal_style.bg_color.g < 0.05 and normal_style.bg_color.b < 0.05)
	assert(normal_style.bg_color.a > 0.0 and normal_style.bg_color.a < 1.0)
	combat.queue_free()
	host.queue_free()
	await process_frame
	print("COMBAT_TOOLTIP_STYLE_PASS")
	quit()
