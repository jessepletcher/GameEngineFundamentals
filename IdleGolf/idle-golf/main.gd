extends Node3D

const Ball = preload("res://scenes/Ball.tscn")

@onready var shot_timer: Timer = $ShotTimer
@onready var tee_position: Marker3D = $TeePosition  # place this in your scene at tee location
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var golfer = $Golfer
@onready var shop = $CanvasLayer
@onready var shop_button: Button = $CanvasLayer/ShopButton

const SHOT_INTERVAL := 5.0
const BALL_SPEED := 100
const ANGLE_SPREAD := 70.0
const BASE_SPEED := 15.0
const BASE_INTERVAL := 5.0
const BASE_SPREAD := 8.0

func _ready() -> void:
    GameState.money_changed.connect(_on_money_changed)
    golfer.swung.connect(_on_golfer_swung)
    shot_timer.timeout.connect(_on_ShotTimer_timeout)
    shot_timer.wait_time = SHOT_INTERVAL
    shot_timer.start()
    shop_button.pressed.connect(_on_shop_button_pressed)

func _on_shop_button_pressed() -> void:
    shop.toggle()
    
func _on_golfer_swung() -> void:
    _hit_ball()


func _on_money_changed(new_amount: float) -> void:
    money_label.text = "$%.2f" % new_amount

func _on_ShotTimer_timeout() -> void:
    shot_timer.wait_time = BASE_INTERVAL / GameState.get_fire_rate()
    golfer.play_swing()


func _hit_ball() -> void:
    var ball = Ball.instantiate()
    ball._speed = BASE_SPEED * GameState.get_ball_speed()
    ball._spread = BASE_SPREAD / GameState.get_consistency()
    ball.position = tee_position.global_position
    add_child(ball)
    ball.landed.connect(_on_ball_landed.bind(ball))

func _on_ball_landed(yards: float, ball: RigidBody3D) -> void:
    var money = yards * 0.05
    GameState.add_money(money)
    await get_tree().create_timer(3.0).timeout
    if is_instance_valid(ball):
        ball.queue_free()


func _on_shot_timer_timeout() -> void:
    pass # Replace with function body.


func _on_golfer_sprite_frame_changed() -> void:
    pass # Replace with function body.
