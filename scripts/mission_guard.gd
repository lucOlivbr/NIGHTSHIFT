extends CharacterBody3D
## Patrol -> investigate -> chase -> search -> patrol. Only LOS updates memory.
const MODEL = preload("res://assets/characters/nightshift_runner.glb")
const PATROL_SPEED := 1.2
const CHASE_SPEED := 4.4
const HALF_FOV := deg_to_rad(39.0)
var mission: Node3D
var route: Array[Vector3] = []
var route_index := 0
var state := "PATROL"
var suspicion := 0.0
var sees_player := false
var last_seen := Vector3.ZERO
var search_time := 0.0
var sight_lost := 0.0
var pause_time := 0.0
var model: Node3D
var animation: AnimationPlayer
var indicator: Label3D
var flashlight: SpotLight3D
var _vision_tick := 0.0
var _route_tick := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _clip := ""
var _catch_time := 0.0
var alarm_response := false

func _ready() -> void:
    collision_layer = 4
    collision_mask = 1
    floor_snap_length = 0.3
    floor_constant_speed = true
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.75
    shape.shape = capsule
    shape.position.y = 0.875
    add_child(shape)
    model = MODEL.instantiate()
    model.scale = Vector3.ONE * 0.96
    add_child(model)
    for mesh in model.find_children("*", "MeshInstance3D", true, false):
        mesh.extra_cull_margin = 0.012
        if mesh.name.contains("Body"):
            var uniform := StandardMaterial3D.new()
            uniform.albedo_color = Color("29303c")
            uniform.roughness = 0.9
            mesh.material_override = uniform
    animation = model.find_child("AnimationPlayer", true, false)
    var library := animation.get_animation_library("").duplicate(true) as AnimationLibrary
    animation.remove_animation_library("")
    animation.add_animation_library("", library)
    for clip in ["Idle", "Walk", "Run"]:
        animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
    animation.play("Idle")
    animation.advance(0.1)
    _clip = "Idle"
    indicator = Label3D.new()
    indicator.position.y = 2.15
    indicator.font_size = 30
    indicator.pixel_size = 0.005
    indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    indicator.no_depth_test = false
    add_child(indicator)
    flashlight = SpotLight3D.new()
    flashlight.name = "PatrolLamp"
    flashlight.position = Vector3(0.16, 1.35, 0.25)
    flashlight.light_color = Color("eadbb9")
    flashlight.light_energy = 2.8
    flashlight.spot_angle = 39
    flashlight.spot_attenuation = 1.2
    flashlight.spot_angle_attenuation = 1.6
    flashlight.shadow_enabled = false
    flashlight.distance_fade_enabled = true
    flashlight.distance_fade_begin = 18
    flashlight.distance_fade_length = 10
    add_child(flashlight)
    flashlight.look_at(global_transform * Vector3(0.16, 0.0, 6.5))
    var lens := MeshInstance3D.new()
    var bulb := SphereMesh.new()
    bulb.radius = 0.035
    bulb.height = 0.07
    lens.mesh = bulb
    lens.position = Vector3(0.16, 1.35, 0.29)
    var lens_material := StandardMaterial3D.new()
    lens_material.albedo_color = Color("b6b4a2")
    lens_material.emission_enabled = true
    lens_material.emission = Color("e0d4b3")
    lens.material_override = lens_material
    lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lens)
    reset_guard()

func reset_guard() -> void:
    global_position = route[0]
    route_index = 1 % route.size()
    rotation.y = atan2(route[route_index].x - position.x, route[route_index].z - position.z)
    velocity = Vector3.ZERO
    state = "PATROL"
    suspicion = 0
    sees_player = false
    sight_lost = 0
    last_seen = route[0]
    search_time = 0
    pause_time = 1.5
    _path.clear()
    _path_index = 0
    _route_tick = 0
    _vision_tick = 0
    _catch_time = 0
    alarm_response = false
    update_presentation()
    reset_physics_interpolation()

func can_see_player() -> bool:
    var target: CharacterBody3D = mission.player
    var eye := global_position + Vector3.UP * 1.48
    var point: Vector3 = target.global_position + Vector3.UP * (0.78 if target.is_crouching else 1.48)
    var difference := point - eye
    var horizontal := Vector3(difference.x, 0, difference.z)
    var distance := horizontal.length()
    var sight_range := 6.5 if target.is_crouching else (14.0 if target.is_skating else 11.0)
    if distance > sight_range:
        return false
    if distance > 1.35 and global_basis.z.dot(horizontal.normalized()) < cos(HALF_FOV):
        return false
    var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func sense(delta: float) -> void:
    sees_player = can_see_player()
    var distance := global_position.distance_to(mission.player.global_position)
    if sees_player:
        last_seen = mission.player.global_position
        sight_lost = 0
        # A newcomer gets several seconds to react at normal street distances.
        var rate := lerpf(0.72, 0.22, clampf(distance / 11.0, 0, 1))
        if mission.player.is_crouching:
            rate *= 0.5
        if mission.player.is_skating:
            rate *= 1.25
        if distance < 1.35:
            rate = 1.35
        suspicion = minf(1.0, suspicion + delta * rate)
        if suspicion >= 1:
            if state != "CHASE":
                mission.get_parent().night_audio.play_event("noticed")
            state = "CHASE"
            search_time = 0
        elif suspicion > 0.2 and state == "PATROL":
            state = "INVESTIGATE"
            pause_time = 0
    else:
        sight_lost += delta
        suspicion = maxf(0, suspicion - delta * (0.12 if state == "CHASE" else 0.25))
        if state == "CHASE" and sight_lost >= 2.5 and not (alarm_response and mission.escape_alarm_time > 0):
            state = "SEARCH"
            search_time = 6.0
        elif state == "INVESTIGATE" and sight_lost >= 3.0:
            state = "SEARCH"
            search_time = 5.0
    update_presentation()

func update_presentation() -> void:
    # A physical lamp suggests facing; the small icon communicates actual alert.
    # Detection range/angle/occlusion above are intentionally unchanged.
    indicator.visible = state != "PATROL" and position.distance_to(mission.player.position) < 18
    indicator.text = "!" if state == "CHASE" else "?"
    indicator.modulate = Color("df7664") if state == "CHASE" else Color("d6b478")
    var eye := flashlight.global_position
    var end := global_transform * Vector3(0.16, 1.35, 11)
    var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, end, 1))
    flashlight.spot_range = 11 if hit.is_empty() else clampf(eye.distance_to(hit.position) + 0.1, 1, 11)

func _physics_process(delta: float) -> void:
    if not mission.is_active():
        animation.speed_scale = 0
        return
    animation.speed_scale = 1
    _vision_tick -= delta
    if _vision_tick <= 0:
        sense(0.125)
        _vision_tick = 0.125
    if state == "SEARCH":
        search_time -= delta
        if search_time <= 0:
            state = "PATROL"
            suspicion = 0
            _route_tick = 0
    var goal := route[route_index] if state == "PATROL" else last_seen
    var distance := Vector2(goal.x - position.x, goal.z - position.z).length()
    var direction := Vector3.ZERO
    pause_time = maxf(0, pause_time - delta)
    # A grid goal may be 0.53 m from the authored point, plus the path follower's
    # 0.3 m arrival radius. A smaller threshold can strand patrols at corners.
    if distance < 0.85:
        if state == "PATROL" and pause_time <= 0:
            route_index = (route_index + 1) % route.size()
            pause_time = 2.8
            _route_tick = 0
        elif state == "SEARCH" or state == "INVESTIGATE":
            rotation.y += delta * 0.6
    elif pause_time <= 0 or state != "PATROL":
        _route_tick -= delta
        if _route_tick <= 0:
            _path = mission.navigation.route(global_position, goal)
            _path_index = 1 if _path.size() > 1 else 0
            _route_tick = 0.55
        while _path_index < _path.size() and Vector2(_path[_path_index].x - position.x, _path[_path_index].z - position.z).length() < 0.3:
            _path_index += 1
        if _path_index < _path.size():
            direction = _path[_path_index] - global_position
            direction.y = 0
            direction = direction.normalized()
    var speed := CHASE_SPEED if state == "CHASE" else (1.9 if state != "PATROL" else PATROL_SPEED)
    var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(direction * speed, 12.0 * delta)
    velocity = Vector3(horizontal.x, -0.2 if is_on_floor() else maxf(velocity.y - 22 * delta, -25), horizontal.z)
    if horizontal.length() > 0.08:
        rotation.y = lerp_angle(rotation.y, atan2(horizontal.x, horizontal.z), 1 - exp(-8 * delta))
    mission.navigation.move_actor(self, delta)
    var next_clip := "Idle" if horizontal.length() < 0.1 else ("Run" if state == "CHASE" else "Walk")
    if _clip != next_clip:
        animation.play(next_clip, 0.2)
        _clip = next_clip
    if state == "CHASE" and sees_player and global_position.distance_to(mission.player.global_position) < 0.95:
        _catch_time += delta
        if _catch_time >= 0.8:
            mission.finish(false, "Você foi alcançado por um vigia.")
    else:
        _catch_time = 0
