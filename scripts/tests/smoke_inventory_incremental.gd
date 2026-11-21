extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var inventory = load("res://scenes/ui/Inventory.tscn").instantiate()
	root.add_child(inventory)
	assert(inventory._entities_list.get_child_count() == 0)
	assert(inventory._builds_list.get_child_count() == 0 and inventory._homunculi_list.get_child_count() == 0)
	assert(inventory._ultrahit_list.get_child_count() == 0 and inventory._techs_list.get_child_count() == 0)
	await process_frame
	assert(inventory._entities_list.get_child_count() <= inventory.ROWS_PER_FRAME)
	while inventory._list_building[0]: await process_frame
	assert(inventory._entities_list.get_child_count() == inventory._registry.get_entities().size())
	inventory._tabs.current_tab = 2
	await process_frame
	assert(inventory._homunculi_list.get_child_count() <= inventory.ROWS_PER_FRAME)
	inventory._tabs.current_tab = 3
	assert(not inventory._list_loaded[2])
	await process_frame
	inventory._on_spell_filter_changed("Hybrid")
	inventory._on_spell_filter_changed("Universal")
	while inventory._list_building[3]: await process_frame
	assert(inventory._ultrahit_list.get_child_count() > 0)
	for row in inventory._ultrahit_list.get_children():
		assert(row.get_meta("entry").type == "universal")
	inventory._tabs.current_tab = 2
	while inventory._list_building[2]: await process_frame
	assert(inventory._homunculi_list.get_child_count() == 22)
	var backend: BackendClient = inventory._spell_backend
	backend.token = "fixture"
	backend._verified_player_id = "fixture"
	inventory._on_spell_progress_updated({"player_id":"fixture", "homunculus_progress":{"astralotl":{"owned":true, "level":0, "xp":0}}})
	while inventory._list_building[2]: await process_frame
	assert(inventory._homunculi_list.get_child_count() == 22)
	var row = inventory._homunculi_list.get_children().filter(func(child): return str(child.get_meta("entry").get("id")) == "astralotl")[0]
	assert(row.get_node("EntryRow/EntryText").get_child(1).text == inventory.tr("HOM_STATUS_OWNED"), "status=%s known=%s progress=%s" % [row.get_node("EntryRow/EntryText").get_child(1).text, inventory._hom_progress_known, inventory._hom_progress])
	inventory._tabs.current_tab = 1
	while inventory._list_building[1]: await process_frame
	assert(inventory._builds_list.get_child_count() == inventory._registry.get_items().size())
	inventory._tabs.current_tab = 4
	while inventory._list_building[4]: await process_frame
	assert(inventory._techs_list.get_child_count() > 0)
	inventory._tabs.current_tab = 3
	inventory._on_spell_filter_changed("All")
	inventory.queue_free()
	await process_frame
	print("INVENTORY_INCREMENTAL_PASS")
	quit()
