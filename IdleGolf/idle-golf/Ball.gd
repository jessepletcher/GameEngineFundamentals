extends RigidBody3D

signal landed(distance_yards: float)

var _start_z: float
var _has_landed := false
var _speed: float
var _spread: float

func launch(speed: float, angle_spread_deg: float, start_z: float) -> void:
    _start_z = start_z
    _speed = speed
    _spread = angle_spread_deg

func _ready() -> void:
    _start_z = global_position.z
    print("Ball ready, start_z: ", _start_z, " speed: ", _speed)
    var spread_rad = deg_to_rad(randf_range(-_spread, _spread))
    linear_velocity = Vector3(
        sin(spread_rad) * _speed * 0.08,
        _speed * 0.38,
        cos(spread_rad) * _speed
    )
    await get_tree().create_timer(6.0).timeout
    _land()
func _land() -> void:
    if _has_landed:
        return
    _has_landed = true
    var yards = (global_position.z - _start_z) * 1.094
    print("start_z: ", _start_z, " end_z: ", global_position.z, " yards: ", yards)
    landed.emit(abs(yards))
