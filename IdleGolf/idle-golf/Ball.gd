extends RigidBody3D

signal landed(distance_yards: float)
signal whiffed
signal exploded(fragments: Array)

var _start_z: float
var _has_landed := false
var _speed: float
var _spread: float
var _aim: float = 0.0  # -1.0 to 1.0
var _is_whiff := false
var _is_firework := false
var _is_fragment := false
var _is_fake := false
var _is_homing := false
var _target_flag: Node3D = null
var _has_peaked := false
var _prev_velocity_y := 0.0
var _initial_velocity_y := 0.0
var _homing_time := 0.0
var _launch_modifier := Vector2.ZERO  # x = curve, y = launch angle
@onready var sprite: Sprite3D = $Sprite3D
@onready var trail: GPUParticles3D = $GPUParticles3D

func launch(speed: float, angle_spread_deg: float, start_z: float) -> void:
	_start_z = start_z
	_speed = speed
	_spread = angle_spread_deg

func _physics_process(delta: float) -> void:
	if not _has_landed and global_position.y > 0.2:
		apply_central_force(Vector3(_curve * .5, 0, 0))
	
	# scale sprite
	var distance = abs(global_position.z - _start_z)
	var scale_factor = pow(distance * 0.05, 1.0)
	sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)

	# disable trail particles far from origin for performance
	var dist_from_origin = global_position.length()
	if trail.emitting and dist_from_origin > 800.0:
		trail.emitting = false
	elif not trail.emitting and dist_from_origin < 800.0:
		trail.emitting = true
	
	# firework explosion before apex — trigger when upward velocity drops below 40% of initial
	if _is_firework and not _has_peaked and _prev_velocity_y > 0:
		if linear_velocity.y < _initial_velocity_y * 0.4:
			_has_peaked = true
			_explode()
			return
	_prev_velocity_y = linear_velocity.y

	# homing
	if _is_homing and _target_flag:
		_homing_time += delta
		_home_toward_flag(delta)
	
	if not _has_landed and global_position.y < 1.0 and _prev_velocity_y < 0.0:
		_land()
		
func _start_homing() -> void:
	var flags = get_tree().get_nodes_in_group("flags")
	if flags.size() == 0:
		return

	# estimate landing position using full velocity (including aim direction)
	var time_to_land = 0.0
	if linear_velocity.y > 0:
		time_to_land = (linear_velocity.y * 2.0) / 9.8
	var estimated_landing = global_position + Vector3(
		linear_velocity.x * time_to_land,
		0.0,
		linear_velocity.z * time_to_land
	)

	# sort flags by distance to estimated landing (closest to landing spot first)
	var sorted_flags = flags.duplicate()
	sorted_flags.sort_custom(func(a, b):
		var da = Vector2(a.global_position.x, a.global_position.z).distance_to(Vector2(estimated_landing.x, estimated_landing.z))
		var db = Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(estimated_landing.x, estimated_landing.z))
		return da < db
	)

	# pick the closest flag to where we'd naturally land, but only if reachable
	var flat_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	var max_range = flat_speed * time_to_land * 0.9  # conservative 90% of max distance
	var best_flag: Node3D = null
	for flag in sorted_flags:
		var flag_dist = Vector2(flag.global_position.x, flag.global_position.z).distance_to(Vector2(global_position.x, global_position.z))
		if flag_dist <= max_range:
			best_flag = flag
			break

	# fallback to nearest flag if none are in range
	if not best_flag:
		sorted_flags.sort_custom(func(a, b):
			return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position)
		)
		best_flag = sorted_flags[0]

	_target_flag = best_flag
	_is_homing = true

func _home_toward_flag(delta: float) -> void:
	# give up after 5 seconds to prevent infinite orbiting
	if _homing_time > 5.0:
		_is_homing = false
		return

	var flat_pos = Vector3(global_position.x, 0, global_position.z)
	var flat_target = Vector3(_target_flag.global_position.x, 0, _target_flag.global_position.z)
	var flat_dist = flat_pos.distance_to(flat_target)

	if flat_dist < 3.0 and global_position.y < 2.0:
		_is_homing = false
		_land()
		return

	# steer toward flag — scales with ball speed so fast balls still turn
	var direction = (flat_target - flat_pos).normalized()
	var current_flat_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var speed = current_flat_vel.length()
	var desired_vel = direction * speed
	var time_strength = clamp(_homing_time * 0.3, 0.05, 2.0)
	var speed_strength = clamp(speed * 0.1, 1.0, 5.0)
	var steer = (desired_vel - current_flat_vel) * time_strength * speed_strength
	apply_central_force(steer)
	
func _explode() -> void:
	var BallScene = preload("res://scenes/Ball.tscn")
	var fragments: Array = []
	var total_count := 6
	var real_count := 3

	for i in total_count:
		var angle = (TAU / float(total_count)) * i

		if i < real_count:
			# real fragment — earns money on landing
			var frag = BallScene.instantiate()
			frag._is_fragment = true
			frag._speed = 0
			frag._spread = 0
			frag._start_z = _start_z
			get_parent().add_child(frag)
			frag.global_position = global_position
			frag.linear_velocity = Vector3(
				sin(angle) * randf_range(5.0, 15.0),
				randf_range(2.0, 6.0),
				cos(angle) * randf_range(5.0, 15.0)
			)
			fragments.append(frag)
		else:
			# fake particle — just visuals, no landing signal
			var fake = BallScene.instantiate()
			fake._is_fragment = true
			fake._is_fake = true
			fake._speed = 0
			fake._spread = 0
			fake._start_z = _start_z
			get_parent().add_child(fake)
			fake.global_position = global_position
			fake.linear_velocity = Vector3(
				sin(angle) * randf_range(5.0, 15.0),
				randf_range(2.0, 6.0),
				cos(angle) * randf_range(5.0, 15.0)
			)

	exploded.emit(fragments)
	queue_free()

func _ready() -> void:
	add_to_group("balls")
	if _is_fragment:
		_start_z = _start_z  # already set by parent
		trail.draw_pass_1 = trail.draw_pass_1.duplicate()
		var mat = trail.draw_pass_1.material.duplicate()
		if _is_fake:
			mat.albedo_color = Color.ORANGE
			sprite.visible = false
		else:
			var ball_data = GameState.balls[GameState.equipped_ball]
			mat.albedo_color = ball_data["trail_color"]
		trail.draw_pass_1.material = mat
		return

	_start_z = global_position.z

	var ball_data = GameState.balls[GameState.equipped_ball]
	trail.draw_pass_1 = trail.draw_pass_1.duplicate()
	var mat = trail.draw_pass_1.material.duplicate()
	mat.albedo_color = ball_data["trail_color"]
	trail.draw_pass_1.material = mat
	var ball_speed_mult = ball_data["speed_mult"]
	
	var spread_rad = deg_to_rad(randf_range(-_spread, _spread))
	var aim_angle = _aim * deg_to_rad(50.0) + spread_rad
	var consistency = GameState.get_consistency()
	var worst_possible = 1.0 - (1.0 / consistency)
	var distance_mult = randf_range(worst_possible, 1.0)
	var whiff_percent = clamp(0.2 / consistency, 0.01, 0.2)  # shrinks as consistency levels up
	var whiff_threshold = worst_possible + (1.0 - worst_possible) * whiff_percent
	if distance_mult < whiff_threshold:
		distance_mult *= 0.3
		_is_whiff = true
	var horizontal_offset = abs(_launch_modifier.x)
	var distance_mult_from_curve = lerp(1.0, 0.5, horizontal_offset)
	var launch_angle = 0.3 + (_launch_modifier.y * -0.3)
	launch_angle = clamp(launch_angle, 0.05, 0.6)
	
	# convert flat yards to extra speed
	var flat_bonus = GameState.get_flat_distance()
	var curve = -_launch_modifier.x

	var total_horizontal_speed = _speed * distance_mult * ball_speed_mult * distance_mult_from_curve + flat_bonus
	linear_velocity = Vector3(
		sin(aim_angle) * total_horizontal_speed,
		_speed * launch_angle * ball_speed_mult,
		cos(aim_angle) * total_horizontal_speed
	)
	
	# check for negative velocity (ball going backwards)
	if linear_velocity.z < 0:
		_is_whiff = true

	# store curve for _process
	_curve = curve

	# start homing immediately if ball supports it
	if ball_data.get("can_home", false):
		_start_homing()

	_is_firework = ball_data.get("is_firework", false)
	_initial_velocity_y = linear_velocity.y

var _curve := 0.0

	
	# ... rest of your existing _process code
	
func _land() -> void:
	if _has_landed:
		return
	_has_landed = true
	if _is_fake:
		# fake particle — just disappear after a moment
		var tween = create_tween()
		tween.tween_interval(0.5)
		tween.tween_callback(queue_free)
		return
	var yards = (global_position.z - _start_z) * 1.094
	landed.emit(abs(yards))
