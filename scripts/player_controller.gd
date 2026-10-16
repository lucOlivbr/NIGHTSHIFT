extends CharacterBody3D
## Feet-origin controller. Only the visual turns; camera orbit stays independent.

@export_range(0.5, 5.0) var walk_speed := 3.0
@export_range(3.0, 10.0) var run_speed := 6.5
@export var acceleration := 28.0
@export var braking := 34.0
@export var turn_response := 14.0
@export_range(0.0, 0.3) var max_step_height := 0.22
@export var jump_height := 0.95
@export var gravity := 22.0
const JUMP_BUFFER := 0.12
const COYOTE_TIME := 0.10

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var animation_player: AnimationPlayer = $Visual/Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_rig: Node3D = $CameraRig
@onready var skate: Node = $SkateMotor
@onready var board: Node3D = $Board
@onready var collider: CollisionShape3D = $CollisionShape3D

var horizontal_speed := 0.0
var locomotion_state := "Idle"
var _movement_blend := 0.0
var _gait_speed := 3.0
var _meshes: Array[MeshInstance3D] = []
var is_skating := false
var skate_blend := 0.0
var mount_hint := ""
var _hint_time := 0.0
var skate_pose: SkeletonModifier3D
var crouch_stance: SkeletonModifier3D
var controls_enabled := true
var is_crouching := false
var _jump_buffer := 0.0
var _coyote := 0.0
var _jump_active := false
var _air_blend := 0.0
var _takeoff_time := 0.0
var _landing_time := 0.0
var _air_state := ""
var _gameplay_paused := false
var _paused_velocity := Vector3.ZERO
var _paused_momentum := Vector3.ZERO
var _reverse_turn := false
var _air_playback: AnimationNodeStateMachinePlayback
const CROUCH_SPEED := 1.35

func _ready() -> void:
    # Imported resources stay unchanged and can still be previewed in the editor.
    var library := animation_player.get_animation_library("").duplicate(true) as AnimationLibrary
    animation_player.remove_animation_library("")
    animation_player.add_animation_library("", library)
    for animation_name in [&"Idle", &"Walk", &"Run"]:
        var clip := animation_player.get_animation(animation_name)
        assert(clip != null, "Missing real character animation: " + animation_name)
        clip.loop_mode = Animation.LOOP_LINEAR
    _make_skate_stance(library)
    _load_jump_animations(library)
    var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
    skate_pose = preload("res://scripts/skate_pose.gd").new()
    skate_pose.name = "SkatePose"
    skeleton.add_child(skate_pose)
    skate_pose.setup(self)
    crouch_stance = preload("res://scripts/crouch_stance.gd").new()
    crouch_stance.name = "GameplayCrouch"
    crouch_stance.rider = self
    crouch_stance.rig = skate_pose
    crouch_stance.influence = 0
    skeleton.add_child(crouch_stance)
    collider.shape = collider.shape.duplicate()
    for mesh in model.find_children("*", "MeshInstance3D", true, false):
        _meshes.append(mesh as MeshInstance3D)
        # Bone animation can extend outside the imported bind-pose bounds.
        # Mesh coordinates use centimeters x 0.01 in this FBX-derived GLB.
        mesh.extra_cull_margin = 0.012
    animation_tree.active = true
    _air_playback = animation_tree.get("parameters/AirState/playback")
    camera_rig.snap_to_target()

func _load_jump_animations(library: AnimationLibrary) -> void:
    # Separate retargeted source clips; the character GLB and skate stay intact.
    var jump_library := load("res://assets/characters/jump/jump_animations.tres") as AnimationLibrary
    assert(jump_library != null, "Missing retargeted jump animation library")
    for clip_name in [&"JumpStart", &"JumpLoop", &"JumpLand"]:
        assert(jump_library.has_animation(clip_name), "Missing jump clip: " + clip_name)
        library.add_animation(clip_name, jump_library.get_animation(clip_name))

func reset_motion_state() -> void:
    _jump_buffer = 0.0
    _coyote = 0.0
    _jump_active = false
    _air_blend = 0.0
    _takeoff_time = 0.0
    _landing_time = 0.0
    _air_state = ""
    _movement_blend = 0.0
    _gait_speed = walk_speed
    _reverse_turn = false
    _gameplay_paused = false
    _paused_velocity = Vector3.ZERO
    _paused_momentum = Vector3.ZERO
    horizontal_speed = 0.0
    animation_tree.active = true
    animation_tree.set("parameters/Air/blend_amount", 0.0)
    animation_tree.set("parameters/StartStop/blend_amount", 0.0)
    animation_tree.set("parameters/Pace/scale", 0.0)

func set_gameplay_paused(paused: bool) -> void:
    if paused == _gameplay_paused:
        return
    _gameplay_paused = paused
    _jump_buffer = 0.0
    if paused:
        _paused_velocity = velocity
        _paused_momentum = skate.momentum
        velocity = Vector3.ZERO
        skate.momentum = Vector3.ZERO
    else:
        velocity = _paused_velocity
        skate.momentum = _paused_momentum
    animation_tree.active = not paused

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("skate_toggle"):
        if camera_rig.mouse_captured and controls_enabled:
            toggle_skate()

func toggle_skate() -> bool:
    if not controls_enabled or is_crouching:
        mount_hint = "Solte C / Ctrl antes de subir no skate."
        _hint_time = 1.5
        return false
    if not is_on_floor():
        mount_hint = "Aguarde tocar o chão para usar F."
        _hint_time = 2.0
        return false
    if not is_skating:
        # The board's ends need a little more room than a pedestrian capsule.
        # Test BEFORE resizing, so F beside a wall cannot embed/eject the body.
        var shape := CapsuleShape3D.new()
        shape.radius = 0.43
        shape.height = 1.95
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = shape
        query.transform = global_transform
        query.transform.origin += Vector3.UP * (0.975 + 0.03)
        query.collision_mask = collision_mask
        query.exclude = [get_rid()]
        if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
            mount_hint = "Afaste-se um pouco da parede ou da guia para subir."
            _hint_time = 2.0
            return false
        skate.start(Vector3(velocity.x, 0, velocity.z), visual.rotation.y)
        collider.shape.radius = 0.43
        collider.shape.height = 1.95
        collider.position.y = 0.975
    else:
        var carry: Vector3 = skate.momentum.limit_length(walk_speed)
        velocity.x = carry.x
        velocity.z = carry.z
        collider.shape.radius = 0.3
        collider.shape.height = 1.8
        collider.position.y = 0.9
    is_skating = not is_skating
    mount_hint = ""
    return true

func _make_skate_stance(library: AnimationLibrary) -> void:
    # Neutral source for the skeletal modifier, kept separate from foot clips.
    animation_player.play("Idle")
    animation_player.advance(0.4)
    var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
    skeleton.force_update_all_bone_transforms()
    var clip := animation_player.get_animation("Idle").duplicate(true) as Animation
    clip.resource_name = "Skate neutral (procedural modifier input)"
    library.add_animation("SkateStance", clip)
    animation_player.stop()

func _physics_process(delta: float) -> void:
    # Freeze before gravity/integration. Menus cannot consume a jump in midair.
    if not controls_enabled:
        return
    if get_parent().get("mission") != null:
        set_gameplay_paused(not camera_rig.mouse_captured)
    if _gameplay_paused:
        return
    _hint_time = maxf(0.0, _hint_time - delta)
    if _hint_time == 0.0:
        mount_hint = ""
    var input_direction := Vector2.ZERO
    set_crouching(camera_rig.mouse_captured and Input.is_action_pressed("crouch") and not is_skating and is_on_floor() and not _jump_active)
    if camera_rig.mouse_captured and controls_enabled:
        input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var horizontal := Vector3(velocity.x, 0, velocity.z)
    if is_skating:
        var brake_force: float = skate.hard_brake if Input.is_action_pressed("skate_brake") else (skate.foot_brake if input_direction.y > 0.1 else 0.0)
        horizontal = skate.drive(delta, input_direction.x, input_direction.y < -0.1, brake_force, camera_rig.mouse_captured and controls_enabled)
    else:
        var direction: Vector3 = Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(input_direction.x, 0, input_direction.y)
        var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
        if is_crouching:
            speed = CROUCH_SPEED
        var target := direction * speed
        _reverse_turn = not direction.is_zero_approx() and horizontal.length() > 0.3 and horizontal.normalized().dot(direction.normalized()) < -0.25
        var response := braking if direction.is_zero_approx() else (40.0 if _reverse_turn else acceleration)
        if not is_on_floor():
            response *= 0.38
        horizontal = horizontal.move_toward(target, response * delta)
    velocity.x = horizontal.x
    velocity.z = horizontal.z
    var was_grounded := is_on_floor()
    _jump_buffer = maxf(0.0, _jump_buffer - delta)
    _coyote = COYOTE_TIME if was_grounded and not _jump_active else maxf(0.0, _coyote - delta)
    if camera_rig.mouse_captured and not is_skating and Input.is_action_just_pressed("jump"):
        _jump_buffer = JUMP_BUFFER
    if _jump_buffer > 0.0 and _coyote > 0.0 and not is_skating:
        # Crouch may stand up to jump, but never expand the capsule into a roof.
        if not set_crouching(false):
            velocity.y = sqrt(2.0 * gravity * jump_height)
            _jump_buffer = 0.0
            _coyote = 0.0
            _jump_active = true
            _landing_time = 0.0
            _takeoff_time = animation_player.get_animation("JumpStart").length
            _set_air_state("Takeoff", true)
    elif was_grounded:
        velocity.y = -0.2
    else:
        velocity.y = maxf(velocity.y - gravity * delta, -35.0)
    var previous_position := global_position
    var stepped := _try_step_up(delta)
    if not stepped:
        move_and_slide()
    if not was_grounded and is_on_floor():
        if not is_skating and (_jump_active or _air_blend > 0.1):
            _set_air_state("Land")
            # A running landing returns to the gait promptly, rather than
            # dragging planted landing feet along the street for a whole clip.
            _landing_time = minf(animation_player.get_animation("JumpLand").length, 0.14 if horizontal.length() > 1.0 else 0.28)
        _jump_active = false
        _takeoff_time = 0.0
    if is_skating:
        skate.reconcile(Vector3(velocity.x, 0, velocity.z))
    var actual := (global_position - previous_position) / delta
    horizontal_speed = Vector2(actual.x, actual.z).length()
    skate_blend = move_toward(skate_blend, 1.0 if is_skating else 0.0, delta / (0.48 if is_skating else 0.4))
    if is_skating:
        visual.rotation.y = lerp_angle(visual.rotation.y, skate.heading + PI / 2.0, 1.0 - exp(-16.0 * delta))
    elif horizontal_speed > 0.08 and skate_blend < 0.01:
        # The artist's character faces +Z. Steering follows camera-relative travel.
        var facing := Vector3(actual.x, 0, actual.z)
        if _reverse_turn:
            facing = Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(input_direction.x, 0, input_direction.y)
        visual.rotation.y = rotate_toward(visual.rotation.y, atan2(facing.x, facing.z), (22.0 if _reverse_turn else turn_response) * delta)
    _animate(delta)
    skate_pose.tick(delta)
    crouch_stance.tick(delta)
    board.visible = skate_blend > 0.01
    board.rotation = Vector3(0, skate.heading, skate.lean * skate_blend)
    var riding_position := Vector3(0, 0.16, 0)
    visual.position = Vector3(0, 0.005, 0).lerp(riding_position, smoothstep(0.0, 1.0, skate_blend))
    visual.rotation.x = 0.0

func set_crouching(wanted: bool) -> bool:
    if wanted == is_crouching or is_skating:
        return is_crouching
    if not wanted:
        var shape := CapsuleShape3D.new()
        shape.radius = 0.3
        shape.height = 1.8
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = shape
        query.transform = global_transform
        query.transform.origin += Vector3.UP * 0.925
        query.collision_mask = collision_mask
        query.exclude = [get_rid()]
        if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
            return true
    is_crouching = wanted
    collider.shape.height = 1.05 if wanted else 1.8
    collider.position.y = 0.525 if wanted else 0.9
    return is_crouching

func _try_step_up(delta: float) -> bool:
    # Only test small curbs when the normal motion would hit an obstacle.
    # Three swept capsule checks enforce headroom, forward clearance and landing;
    # tall facade walls cannot pass the height/normal tests. No per-frame mesh work.
    if not is_on_floor() or velocity.y > 0.0:
        return false
    var motion := Vector3(velocity.x, 0, velocity.z) * delta
    if motion.length_squared() < 0.000001:
        return false
    var query := PhysicsTestMotionParameters3D.new()
    query.from = global_transform
    query.motion = motion
    query.margin = 0.001
    var blocked := PhysicsTestMotionResult3D.new()
    if not PhysicsServer3D.body_test_motion(get_rid(), query, blocked):
        return false
    # Rounded capsule contact on the final street curb is almost exactly 45°.
    # Treat only an essentially flat contact as floor here; otherwise the motor
    # loses its small starting impulse forever before the step sweep can run.
    if blocked.get_collision_normal().y > 0.98:
        return false
    query.motion = Vector3.UP * max_step_height
    if PhysicsServer3D.body_test_motion(get_rid(), query):
        return false
    query.from.origin += Vector3.UP * max_step_height
    query.motion = motion
    if PhysicsServer3D.body_test_motion(get_rid(), query):
        return false
    query.from.origin += motion
    query.motion = Vector3.DOWN * (max_step_height + 0.02)
    var landing := PhysicsTestMotionResult3D.new()
    if not PhysicsServer3D.body_test_motion(get_rid(), query, landing):
        return false
    var destination := query.from.origin + landing.get_travel()
    var rise := destination.y - global_position.y
    if rise < 0.0005 or rise > max_step_height + 0.001:
        return false
    if landing.get_collision_normal().y < cos(floor_max_angle):
        # Rounded capsule contact at a curb edge has a diagonal normal. Confirm
        # that the actual surface just beyond the edge is a walkable top face.
        var point := landing.get_collision_point() + motion.normalized() * 0.04
        var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.05, point - Vector3.UP * 0.05, collision_mask, [get_rid()])
        var surface := get_world_3d().direct_space_state.intersect_ray(ray)
        if surface.is_empty() or surface.normal.y < cos(floor_max_angle):
            return false
    global_position = destination
    velocity.y = 0.0
    return true

func _animate(delta: float) -> void:
    var moving := horizontal_speed > 0.08 and not is_skating
    # Pose amplitude settles with actual travel, including wall collisions.
    # Cadence has no minimum: stopped feet cannot keep walking in place.
    var movement_target := smoothstep(0.04, 0.95, horizontal_speed) if not is_skating else 0.0
    _movement_blend = move_toward(_movement_blend, movement_target, delta / (0.09 if moving else 0.07))
    _gait_speed = move_toward(_gait_speed, clampf(horizontal_speed, walk_speed, run_speed), 18.0 * delta)
    var gait := inverse_lerp(walk_speed, run_speed, _gait_speed)
    var native_speed := lerpf(1.6, 3.8, gait)
    var pace := clampf(horizontal_speed / native_speed, 0.0, 2.4)
    _takeoff_time = maxf(0.0, _takeoff_time - delta)
    _landing_time = maxf(0.0, _landing_time - delta)
    var airborne := not is_on_floor() and not is_skating
    if airborne and _takeoff_time <= 0.0 and _air_state != "Air":
        _set_air_state("Air", _air_blend < 0.01)
    var air_target := 1.0 if airborne or _landing_time > 0.0 else 0.0
    _air_blend = move_toward(_air_blend, air_target, delta / (0.08 if air_target > _air_blend else 0.12))
    animation_tree.set("parameters/StartStop/blend_amount", _movement_blend)
    animation_tree.set("parameters/Gait/blend_position", _gait_speed)
    animation_tree.set("parameters/Pace/scale", pace)
    animation_tree.set("parameters/Ride/blend_amount", smoothstep(0.0, 1.0, skate_blend))
    animation_tree.set("parameters/Air/blend_amount", _air_blend)
    locomotion_state = "Skate" if is_skating else ("Jump" if airborne else ("Idle" if not moving else ("Run" if horizontal_speed > walk_speed + 0.6 else "Walk")))

func _set_air_state(state: String, restart := false) -> void:
    if _air_playback == null:
        return
    if restart or not _air_playback.is_playing():
        _air_playback.start(state, true)
    else:
        _air_playback.travel(state)
    _air_state = state

func get_facing_yaw() -> float:
    return skate.heading if is_skating else visual.rotation.y

func get_camera() -> Camera3D:
    return camera_rig.camera
