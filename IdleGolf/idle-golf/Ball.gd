extends RigidBody3D

signal landed(distance_yards: float)

var _start_z: float
var _has_landed := false
var _speed: float
var _spread: float
var _aim: float = 0.0  # -1.0 to 1.0
var _is_homing := false
var _target_flag: Node3D = null
var _has_peaked := false
@onready var sprite: Sprite3D = $Sprite3D

func launch(speed: float, angle_spread_deg: float, start_z: float) -> void:
	_start_z = start_z
	_speed = speed
	_spread = angle_spread_deg

func _process(delta: float) -> void:
	var distance = abs(global_position.z - _start_z)
	var scale_factor = 1.0 + (distance * 0.04)
	sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	if not _has_landed:
		var ball_data = GameState.balls[GameState.equipped_ball]
		
		# detect apex — when ball starts falling
		if not _has_peaked and linear_velocity.y < 15.0:
			_has_peaked = true
			if ball_data.get("can_home", false):
				_start_homing()
		
		# steer toward flag
		if _is_homing and _target_flag:
			_home_toward_flag(delta)
		
		if global_position.y < 0.5 and abs(linear_velocity.y) < 2.0:
			_land()

func _start_homing() -> void:
	
	# find nearest flag
	var flags = get_tree().get_nodes_in_group("flags")
	var nearest: Node3D = null
	var nearest_dist = INF
	for flag in flags:
		var d = global_position.distance_to(flag.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = flag
	if nearest:
		_target_flag = nearest
		_is_homing = true

func _home_toward_flag(delta: float) -> void:
	var flat_dist = Vector2(global_position.x - _target_flag.global_position.x, 
							global_position.z - _target_flag.global_position.z).length()
	if flat_dist < 20.0:
		_is_homing = false
		return
	
	var target_pos = _target_flag.global_position
	var direction = (target_pos - global_position).normalized()
	var home_strength = 1.0
	linear_velocity = linear_velocity.lerp(direction * linear_velocity.length(), delta * home_strength)
	
func _ready() -> void:
	_start_z = global_position.z
	
	var ball_data = GameState.balls[GameState.equipped_ball]
	var ball_speed_mult = ball_data["speed_mult"]
	
	sprite.texture = ball_data["texture"]
	
	var trail: GPUParticles3D = $GPUParticles3D
	if trail:
		var mat = trail.draw_pass_1.material.duplicate()
		mat.albedo_color = ball_data["trail_color"]
		trail.draw_pass_1.material = mat
	
	var spread_rad = deg_to_rad(randf_range(-_spread, _spread))
	var aim_angle = _aim * deg_to_rad(45.0)
	var distance_mult = randf_range(1.0 - (1.0 / GameState.get_consistency()), 1.0)
	
	linear_velocity = Vector3(
		sin(aim_angle) * _speed * 0.5,
		_speed * 0.38 * ball_speed_mult,
		cos(aim_angle) * _speed * distance_mult * ball_speed_mult
	)
	
func _land() -> void:
	if _has_landed:
		return
	_has_landed = true
	var yards = (global_position.z - _start_z) * 1.094
	print(yards)
	landed.emit(abs(yards))
