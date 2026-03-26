extends Node3D

const Ball = preload("res://scenes/Ball.tscn")

@onready var shot_timer: Timer = $ShotTimer
@onready var tee_position: Marker3D = $TeePosition  # place this in your scene at tee location
@onready var money_label: Label = $CanvasLayer/MoneyLabel

const SHOT_INTERVAL := 5.0
const BALL_SPEED := 20
const ANGLE_SPREAD := 70.0

func _ready() -> void:
    GameState.money_changed.connect(_on_money_changed)
    shot_timer.timeout.connect(_on_ShotTimer_timeout)
    shot_timer.wait_time = SHOT_INTERVAL
    shot_timer.start()

func _on_money_changed(new_amount: float) -> void:
    money_label.text = "$%.2f" % new_amount

func _on_ShotTimer_timeout() -> void:
    print("Timer fired")
    _hit_ball()

func _hit_ball() -> void:
    var ball = Ball.instantiate()
    ball._speed = BALL_SPEED
    ball._spread = ANGLE_SPREAD
    add_child(ball)  # add first
    ball.global_position = tee_position.global_position  # then set position
    ball.landed.connect(_on_ball_landed.bind(ball))

func _on_ball_landed(yards: float, ball: RigidBody3D) -> void:
    print("_on_ball_landed called with yards: ", yards)
    var money = yards * 0.05
    GameState.add_money(money)
    await get_tree().create_timer(3.0).timeout
    if is_instance_valid(ball):
        ball.queue_free()


func _on_shot_timer_timeout() -> void:
    pass # Replace with function body.
