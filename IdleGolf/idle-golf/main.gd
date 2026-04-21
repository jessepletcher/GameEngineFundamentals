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
var _settings_panel: PanelContainer

# Market Ball — invested money per flag
var _market_investments := {}  # flag node -> invested money
var _market_labels := {}  # flag node -> Label3D showing invested amount
const MARKET_GROWTH_RATE := 0.20  # 10% per second

# Golden Flag
var _golden_flag: Node3D = null
var _golden_timer: Timer
const GOLDEN_FLAG_INTERVAL_MIN := 20.0
const GOLDEN_FLAG_INTERVAL_MAX := 40.0

var _course_data := {
	"course1": {"sprites": null, "flags": null},
	"course2": {"sprites": null, "flags": null},
}

func _get_active_flags() -> Node3D:
	return _course_data[GameState.equipped_course]["flags"]

func _process(delta: float) -> void:
	# grow market ball investments
	for flag in _market_investments:
		if not is_instance_valid(flag):
			continue
		_market_investments[flag] *= (1.0 + MARKET_GROWTH_RATE * delta)
		_update_market_label(flag)

func _switch_course() -> void:
	# cash out any market investments before switching
	var cashout = _cashout_all_investments()
	if cashout > 0.0:
		GameState.money += cashout
		GameState.lifetime_money += cashout
		GameState.money_changed.emit(GameState.money)
	# deactivate golden flag on course switch
	if _golden_flag and is_instance_valid(_golden_flag):
		_golden_flag.deactivate_golden()
		_golden_flag = null
	if _golden_timer:
		_start_golden_timer()
	for key in _course_data:
		var show = key == GameState.equipped_course
		_course_data[key]["sprites"].visible = show
		_course_data[key]["flags"].visible = show
	_show_all_yardage()

func _ready() -> void:
	_course_data["course1"]["sprites"] = level1_sprites
	_course_data["course1"]["flags"] = level1_flags
	_course_data["course2"]["sprites"] = level2_sprites
	_course_data["course2"]["flags"] = level2_flags
	_switch_course()
	GameState.course_changed.connect(_switch_course)
	money_label.text = GameState.format_number(GameState.money)
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
	medals_label.text = GameState.format_number(GameState.medals)

	# auto-save every 15 seconds
	var save_timer = Timer.new()
	save_timer.wait_time = 15.0
	save_timer.autostart = true
	save_timer.timeout.connect(GameState.save)
	add_child(save_timer)

	# reset button
	reset_button.visible = false  # hidden, moved to settings menu

	# music
	AudioManager.play_music($Music.stream)

	# nature ambience loop
	var ambience_stream = load("res://u_vr5icvkppa-nature-ambience-323729.mp3")
	ambience_stream.loop = true
	AudioManager.play_ambience(ambience_stream)
	AudioManager.ambience_volume = 0.3
	# cut off last 20 seconds by restarting when it reaches that point
	var ambience_length = ambience_stream.get_length()
	var loop_timer = Timer.new()
	loop_timer.wait_time = ambience_length - 20.0
	loop_timer.autostart = true
	loop_timer.timeout.connect(func(): AudioManager.ambience_player.play())
	add_child(loop_timer)
	confirm_reset.pressed.connect(_on_confirm_reset)
	cancel_reset.pressed.connect(_on_cancel_reset)
	reset_dialog.visible = false

	# settings menu
	_setup_settings_menu()

	# connect destructibles
	for obj in get_tree().get_nodes_in_group("destructibles"):
		obj.destroyed.connect(_on_destructible_destroyed)

	# connect golden flag signals on all courses' flags
	for key in _course_data:
		for flag in _course_data[key]["flags"].get_children():
			flag.golden_hit.connect(_on_golden_flag_hit)

	# golden flag timer
	_golden_timer = Timer.new()
	_golden_timer.one_shot = true
	_golden_timer.timeout.connect(_spawn_golden_flag)
	add_child(_golden_timer)
	_start_golden_timer()

	_show_all_yardage()

func _show_all_yardage() -> void:
	for obj in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(obj):
			obj.show_yardage()

func _on_destructible_destroyed(reward: float) -> void:
	GameState.money += reward
	GameState.lifetime_money += reward
	GameState.money_changed.emit(GameState.money)
	GameState.add_xp(reward * 0.1)
	_text_queue.append({"money": reward, "yards": 0.0, "flag_hit": false, "direct_hit": true})
	if not _queue_processing:
		_process_text_queue()

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
	medals_label.text = " " + GameState.format_number(amount)

func _on_retire_pressed() -> void:
	print("DEBUG: lifetime_money=", GameState.lifetime_money, " money=", GameState.money)
	var medals = GameState.get_medal_reward()
	retire_info_label.text = "You will earn %s Medals!\n\nUpgrades will be reset.\nBalls, clubs, levels and level bonuses are kept." % GameState.format_number(medals)
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
	AudioManager.music_player.stream_paused = true
	AudioManager.ambience_player.stream_paused = true
	AudioManager.set_sfx_ducked(true)

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
	AudioManager.set_sfx_ducked(false)
	if not AudioManager.music_muted:
		AudioManager.music_player.stream_paused = false
		AudioManager.ambience_player.stream_paused = false
	# reload golfer sprite in case player switched golfer
	golfer._load_golfer_sprite()
	_show_all_yardage()

func _on_golfer_swung() -> void:
	_hit_ball()


func _on_money_changed(new_amount: float) -> void:
	money_label.text = GameState.format_number(new_amount)

func _on_ShotTimer_timeout() -> void:
	shot_timer.wait_time = BASE_INTERVAL / GameState.get_fire_rate()
	golfer.play_swing()


func _hit_ball() -> void:
	AudioManager.play_sfx("hit")
	var modifier = shot_control.get_launch_modifier()
	var ball_count = GameState.get_ball_count()
	for i in ball_count:
		var ball = Ball.instantiate()
		ball._speed = BASE_SPEED * GameState.get_ball_speed()
		var consistency_mult = GameState.balls[GameState.equipped_ball].get("consistency_mult", 1.0)
		ball._spread = BASE_SPREAD / (GameState.get_consistency() * consistency_mult)
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
	var hit_flag: Node3D = null
	for flag in _get_active_flags().get_children():
		var result = flag.check_hit(ball.global_position)
		if result[0] > best_bonus:
			best_bonus = result[0]
		if result[1]:
			direct_hit = true
			hit_flag = flag

	if best_bonus > 0.0:
		AudioManager.play_sfx("flag")
		var flag_mult = GameState.balls[GameState.equipped_ball].get("flag_mult", 1.0)
		base_money += best_bonus * flag_mult

	if direct_hit:
		base_money *= 2.5

	var final_money = base_money * GameState.get_money_mult()
	var is_market = GameState.balls[GameState.equipped_ball].get("is_market", false)

	if is_market and direct_hit and hit_flag:
		# invest money into this flag instead of cashing
		if hit_flag not in _market_investments:
			_market_investments[hit_flag] = 0.0
		_market_investments[hit_flag] += final_money
		_update_market_label(hit_flag)
		_text_queue.append({"money": final_money, "yards": yards, "flag_hit": true, "direct_hit": true, "invested": true})
	else:
		# cash out any market investments when a ball misses
		var cashout = _cashout_all_investments()
		final_money += cashout
		GameState.money += final_money
		GameState.lifetime_money += final_money
		GameState.money_changed.emit(GameState.money)
		GameState.add_xp(final_money * 0.1)
		_text_queue.append({"money": final_money, "yards": yards, "flag_hit": best_bonus > 0.0, "direct_hit": direct_hit, "cashout": cashout})
	if not _queue_processing:
		_process_text_queue()
	else:
		# safety: if queue is stuck, force restart
		if _floating_texts.size() == 0 and _text_queue.size() > 3:
			_queue_processing = false
			_process_text_queue()

	var is_pinball = GameState.balls[GameState.equipped_ball].get("is_pinball", false)
	if is_pinball and direct_hit and hit_flag and is_instance_valid(ball):
		_pinball_chain(ball, hit_flag)
	elif direct_hit and is_instance_valid(ball):
		ball.queue_free()
	else:
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(ball):
			ball.queue_free()


func _pinball_chain(ball: RigidBody3D, first_flag: Node3D) -> void:
	# stop physics so we can tween the ball manually
	ball.freeze = true

	# gather remaining flags sorted by distance from first flag
	var remaining_flags: Array = []
	for flag in _get_active_flags().get_children():
		if flag != first_flag:
			remaining_flags.append(flag)
	remaining_flags.sort_custom(func(a, b):
		return a.global_position.distance_to(first_flag.global_position) < b.global_position.distance_to(first_flag.global_position)
	)

	for flag in remaining_flags:
		if not is_instance_valid(ball) or not is_instance_valid(flag):
			break

		# fly to the flag
		var fly_tween = create_tween()
		var travel_dist = ball.global_position.distance_to(flag.global_position)
		var fly_time = clampf(travel_dist * 0.003, 0.1, 0.4)
		# arc upward slightly
		var mid_point = (ball.global_position + flag.global_position) / 2.0
		mid_point.y += travel_dist * 0.15
		fly_tween.tween_property(ball, "global_position", mid_point, fly_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly_tween.tween_property(ball, "global_position", flag.global_position, fly_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fly_tween.finished

		if not is_instance_valid(ball):
			break

		# cash this flag hit
		AudioManager.play_sfx("flag_stick")
		flag._wiggle()
		var flag_bonus = flag.global_position.z * 0.1 * flag.distance_mult
		var flag_mult = GameState.balls[GameState.equipped_ball].get("flag_mult", 1.0)
		var pin_money = (flag_bonus * flag_mult * 2.5) * GameState.get_money_mult()
		GameState.money += pin_money
		GameState.lifetime_money += pin_money
		GameState.money_changed.emit(GameState.money)
		GameState.add_xp(pin_money * 0.1)

		var pin_yards = flag.global_position.distance_to(tee_position.global_position) * 1.094
		_text_queue.append({"money": pin_money, "yards": pin_yards, "flag_hit": true, "direct_hit": true})
		if not _queue_processing:
			_process_text_queue()

		# check golden flag
		if flag._is_golden:
			var golden_bonus = flag_bonus * 50.0
			flag.golden_hit.emit(flag, golden_bonus)
			flag.deactivate_golden()

	# done chaining — despawn
	if is_instance_valid(ball):
		ball.queue_free()

func _cashout_all_investments() -> float:
	var total := 0.0
	for flag in _market_investments:
		total += _market_investments[flag]
		_remove_market_label(flag)
	_market_investments.clear()
	return total

func _update_market_label(flag: Node3D) -> void:
	if not is_instance_valid(flag):
		return
	var amount = _market_investments.get(flag, 0.0)
	if flag not in _market_labels:
		var label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.modulate = Color.CYAN
		label.no_depth_test = true
		label.render_priority = 10
		var f = load("res://balatro.otf")
		if f:
			label.font = f
		flag.add_child(label)
		_market_labels[flag] = label
	_market_labels[flag].text = "$" + GameState.format_number(amount)
	# scale based on camera distance so it's readable from far away
	var cam = get_viewport().get_camera_3d()
	var distance = flag.global_position.distance_to(cam.global_position)
	var scale_factor = pow(distance * 0.05, 1.0) * 1.5
	_market_labels[flag].scale = Vector3(scale_factor, scale_factor, scale_factor)
	# position above the flag sprite
	_market_labels[flag].position = Vector3(0, scale_factor * 1.5, 0)

func _remove_market_label(flag: Node3D) -> void:
	if flag in _market_labels:
		if is_instance_valid(_market_labels[flag]):
			_market_labels[flag].queue_free()
		_market_labels.erase(flag)

func _start_golden_timer() -> void:
	_golden_timer.wait_time = randf_range(GOLDEN_FLAG_INTERVAL_MIN, GOLDEN_FLAG_INTERVAL_MAX)
	_golden_timer.start()

func _spawn_golden_flag() -> void:
	# deactivate any existing golden flag
	if _golden_flag and is_instance_valid(_golden_flag):
		_golden_flag.deactivate_golden()

	var flags = _get_active_flags().get_children()
	if flags.size() == 0:
		_start_golden_timer()
		return

	# pick a random flag
	_golden_flag = flags[randi() % flags.size()]
	_golden_flag.activate_golden()

func _on_golden_flag_hit(flag: Node3D, bonus: float) -> void:
	var final_money = bonus * GameState.get_money_mult()
	GameState.money += final_money
	GameState.lifetime_money += final_money
	GameState.money_changed.emit(GameState.money)
	GameState.add_xp(final_money * 0.1)
	_golden_flag = null

	# show golden cashout text
	_text_queue.append({"money": final_money, "yards": 0.0, "flag_hit": true, "direct_hit": true, "golden": true})
	if not _queue_processing:
		_process_text_queue()

	# start timer for next golden flag
	_start_golden_timer()

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
				_spawn_floating_text(data["money"], data["yards"], data.get("flag_hit", false), data.get("direct_hit", false), data.get("invested", false), data.get("cashout", 0.0), data.get("golden", false))
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
			_spawn_floating_text(data["money"], data["yards"], data.get("flag_hit", false), data.get("direct_hit", false), data.get("invested", false), data.get("cashout", 0.0), data.get("golden", false))
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

func _spawn_floating_text(money: float, yards: float, flag_hit: bool = false, direct_hit: bool = false, invested: bool = false, cashout: float = 0.0, golden: bool = false) -> void:
	_push_existing_texts_up()

	var text = FloatingText.instantiate()
	add_child(text)
	text.global_position = golfer.global_position + Vector3(0, 1.5, 0)
	if golden:
		text.setup_summary("GOLDEN FLAG! +$%s" % GameState.format_number(money), _get_dynamic_lifetime(), Color(1.0, 0.84, 0.0))
	elif invested:
		text.setup_summary("INVESTED $%s" % GameState.format_number(money), _get_dynamic_lifetime(), Color.CYAN)
	elif cashout > 0.0:
		text.setup_summary("CASHOUT! +$%s" % GameState.format_number(money), _get_dynamic_lifetime(), Color.GREEN)
	else:
		text.setup(money, yards, flag_hit, direct_hit, _get_dynamic_lifetime())
	_floating_texts.append(text)
	text.tree_exited.connect(func(): _floating_texts.erase(text))

func _spawn_summary_text(total_money: float, hit_count: int, any_flag: bool, any_direct: bool) -> void:
	_push_existing_texts_up()

	var text = FloatingText.instantiate()
	add_child(text)
	text.global_position = golfer.global_position + Vector3(0, 1.5, 0)
	var summary = "+$%s (%d more hits)" % [GameState.format_number(total_money), hit_count]
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
	reset_dialog.move_to_front()
	reset_dialog.visible = true

func _on_confirm_reset() -> void:
	GameState.full_reset()
	get_tree().reload_current_scene()

func _on_cancel_reset() -> void:
	reset_dialog.visible = false

func _setup_settings_menu() -> void:
	var font = load("res://balatro.otf")

	# settings button - top right
	var settings_btn = TextureButton.new()
	settings_btn.texture_normal = load("res://SettingsButton.png")
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP
	settings_btn.ignore_texture_size = false
	settings_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	var tex_size = settings_btn.texture_normal.get_size() if settings_btn.texture_normal else Vector2(32, 32)
	settings_btn.offset_right = -10
	settings_btn.offset_left = -10 - tex_size.x
	settings_btn.offset_top = 10
	settings_btn.offset_bottom = 10 + tex_size.y
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

	var reset_btn = Button.new()
	reset_btn.text = "Reset Game"
	reset_btn.add_theme_font_override("font", font)
	reset_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(reset_btn)

	var medals_btn = Button.new()
	medals_btn.text = "+100 Medals"
	medals_btn.add_theme_font_override("font", font)
	medals_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(medals_btn)

	var money_btn = Button.new()
	money_btn.text = "+$1,000,000"
	money_btn.add_theme_font_override("font", font)
	money_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(money_btn)

	settings_btn.pressed.connect(func(): _settings_panel.visible = !_settings_panel.visible)

	sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx_mute()
		sfx_btn.text = "Enable SFX" if AudioManager.sfx_muted else "Disable SFX"
	)

	music_btn.pressed.connect(func():
		AudioManager.toggle_music_mute()
		music_btn.text = "Enable Music" if AudioManager.music_muted else "Disable Music"
	)

	exit_btn.pressed.connect(func():
		GameState.save()
		get_tree().quit()
	)

	reset_btn.pressed.connect(func():
		_settings_panel.visible = false
		_on_reset_pressed()
	)

	medals_btn.pressed.connect(func():
		GameState.medals += 100
		GameState.medals_changed.emit(GameState.medals)
	)

	money_btn.pressed.connect(func():
		GameState.money += 100000
		GameState.lifetime_money += 100000
		GameState.money_changed.emit(GameState.money)
	)
