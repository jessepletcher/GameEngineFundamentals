extends Node3D

signal swung

@onready var sprite: AnimatedSprite3D = $GolferSprite

func play_swing() -> void:
	sprite.speed_scale = GameState.get_swing_speed()
	sprite.play("swing")


func _on_golfer_sprite_frame_changed() -> void:
	if sprite.frame == 4:
		swung.emit()
