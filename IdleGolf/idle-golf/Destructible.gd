extends Node3D

signal destroyed(reward: float)

@export var hits_required: int = 10
@export var respawn_time: float = 15.0
@export var shake_factor: float = 1.0
@export var money_per_hit: float = 5.0

@onready var scaled_sprite: Node3D = $ScaledSprite
@onready var static_body: StaticBody3D = $StaticBody3D
@onready var collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D

var _hits_taken := 0
var _is_alive := true
var _hit_balls: Array = []  # track which balls already counted a hit
var _yardage_label: Label3D
var _yardage_tween: Tween

func _ready() -> void:
	add_to_group("destructibles")
	_create_yardage_label()
	static_body.mouse_entered.connect(func(): _yardage_label.visible = true)
	static_body.mouse_exited.connect(func(): _yardage_label.visible = false)

func _create_yardage_label() -> void:
	_yardage_label = Label3D.new()
	var yards = global_position.length() * 1.094
	_yardage_label.text = "%.0f yds" % yards
	_yardage_label.font = load("res://balatro.otf")
	_yardage_label.font_size = 40
	_yardage_label.modulate = Color.WHITE
	_yardage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_yardage_label.outline_size = 0
	_yardage_label.no_depth_test = true
	_yardage_label.visible = false

	var ds = _get_distance_scale()
	_yardage_label.scale = Vector3(ds, ds, ds)

	# position above collision shape
	var shape_top_y = collision_shape.global_position.y
	var shape = collision_shape.shape
	if shape is BoxShape3D:
		shape_top_y += shape.size.y * 0.5
	elif shape is SphereShape3D:
		shape_top_y += shape.radius
	add_child(_yardage_label)
	_yardage_label.global_position = Vector3(collision_shape.global_position.x, shape_top_y + 0.5 * ds, collision_shape.global_position.z)

func show_yardage() -> void:
	if not _yardage_label or not is_instance_valid(_yardage_label):
		return
	# kill previous blink if still running
	if _yardage_tween and _yardage_tween.is_valid():
		_yardage_tween.kill()

	_yardage_label.modulate.a = 1.0

	# blink 5 times then hide
	_yardage_tween = create_tween()
	for i in 3:
		_yardage_tween.tween_callback(func():
			_yardage_label.visible = true
			AudioManager.play_sfx("blink")
		)
		_yardage_tween.tween_interval(0.6)
		_yardage_tween.tween_callback(func(): _yardage_label.visible = false)
		_yardage_tween.tween_interval(0.6)

func _physics_process(_delta: float) -> void:
	if not _is_alive:
		return

	# use the collision shape's AABB for hit detection
	var shape = collision_shape.shape
	var shape_origin = collision_shape.global_position
	var half_extents: Vector3

	# pad the detection area so balls that bounce off the surface still register
	var padding := 1.0
	if shape is BoxShape3D:
		half_extents = shape.size * 0.5 + Vector3(padding, padding, padding)
	elif shape is SphereShape3D:
		half_extents = Vector3.ONE * (shape.radius + padding)
	else:
		half_extents = Vector3(3.0, 3.0, 3.0)

	for ball in get_tree().get_nodes_in_group("balls"):
		if not is_instance_valid(ball):
			continue
		if ball in _hit_balls:
			continue

		var dx = abs(ball.global_position.x - shape_origin.x)
		var dy = abs(ball.global_position.y - shape_origin.y)
		var dz = abs(ball.global_position.z - shape_origin.z)

		if dx < half_extents.x and dy < half_extents.y and dz < half_extents.z:
			_hit_balls.append(ball)
			_take_hit()

func _take_hit() -> void:
	_hits_taken += 1
	_shake()

	if _hits_taken >= hits_required:
		_crumble()

func _get_distance_scale() -> float:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return 1.0
	var dist = global_position.distance_to(cam.global_position)
	return max(dist * 0.15, 0.1)

func _shake() -> void:
	var tween = create_tween()
	var base_x = 0.0
	var intensity = 0.08 * _get_distance_scale() * shake_factor
	tween.tween_property(scaled_sprite, "position:x", base_x + intensity, 0.03)
	tween.tween_property(scaled_sprite, "position:x", base_x - intensity, 0.04)
	tween.tween_property(scaled_sprite, "position:x", base_x + intensity * 0.6, 0.03)
	tween.tween_property(scaled_sprite, "position:x", base_x - intensity * 0.4, 0.03)
	tween.tween_property(scaled_sprite, "position:x", base_x + intensity * 0.2, 0.02)
	tween.tween_property(scaled_sprite, "position:x", base_x, 0.02)

func _crumble() -> void:
	_is_alive = false
	collision_shape.disabled = true

	var distance = global_position.distance_to(Vector3.ZERO) * 1.094  # convert to yards
	var destruct_mult = GameState.balls[GameState.equipped_ball].get("destruct_mult", 1.0)
	var reward = money_per_hit * _hits_taken * distance * GameState.get_money_mult() * destruct_mult
	destroyed.emit(reward)
	_spawn_reward_text(reward)

	AudioManager.play_sfx("destroy")

	var ds = _get_distance_scale()
	var fall_distance = 3.0 * ds

	# violent shake while falling
	var shake_tween = create_tween().set_loops(50)
	var shake_intensity = 0.12 * ds * shake_factor
	shake_tween.tween_property(scaled_sprite, "position:x", shake_intensity, 0.02)
	shake_tween.tween_property(scaled_sprite, "position:x", -shake_intensity, 0.02)

	# fall straight down and fade
	var fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(scaled_sprite, "position:y", scaled_sprite.position.y - fall_distance, 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall_tween.tween_callback(_fade_sprite).set_delay(1.2)

	# after fall completes, stop shaking and respawn later
	fall_tween.set_parallel(false)
	fall_tween.tween_callback(func():
		shake_tween.kill()
		scaled_sprite.position.x = 0.0
	)
	var respawn_mult = GameState.get_golfer_data().get("respawn_mult", 1.0)
	fall_tween.tween_interval(respawn_time * respawn_mult)
	fall_tween.tween_callback(_respawn)

var _reward_label: Label3D

func _spawn_reward_text(reward: float) -> void:
	# remove previous label if one exists
	if _reward_label and is_instance_valid(_reward_label):
		_reward_label.queue_free()

	_reward_label = Label3D.new()
	_reward_label.text = "+$%.0f" % reward
	_reward_label.font = load("res://balatro.otf")
	_reward_label.font_size = 32
	_reward_label.modulate = Color(1.0, 0.84, 0.0)  # gold
	_reward_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reward_label.outline_size = 0

	var ds = _get_distance_scale()
	_reward_label.scale = Vector3(ds, ds, ds)

	add_child(_reward_label)
	# position above the collision shape
	var shape = collision_shape.shape
	var shape_top_y = collision_shape.global_position.y
	if shape is BoxShape3D:
		shape_top_y += shape.size.y * 0.5
	elif shape is SphereShape3D:
		shape_top_y += shape.radius
	_reward_label.global_position = Vector3(collision_shape.global_position.x, shape_top_y + 0.5 * ds, collision_shape.global_position.z)

	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_reward_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_reward_label.queue_free)

func _fade_sprite() -> void:
	var sprite_3d = scaled_sprite.get_node("Sprite3D")
	var fade_tween = create_tween()
	fade_tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.3)

func _respawn() -> void:
	_hits_taken = 0
	_hit_balls.clear()
	_is_alive = true
	collision_shape.disabled = false
	scaled_sprite.scale = Vector3.ONE
	scaled_sprite.position = Vector3.ZERO
	var sprite_3d = scaled_sprite.get_node("Sprite3D")
	sprite_3d.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(sprite_3d, "modulate:a", 1.0, 0.5)

func get_progress() -> String:
	if not _is_alive:
		return "DESTROYED"
	return "%d/%d" % [_hits_taken, hits_required]
