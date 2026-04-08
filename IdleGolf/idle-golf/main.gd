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
@onready var open_shop_button: Button = $CanvasLayer/OpenShopButton
@onready var xp_progress: ProgressBar = $CanvasLayer/XPBar/XPProgress
@onready var level_label: Label = $CanvasLayer/XPBar/LevelLabel
@onready var retire_button: Button = $CanvasLayer/RetireButton
@onready var retire_dialog = $CanvasLayer/RetireDialog
@onready var retire_info_label: Label = $CanvasLayer/RetireDialog/VBoxContainer/RetireInfoLabel
@onready var confirm_retire: Button = $CanvasLayer/RetireDialog/VBoxContainer/ConfirmRetireButton
@onready var cancel_retire: Button = $CanvasLayer/RetireDialog/VBoxContainer/CancelRetireButton
@onready var medals_label: Label = $CanvasLayer/MedalsLabel
@onready var shot_control = $CanvasLayer/ShotControl

const SHOT_INTERVAL := 5.0
const BALL_SPEED := 100
const ANGLE_SPREAD := 70.0
const BASE_SPEED := 10.0
const BASE_INTERVAL := 5.0
const BASE_SPREAD := 8.0
const FloatingText = preload("res://scenes/FloatingText.tscn")

func _ready() -> void:
    money_label.text = "$%.2f" % GameState.money
    level_label.text = "Level %d" % GameState.level
    xp_progress.max_value = GameState.xp_to_next_level
    xp_progress.value = GameState.xp
    GameState.xp_changed.connect(_on_xp_changed)
    GameState.leveled_up.connect(_on_leveled_up)
    GameState.money_changed.connect(_on_money_changed)
    golfer.swung.connect(_on_golfer_swung)
    open_shop_button.pressed.connect(_on_open_shop_pressed)
    shot_timer.timeout.connect(_on_ShotTimer_timeout)
    shot_timer.wait_time = BASE_INTERVAL / GameState.get_fire_rate()
    shop_button.pressed.connect(_on_shop_button_pressed)
    shot_timer.start()
    retire_button.pressed.connect(_on_retire_pressed)
    confirm_retire.pressed.connect(_on_confirm_retire)
    cancel_retire.pressed.connect(_on_cancel_retire)
    retire_dialog.visible = false
    GameState.medals_changed.connect(_on_medals_changed)
    medals_label.text = "🏅 %.0f" % GameState.medals


func _on_xp_changed(current_xp: float, required_xp: float) -> void:
    xp_progress.max_value = required_xp
    xp_progress.value = current_xp

func _on_confirm_retire() -> void:
    retire_dialog.visible = false
    GameState.retire()
    # refresh UI
    money_label.text = "$%.2f" % GameState.money
    level_label.text = "Level %d" % GameState.level
    xp_progress.value = 0
    xp_progress.max_value = GameState.xp_to_next_level
    shot_timer.wait_time = BASE_INTERVAL / GameState.get_fire_rate()

func _on_cancel_retire() -> void:
    retire_dialog.visible = false

func _on_medals_changed(amount: float) -> void:
    medals_label.text = "🏅 %.0f" % amount

func _on_retire_pressed() -> void:
    var medals = GameState.get_medal_reward()
    retire_info_label.text = "You will earn %.0f Medals!\n\nUpgrades will be reset.\nBalls, clubs and levels are kept." % medals
    retire_dialog.visible = true

func _on_leveled_up(new_level: int, stat_boosted: String) -> void:
    level_label.text = "Level %d" % new_level
    _show_level_up_popup(new_level, stat_boosted)

func _show_level_up_popup(new_level: int, stat: String) -> void:
    var label = Label.new()
    label.text = "LEVEL UP! %d\n+%s" % [new_level, GameState.upgrades[stat]["label"]]
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    $CanvasLayer.add_child(label)
    label.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2)
    
    var tween = create_tween()
    tween.tween_property(label, "position:y", label.position.y - 100, 1.5)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
    tween.tween_callback(label.queue_free)

func _on_open_shop_pressed() -> void:
    GameState.save()
    get_tree().change_scene_to_file("res://Shop.tscn")

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
    var modifier = shot_control.get_launch_modifier()
    var ball = Ball.instantiate()
    ball._speed = BASE_SPEED * GameState.get_ball_speed()
    ball._spread = BASE_SPREAD / GameState.get_consistency()
    ball._aim = -aim_slider.value
    ball._launch_modifier = modifier
    ball.position = tee_position.global_position
    add_child(ball)
    ball.landed.connect(_on_ball_landed.bind(ball))

func _on_ball_landed(yards: float, ball: RigidBody3D) -> void:
    var base_money = pow(yards, 2) * 0.0002 + 5
    
    var best_bonus = 0.0
    for flag in flags.get_children():
        var bonus = flag.check_hit(ball.global_position)
        if bonus > best_bonus:
            best_bonus = bonus
    
    if best_bonus > 0.0:
        flag_sound.play(1.0)
        base_money += best_bonus
    
    var final_money = base_money * GameState.get_money_mult()
    GameState.money += final_money
    GameState.money_changed.emit(GameState.money)
    GameState.add_xp(final_money * 0.1)  # just call add_xp directly here
    
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
