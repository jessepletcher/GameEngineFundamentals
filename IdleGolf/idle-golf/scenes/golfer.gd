extends Node3D

signal swung

@onready var sprite: AnimatedSprite3D = $GolferSprite

func _ready() -> void:
	_load_golfer_sprite()
	GameState.golfer_changed.connect(_load_golfer_sprite)

func play_swing() -> void:
	sprite.speed_scale = GameState.get_swing_speed()
	sprite.play("swing")

func _load_golfer_sprite() -> void:
	var data = GameState.get_golfer_data()
	var sheet = load(data["spritesheet"])
	var h_frames = data["h_frames"]
	var frame_size = data["frame_size"]

	var frames = SpriteFrames.new()
	frames.add_animation("swing")
	frames.set_animation_speed("swing", 5.0)
	frames.set_animation_loop("swing", false)

	for i in h_frames:
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("swing", atlas)

	sprite.sprite_frames = frames
	sprite.animation = "swing"

func _on_golfer_sprite_frame_changed() -> void:
	if sprite.frame == 4:
		swung.emit()
