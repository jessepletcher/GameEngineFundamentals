extends Node

var money: float = 0.0

signal money_changed(new_amount: float)

var upgrades = {
    "ball_speed":   {"level": 0, "base_cost": 10.0,  "label": "Ball Speed"},
    "fire_rate":    {"level": 0, "base_cost": 15.0,  "label": "Fire Rate"},
    "money_mult":   {"level": 0, "base_cost": 20.0,  "label": "Money Multiplier"},
    "consistency":  {"level": 0, "base_cost": 12.0,  "label": "Consistency"},
    "swing_speed":  {"level": 0, "base_cost": 8.0,   "label": "Swing Speed"},
}

func get_swing_speed() -> float:
    return 1.0 + upgrades["swing_speed"]["level"] * 0.2

func add_money(amount: float) -> void:
    money += amount * get_money_mult()
    money_changed.emit(money)

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
    return 100.0 + upgrades["money_mult"]["level"] * 0.3

func get_consistency() -> float:
    return 1.0 + upgrades["consistency"]["level"] * 0.25
