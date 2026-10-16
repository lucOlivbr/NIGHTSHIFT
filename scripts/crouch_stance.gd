extends SkeletonModifier3D
## Minimal gameplay crouch. Retains locomotion clips and planted animated feet.
## Reuses the existing limb solver; no skate curves or source assets are edited.
var rider: CharacterBody3D
var rig: SkeletonModifier3D

func tick(delta: float) -> void:
    influence = move_toward(influence, 1.0 if rider.is_crouching else 0.0, delta * 6)

func _process_modification_with_delta(_delta: float) -> void:
    if rider == null or influence < 0.001 or rider.is_skating:
        return
    var left: Transform3D = rig.pose("Foot.L")
    var right: Transform3D = rig.pose("Foot.R")
    var body: Transform3D = rig.pose("Body")
    body.origin += Vector3(0, -0.62, -0.1)
    rig.put("Body", body)
    rig.rotate_bone("Abdomen", Quaternion(Vector3.RIGHT, 0.18))
    for side in ["L", "R"]:
        rig.rotate_bone("UpperArm." + side, Quaternion(Vector3.RIGHT, -0.65))
        rig.rotate_bone("LowerArm." + side, Quaternion(Vector3.RIGHT, 0.45))
    rig.solve_leg("L", left.origin, 0)
    rig.solve_leg("R", right.origin, 0)
