extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var gate = root.get_node("ConnectionGate")
 gate.require_authentication()
 assert(gate.enable_debug_lab())
 SceneRouter.go_to_loadout()
 await process_frame
 await process_frame
 var queue = current_scene.ranked_queue
 assert(queue.debug_button != null and not queue.debug_button.visible)
 queue._select()
 assert(queue.debug_button.visible)
 queue.debug_button.pressed.emit()
 await process_frame
 await process_frame
 assert(current_scene.scene_file_path == SceneRouter.SCENE_COMBAT)
 assert(current_scene._ranked_controller.debug_visual)
 assert(current_scene._ranked_controller.backend == null)
 current_scene._ranked_controller.back()
 await process_frame
 await process_frame
 assert(current_scene.scene_file_path == SceneRouter.SCENE_LOADOUT)
 assert(SceneRouter._ranked_context.is_empty())
 print("PASS local PvP preview")
 quit()


