extends Node

var money: float = 0.0
var xp: float = 0.0
var level: int = 1
var xp_to_next_level: float = 100.0

signal money_changed(new_amount: float)
signal leveled_up(new_level: int, stat_boosted: String)
signal xp_changed(current_xp: float, required_xp: float)

const SAVE_PATH = "user://save.cfg"

const LEVEL_REWARDS = [
    "ball_speed",
    "money_mult",
    "fire_rate",
    "consistency",
    "swing_speed",
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
    "swing_speed":  {"level": 0, "base_cost": 8.0,   "label": "Swing Speed"},
}

var balls = {
    "standard": {"name": "Standard Ball", "desc": "Your trusty golf ball", "cost": 0.0, "owned": true, "speed_mult": 1.0, "money_mult": 1.0, "can_home": false, "trail_color": Color.WHITE, "texture": preload("res://GolfBall2.png")},
    "homing_ball": {"name": "Homing Ball", "desc": "Homes in on nearest flag", "cost": 2000.0, "owned": false, "speed_mult": 1.0, "money_mult": 1.5, "can_home": true, "trail_color": Color.LIME_GREEN, "texture": preload("res://GolfBall2.png")},
    # ... etc
}

var clubs = {
    "standard": {"name": "Standard Club", "desc": "A reliable iron", "cost": 0.0, "owned": true, "speed_mult": 1.0, "fire_rate_mult": 1.0},
    "driver": {"name": "Driver", "desc": "+30% distance", "cost": 750.0, "owned": false, "speed_mult": 1.3, "fire_rate_mult": 0.9},
    "rapid_iron": {"name": "Rapid Iron", "desc": "+50% fire rate", "cost": 1500.0, "owned": false, "speed_mult": 1.0, "fire_rate_mult": 1.5},
    "golden_club": {"name": "Golden Club", "desc": "+50% money, +20% distance", "cost": 5000.0, "owned": false, "speed_mult": 1.2, "fire_rate_mult": 1.0},
}

var equipped_ball: String = "standard"
var equipped_club: String = "standard"

func _ready() -> void:
    get_tree().set_auto_accept_quit(false)
    load_game()

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
    config.set_value("player", "equipped_club", equipped_club)
    
    for key in upgrades:
        config.set_value("upgrades", key, upgrades[key]["level"])
    
    for key in balls:
        config.set_value("balls", key, balls[key]["owned"])
    
    for key in clubs:
        config.set_value("clubs", key, clubs[key]["owned"])
    
    config.save(SAVE_PATH)
    print("Game saved")

func load_game() -> void:
    var config = ConfigFile.new()
    var err = config.load(SAVE_PATH)
    print("Load error code: ", err)  # 0 = OK, anything else = problem
    if err != OK:
        print("No save file found at: ", SAVE_PATH)
        return
    
    money = config.get_value("player", "money", 0.0)
    print("Loaded money: ", money)
    xp = config.get_value("player", "xp", 0.0)
    level = config.get_value("player", "level", 1)
    xp_to_next_level = config.get_value("player", "xp_to_next_level", 100.0)
    equipped_ball = config.get_value("player", "equipped_ball", "standard")
    equipped_club = config.get_value("player", "equipped_club", "standard")
    
    for key in upgrades:
        upgrades[key]["level"] = config.get_value("upgrades", key, 0)
    
    for key in balls:
        balls[key]["owned"] = config.get_value("balls", key, false)
    
    for key in clubs:
        clubs[key]["owned"] = config.get_value("clubs", key, false)
    
    print("Game loaded, money: ", money)

func add_xp(amount: float) -> void:
    print("Adding XP: ", amount, " current XP: ", xp)
    xp += amount * exp_mult
    xp_changed.emit(xp, xp_to_next_level)
    while xp >= xp_to_next_level:
        xp -= xp_to_next_level
        _level_up()

func _level_up() -> void:
    level += 1
    xp_to_next_level = floor(100.0 * pow(1.4, level - 1))  # increases each level
    var reward_index = (level - 2) % LEVEL_REWARDS.size()
    var stat = LEVEL_REWARDS[reward_index]
    upgrades[stat]["level"] += 1
    leveled_up.emit(level, stat)
    money_changed.emit(money)  # refresh shop button states

var exp_mult: float = 1.0

func get_swing_speed() -> float:
    return 1.0 + upgrades["swing_speed"]["level"] * 0.2

func add_money(amount: float) -> void:
    var final = amount * get_money_mult()
    money += final
    money_changed.emit(money)
    add_xp(final * 0.1)  # 10% of money earned becomes XP

func get_cost(upgrade: String) -> float:
    var level = upgrades[upgrade]["level"]
    return floor(upgrades[upgrade]["base_cost"] * pow(1.6, level))

func try_purchase(upgrade: String) -> bool:
    var cost = get_cost(upgrade)
    if money >= cost:
        money -= cost
        upgrades[upgrade]["level"] += 1
        money_changed.emit(money)
        return true
    return false

func get_ball_speed() -> float:
    return 1.0 + upgrades["ball_speed"]["level"] * 0.2

func get_fire_rate() -> float:
    return 10.0 + upgrades["fire_rate"]["level"] * 0.15

func get_money_mult() -> float:
    return 100.0 + upgrades["money_mult"]["level"] * 1

func get_consistency() -> float:
    return .3 + upgrades["consistency"]["level"] * 0.25
