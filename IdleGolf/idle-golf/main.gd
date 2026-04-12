extends Node3D

const Ball = preload("res://scenes/Ball.tscn")

@onready var shot_timer: Timer = $ShotTimer
@onready var tee_position: Marker3D = $TeePosition  # place this in your scene at tee location
@onready var money_label: Label = $CanvasLayer/LeftVBox/Money/MoneyLabel
@onready var golfer = $Golfer
@onready var shop = $CanvasLayer
@onready var aim_slider: HSlider = $CanvasLayer/AimSlider
@onready var level1_sprites = $Level1
@onready var level1_flags = $Level1Flags
@onready var level2_sprites = $Level2
@onready var level2_flags = $Level2Flags
@onready var hit_sound: AudioStreamPlayer3D = $Golfer/GolfHit
@onready var flag_sound: AudioStreamPlayer3D = $FlagSound
@onready var open_shop_button: Button = $CanvasLayer/OpenShopButton
@onready var xp_progress: ProgressBar = $CanvasLayer/LeftVBox/XPBar/XPProgress
@onready var level_label: Label = $CanvasLayer/LeftVBox/XPBar/LevelLabel
@onready var retire_button: Button = $CanvasLayer/LeftVBox/LeftMenu/TopBar/RetireButton
@onready var retire_dialog = $CanvasLayer/RetireDialog
@onready var retire_info_label: Label = $CanvasLayer/RetireDialog/VBoxContainer/RetireInfoLabel
@onready var confirm_retire: Button = $CanvasLayer/RetireDialog/VBoxContainer/ConfirmRetireButton
@onready var cancel_retire: Button = $CanvasLayer/RetireDialog/VBoxContainer/CancelRetireButton
@onready var medals_label: Label = $CanvasLayer/LeftVBox/Medals/MedalsLabel
@onready var shot_control = $CanvasLayer/ShotControl
@onready var reset_button: Button = $CanvasLayer/ResetButton
@onready var reset_dialog = $CanvasLayer/ResetDialog
@onready var confirm_reset: Button = $CanvasLayer/ResetDialog/VBoxContainer/ConfirmResetButton
@onready var cancel_reset: Button = $CanvasLayer/ResetDialog/VBoxContainer/CancelResetButton

const SHOT_INTERVAL := 5.0
const BALL_SPEED := 100
const ANGLE_SPREAD := 70.0
const BASE_SPEED := 10.0
const BASE_INTERVAL := 5.0
const BASE_SPREAD := 8.0
const FloatingText = preload("res://scenes/FloatingText.tscn")

var _floating_texts: Array = []
var _text_queue: Array = []
var _queue_processing: bool = false
const TEXT_QUEUE_INTERVAL := 0.15
const MAX_INDIVIDUAL_TEXTS := 4  # show this many individually, then batch the rest
var _ambience_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer3D
var _settings_panel: PanelContainer
var _music_muted := false

var _course_data := {
	"course1": {"sprites": null, "flags": null},
	"course2": {"sprites": null, "flags": null},
}

func _get_active_flags() -> Node3D:
	return _course_data[GameState.equipped_course]["flags"]

func _switch_course() -> void:
	for key in _course_data:
		var show = key == GameState.equipped_course
		_course_data[key]["sprites"].visible = show
		_course_data[key]["flags"].visible = show

func _ready() -> void:
	_course_data["course1"]["sprites"] = level1_sprites
	_course_data["course1"]["flags"] = level1_flags
	_course_data["course2"]["sprites"] = level2_sprites
	_course_data["course2"]["flags"] = level2_flags
	_switch_course()
	GameState.course_changed.connect(_switch_course)
	money_label.text = "%.0f" % GameState.money
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
	shot_timer.start()
	retire_button.pressed.connect(_on_retire_pressed)
	confirm_retire.pressed.connect(_on_confirm_retire)
	cancel_retire.pressed.connect(_on_cancel_retire)
	retire_dialog.visible = false
	GameState.medals_changed.connect(_on_medals_changed)
	medals_label.text = "%.0f" % GameState.medals

	# auto-save every 15 seconds
	var save_timer = Timer.new()
	save_timer.wait_time = 15.0
	save_timer.autostart = true
	save_timer.timeout.connect(GameState.save)
	add_child(save_timer)

	# reset button
	reset_button.pressed.connect(_on_reset_pressed)

	# music
	_music_player = $Music
	if not _music_player.playing:
		_music_player.play()

	# nature ambience loop
	_ambience_player = AudioStreamPlayer.new()
	var stream = load("res://u_vr5icvkppa-nature-ambience-323729.mp3")
	stream.loop = true
	_ambience_player.stream = stream
	_ambience_player.volume_db = -10.0
	add_child(_ambience_player)
	_ambience_player.play()
	# cut off last 20 seconds by restarting when it reaches that point
	var ambience_length = stream.get_length()
	var loop_timer = Timer.new()
	loop_timer.wait_time = ambience_length - 20.0
	loop_timer.autostart = true
	loop_timer.timeout.connect(func(): _ambience_player.play())
	add_child(loop_timer)
	confirm_reset.pressed.connect(_on_confirm_reset)
	cancel_reset.pressed.connect(_on_cancel_reset)
	reset_dialog.visible = false

	# settings menu
	_setup_settings_menu()


func _on_xp_changed(current_xp: float, required_xp: float) -> void:
	xp_progress.max_value = required_xp
	xp_progress.value = current_xp

func _on_confirm_retire() -> void:
	retire_dialog.visible = false
	GameState.retire()
	get_tree().reload_current_scene()

func _on_cancel_retire() -> void:
	retire_dialog.visible = false

func _on_medals_changed(amount: float) -> void:
	medals_label.text = " %.0f" % amount

func _on_retire_pressed() -> void:
	var medals = GameState.get_medal_reward()
	retire_info_label.text = "You will earn %.0f Medals!\n\nUpgrades will be reset.\nBalls, clubs, levels and level bonuses are kept." % medals
	retire_dialog.visible = true

func _on_leveled_up(new_level: int, stat_boosted: String) -> void:
	level_label.text = "Level %d" % new_level
	_show_level_up_popup(new_level, stat_boosted)

func _show_level_up_popup(new_level: int, stat: String) -> void:
	var label = Label.new()
	label.text = "LEVEL UP! %d\n+5%% %s" % [new_level, GameState.upgrades[stat]["label"]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CanvasLayer.add_child(label)
	label.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 100, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

var _shop_instance: Control = null
var _shop_layer: CanvasLayer = null
var _transitioning := false
const TRANSITION_DURATION := 0.4

func _on_open_shop_pressed() -> void:
	GameState.save()
	if _shop_instance or _transitioning:
		return
	_transitioning = true
	_music_player.stream_paused = true
	_ambience_player.stream_paused = true
	AudioServer.set_bus_volume_db(0, -20.0)

	var screen_w = get_viewport().get_visible_rect().size.x

	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 10
	add_child(_shop_layer)

	var shop_scene = load("res://Shop.tscn")
	_shop_instance = shop_scene.instantiate()
	_shop_layer.add_child(_shop_instance)
	_shop_instance.shop_closed.connect(_on_shop_close_requested)

	# shop starts offscreen right
	_shop_layer.offset = Vector2(screen_w, 0)

	var tween = create_tween().set_parallel(true)
	# slide main UI left
	tween.tween_property($CanvasLayer, "offset", Vector2(-screen_w, 0), TRANSITION_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# slide shop in from right
	tween.tween_property(_shop_layer, "offset", Vector2.ZERO, TRANSITION_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(func():
		_transitioning = false
	)

func _on_shop_close_requested() -> void:
	if _transitioning:
		return
	_transitioning = true
	var screen_w = get_viewport().get_visible_rect().size.x

	var tween = create_tween().set_parallel(true)
	# slide shop out to the right
	tween.tween_property(_shop_layer, "offset", Vector2(screen_w, 0), TRANSITION_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# slide main UI back from left
	tween.tween_property($CanvasLayer, "offset", Vector2.ZERO, TRANSITION_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(_on_shop_closed)

func _on_shop_closed() -> void:
	if _shop_layer:
		_shop_layer.queue_free()
		_shop_layer = null
		_shop_instance = null
	_transitioning = false
	AudioServer.set_bus_volume_db(0, 0.0)
	if not _music_muted:
		_music_player.stream_paused = false
		_ambience_player.stream_paused = false
	# reload golfer sprite in case player switched golfer
	golfer._load_golfer_sprite()

func _on_golfer_swung() -> void:
	_hit_ball()


func _on_money_changed(new_amount: float) -> void:
	money_label.text = "%.0f" % new_amount

func _on_ShotTimer_timeout() -> void:
	shot_timer.wait_time = BASE_INTERVAL / GameState.get_fire_rate()
	golfer.play_swing()


func _hit_ball() -> void:
	if not GameState.sfx_muted:
		hit_sound.play()
	var modifier = shot_control.get_launch_modifier()
	var ball_count = GameState.get_ball_count()
	for i in ball_count:
		var ball = Ball.instantiate()
		ball._speed = BASE_SPEED * GameState.get_ball_speed()
		ball._spread = BASE_SPREAD / GameState.get_consistency()
		ball._aim = -aim_slider.value
		ball._launch_modifier = modifier
		ball.position = tee_position.global_position
		add_child(ball)
		ball.landed.connect(_on_ball_landed.bind(ball))
		ball.exploded.connect(_on_ball_exploded)
		if ball._is_whiff:
			_on_ball_whiffed()

func _on_ball_landed(yards: float, ball: RigidBody3D) -> void:
	var base_money = pow(yards, 2) * 0.0002 + 5
	
	var best_bonus = 0.0
	var direct_hit = false
	for flag in _get_active_flags().get_children():
		var result = flag.check_hit(ball.global_position)
		if result[0] > best_bonus:
			best_bonus = result[0]
		if result[1]:
			direct_hit = true

	if best_bonus > 0.0:
		if not GameState.sfx_muted:
			flag_sound.play(1.0)
		var flag_mult = GameState.balls[GameState.equipped_ball].get("flag_mult", 1.0)
		base_money += best_bonus * flag_mult

	if direct_hit:
		base_money *= 5.0

	var final_money = base_money * GameState.get_money_mult()
	GameState.money += final_money
	GameState.money_changed.emit(GameState.money)
	GameState.add_xp(final_money * 0.1)  # just call add_xp directly here

	# queue the floating text so multiple landings in the same frame don't stack
	_text_queue.append({"money": final_money, "yards": yards, "flag_hit": best_bonus > 0.0, "direct_hit": direct_hit})
	if not _queue_processing:
		_process_text_queue()

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(ball):
		ball.queue_free()


func _get_dynamic_lifetime() -> float:
	# base 1.0s, shrinks as queue + active texts grow, minimum 0.3s
	var pressure = _text_queue.size() + _floating_texts.size()
	return clampf(1.0 - pressure * 0.1, 0.3, 1.0)

func _process_text_queue() -> void:
	_queue_processing = true
	while _text_queue.size() > 0:
		# if queue is overflowing, batch the extras into a summary
		if _text_queue.size() > MAX_INDIVIDUAL_TEXTS:
			# show first few individually
			for i in MAX_INDIVIDUAL_TEXTS:
				if _text_queue.size() == 0:
					break
				var data = _text_queue.pop_front()
				_spawn_floating_text(data["money"], data["yards"], data.get("flag_hit", false), data.get("direct_hit", false))
				await get_tree().create_timer(TEXT_QUEUE_INTERVAL).timeout

			# collapse everything remaining into one summary
			if _text_queue.size() > 0:
				var total_money := 0.0
				var hit_count := _text_queue.size()
				var any_flag := false
				var any_direct := false
				for data in _text_queue:
					total_money += data["money"]
					if data.get("direct_hit", false):
						any_direct = true
					elif data.get("flag_hit", false):
						any_flag = true
				_text_queue.clear()
				_spawn_summary_text(total_money, hit_count, any_flag, any_direct)
				await get_tree().create_timer(TEXT_QUEUE_INTERVAL).timeout
		else:
			var data = _text_queue.pop_front()
			_spawn_floating_text(data["money"], data["yards"], data.get("flag_hit", false), data.get("direct_hit", false))
			await get_tree().create_timer(TEXT_QUEUE_INTERVAL).timeout
	_queue_processing = false


func _push_existing_texts_up() -> void:
	if _floating_texts.size() >= 10:
		var oldest = _floating_texts[0]
		if is_instance_valid(oldest):
			oldest.force_fade()

	for existing in _floating_texts:
		if is_instance_valid(existing):
			var shift_tween = create_tween()
			shift_tween.tween_property(existing, "global_position:y", existing.global_position.y + .1, 0.15)

func _spawn_floating_text(money: float, yards: float, flag_hit: bool = false, direct_hit: bool = false) -> void:
	_push_existing_texts_up()

	var text = FloatingText.instantiate()
	add_child(text)
	text.global_position = golfer.global_position + Vector3(0, 1.5, 0)
	text.setup(money, yards, flag_hit, direct_hit, _get_dynamic_lifetime())
	_floating_texts.append(text)
	text.tree_exited.connect(func(): _floating_texts.erase(text))

func _spawn_summary_text(total_money: float, hit_count: int, any_flag: bool, any_direct: bool) -> void:
	_push_existing_texts_up()

	var text = FloatingText.instantiate()
	add_child(text)
	text.global_position = golfer.global_position + Vector3(0, 1.5, 0)
	var summary = "+$%.0f (%d more hits)" % [total_money, hit_count]
	text.setup_summary(summary, _get_dynamic_lifetime())
	_floating_texts.append(text)
	text.tree_exited.connect(func(): _floating_texts.erase(text))


func _on_ball_exploded(fragments: Array) -> void:
	for frag in fragments:
		frag.landed.connect(_on_ball_landed.bind(frag))

func _on_ball_whiffed() -> void:
	var label = Label.new()
	label.text = "!!!"
	label.add_theme_color_override("font_color", Color.RED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CanvasLayer.add_child(label)
	var golfer_screen_pos = get_viewport().get_camera_3d().unproject_position(golfer.global_position)
	label.position = golfer_screen_pos + Vector2(-40, -400)
	label.add_theme_font_size_override("font_size", 64)

	# use a custom font (load a .ttf or .otf file)
	var font = load("res://balatro.otf")
	label.add_theme_font_override("font", font)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _on_reset_pressed() -> void:
	reset_dialog.visible = true

func _on_confirm_reset() -> void:
	GameState.full_reset()
	get_tree().reload_current_scene()

func _on_cancel_reset() -> void:
	reset_dialog.visible = false

func _setup_settings_menu() -> void:
	var font = load("res://balatro.otf")

	# settings button - top right
	var settings_btn = Button.new()
	settings_btn.text = "⚙"
	settings_btn.add_theme_font_override("font", font)
	settings_btn.add_theme_font_size_override("font_size", 24)
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -50
	settings_btn.offset_right = -10
	settings_btn.offset_top = 10
	settings_btn.offset_bottom = 50
	$CanvasLayer.add_child(settings_btn)

	# settings panel
	_settings_panel = PanelContainer.new()
	_settings_panel.anchor_left = 1.0
	_settings_panel.anchor_right = 1.0
	_settings_panel.anchor_top = 0.0
	_settings_panel.anchor_bottom = 0.0
	_settings_panel.offset_left = -200
	_settings_panel.offset_right = -10
	_settings_panel.offset_top = 55
	_settings_panel.offset_bottom = 200
	_settings_panel.visible = false
	$CanvasLayer.add_child(_settings_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_settings_panel.add_child(vbox)

	var sfx_btn = Button.new()
	sfx_btn.text = "Disable SFX"
	sfx_btn.add_theme_font_override("font", font)
	sfx_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(sfx_btn)

	var music_btn = Button.new()
	music_btn.text = "Disable Music"
	music_btn.add_theme_font_override("font", font)
	music_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(music_btn)

	var exit_btn = Button.new()
	exit_btn.text = "Exit Game"
	exit_btn.add_theme_font_override("font", font)
	exit_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(exit_btn)

	var medals_btn = Button.new()
	medals_btn.text = "+100 Medals"
	medals_btn.add_theme_font_override("font", font)
	medals_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(medals_btn)

	settings_btn.pressed.connect(func(): _settings_panel.visible = !_settings_panel.visible)

	sfx_btn.pressed.connect(func():
		GameState.sfx_muted = !GameState.sfx_muted
		sfx_btn.text = "Enable SFX" if GameState.sfx_muted else "Disable SFX"
	)

	music_btn.pressed.connect(func():
		_music_muted = !_music_muted
		_ambience_player.stream_paused = _music_muted
		_music_player.stream_paused = _music_muted
		music_btn.text = "Enable Music" if _music_muted else "Disable Music"
	)

	exit_btn.pressed.connect(func():
		GameState.save()
		get_tree().quit()
	)

	medals_btn.pressed.connect(func():
		GameState.medals += 100
		GameState.medals_changed.emit(GameState.medals)
	)
