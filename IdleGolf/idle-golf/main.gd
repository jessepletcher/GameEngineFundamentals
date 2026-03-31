extends Node3D

const Ball = preload("res://scenes/Ball.tscn")

@onready var shot_timer: Timer = $ShotTimer
@onready var tee_position: Marker3D = $TeePosition  # place this in your scene at tee location
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var golfer = $Golfer
@onready var shop = $CanvasLayer
@onready var shop_button: Button = $CanvasLayer/ShopButton
@onready var aim_slider: HSlider = $CanvasLayer/AimSlider
@onready var flags = $Flags
@onready var hit_sound: AudioStreamPlayer3D = $Golfer/GolfHit
@onready var flag_sound: AudioStreamPlayer3D = $FlagSound

const SHOT_INTERVAL := 5.0
const BALL_SPEED := 100
const ANGLE_SPREAD := 70.0
const BASE_SPEED := 10.0
const BASE_INTERVAL := 5.0
const BASE_SPREAD := 8.0
const FloatingText = preload("res://scenes/FloatingText.tscn")

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
    hit_sound.play()
    var ball = Ball.instantiate()
    ball._speed = BASE_SPEED * GameState.get_ball_speed()
    ball._spread = BASE_SPREAD / GameState.get_consistency()
    ball._aim = aim_slider.value
    ball.position = tee_position.global_position
    add_child(ball)
    ball.landed.connect(_on_ball_landed.bind(ball))

func _on_ball_landed(yards: float, ball: RigidBody3D) -> void:
    var base_money = yards * 0.05
    
    var best_bonus = 0.0
    for flag in flags.get_children():
        var bonus = flag.check_hit(ball.global_position)
        if bonus > best_bonus:
            best_bonus = bonus
    
    if best_bonus > 0.0:
        base_money += best_bonus
    
    var final_money = base_money * GameState.get_money_mult()
    GameState.money += final_money
    GameState.money_changed.emit(GameState.money)
    
    var text = FloatingText.instantiate()
    add_child(text)
    text.global_position = ball.global_position + Vector3(0, 1, 0)
    text.setup(final_money, yards)
    
    await get_tree().create_timer(3.0).timeout
    if is_instance_valid(ball):
        ball.queue_free()


func _on_shot_timer_timeout() -> void:
    pass # Replace with function body.


func _on_golfer_sprite_frame_changed() -> void:
    pass # Replace with function body.
