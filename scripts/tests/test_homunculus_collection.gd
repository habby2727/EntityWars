extends SceneTree

const HomProgress = preload("res://scripts/domain/homunculus_progress.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := DataRegistry.new()
	var collection := registry.get_homunculus_collection()
	assert(collection.size() == 22 and registry.get_homunculi().size() == 8)
	for id in collection:
		if not registry.get_homunculi().has(id):
			assert(FileAccess.file_exists(collection[id].preview_texture))
			assert(not collection[id].has("buff_atk"))
	TranslationServer.set_locale("es")
	assert(HomProgress.passive_text(collection.astralotl) == collection.astralotl.passive.description.es)
	TranslationServer.set_locale("en")
	assert(HomProgress.passive_text(collection.astralotl) == collection.astralotl.passive.description.en)
	collection.erase("astralotl")
	assert(registry.get_homunculus_collection().size() == 22)
	assert(HomProgress.collection_status("cinder", true, {}, false) == "owned")
	assert(HomProgress.collection_status("astralotl", false, {}, false) == "unknown")
	assert(HomProgress.collection_status("astralotl", false, {}, true) == "locked")
	assert(HomProgress.collection_status("astralotl", false, {"astralotl": {"owned": true, "level": 0, "xp": 0}}, true) == "owned")
	assert(HomProgress.collection_status("astralotl", false, {"astralotl": {"owned": 1}}, true) == "locked")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		var inventory = load("res://scenes/ui/Inventory.tscn").instantiate()
		root.add_child(inventory)
		await process_frame
		inventory._tabs.current_tab = 2
		while inventory._list_building[2]:
			await process_frame
		assert(inventory._homunculi_list.get_child_count() == 22)
		var hom: Dictionary = registry.get_homunculus_collection().astralotl
		hom["kind"] = "homunculus"
		assert(inventory._extract_preview_texture(hom) != null)
		assert(inventory._hom_status(hom) == "unknown")
		var backend: BackendClient = inventory._spell_backend
		backend.token = "test"
		backend._verified_player_id = "a"
		inventory._on_spell_progress_updated({"player_id": "a", "homunculus_progress": {"astralotl": {"owned": true, "level": 3, "xp": 550, "mutation_id": "vitality"}}})
		assert(inventory._hom_status(hom) == "owned")
		var detail: String = inventory._entry_details(hom)
		assert(detail.contains("550") and detail.contains("3 / 10"))
		inventory._on_spell_auth_changed("")
		assert(inventory._hom_status(hom) == "unknown")
		backend._verified_player_id = "b"
		inventory._on_spell_progress_updated({"player_id": "b", "homunculus_progress": {}})
		assert(inventory._hom_status(hom) == "locked")
		var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
		root.add_child(panel)
		panel.setup(registry, backend, false, 20, 10)
		panel.show_building("homunculus_vat", {"player_id": "b", "homunculus_progress": {}, "lab": {"buildings": {"homunculus_vat": {"level": 1}}}}, {}, {}, true)
		var catalog_list: ItemList = panel.find_child("LocalizationCatalogItems", true, false)
		assert(catalog_list != null and catalog_list.item_count == 22)
		panel._vat_item = "astralotl"
		panel._update_vat_status()
		for button in panel._vat_mutations: assert(button.disabled)
		assert(panel._vat_info.text.contains(HomProgress.passive_text(hom)))
		panel._forge_state.homunculus_progress = {"astralotl": {"owned": true, "level": 3, "xp": 550, "mutation_id": "vitality"}}
		panel._update_vat_status()
		assert(panel._vat_xp.text.contains("550"))
		assert(not panel._vat_mutations[0].disabled and panel._vat_mutations[1].disabled)
		panel._on_catalog_auth_changed("")
		for button in panel._vat_mutations: assert(button.disabled)
		panel.queue_free()
		inventory.queue_free()
		await process_frame
	registry.free()
	print("HOMUNCULUS_COLLECTION_PASS")
	quit()
