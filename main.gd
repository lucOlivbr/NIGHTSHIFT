extends Node3D

const NightAudio = preload("res://scripts/night_audio.gd")
const NOIR_ENVIRONMENT = preload("res://environments/noir_environment.tres")
const PLAYER_SCENE = preload("res://scenes/player_native.tscn")
const INFILTRATION_MISSION = preload("res://scripts/infiltration_mission.gd")
const STREET_ART = preload("res://scripts/street_art.gd")

var player: CharacterBody3D
var camera: Camera3D
var night_audio: NightAudio
var music_label: Label
var movement_label: Label
var _street_lights: Array[SpotLight3D] = []
var _shadow_light: SpotLight3D
var _shadow_refresh := 0.0
var _wet_asphalt: Dictionary = {}
var _building_bounds: Dictionary = {}
var _stair_facades: Dictionary = {}
var _street_shapes: Dictionary = {}
var mission: Node3D
var _music_toast_time := 0.0

func _ready() -> void:
    _make_world()
    night_audio = NightAudio.new()
    night_audio.music_mute_changed.connect(_update_music_label)
    add_child(night_audio)
    _update_music_label(night_audio.music_muted)
    # Existing movement/audio QA can still load the unmodified exploration setup.
    if not "--sandbox" in OS.get_cmdline_user_args():
        mission = INFILTRATION_MISSION.new()
        add_child(mission)
        var art := STREET_ART.new()
        art.mission = mission
        add_child(art)
        if "--self-test" in OS.get_cmdline_user_args():
            var driver = load("res://scripts/release_playthrough.gd").new()
            driver.world = self
            get_tree().root.add_child.call_deferred(driver)

func box_mesh(size: Vector3, color: Color, pos: Vector3, collision := false) -> Node3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.84
    node.material_override = mat
    node.position = pos
    add_child(node)
    if collision:
        var body := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.position = pos
        add_child(body)
        body.add_child(shape)
    return node

func asset(name: String, pos: Vector3, scale_factor: float = 1.0, angle: float = 0.0) -> void:
    var resource := load("res://assets/" + name + ".gltf") as PackedScene
    if resource == null:
        push_error("NIGHTSHIFT: could not load model: " + name)
        return
    var instance := resource.instantiate() as Node3D
    instance.position = pos
    instance.scale = Vector3.ONE * scale_factor
    instance.rotation.y = angle
    add_child(instance)
    if name == "Street_2Lane":
        _wet_road_materials(instance)
        _add_street_collision(instance)
    elif name.begins_with("Building_"):
        _add_building_collision(instance, name)

func _add_street_collision(instance: Node3D) -> void:
    # Reuse one small collision resource per original road mesh (220 triangles),
    # so the shoes follow the actual asphalt/curbs rather than the support plane.
    for mesh in instance.find_children("*", "MeshInstance3D", true, false):
        if not _street_shapes.has(mesh.mesh):
            _street_shapes[mesh.mesh] = mesh.mesh.create_trimesh_shape()
        var body := StaticBody3D.new()
        body.name = "StreetCollision"
        var shape := CollisionShape3D.new()
        shape.shape = _street_shapes[mesh.mesh]
        mesh.add_child(body)
        body.add_child(shape)

func _add_building_collision(instance: Node3D, asset_name: String) -> void:
    if asset_name == "Building_Small_1":
        _add_stair_facade_collision(instance, asset_name)
        return
    # Small static proxies make the existing facades solid for player/camera.
    # No render meshes or original asset files are changed, no trimesh cooking.
    if not _building_bounds.has(asset_name):
        var bounds := AABB()
        var first := true
        for mesh in instance.find_children("*", "MeshInstance3D", true, false):
            var relative: Transform3D = instance.global_transform.affine_inverse() * mesh.global_transform
            var part: AABB = relative * mesh.get_aabb()
            bounds = part if first else bounds.merge(part)
            first = false
        _building_bounds[asset_name] = bounds
    var bounds: AABB = _building_bounds[asset_name]
    var body := StaticBody3D.new()
    body.name = "BuildingCollision"
    body.position = bounds.get_center()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = bounds.size
    shape.shape = box
    instance.add_child(body)
    body.add_child(shape)

func _add_stair_facade_collision(instance: Node3D, asset_name: String) -> void:
    # Local fix for the stair-front building: the old full-model AABB filled the
    # empty space beside the porch, across the entire facade, ~2.1 m in front.
    # Cook just its bottom 3 m once, reuse on all five copies. Upper floors retain
    # one cheap box, so no full-building trimesh or rendering changes are needed.
    if not _stair_facades.has(asset_name):
        var faces := PackedVector3Array()
        for mesh in instance.find_children("*", "MeshInstance3D", true, false):
            var relative: Transform3D = instance.global_transform.affine_inverse() * mesh.global_transform
            var source: PackedVector3Array = mesh.mesh.get_faces()
            for triangle in range(0, source.size(), 3):
                var polygon: Array[Vector3] = []
                for vertex in range(3):
                    polygon.append(relative * source[triangle + vertex])
                var clipped: Array[Vector3] = []
                for vertex in range(3):
                    var a := polygon[vertex]
                    var b := polygon[(vertex + 1) % 3]
                    if a.y <= 3.0:
                        clipped.append(a)
                    if (a.y < 3.0 and b.y > 3.0) or (a.y > 3.0 and b.y < 3.0):
                        clipped.append(a.lerp(b, (3.0 - a.y) / (b.y - a.y)))
                for vertex in range(1, clipped.size() - 1):
                    if (clipped[vertex] - clipped[0]).cross(clipped[vertex + 1] - clipped[0]).length_squared() > 0.00000001:
                        faces.append_array(PackedVector3Array([clipped[0], clipped[vertex], clipped[vertex + 1]]))
        var lower := ConcavePolygonShape3D.new()
        lower.backface_collision = true
        lower.set_faces(faces)
        _stair_facades[asset_name] = lower
    var body := StaticBody3D.new()
    body.name = "BuildingCollision"
    instance.add_child(body)
    var lower_shape := CollisionShape3D.new()
    lower_shape.name = "StairsAndFacade"
    lower_shape.shape = _stair_facades[asset_name]
    body.add_child(lower_shape)
    var upper_shape := CollisionShape3D.new()
    upper_shape.name = "UpperFloors"
    var upper := BoxShape3D.new()
    # Main masonry footprint only: decorative trim must not form a lip above
    # the precise lower facade that could trap the elevated camera pivot.
    upper.size = Vector3(12.0, 14.014, 12.0)
    upper_shape.position = Vector3(-1, 10.007, -6)
    upper_shape.shape = upper
    body.add_child(upper_shape)

func _wet_road_materials(node: Node) -> void:
    # Shared local material copies: original glTFs/textures stay untouched.
    # Direct-light highlights only; no reflection probe or screen-space reflection.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var original := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
            if original == null or original.resource_name != "MI_Asphalt":
                continue
            if not _wet_asphalt.has(original):
                var wet := original.duplicate() as StandardMaterial3D
                wet.roughness = 0.3
                wet.metallic = 0.08
                _wet_asphalt[original] = wet
            mesh_instance.set_surface_override_material(surface, _wet_asphalt[original])
    for child in node.get_children():
        _wet_road_materials(child)

func _make_world() -> void:
    var environment := WorldEnvironment.new()
    environment.name = "NoirEnvironment"
    environment.environment = NOIR_ENVIRONMENT
    add_child(environment)
    var moon := DirectionalLight3D.new()
    moon.name = "MoonFill"
    moon.rotation_degrees = Vector3(-38, -32, 0)
    moon.light_color = Color("8aaed4")
    moon.light_energy = 0.32
    moon.shadow_enabled = false
    add_child(moon)
    # Original ground top (-0.10) covered the street asphalt at -0.15.
    # Lower the existing support plane 8 cm to expose the preserved road meshes.
    box_mesh(Vector3(140, 0.4, 140), Color("252b30"), Vector3(0,-0.38,0), true)
    for i in range(-3,4):
        asset("Street_2Lane", Vector3(0,0,i*12.0))
    for i in range(-2,3):
        var z = i * 25.0
        asset("Building_Small_1", Vector3(-15,0,z),1.0,0.0)
        asset("Building_Medium_2_001", Vector3(15,0,z),1.0,PI)
    for i in range(-3,4):
        var z = i * 12.0
        box_mesh(Vector3(0.12,5.8,0.12),Color("383e3c"),Vector3(-5,2.9,z))
        var light := SpotLight3D.new()
        light.name = "StreetLight_%d" % (i + 3)
        light.position = Vector3(-4.8,5.65,z)
        light.light_color = Color("ffd09a")
        light.light_energy = 3.8
        light.spot_range = 12.0
        light.spot_angle = 58.0
        light.spot_attenuation = 0.8
        light.spot_angle_attenuation = 0.7
        light.shadow_enabled = false
        light.shadow_bias = 0.06
        light.shadow_normal_bias = 1.0
        light.distance_fade_enabled = true
        light.distance_fade_begin = 28.0
        light.distance_fade_shadow = 20.0
        light.distance_fade_length = 12.0
        add_child(light)
        light.look_at(Vector3(-2.0,-0.15,z), Vector3.FORWARD)
        _street_lights.append(light)
        var housing := box_mesh(Vector3(0.5,0.15,0.35),Color("e4bd78"),Vector3(-4.8,5.75,z)) as MeshInstance3D
        var lamp_material := housing.material_override as StandardMaterial3D
        lamp_material.emission_enabled = true
        lamp_material.emission = Color("ffd09a")
        lamp_material.emission_energy_multiplier = 1.7
    var sector := preload("res://scripts/city_sector.gd").new()
    add_child(sector)
    # The preserved legacy scene remains available for regression/rollback.
    var player_scene: PackedScene = load("res://scenes/player.tscn") if "--legacy-player" in OS.get_cmdline_user_args() else PLAYER_SCENE
    player = player_scene.instantiate() as CharacterBody3D
    player.position = Vector3(0,-0.15,0)
    add_child(player)
    camera = player.get_camera()
    _update_shadow_light()
    var ui := CanvasLayer.new()
    add_child(ui)
    var label := Label.new()
    label.text = "NIGHTSHIFT / RUA 01\nWASD mover   •   Shift correr   •   F subir/descer do skate\nSkate: W acelerar   •   S / ESPAÇO frear   •   A/D virar\nMouse câmera   •   R recentrar   •   Roda distância   •   ESC liberar / Clique capturar"
    label.position = Vector2(18,16)
    label.add_theme_color_override("font_color",Color("d6d0be"))
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    ui.add_child(label)
    label.visible = false
    music_label = Label.new()
    music_label.position = Vector2(18,116)
    music_label.add_theme_color_override("font_color",Color("afc3d2"))
    music_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    music_label.add_theme_constant_override("shadow_offset_y", 1)
    ui.add_child(music_label)
    music_label.position = Vector2(32, 112)
    music_label.visible = false
    movement_label = Label.new()
    movement_label.position = Vector2(18,140)
    movement_label.add_theme_color_override("font_color",Color("d6d0be"))
    movement_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    movement_label.add_theme_constant_override("shadow_offset_y", 1)
    ui.add_child(movement_label)
    movement_label.visible = false
    _update_movement_label()

func _update_movement_label() -> void:
    if player.mount_hint != "":
        movement_label.text = player.mount_hint
    elif player.is_skating:
        movement_label.text = "SKATE   •   %.0f km/h" % (player.horizontal_speed * 3.6)
    else:
        movement_label.text = "AGACHADO   •   use as cargas como cobertura" if player.is_crouching else "A PÉ   •   F skate   •   C / CTRL agachar   •   E interagir"

func _update_music_label(is_muted: bool) -> void:
    music_label.text = "M  trilha: %s" % ("desligada" if is_muted else "ligada")

func _update_shadow_light() -> void:
    # Select at most one nearby shadow-casting spotlight, four times per second.
    # The seven original pole locations and all model transforms are preserved.
    var nearest: SpotLight3D
    var best_distance := 144.0
    for light in _street_lights:
        var distance := light.global_position.distance_squared_to(player.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = light
    if nearest == _shadow_light:
        return
    if is_instance_valid(_shadow_light):
        _shadow_light.shadow_enabled = false
    _shadow_light = nearest
    if is_instance_valid(_shadow_light):
        _shadow_light.shadow_enabled = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_M:
            night_audio.toggle_music()
            music_label.visible = true
            _music_toast_time = 2.5
        elif event.keycode == KEY_F11:
            var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _physics_process(delta: float) -> void:
    _music_toast_time = maxf(0, _music_toast_time - delta)
    if _music_toast_time == 0:
        music_label.visible = false
    _shadow_refresh -= delta
    if _shadow_refresh <= 0.0:
        _shadow_refresh = 0.25
        _update_shadow_light()
        _update_movement_label()
