extends Node3D
## Orbit + sphere sweep, no screen effects, independent from the visual's yaw.

@export var mouse_sensitivity := 0.0025
@export var look_response := 28.0
@export var follow_response := 18.0
@export var target_height := 1.30
@export var min_pitch := -1.05
@export var max_pitch := 0.30
@export var min_distance := 2.4
@export var max_distance := 5.5

@onready var target: CharacterBody3D = get_parent() as CharacterBody3D
@onready var pitch_pivot: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D

var mouse_captured := true
var target_yaw := 0.0
var target_pitch := -0.20
var target_distance := 3.8
var _render_distance := 3.8
var _wall_blend := 0.0
var input_locked := false

func _ready() -> void:
    spring_arm.add_excluded_object(target.get_rid())
    set_mouse_captured(true)
    snap_to_target()

func snap_to_target() -> void:
    global_position = target.global_position + Vector3.UP * target_height
    rotation = Vector3(0, target_yaw, 0)
    pitch_pivot.rotation.x = target_pitch
    spring_arm.spring_length = target_distance
    _render_distance = target_distance
    _wall_blend = 0.0
    reset_physics_interpolation()

func set_mouse_captured(captured: bool) -> void:
    mouse_captured = captured
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE)

func orbit(relative_motion: Vector2) -> void:
    target_yaw = wrapf(target_yaw - relative_motion.x * mouse_sensitivity, -PI, PI)
    target_pitch = clampf(target_pitch - relative_motion.y * mouse_sensitivity, min_pitch, max_pitch)

func _unhandled_input(event: InputEvent) -> void:
    if input_locked:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            set_mouse_captured(not mouse_captured)
        elif event.is_action_pressed("camera_recenter") and mouse_captured:
            target_yaw = wrapf(target.get_facing_yaw() - PI, -PI, PI)
            target_pitch = -0.20
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
            set_mouse_captured(true)
        elif mouse_captured:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                target_distance = clampf(target_distance - 0.35, min_distance, max_distance)
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                target_distance = clampf(target_distance + 0.35, min_distance, max_distance)
    elif event is InputEventMouseMotion and mouse_captured:
        orbit(event.screen_relative)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        set_mouse_captured(false)

func _physics_process(delta: float) -> void:
    var look := 1.0 - exp(-look_response * delta)
    rotation.y = lerp_angle(rotation.y, target_yaw, look)
    # A lagging horizontal pivot can enter the facade while the body is safe.
    # Keep X/Z on the collider; smooth only height (curbs and the close view).
    var away := Basis(Vector3.UP, rotation.y) * Vector3.BACK
    var origin := target.global_position + Vector3.UP * target_height
    var query := PhysicsRayQueryParameters3D.create(origin, origin + away * 1.6, 1, [target.get_rid()])
    var wall := get_world_3d().direct_space_state.intersect_ray(query)
    var close_amount := 0.0
    if not wall.is_empty():
        close_amount = 1.0 - smoothstep(0.35, 1.5, origin.distance_to(wall.position))
    _wall_blend = lerpf(_wall_blend, close_amount, 1.0 - exp(-14.0 * delta))
    var anchor := target.global_position + Vector3.UP * (target_height + 1.9 * _wall_blend)
    # Keep the orbit orientation independent of takeoff/landing. A gentler
    # vertical follow absorbs the jump arc and landing without camera bob.
    var vertical_response := follow_response if target.is_on_floor() else 5.5
    global_position = Vector3(anchor.x, lerpf(global_position.y, anchor.y, 1.0 - exp(-vertical_response * delta)), anchor.z)
    # Above-head framing in the last few centimeters avoids seeing inside the
    # model without ever hiding the character or changing its physical position.
    var framed_pitch := lerpf(target_pitch, -1.28, _wall_blend)
    pitch_pivot.rotation.x = lerpf(pitch_pivot.rotation.x, framed_pitch, look)
    spring_arm.spring_length = lerpf(spring_arm.spring_length, target_distance, 1.0 - exp(-10.0 * delta))
    var run_amount: float = clampf((target.horizontal_speed - target.walk_speed) / (target.run_speed - target.walk_speed), 0.0, 1.0)
    camera.fov = lerpf(camera.fov, lerpf(62.0, 67.0, run_amount), 1.0 - exp(-5.0 * delta))

func resolve_camera_distance(delta: float) -> void:
    var allowed := maxf(0.0, spring_arm.get_hit_length())
    # Retract immediately for safety; extend gradually when a wall/corner clears.
    _render_distance = allowed if allowed < _render_distance else move_toward(_render_distance, allowed, 8.0 * delta)
    camera.position = Vector3(0, 0, _render_distance)
    # Keep the character centered in the elevated close view, instead of filling
    # the frame with the head. The collision sphere still governs camera position.
    var neutral := spring_arm.global_basis.orthonormalized().get_rotation_quaternion()
    var aimed := Transform3D(Basis.IDENTITY, camera.global_position).looking_at(target.global_position + Vector3.UP * 1.0).basis.get_rotation_quaternion()
    camera.global_basis = Basis(neutral.slerp(aimed, _wall_blend))
