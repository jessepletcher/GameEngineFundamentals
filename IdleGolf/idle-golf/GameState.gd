extends Node

var _cursor_normal: Texture2D
var _cursor_pressed: Texture2D
var money: float = 0.0
var xp: float = 0.0
var level: int = 1
var xp_to_next_level: float = 100.0
var medals: float = 0.0
var lifetime_xp: float = 0.0  # total xp earned this run
var lifetime_money: float = 0.0  # total money earned this run
var best_run_xp: float = 0.0  # best xp from any run
var best_run_money: float = 0.0  # best money from any run

signal medals_changed(new_amount: float)
signal money_changed(new_amount: float)
signal leveled_up(new_level: int, stat_boosted: String)
signal xp_changed(current_xp: float, required_xp: float)
signal golfer_changed
signal course_changed

static func format_number(value: float) -> String:
	var num_str = str(int(value))
	var result = ""
	var count = 0
	for i in range(num_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0 and num_str[i] != "-":
			result = "," + result
		result = num_str[i] + result
		count += 1
	return result

const SAVE_PATH = "user://save.cfg"

const LEVEL_REWARDS = [
	"ball_speed",
	"money_mult",
	"fire_rate",
	"consistency",
	"fire_rate",
	"money_mult",
	"ball_speed",
	"consistency",
	"fire_rate",
	"money_mult",
]


var upgrades = {
	"ball_speed":   {"level": 0, "base_cost": 10.0,  "label": "Ball Speed"},
	"fire_rate":    {"level": 0, "base_cost": 15.0,  "label": "Fire Rate"},
	"money_mult":   {"level": 0, "base_cost": 20.0,  "label": "Money Multiplier"},
	"consistency":  {"level": 0, "base_cost": 12.0,  "label": "Consistency"},
	"xp_mult":      {"level": 0, "base_cost": 20.0,  "label": "XP Multiplier"},
	"flat_distance": {"level": 0, "base_cost": 8.0, "label": "Flat Distance", "use_medals": true},
	"multi_ball": {"level": 0, "base_cost": 150.0, "label": "Multi Ball", "use_medals": true, "max_level": 3},
	"multi_ball_spread": {"level": 0, "base_cost": 75.0, "label": "Multi Ball Spread", "use_medals": true, "max_level": 6},
	"consistency_mult": {"level": 0, "base_cost": 100.0, "label": "Consistency Mult", "use_medals": true, "max_level": 10},
}

var balls = {
	"standard": {"name": "Standard Ball", "desc": "Your trusty golf ball", "medal_cost": 0.0, "owned": true, "speed_mult": 1.0, "money_mult": 1.0, "can_home": false, "trail_color": Color.WHITE, "texture": preload("res://BallIcon.png"), "flag_mult": 1.0, "unlock_level": 1},
	"homing_ball": {"name": "Homing Ball", "desc": "Homes in on nearest flag", "medal_cost": 5, "owned": false, "speed_mult": 1.0, "money_mult": 1.5, "can_home": true, "trail_color": Color.LIME_GREEN, "texture": preload("res://HomingBalllIcon.png"), "flag_mult": 1.0, "unlock_level": 5},
	"pin_seeker": {"name": "Pin Seeker", "desc": "2x flag bonus money", "medal_cost": 25, "owned": false, "speed_mult": 1.0, "money_mult": 1.0, "can_home": false, "trail_color": Color.GOLD, "texture": preload("res://PinSeekBalllIcon.png"), "flag_mult": 2.0, "unlock_level": 15},
	"firework": {"name": "Firework Ball", "desc": "Explodes into 6 balls at apex", "medal_cost": 60, "owned": false, "speed_mult": 1.0, "money_mult": 0.5, "can_home": false, "trail_color": Color.ORANGE_RED, "texture": preload("res://FireWorksBalllIcon.png"), "flag_mult": 1.0, "is_firework": true, "unlock_level": 30},
	"market": {"name": "Market Ball", "desc": "Flag hits invest money, grows 10%/s. Miss to cash out!", "medal_cost": 40, "owned": false, "speed_mult": 1.0, "money_mult": 1.0, "can_home": false, "trail_color": Color.CYAN, "texture": preload("res://BallIcon.png"), "flag_mult": 1.5, "is_market": true, "unlock_level": 20, "consistency_mult": 1.5},
	"wrecking": {"name": "Wrecking Ball", "desc": "1.5x distance, 2x destructible money", "medal_cost": 30, "owned": false, "speed_mult": 1.0, "money_mult": 1.0, "can_home": false, "trail_color": Color.DARK_GRAY, "texture": preload("res://BallIcon.png"), "flag_mult": 1.0, "destruct_mult": 2.0, "unlock_level": 12},
	"pinball": {"name": "Pin Ball", "desc": "Hits a flag then flies to every other flag! 1.5x consistency", "medal_cost": 50, "owned": false, "speed_mult": 1.0, "money_mult": 0.7, "can_home": false, "trail_color": Color.MAGENTA, "texture": preload("res://BallIcon.png"), "flag_mult": 1.0, "consistency_mult": 10.5, "is_pinball": true, "unlock_level": 18},
}

var golfers = {
	"standard":    {"name": "Standard Golfer", "desc": "A reliable swing",             "medal_cost": 0,  "owned": true,  "speed_mult": 1.0, "fire_rate_mult": 1.0, "money_mult": 1.0, "spritesheet": "res://GolfSwing-Sheet.png", "h_frames": 5, "frame_size": 96, "unlock_level": 1, "texture": preload("res://BallIcon.png")},
	"power":       {"name": "Power Golfer",    "desc": "+15% distance, -5% fire rate", "medal_cost": 5,  "owned": false, "speed_mult": 1.15, "fire_rate_mult": 0.95, "money_mult": 1.0, "spritesheet": "res://GolfSwing-Sheet.png", "h_frames": 5, "frame_size": 96, "unlock_level": 3, "texture": preload("res://BallIcon.png")},
	"speedy":      {"name": "Speedy Golfer",   "desc": "+25% fire rate",               "medal_cost": 20, "owned": false, "speed_mult": 1.0, "fire_rate_mult": 1.25, "money_mult": 1.0, "spritesheet": "res://GolfSwing-Sheet.png", "h_frames": 5, "frame_size": 96, "unlock_level": 10, "texture": preload("res://BallIcon.png")},
	"Lion Trees":      {"name": "Lion Trees",   "desc": "+25% money, +20% distance",   "medal_cost": 50, "owned": false, "speed_mult": 1.2, "fire_rate_mult": 1.0, "money_mult": 1.25, "spritesheet": "res://LionTreesSwing.png", "h_frames": 5, "frame_size": 96, "unlock_level": 25, "texture": preload("res://BallIcon.png")},
	"construction":    {"name": "Construction Worker", "desc": "Destructibles respawn 50% faster", "medal_cost": 15, "owned": false, "speed_mult": 1.0, "fire_rate_mult": 1.0, "money_mult": 1.0, "respawn_mult": 0.5, "spritesheet": "res://GolfSwing-Sheet.png", "h_frames": 5, "frame_size": 96, "unlock_level": 7, "texture": preload("res://BallIcon.png")},
	"golfer1": {"name": "Golfer 1", "desc": "+10% distance", "medal_cost": 8, "owned": false, "speed_mult": 1.1, "fire_rate_mult": 1.0, "money_mult": 1.0, "spritesheet": "res://Golfer1.png", "h_frames": 1, "frame_size": 96, "unlock_level": 4, "texture": preload("res://BallIcon.png")},
	"golfer2": {"name": "Golfer 2", "desc": "+15% fire rate", "medal_cost": 18, "owned": false, "speed_mult": 1.0, "fire_rate_mult": 1.15, "money_mult": 1.0, "spritesheet": "res://Golfer2.png", "h_frames": 1, "frame_size": 96, "unlock_level": 9, "texture": preload("res://BallIcon.png")},
	"golfer4": {"name": "Golfer 4", "desc": "+15% money", "medal_cost": 35, "owned": false, "speed_mult": 1.0, "fire_rate_mult": 1.0, "money_mult": 1.15, "spritesheet": "res://Golfer4.png", "h_frames": 1, "frame_size": 96, "unlock_level": 14, "texture": preload("res://BallIcon.png")},
}

var courses = {
	"course1": {"name": "Driving Range", "desc": "The classic range", "medal_cost": 0, "owned": true, "unlock_level": 1, "texture": preload("res://BallIcon.png")},
	"course2": {"name": "Course 2", "desc": "A new challenge", "medal_cost": 10, "owned": false, "unlock_level": 8, "texture": preload("res://BallIcon.png")},
	"course3": {"name": "Course 3", "desc": "A longer course with tighter payouts", "medal_cost": 25, "owned": false, "unlock_level": 15, "texture": preload("res://BallIcon.png")},
}


var equipped_ball: String = "standard"
var equipped_golfer: String = "standard"
var equipped_course: String = "course1"

var level_bonuses = {
	"ball_speed": 0.0,
	"fire_rate": 0.0,
	"money_mult": 0.0,
	"consistency": 0.0,
	"xp_mult": 0.0,
}

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	load_game()

	# custom mouse cursor
	_cursor_normal = load("res://Mouse.png")
	_cursor_pressed = load("res://MousePressed.png")
	Input.set_custom_mouse_cursor(_cursor_normal)

	# global button press sound hookup
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons.call_deferred()

func _connect_existing_buttons() -> void:
	_connect_buttons_recursive(get_tree().root)

func _connect_buttons_recursive(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)
	for child in node.get_children():
		_connect_buttons_recursive(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.set_custom_mouse_cursor(_cursor_pressed)
		else:
			Input.set_custom_mouse_cursor(_cursor_normal)

func _play_button_sound() -> void:
	AudioManager.play_sfx("button")
	
func get_flat_distance() -> float:
	return upgrades["flat_distance"]["level"] * 1.0  # +2 yards per level → 100 yds at lv50

func get_medal_reward() -> float:
	if lifetime_money <= 1.0:
		return 0.0
	var raw_medals: float
	if best_run_money <= 0.0:
		# first run: log scaling
		raw_medals = 16.67 * log(lifetime_money) / log(10.0)
	elif lifetime_money <= best_run_money:
		return 0.0
	else:
		# medals based on how much you beat your best by (ratio-based, log-dampened)
		var improvement_ratio = (lifetime_money - best_run_money) / best_run_money
		raw_medals = 150.0 * log(1.0 + improvement_ratio) / log(2.0)
	# asymptotic soft cap — trails off toward 250, never quite reaches it
	return floor(250.0 * (1.0 - exp(-raw_medals / 250.0)))

func retire() -> void:
	var earned_medals = get_medal_reward()
	medals += earned_medals

	# update high scores if this run beat them
	best_run_xp = max(best_run_xp, lifetime_xp)
	best_run_money = max(best_run_money, lifetime_money)
	
	# reset run stats
	lifetime_xp = 0.0
	lifetime_money = 0.0
	money = 0.0
	
	# reset upgrades (keep medal upgrades)
	for key in upgrades:
		if not upgrades[key].get("use_medals", false):
			upgrades[key]["level"] = 0
	
	medals_changed.emit(medals)
	save()
	
func full_reset() -> void:
	money = 0.0
	xp = 0.0
	level = 1
	xp_to_next_level = 100.0
	medals = 0.0
	lifetime_xp = 0.0
	lifetime_money = 0.0
	best_run_xp = 0.0
	best_run_money = 0.0
	equipped_ball = "standard"
	equipped_golfer = "standard"
	equipped_course = "course1"

	for key in upgrades:
		upgrades[key]["level"] = 0

	for key in level_bonuses:
		level_bonuses[key] = 0.0

	for key in balls:
		balls[key]["owned"] = (key == "standard")

	for key in golfers:
		golfers[key]["owned"] = (key == "standard")

	for key in courses:
		courses[key]["owned"] = (key == "course1")

	money_changed.emit(money)
	medals_changed.emit(medals)
	xp_changed.emit(xp, xp_to_next_level)
	save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
	

func save() -> void:
	var config = ConfigFile.new()
	
	config.set_value("player", "money", money)
	config.set_value("player", "xp", xp)
	config.set_value("player", "level", level)
	config.set_value("player", "xp_to_next_level", xp_to_next_level)
	config.set_value("player", "equipped_ball", equipped_ball)
	config.set_value("player", "equipped_golfer", equipped_golfer)
	config.set_value("player", "equipped_course", equipped_course)
	config.set_value("player", "medals", medals)
	config.set_value("player", "lifetime_xp", lifetime_xp)
	config.set_value("player", "lifetime_money", lifetime_money)
	config.set_value("player", "best_run_xp", best_run_xp)
	config.set_value("player", "best_run_money", best_run_money)
	
	for key in upgrades:
		config.set_value("upgrades", key, upgrades[key]["level"])

	for key in level_bonuses:
		config.set_value("level_bonuses", key, level_bonuses[key])

	for key in balls:
		config.set_value("balls", key, balls[key]["owned"])
	
	for key in golfers:
		config.set_value("golfers", key, golfers[key]["owned"])

	for key in courses:
		config.set_value("courses", key, courses[key]["owned"])

	config.save(SAVE_PATH)

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return

	money = config.get_value("player", "money", 0.0)
	xp = config.get_value("player", "xp", 0.0)
	level = config.get_value("player", "level", 1)
	xp_to_next_level = config.get_value("player", "xp_to_next_level", 100.0)
	equipped_ball = config.get_value("player", "equipped_ball", "standard")
	equipped_golfer = config.get_value("player", "equipped_golfer", "standard")
	equipped_course = config.get_value("player", "equipped_course", "course1")
	medals = config.get_value("player", "medals", 0.0)
	lifetime_xp = config.get_value("player", "lifetime_xp", 0.0)
	lifetime_money = config.get_value("player", "lifetime_money", 0.0)
	best_run_xp = config.get_value("player", "best_run_xp", 0.0)
	best_run_money = config.get_value("player", "best_run_money", 0.0)
	
	for key in upgrades:
		upgrades[key]["level"] = config.get_value("upgrades", key, 0)

	for key in level_bonuses:
		level_bonuses[key] = config.get_value("level_bonuses", key, 0.0)

	for key in balls:
		balls[key]["owned"] = config.get_value("balls", key, balls[key].get("owned", false))
	
	for key in golfers:
		golfers[key]["owned"] = config.get_value("golfers", key, golfers[key].get("owned", false))

	for key in courses:
		courses[key]["owned"] = config.get_value("courses", key, courses[key].get("owned", false))

	_sanitize_progress()

func add_xp(amount: float) -> void:
	var gained = amount * get_xp_mult()
	xp += gained
	lifetime_xp += gained
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		_level_up()
	xp_changed.emit(xp, xp_to_next_level)

func add_level(amount: int = 1) -> void:
	for i in maxi(1, amount):
		_level_up()
	xp_changed.emit(xp, xp_to_next_level)
	save()

func _level_up() -> void:
	level += 1
	xp_to_next_level = floor(100.0 * pow(1.4, level - 1))
	var reward_index = (level - 2) % LEVEL_REWARDS.size()
	var stat = LEVEL_REWARDS[reward_index]
	level_bonuses[stat] += 0.05  # +5% multiplier per level
	leveled_up.emit(level, stat)
	money_changed.emit(money)

func get_level_mult(stat: String) -> float:
	return 1.0 + level_bonuses.get(stat, 0.0)

func get_swing_speed() -> float:
	return (1.0 + upgrades["fire_rate"]["level"] * 0.06) * get_level_mult("fire_rate")

func add_money(amount: float) -> void:
	var final = amount * get_money_mult()
	money += final
	lifetime_money += final
	money_changed.emit(money)
	add_xp(final * 0.1)

func get_ball_count() -> int:
	return 1 + upgrades["multi_ball"]["level"]

func get_multi_ball_spread_degrees() -> float:
	return max(8.0, 20.0 - upgrades["multi_ball_spread"]["level"] * 2.0)

func get_cost_for_level(upgrade: String, level: int) -> float:
	if upgrade == "multi_ball":
		return floor(upgrades[upgrade]["base_cost"] * pow(3.0, level))  # 150 → 450 → 1350
	if upgrade == "multi_ball_spread":
		return floor(upgrades[upgrade]["base_cost"] * pow(1.9, level))
	if upgrade == "consistency_mult":
		return floor(upgrades[upgrade]["base_cost"] * pow(2.0, level))
	if upgrade == "flat_distance":
		return floor(upgrades[upgrade]["base_cost"] * pow(1.8, level))  # 8 → 14 → 26 → 46 → 83
	return floor(upgrades[upgrade]["base_cost"] * pow(1.08, level))

func get_cost(upgrade: String) -> float:
	var level = int(upgrades[upgrade]["level"])
	return get_cost_for_level(upgrade, level)

func try_purchase(upgrade: String) -> bool:
	var cost = get_cost(upgrade)
	if money >= cost:
		money -= cost
		upgrades[upgrade]["level"] += 1
		money_changed.emit(money)
		return true
	return false

func get_golfer_data() -> Dictionary:
	return golfers[equipped_golfer]

func get_ball_speed() -> float:
	return (1.0 + upgrades["ball_speed"]["level"] * 0.04) * get_level_mult("ball_speed") * get_golfer_data()["speed_mult"]

func get_fire_rate() -> float:
	return (1.0 + upgrades["fire_rate"]["level"] * 0.03) * get_level_mult("fire_rate") * get_golfer_data()["fire_rate_mult"]

func get_money_mult() -> float:
	return (1.0 + upgrades["money_mult"]["level"] * 0.09) * get_level_mult("money_mult") * get_golfer_data()["money_mult"]

func get_consistency() -> float:
	var medal_mult = 1.0 + upgrades["consistency_mult"]["level"] * 0.5
	return (0.5 + upgrades["consistency"]["level"] * .1) * get_level_mult("consistency") * medal_mult

func get_xp_mult() -> float:
	return (1.0 + upgrades["xp_mult"]["level"] * 0.09) * get_level_mult("xp_mult")

func _sanitize_progress() -> void:
	level = max(1, int(level))
	xp_to_next_level = max(1.0, float(xp_to_next_level))
	money = max(0.0, float(money))
	xp = max(0.0, float(xp))
	medals = max(0.0, float(medals))
	lifetime_xp = max(0.0, float(lifetime_xp))
	lifetime_money = max(0.0, float(lifetime_money))
	best_run_xp = max(0.0, float(best_run_xp))
	best_run_money = max(0.0, float(best_run_money))

	for key in upgrades:
		var level_value: int = max(0, int(upgrades[key].get("level", 0)))
		var max_level: int = int(upgrades[key].get("max_level", -1))
		if max_level >= 0:
			level_value = min(level_value, max_level)
		upgrades[key]["level"] = level_value

	balls["standard"]["owned"] = true
	golfers["standard"]["owned"] = true
	courses["course1"]["owned"] = true

	if not balls.has(equipped_ball) or not balls[equipped_ball].get("owned", false):
		equipped_ball = "standard"
	if not golfers.has(equipped_golfer) or not golfers[equipped_golfer].get("owned", false):
		equipped_golfer = "standard"
	if not courses.has(equipped_course) or not courses[equipped_course].get("owned", false):
		equipped_course = "course1"
