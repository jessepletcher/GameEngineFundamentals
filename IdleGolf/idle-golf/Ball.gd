extends RigidBody3D

signal landed(distance_yards: float)

var _start_z: float
var _has_landed := false
var _speed: float
var _spread: float
var _aim: float = 0.0  # -1.0 to 1.0
@onready var sprite: Sprite3D = $Sprite3D

func launch(speed: float, angle_spread_deg: float, start_z: float) -> void:
    _start_z = start_z
    _speed = speed
    _spread = angle_spread_deg

func _process(_delta: float) -> void:
    var distance = abs(global_position.z - _start_z)
    var scale_factor = 1.0 + (distance * 0.04)
    sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
    
    if not _has_landed:
        if global_position.y < 0.2 and abs(linear_velocity.y) < 1.0:
            _land()

func _ready() -> void:
    _start_z = global_position.z
    
    var spread_rad = deg_to_rad(randf_range(-_spread, _spread))
    var aim_angle = _aim * deg_to_rad(45.0)  # max 45 degrees left or right
    
    linear_velocity = Vector3(
        sin(spread_rad + aim_angle) * _speed * 0.08 - _aim * _speed * 0.3,
        _speed * 0.38,
        cos(spread_rad) * _speed
)
    
func _land() -> void:
    if _has_landed:
        return
    _has_landed = true
    var yards = (global_position.z - _start_z) * 1.094
    print(yards)
    landed.emit(abs(yards))
