extends CanvasLayer

const CURSOR_HOTSPOT := Vector2(3, 3)
const CURSOR_SIZE := Vector2i(32, 32)

var _click_particle_fill_texture: Texture2D
var _click_particle_ring_texture: Texture2D
var _cursor_texture: Texture2D
var _optional_resource_paths := {
    "click_fill": "res://assets/pics/ui/click_particle_fill.png",
    "click_ring": "res://assets/pics/ui/click_particle_ring.png",
    "cursor": "res://assets/pics/ui/cursor.png",
}
var _optional_resource_pending: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    follow_viewport_enabled = true
    _request_optional_resource("click_fill")
    _request_optional_resource("click_ring")
    _request_optional_resource("cursor")
    set_process(not _optional_resource_pending.is_empty())
    set_process_input(true)


func _process(_delta: float) -> void:
    _poll_optional_resources()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
            return
        _spawn_click_particles(get_viewport().get_mouse_position())


func _request_optional_resource(resource_key: String) -> void:
    var resource_path: String = _optional_resource_paths.get(resource_key, "")
    if resource_path.is_empty():
        return
    if not ResourceLoader.exists(resource_path):
        return
    var err := ResourceLoader.load_threaded_request(resource_path)
    if err == OK:
        _optional_resource_pending[resource_key] = resource_path
        return
    var fallback := load(resource_path)
    _match_optional_resource(resource_key, fallback)


func _poll_optional_resources() -> void:
    if _optional_resource_pending.is_empty():
        return
    var loaded_keys: Array[String] = []
    for resource_key_variant in _optional_resource_pending.keys():
        var resource_key := String(resource_key_variant)
        var resource_path := String(_optional_resource_pending[resource_key])
        var status := ResourceLoader.load_threaded_get_status(resource_path)
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var resource := ResourceLoader.load_threaded_get(resource_path)
            _match_optional_resource(resource_key, resource)
            loaded_keys.append(resource_key)
        elif status == ResourceLoader.THREAD_LOAD_FAILED:
            loaded_keys.append(resource_key)
    for resource_key in loaded_keys:
        _optional_resource_pending.erase(resource_key)
    if _optional_resource_pending.is_empty():
        set_process(false)   # всё загружено — опрос каждый кадр больше не нужен


func _match_optional_resource(resource_key: String, resource: Resource) -> void:
    var texture := resource as Texture2D
    if texture == null:
        return
    match resource_key:
        "click_fill":
            _click_particle_fill_texture = texture
        "click_ring":
            _click_particle_ring_texture = texture
        "cursor":
            _cursor_texture = texture
            _apply_custom_cursor()


func _apply_custom_cursor() -> void:
    if _cursor_texture == null:
        return
    var img := _cursor_texture.get_image()
    img.resize(CURSOR_SIZE.x, CURSOR_SIZE.y)
    var resized := ImageTexture.create_from_image(img)
    Input.set_custom_mouse_cursor(resized, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
    Input.set_custom_mouse_cursor(resized, Input.CURSOR_POINTING_HAND, CURSOR_HOTSPOT)


func _spawn_click_particles(global_pos: Vector2) -> void:
    if _click_particle_fill_texture == null or _click_particle_ring_texture == null:
        return
    _spawn_particle_burst(global_pos, _click_particle_fill_texture, Color(1.0, 1.0, 1.0, 0.95), 3, 0.52, 0.22, 0.62, 125.0, 210.0)
    _spawn_particle_burst(global_pos, _click_particle_fill_texture, Color(0.992, 0.369, 0.737, 0.922), 4, 0.56, 0.16, 0.56, 115.0, 195.0)
    _spawn_particle_burst(global_pos, _click_particle_ring_texture, Color(0.828, 0.35, 1.0, 0.957), 2, 0.62, 0.34, 0.72, 95.0, 170.0)


func _spawn_particle_burst(global_pos: Vector2, texture: Texture2D, color: Color, amount: int, lifetime: float, scale_min: float, scale_max: float, velocity_min: float, velocity_max: float) -> void:
    var particles := GPUParticles2D.new()
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.amount = amount
    particles.lifetime = lifetime
    particles.texture = texture
    particles.position = global_pos
    particles.local_coords = false
    particles.z_index = 50
    particles.modulate = color

    var canvas_material := CanvasItemMaterial.new()
    canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    particles.material = canvas_material

    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
    material.direction = Vector3.UP
    material.spread = 180.0
    material.gravity = Vector3(0.0, 180.0, 0.0)
    material.initial_velocity_min = velocity_min
    material.initial_velocity_max = velocity_max
    material.angular_velocity_min = -260.0
    material.angular_velocity_max = 260.0
    material.scale_min = scale_min
    material.scale_max = scale_max
    material.scale_curve = _make_scale_curve()
    material.alpha_curve = _make_alpha_curve()
    particles.process_material = material

    add_child(particles)
    particles.finished.connect(particles.queue_free)
    particles.emitting = true
    particles.restart()


var _scale_curve_cache: CurveTexture
var _alpha_curve_cache: CurveTexture


func _make_scale_curve() -> CurveTexture:
    if _scale_curve_cache != null:
        return _scale_curve_cache
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.25))
    curve.add_point(Vector2(0.2, 1.0))
    curve.add_point(Vector2(0.55, 0.72))
    curve.add_point(Vector2(1.0, 0.0))
    var texture := CurveTexture.new()
    texture.curve = curve
    _scale_curve_cache = texture
    return texture


func _make_alpha_curve() -> CurveTexture:
    if _alpha_curve_cache != null:
        return _alpha_curve_cache
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.0))
    curve.add_point(Vector2(0.1, 1.0))
    curve.add_point(Vector2(0.68, 0.82))
    curve.add_point(Vector2(1.0, 0.0))
    var texture := CurveTexture.new()
    texture.curve = curve
    _alpha_curve_cache = texture
    return texture
