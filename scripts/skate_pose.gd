extends SkeletonModifier3D
## Hybrid skate animation on the existing Quaternius skeleton. The donor's
## authored body rhythm is retained; two-bone legs/contact are solved here.
## Runs after AnimationTree and blends through SkeletonModifier3D.influence.

const MOTION = preload("res://assets/skate/skate_motion_kenney.gd")
var rider: CharacterBody3D
var phase := 0.0
var pushing := false
var ground_stroke := false
var transition_progress := 0.0
var foot_targets: Dictionary = {}
var solved_feet: Dictionary = {}
var _cycling := false
var _clock := 0.0
var _base: Array[Transform3D] = []
var _bones: Dictionary = {}
var _tips: Dictionary = {}
var _lengths: Dictionary = {}
var _space := Transform3D.IDENTITY
var _inverse := Transform3D.IDENTITY
var _motion: Dictionary = {}

func setup(player: CharacterBody3D) -> void:
    rider = player
    var sk := get_skeleton()
    _space = rider.model.global_transform.affine_inverse() * sk.global_transform
    _inverse = _space.affine_inverse()
    _motion = MOTION.DATA.clips
    for bone in sk.get_bone_count():
        _bones[String(sk.get_bone_name(bone))] = bone
        _base.append(sk.get_bone_pose(bone))
    for side in ["L", "R"]:
        var upper := pose("UpperLeg." + side)
        var lower := pose("LowerLeg." + side)
        var foot := pose("Foot." + side)
        _tips[side] = lower.affine_inverse() * foot.origin
        _lengths[side] = Vector2(upper.origin.distance_to(lower.origin), lower.origin.distance_to(foot.origin))
    influence = 0.0

func tick(delta: float) -> void:
    _clock += delta
    transition_progress = rider.skate_blend
    influence = smoothstep(0.0, 1.0, transition_progress)
    pushing = rider.is_skating and rider.is_on_floor() and rider.camera_rig.mouse_captured and Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_back") and not Input.is_action_pressed("skate_brake") and rider.horizontal_speed < 8.7 and transition_progress > 0.98
    if pushing and not _cycling:
        phase = 0.0
        _cycling = true
    if _cycling:
        phase += delta / lerpf(1.12, 0.82, clampf(rider.horizontal_speed / 9.0, 0.0, 1.0))
        if phase >= 1.0:
            phase = fmod(phase, 1.0) if pushing else 0.0
            _cycling = pushing
    if not rider.is_skating:
        _cycling = false
        phase = 0.0
    ground_stroke = _cycling and phase >= 0.22 and phase < 0.58

func pose(bone_name: String) -> Transform3D:
    return _space * get_skeleton().get_bone_global_pose(_bones[bone_name])

func put(bone_name: String, value: Transform3D) -> void:
    get_skeleton().set_bone_global_pose(_bones[bone_name], _inverse * value)

func rotate_bone(bone_name: String, rotation: Quaternion) -> void:
    var value := pose(bone_name)
    value.basis = Basis(rotation) * value.basis
    put(bone_name, value)

func _process_modification_with_delta(_delta: float) -> void:
    if rider == null or _base.is_empty() or influence < 0.001:
        return
    var sk := get_skeleton()
    # Start from the real neutral pose. No accumulated offsets between frames;
    # the modifier restores AnimationTree's foot locomotion after each update.
    for bone in _base.size():
        sk.set_bone_pose(bone, _base[bone])
    var cycle := phase if _cycling else 0.0
    var rhythm := sin(cycle * TAU) if _cycling else sin(_clock * 2.1) * 0.12
    var weight_shift := sin(cycle * PI) if _cycling else 0.0
    var body := pose("Body")
    body.origin += Vector3(0.035 * weight_shift, -0.13 - absf(rhythm) * 0.018 - 0.18 * weight_shift, rider.skate.lean * 0.3 + 0.1 * weight_shift)
    body.basis = Basis(Vector3.RIGHT, -rider.skate.lean * 1.6) * body.basis
    put("Body", body)
    rotate_bone("Abdomen", Quaternion(Vector3.FORWARD, -0.08 - (0.06 if _cycling else 0.0)))
    rotate_bone("Chest", Quaternion(Vector3.UP, -0.25))
    rotate_bone("Head", Quaternion(Vector3.UP, -0.72))
    # Actual authored torso and arm curves, adapted from the much smaller donor.
    var clip := "skate" if _cycling else "skate-stand"
    var sample_time := cycle * 0.51666665 if _cycling else fmod(_clock * 0.25, 0.5)
    var remap := Quaternion(Vector3.UP, -PI / 2.0)
    for mapping in [["torso", "Torso", 0.65], ["arm-left", "UpperArm.L", 0.65], ["arm-right", "UpperArm.R", 0.65]]:
        var key: String = mapping[0] + "/rotation"
        var rotation := sample_rotation(clip, key, sample_time)
        var first := sample_rotation(clip, key, 0.0)
        var adapted := remap * (rotation * first.inverse()) * remap.inverse()
        rotate_bone(mapping[1], Quaternion.IDENTITY.slerp(adapted, mapping[2]))
    rotate_bone("UpperArm.L", Quaternion(Vector3.FORWARD, 0.18 + rider.skate.lean * 0.5))
    rotate_bone("UpperArm.R", Quaternion(Vector3.FORWARD, -0.18 + rider.skate.lean * 0.5))
    var support := Vector3(-0.23, 0.035, 0.015)
    var pushing_foot := Vector3(0.23, 0.035, 0.015)
    if _cycling:
        if cycle < 0.22:
            var t := smoothstep(0.0, 0.22, cycle)
            pushing_foot = pushing_foot.lerp(Vector3(-0.1, -0.137, 0.34), t)
            pushing_foot.y += sin(t * PI) * 0.14
        elif cycle < 0.58:
            var t := inverse_lerp(0.22, 0.58, cycle)
            pushing_foot = Vector3(lerpf(-0.1, 0.56, t), -0.137, 0.34)
        else:
            var t := smoothstep(0.58, 1.0, cycle)
            pushing_foot = Vector3(0.56, -0.137, 0.34).lerp(pushing_foot, t)
            pushing_foot.y += sin(t * PI) * 0.24
    # Staggered foot lifts make mounting/dismounting read as two steps. The
    # root and AnimationTree blend continuously, including an interrupted F.
    if transition_progress > 0.001 and transition_progress < 0.999:
        support.y += sin(smoothstep(0.0, 0.7, transition_progress) * PI) * 0.16
        pushing_foot.y += sin(smoothstep(0.25, 1.0, transition_progress) * PI) * 0.2
    # Match planted shoes to the banked board instead of rotating the whole rig.
    var bank := Basis(Vector3.RIGHT, -rider.skate.lean)
    support = bank * support
    if not _cycling:
        pushing_foot = bank * pushing_foot
    foot_targets = {"R": support, "L": pushing_foot}
    solve_leg("R", support, -0.48)
    solve_leg("L", pushing_foot, -0.08 if not _cycling else lerpf(-0.08, -PI / 2.0, sin(cycle * PI)))

func solve_leg(side: String, target: Vector3, foot_yaw: float) -> void:
    var upper_name := "UpperLeg." + side
    var lower_name := "LowerLeg." + side
    var upper := pose(upper_name)
    var lower := pose(lower_name)
    var lengths: Vector2 = _lengths[side]
    var reach := target - upper.origin
    var distance := clampf(reach.length(), absf(lengths.x - lengths.y) + 0.001, lengths.x + lengths.y - 0.003)
    var direction := reach.normalized()
    var pole := Vector3(0, 0, 1)
    var bend := (pole - direction * pole.dot(direction)).normalized()
    var along := (lengths.x * lengths.x - lengths.y * lengths.y + distance * distance) / (2.0 * distance)
    var knee := upper.origin + direction * along + bend * sqrt(maxf(0.0, lengths.x * lengths.x - along * along))
    upper.basis = Basis(Quaternion((lower.origin - upper.origin).normalized(), (knee - upper.origin).normalized())) * upper.basis
    put(upper_name, upper)
    lower = pose(lower_name)
    var endpoint: Vector3 = lower * _tips[side]
    lower.basis = Basis(Quaternion((endpoint - lower.origin).normalized(), (target - lower.origin).normalized())) * lower.basis
    put(lower_name, lower)
    var foot := pose("Foot." + side)
    foot.origin = upper.origin + direction * distance
    foot.basis = Basis(Vector3.UP, foot_yaw) * foot.basis
    if side == "R" or not _cycling:
        foot.basis = Basis(Vector3.RIGHT, -rider.skate.lean) * foot.basis
    put("Foot." + side, foot)
    solved_feet[side] = foot.origin

func sample_rotation(clip: String, key: String, time: float) -> Quaternion:
    var track: Dictionary = _motion[clip][key]
    var times: Array = track.times
    var values: Array = track.values
    var index := 0
    while index < times.size() - 2 and time > float(times[index + 1]):
        index += 1
    var a: Array = values[index]
    var b: Array = values[index + 1]
    var amount := clampf(inverse_lerp(times[index], times[index + 1], time), 0.0, 1.0)
    return Quaternion(a[0], a[1], a[2], a[3]).normalized().slerp(Quaternion(b[0], b[1], b[2], b[3]).normalized(), amount)
