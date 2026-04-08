extends Node3D

@export var radius: float = 5.0       # eligible hit radius
@export var distance_mult: float = 1.0 # set this per flag based on how far it is
@export var flag_texture: Texture2D
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var distance_label: Label3D = $DistanceLabel

func _process(_delta: float) -> void:
	var distance = global_position.distance_to(camera.global_position)
	var scale_factor = pow(distance * 0.6, .6)
	$Sprite3D.scale = Vector3(scale_factor, scale_factor, scale_factor)
	distance_label.scale = Vector3(scale_factor, scale_factor, scale_factor) * 0.8
	var bob = sin(Time.get_ticks_msec() * 0.002) * 0.3
	distance_label.position.y = scale_factor * .7 + bob

func _ready() -> void:
	if flag_texture:
		$Sprite3D.texture = flag_texture
	var yards = global_position.length() * 1.094
	distance_label.text = "%.0f yds" % yards
	distance_label.font = load("res://balatro.otf")

func check_hit(ball_position: Vector3) -> float:
	var dist = Vector3(global_position.x, 0, global_position.z).distance_to(
				Vector3(ball_position.x, 0, ball_position.z))
	
	if dist > radius:
		return 0.0
	
	var accuracy = 1.0 - (dist / radius)
	var distance_bonus = global_position.z * 0.1
	return accuracy * distance_bonus * distance_mult
