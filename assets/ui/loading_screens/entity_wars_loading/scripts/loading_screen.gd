extends Control
## Reusable Godot 4.x loading overlay. Shows actual resource loading progress or values
## provided by your own system; never pretends demo progress is a real load.
## All images and positioning assume a 1920x1080 (16:9) UI layout.

signal load_failed(path: String)
signal finished_loading

@export_range(0.0, 1.0, 0.001) var initial_progress: float = 0.0
@export_range(0.0, 2.0, 0.05) var transition_hold_seconds: float = 0.35

@onready var fill: ColorRect = $ProgressFill

var _target_progress: float = 0.0
var _shown_progress: float = 0.0
var _pending_path: String = ""
var _loaded_scene: PackedScene = null
var _completion_delay: float = -1.0
var _indeterminate: bool = false
var _shown_since_ms: int = 0


func _ready() -> void:
    _shown_since_ms = Time.get_ticks_msec()
    # Each instance owns its material; switching screens won't share progress state.
    fill.material = fill.material.duplicate()
    _target_progress = clampf(initial_progress, 0.0, 1.0)
    _shown_progress = _target_progress
    _update_bar()


func set_progress(value: float) -> void:
    # Expected values: 0.0 to 1.0, not percentages from 0 to 100.
    _indeterminate = false
    _target_progress = clampf(value, 0.0, 1.0)


func get_progress() -> float:
    return _target_progress


func start_indeterminate() -> void:
    # A visibly moving incomplete bar, not a fake load percentage.
    _indeterminate = true
    _pending_path = ""
    _target_progress = 0.0
    _shown_progress = 0.0


func stop_indeterminate() -> void:
    _indeterminate = false
    _target_progress = 0.0
    _shown_progress = 0.0
    _update_bar()


func load_scene_threaded(scene_path: String) -> void:
    ## Convenience integration: actually preload the destination scene asynchronously.
    ## Call this while this loading screen is already visible in the scene tree.
    if _pending_path != "":
        push_warning("Entity Wars: a threaded load is already active.")
        return
    if not ResourceLoader.exists(scene_path):
        push_error("Entity Wars: missing scene: " + scene_path)
        load_failed.emit(scene_path)
        return
    var err: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if err != OK:
        push_error("Entity Wars: cannot queue scene: " + scene_path)
        load_failed.emit(scene_path)
        return
    _pending_path = scene_path
    _completion_delay = -1.0
    _loaded_scene = null
    _indeterminate = false
    _target_progress = 0.0
    _shown_progress = 0.0


func _process(delta: float) -> void:
    if _pending_path != "":
        var report: Array = []
        var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_pending_path, report)
        match status:
            ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                if not report.is_empty():
                    set_progress(clampf(float(report[0]), 0.0, 0.98))
            ResourceLoader.THREAD_LOAD_LOADED:
                _loaded_scene = ResourceLoader.load_threaded_get(_pending_path) as PackedScene
                _pending_path = ""
                if _loaded_scene == null:
                    load_failed.emit("PackedScene")
                else:
                    set_progress(1.0)
                    _shown_progress = 1.0
                    _update_bar()
                    _completion_delay = transition_hold_seconds
            ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
                var bad_path: String = _pending_path
                _pending_path = ""
                push_error("Entity Wars: threaded load failed: " + bad_path)
                load_failed.emit(bad_path)

    if _indeterminate:
        # Pulsing decorative segment. Use set_progress() for real percentages.
        var phase: float = fposmod(Time.get_ticks_msec() / 1000.0 * 0.62, 1.4)
        _shown_progress = 0.08 + 0.26 * (0.5 - 0.5 * cos(phase * TAU))
    else:
        _shown_progress = move_toward(_shown_progress, _target_progress, delta * 1.5)
    _update_bar()

    if _completion_delay >= 0.0:
        _completion_delay -= delta
        if _completion_delay < 0.0 and _loaded_scene != null:
            if Time.get_ticks_msec() - _shown_since_ms < 3000:
                _completion_delay = 0.0
                return
            var scene_to_enter: PackedScene = _loaded_scene
            _loaded_scene = null
            finished_loading.emit()
            # This screen may be attached directly to SceneTree.root; remove it
            # when changing scenes so it cannot cover the destination scene.
            var err: Error = get_tree().change_scene_to_packed(scene_to_enter)
            if err == OK:
                queue_free()
            else:
                push_error("Entity Wars: unable to enter loaded scene.")


func _update_bar() -> void:
    if fill != null and fill.material is ShaderMaterial:
        (fill.material as ShaderMaterial).set_shader_parameter("progress", _shown_progress)
