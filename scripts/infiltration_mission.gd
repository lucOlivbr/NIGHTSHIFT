extends Node3D
## One self-contained mission in the existing city block. No combat/upgrades.
const GUARD = preload("res://scripts/mission_guard.gd")
const NAVIGATION = preload("res://scripts/mission_navigation.gd")
const HUD = preload("res://scripts/mission_hud.gd")
const SPAWN := Vector3(0, -0.15, -37)
var player: CharacterBody3D
var navigation: RefCounted
var guards: Array[CharacterBody3D] = []
var cover_positions: Array[Vector3] = []
var entry_point := Vector3(7.7, -0.15, 18.5)
var package_point := Vector3(18.3, -0.15, 20.3)
var alternate_exit := Vector3(46, -0.15, 87)
var exit_point := Vector3(0, -0.15, -40)
var phase := "BRIEFING"
var door_open := false
var door_opening := false
var has_package := false
var escape_started := false
var escape_alarm_time := 0.0
var entered_warehouse := false
var elapsed := 0.0
var interaction_progress := 0.0
var boundary_time := 0.0
var ready_to_start := false
var busy := false
var shutter: MeshInstance3D
var shutter_shape: CollisionShape3D
var parcel: Node3D
var entry_marker: Node3D
var exit_marker: Node3D
var presentation: Control
var canvas: CanvasLayer
var overlay: ColorRect
var title: Label
var briefing: Label
var start_button: Button
var objective: Label
var status: Label
var prompt: Label
var exposure_bar: ProgressBar
var interaction_bar: ProgressBar
var map: Control
var restart_count := 0
var _hud_tick := 0.0
var _materials: Dictionary = {}
var _interaction_kind := ""
var _door_tween: Tween
var _shutter_closed_position := Vector3(9, 1.55, 18.6)

func _ready() -> void:
    name = "InfiltrationMission"
    process_physics_priority = 5
    player = get_parent().player
    _build_location()
    _spawn_guards()
    _build_hud()
    _freeze_player()
    player.camera_rig.input_locked = true
    player.camera_rig.set_mouse_captured(false)
    navigation = NAVIGATION.new()
    await get_tree().physics_frame
    navigation.bake(self)
    ready_to_start = true
    start_button.disabled = false
    start_button.text = "INICIAR MISSÃO  [ENTER]"
    start_button.grab_focus()

func is_active() -> bool:
    return phase == "RUNNING" and ready_to_start and player.camera_rig.mouse_captured

func _material(color: Color) -> StandardMaterial3D:
    if not _materials.has(color):
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.88
        _materials[color] = material
    return _materials[color]

func _box(label: String, size: Vector3, position: Vector3, color: Color, solid := true) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    var geometry := BoxMesh.new()
    geometry.size = size
    mesh.mesh = geometry
    mesh.material_override = _material(color)
    add_child(mesh)
    mesh.position = position
    if solid:
        var body := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        mesh.add_child(body)
        body.add_child(shape)
    return mesh

func _sign(text: String, position: Vector3, size := 36) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.position = position
    label.font_size = size
    label.pixel_size = 0.01
    label.modulate = Color("d8d3be")
    label.outline_modulate = Color("111820")
    add_child(label)
    return label

func _marker(position: Vector3, color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var geometry := CylinderMesh.new()
    geometry.top_radius = 0.6
    geometry.bottom_radius = 0.6
    geometry.height = 0.025
    geometry.radial_segments = 20
    mesh.mesh = geometry
    var material := _material(color).duplicate() as StandardMaterial3D
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)
    mesh.position = Vector3(position.x, 0.025, position.z)
    return mesh

func _crate(position: Vector3, size := Vector3(2.2, 1.12, 1.5)) -> void:
    cover_positions.append(position)
    var center := position + Vector3.UP * (-0.15 + size.y * 0.5)
    _box("CargoCover", size, center, Color("65594b"))
    _box("CargoBand", Vector3(size.x + 0.02, 0.12, size.z + 0.02), center + Vector3.UP * size.y * 0.23, Color("899084"), false)

func _build_location() -> void:
    # Loading annex fits the pre-existing 12 m gap between two right-side blocks.
    # All ten original building instances and their collision fixes stay intact.
    var wall := Color("3e4c50")
    _box("WarehouseFloor", Vector3(12.2, 0.12, 9.2), Vector3(15, -0.21, 18.5), Color("424b4f"))
    _box("WarehouseBack", Vector3(0.2, 5, 9.2), Vector3(21, 2.35, 18.5), wall)
    _box("WarehouseSouth", Vector3(12, 5, 0.2), Vector3(15, 2.35, 14), wall)
    _box("WarehouseNorth", Vector3(12, 5, 0.2), Vector3(15, 2.35, 23), wall)
    _box("WarehouseFrontA", Vector3(0.2, 5, 3.2), Vector3(9, 2.35, 15.6), wall)
    _box("WarehouseFrontB", Vector3(0.2, 5, 3), Vector3(9, 2.35, 21.5), wall)
    _box("WarehouseLintel", Vector3(0.2, 1.6, 2.8), Vector3(9, 4.05, 18.6), wall)
    _box("WarehouseRoof", Vector3(12.2, 0.15, 9.2), Vector3(15, 4.93, 18.5), Color("343d40"))
    shutter = _box("WarehouseShutter", Vector3(0.16, 3.4, 2.8), Vector3(9, 1.55, 18.6), Color("637273"))
    shutter_shape = shutter.get_child(0).get_child(0)
    # The existing opening is a real 2.8 m loading entrance, with a housing above
    # head height. The shutter and its collider move together while retracting.
    _box("WarehouseDoorHousing", Vector3(0.42, 0.32, 3.05), Vector3(9, 3.44, 18.6), Color("465653"), false)
    var sign := _sign("ARMAZÉM 07\nCARGA RESTRITA", Vector3(8.84, 3.8, 18.5), 34)
    sign.rotation.y = -PI / 2
    var panel := _box("AccessPanel", Vector3(0.15, 0.45, 0.3), Vector3(8.7, 1.1, 17), Color("729b91"), false)
    var lamp := OmniLight3D.new()
    lamp.position = Vector3(15, 3.9, 18.5)
    lamp.light_color = Color("c0d4b9")
    lamp.light_energy = 2.0
    lamp.omni_range = 9
    lamp.shadow_enabled = false
    add_child(lamp)
    # Keep both sides of the cargo usable. The former 1.2 m gap beside the
    # package table fell between navigation cells and made approach turns tight.
    _crate(Vector3(14.6, 0, 18.4), Vector3(2.4, 1.18, 2.8))
    for point in [Vector3(-3.9, 0, -27), Vector3(-5.2, 0, -16), Vector3(3.8, 0, -18), Vector3(-3.8, 0, -5), Vector3(-5.2, 0, 5), Vector3(3.8, 0, 2), Vector3(6.4, 0, 12), Vector3(6.4, 0, 24)]:
        _crate(point)
    parcel = _box("MissionPackage", Vector3(0.55, 0.4, 0.4), package_point + Vector3.UP * 0.85, Color("c6ad73"), false)
    _box("PackageTable", Vector3(1.4, 0.6, 0.9), Vector3(package_point.x, 0.15, package_point.z), Color("42494a"))
    var package_sign := _sign("PACOTE", package_point + Vector3.UP * 1.7, 28)
    package_sign.pixel_size = 0.004
    package_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    package_sign.name = "PackageSign"
    entry_marker = _marker(entry_point, Color("80c6b0"))
    exit_marker = _box("ExtractionMark", Vector3(7, 0.025, 5), Vector3(exit_point.x, -0.12, exit_point.z), Color("476f75"), false)
    var exit_sign := _sign("SAÍDA / SKATE", exit_point + Vector3.UP * 2.6, 38)
    exit_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    exit_sign.modulate = Color("8bd6c3")

func _spawn_guards() -> void:
    var paths := [
        [Vector3(1.8, -0.15, -25), Vector3(1.8, -0.15, -8), Vector3(3.8, -0.15, -8), Vector3(3.8, -0.15, -25)],
        [Vector3(-0.5, -0.15, 5), Vector3(2.2, -0.15, 5), Vector3(2.2, -0.15, 26), Vector3(-0.5, -0.15, 26)],
        [Vector3(19.6, -0.15, 15.5), Vector3(19.6, -0.15, 21.5), Vector3(20.1, -0.15, 21.5), Vector3(20.1, -0.15, 15.5)]
    ]
    for index in paths.size():
        var guard := GUARD.new()
        guard.name = "Guard_%d" % (index + 1)
        guard.mission = self
        guard.route.assign(paths[index])
        guards.append(guard)
        add_child(guard)

func _label(parent: Node, text: String, size := 18) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color("d6dedc"))
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _build_hud() -> void:
    canvas = CanvasLayer.new()
    canvas.layer = 4
    add_child(canvas)
    presentation = HUD.new()
    presentation.mission = self
    canvas.add_child(presentation)
    objective = presentation.objective
    status = presentation.status
    prompt = presentation.prompt
    exposure_bar = presentation.exposure_bar
    interaction_bar = presentation.interaction_bar
    map = presentation.map
    overlay = presentation.overlay
    title = presentation.title
    briefing = presentation.briefing
    start_button = presentation.start_button

func _freeze_player() -> void:
    player.controls_enabled = false
    player.reset_motion_state()
    player.velocity = Vector3.ZERO
    player.skate.momentum = Vector3.ZERO
    player.set_gameplay_paused(true)

func start_mission() -> void:
    if busy or not ready_to_start:
        return
    busy = true
    get_parent().night_audio.set_escape_mode(false)
    phase = "BRIEFING"
    _freeze_player()
    restart_count += 1
    if is_instance_valid(_door_tween):
        _door_tween.kill()
    door_open = false
    door_opening = false
    has_package = false
    escape_started = false
    escape_alarm_time = 0.0
    entered_warehouse = false
    elapsed = 0
    boundary_time = 0
    interaction_progress = 0
    _interaction_kind = ""
    shutter.visible = true
    shutter.position = _shutter_closed_position
    shutter_shape.set_deferred("disabled", false)
    parcel.visible = true
    get_node("PackageSign").visible = true
    entry_marker.visible = true
    player.is_skating = false
    player.skate_blend = 0
    player.skate_pose.influence = 0
    player.crouch_stance.influence = 0
    player.board.visible = false
    player.is_crouching = false
    player.collider.shape.radius = 0.3
    player.collider.shape.height = 1.8
    player.collider.position.y = 0.9
    player.global_position = SPAWN
    player.reset_motion_state()
    player.visual.rotation.y = 0
    player.visual.scale = Vector3.ONE
    player.horizontal_speed = 0
    player.reset_physics_interpolation()
    player.camera_rig.target_yaw = PI
    player.camera_rig.target_pitch = -0.2
    player.camera_rig.snap_to_target()
    for guard in guards:
        guard.reset_guard()
    await get_tree().physics_frame
    navigation.bake(self)
    player.controls_enabled = true
    player.camera_rig.input_locked = false
    player.camera_rig.set_mouse_captured(true)
    overlay.visible = false
    phase = "RUNNING"
    busy = false
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if presentation._credits.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ENTER and phase != "RUNNING":
            start_mission()
            get_viewport().set_input_as_handled()

func is_chased() -> bool:
    for guard in guards:
        if guard.state == "CHASE":
            return true
    return false

func exposure() -> float:
    var value := 0.0
    for guard in guards:
        value = maxf(value, guard.suspicion)
    return value

func _interaction() -> String:
    if player.is_skating or not player.is_on_floor() or player.horizontal_speed > 0.2 or is_chased() or door_opening:
        return ""
    if not door_open and player.global_position.distance_to(entry_point) < 2 and _interaction_visible(Vector3(8.55, 1.1, 17)):
        return "DOOR"
    if door_open and entered_warehouse and not has_package and player.global_position.distance_to(package_point) < 1.8 and _interaction_visible(parcel.global_position + Vector3.UP * 0.1):
        return "PACKAGE"
    return ""

func _interaction_visible(target: Vector3) -> bool:
    # Interaction must obey the same solid walls/cargo as the character. Aim
    # above the table so the package can be reached naturally from the aisle.
    var eye := player.global_position + Vector3.UP * (0.9 if player.is_crouching else 1.4)
    var ray := PhysicsRayQueryParameters3D.create(eye, target, 1, [player.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
    if not ready_to_start:
        return
    _hud_tick -= delta
    if _hud_tick <= 0:
        _hud_tick = 0.1
        _update_hud()
    if not is_active():
        if phase == "RUNNING":
            # Mission pause must not let a coasting board move through frozen AI.
            player.set_gameplay_paused(true)
            if door_opening and is_instance_valid(_door_tween):
                _door_tween.pause()
            interaction_progress = 0
        return
    player.set_gameplay_paused(false)
    if door_opening and is_instance_valid(_door_tween):
        _door_tween.play()
    elapsed += delta
    escape_alarm_time = maxf(0.0, escape_alarm_time - delta)
    if player.position.y < -5:
        finish(false, "Você caiu para fora da área da missão.")
        return
    var in_original := absf(player.position.x) <= 25 and player.position.z >= -45 and player.position.z <= 43
    var in_sector := player.position.x >= -25 and player.position.x <= 71 and player.position.z >= 38 and player.position.z <= 98
    var outside := not (in_original or in_sector)
    boundary_time = boundary_time + delta if outside else 0.0
    if boundary_time > 6:
        finish(false, "A entrega foi abandonada. Permaneça na Rua 01 ou no Cais Norte.")
        return
    if door_open and player.position.x > 9.4 and player.position.x < 21 and player.position.z > 14 and player.position.z < 23:
        entered_warehouse = true
    var kind := _interaction()
    if kind != _interaction_kind:
        interaction_progress = 0
        _interaction_kind = kind
    if kind != "" and Input.is_action_pressed("interact") and exposure() < 0.55:
        interaction_progress += delta / (2.2 if kind == "DOOR" else 1.5)
        if interaction_progress >= 1:
            if kind == "DOOR":
                open_door()
            elif entered_warehouse:
                has_package = true
                parcel.visible = false
                get_node("PackageSign").visible = false
                start_escape()
            interaction_progress = 0
    else:
        interaction_progress = 0
    if has_package and player.is_skating and player.horizontal_speed >= 3.0 and not is_chased():
        var old_exit := absf(player.position.x - exit_point.x) < 3.5 and absf(player.position.z - exit_point.z) < 2.5
        var new_exit := absf(player.position.x - alternate_exit.x) < 3.5 and absf(player.position.z - alternate_exit.z) < 2.5
        if old_exit or new_exit:
            finish(true, "Pacote recuperado. Você saiu da Rua 01 com a entrega.")

func start_escape() -> void:
    if escape_started:
        return
    escape_started = true
    escape_alarm_time = 8.0
    # The alarm reports the warehouse doorway, not the player's hidden position.
    # No teleporting guards, and enough warning to leave the room and mount.
    var responder = guards[1]
    responder.state = "CHASE"
    responder.suspicion = 1.0
    responder.last_seen = entry_point
    responder.sight_lost = 0
    responder.alarm_response = true
    responder._route_tick = 0
    if get_parent().night_audio.has_method("play_event"):
        get_parent().night_audio.play_event("parcel")
        get_parent().night_audio.play_event("alarm")
        get_parent().night_audio.set_escape_mode(true)

func open_door() -> void:
    if door_open or door_opening:
        return
    door_opening = true
    get_parent().night_audio.play_event("door")
    entry_marker.visible = false
    _door_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    _door_tween.tween_property(shutter, "position:y", 5.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _door_tween.tween_callback(_finish_open_door)

func _finish_open_door() -> void:
    door_opening = false
    door_open = true
    shutter.visible = false
    shutter_shape.set_deferred("disabled", true)
    _rebake_door.call_deferred()

func _rebake_door() -> void:
    await get_tree().physics_frame
    navigation.bake(self)

func finish(won: bool, reason: String) -> void:
    if phase != "RUNNING":
        return
    phase = "WON" if won else "LOST"
    _freeze_player()
    player.camera_rig.input_locked = true
    player.camera_rig.set_mouse_captured(false)
    title.text = "ENTREGA CONCLUÍDA" if won else "MISSÃO INTERROMPIDA"
    if won:
        get_parent().night_audio.play_event("win")
        get_parent().night_audio.set_escape_mode(false)
        briefing.text = "As luzes do cais desaparecem na chuva.\nO pacote chega ao destino. Ninguém precisa saber seu nome.\n\nPor esta noite, a última entrega está feita.\n\nTempo: %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
    else:
        briefing.text = reason + "\n\nUma distração não encerra a noite. Tente pela rua de serviço.\n\nTempo: %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
    start_button.text = "JOGAR NOVAMENTE  [ENTER]"
    overlay.visible = true
    overlay.modulate.a = 0.0
    create_tween().tween_property(overlay, "modulate:a", 1.0, 0.65)
    start_button.grab_focus()
    interaction_progress = 0

func show_main_menu() -> void:
    if busy:
        return
    phase = "BRIEFING"
    _freeze_player()
    player.camera_rig.input_locked = true
    player.camera_rig.set_mouse_captured(false)
    get_parent().night_audio.set_escape_mode(false)
    presentation.show_intro()
    overlay.modulate.a = 1.0
    overlay.visible = true
    start_button.grab_focus()

func _update_hud() -> void:
    if is_instance_valid(presentation):
        presentation.refresh()
