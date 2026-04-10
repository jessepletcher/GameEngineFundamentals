extends Node3D

@export var radius_x: float = 5.0     # hit detection width
@export var radius_z: float = 5.0     # hit detection depth
@export var direct_radius_x: float = 1.5  # direct hit width
@export var direct_radius_z: float = 1.5  # direct hit depth
@export var distance_mult: float = 1.0 # set this per flag based on how far it is
@export var flag_texture: Texture2D
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var distance_label: Label3D = $DistanceLabel
@onready var sprite: Sprite3D = $Sprite3D

var _wiggle_tween: Tween
var _hit_sound: AudioStreamPlayer3D

func _process(_delta: float) -> void:
	var distance = global_position.distance_to(camera.global_position)
	var scale_factor = pow(distance * 0.6, .6)
	sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
	distance_label.scale = Vector3(scale_factor, scale_factor, scale_factor) * 0.8
	var bob = sin(Time.get_ticks_msec() * 0.002) * 0.3
	distance_label.position.y = scale_factor * .7 + bob

func _ready() -> void:
	if flag_texture:
		sprite.texture = flag_texture
	var yards = global_position.length() * 1.094
	distance_label.text = "%.0f yds" % yards
	distance_label.font = load("res://balatro.otf")

	_hit_sound = AudioStreamPlayer3D.new()
	_hit_sound.stream = load("res://FlagStickHit.mp3")
	add_child(_hit_sound)

## Returns [bonus, is_direct_hit]
func check_hit(ball_position: Vector3) -> Array:
	var dx = abs(ball_position.x - global_position.x)
	var dz = abs(ball_position.z - global_position.z)

	if dx > radius_x or dz > radius_z:
		return [0.0, false]

	var accuracy = 1.0 - max(dx / radius_x, dz / radius_z)
	var distance_bonus = global_position.z * 0.1
	var bonus = accuracy * distance_bonus * distance_mult

	var direct = dx <= direct_radius_x and dz <= direct_radius_z
	if direct:
		if not GameState.sfx_muted:
			_hit_sound.play()
		_wiggle()

	return [bonus, direct]

func _wiggle() -> void:
	if _wiggle_tween and _wiggle_tween.is_valid():
		_wiggle_tween.kill()
	sprite.rotation.z = 0.0
	_wiggle_tween = create_tween()
	_wiggle_tween.tween_property(sprite, "rotation:z", deg_to_rad(15), 0.05)
	_wiggle_tween.tween_property(sprite, "rotation:z", deg_to_rad(-12), 0.07)
	_wiggle_tween.tween_property(sprite, "rotation:z", deg_to_rad(8), 0.06)
	_wiggle_tween.tween_property(sprite, "rotation:z", deg_to_rad(-5), 0.06)
	_wiggle_tween.tween_property(sprite, "rotation:z", deg_to_rad(2), 0.05)
	_wiggle_tween.tween_property(sprite, "rotation:z", 0.0, 0.05)
