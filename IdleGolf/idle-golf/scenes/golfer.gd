extends Node3D

signal swung

@onready var sprite: AnimatedSprite3D = $GolferSprite
var _swing_emit_frame := 4
var _shot_emitted_this_swing := false
var _spawn_disabled := false

func _ready() -> void:
	_load_golfer_sprite()
	GameState.golfer_changed.connect(_load_golfer_sprite)

func play_swing() -> void:
	if _spawn_disabled:
		return
	_shot_emitted_this_swing = false
	sprite.speed_scale = GameState.get_swing_speed()
	sprite.play("swing")
	if _swing_emit_frame <= 0:
		_shot_emitted_this_swing = true
		swung.emit()

func set_spawn_disabled(disabled: bool) -> void:
	_spawn_disabled = disabled
	visible = not disabled
	if disabled:
		_shot_emitted_this_swing = true
		sprite.stop()

func _load_golfer_sprite() -> void:
	var data = GameState.get_golfer_data()
	var sheet = load(data["spritesheet"])
	var h_frames: int = int(data["h_frames"])
	var frame_size: int = int(data["frame_size"])
	_swing_emit_frame = mini(4, max(0, h_frames - 1))

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
	if not _spawn_disabled and not _shot_emitted_this_swing and sprite.frame >= _swing_emit_frame:
		_shot_emitted_this_swing = true
		swung.emit()
