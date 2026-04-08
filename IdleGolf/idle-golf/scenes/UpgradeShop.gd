extends CanvasLayer

@onready var shop_panel = $Panel
@onready var rows = {
    "ball_speed":  $Panel/VBoxContainer/BallSpeedRow,
    "fire_rate":   $Panel/VBoxContainer/FireRateRow,
    "money_mult":  $Panel/VBoxContainer/MoneyMultRow,
    "consistency": $Panel/VBoxContainer/ConsistencyRow,
    "swing_speed": $Panel/VBoxContainer/SwingSpeedRow,
    "flat_distance": $Panel/VBoxContainer/FlatDistanceRow,
}

func _ready() -> void:
    shop_panel.visible = false
    GameState.money_changed.connect(_refresh)
    
    for key in rows:
        var btn = rows[key].get_node("BuyButton")
        btn.pressed.connect(_on_buy_pressed.bind(key))
    
    _refresh(GameState.money)

func toggle() -> void:
    shop_panel.visible = !shop_panel.visible
    if shop_panel.visible:
        _refresh(GameState.money)

func _refresh(_money: float) -> void:
    for key in rows:
        var upgrade = GameState.upgrades[key]
        var cost = GameState.get_cost(key)
        var level = upgrade["level"]
        rows[key].get_node("NameLabel").text = upgrade["label"]
        rows[key].get_node("LevelLabel").text = "Lv.%d" % level
        var btn = rows[key].get_node("BuyButton")
        if upgrade.get("use_medals", false):
            btn.text = "🏅 %.0f" % cost
            btn.disabled = GameState.medals < cost
        else:
            btn.text = "$%.0f" % cost
            btn.disabled = GameState.money < cost

func _on_buy_pressed(key: String) -> void:
    var upgrade = GameState.upgrades[key]
    if upgrade.get("use_medals", false):
        var cost = GameState.get_cost(key)
        if GameState.medals >= cost:
            GameState.medals -= cost
            GameState.medals_changed.emit(GameState.medals)
            GameState.upgrades[key]["level"] += 1
            _refresh(GameState.money)
    else:
        GameState.try_purchase(key)

func _on_CloseButton_pressed() -> void:
    shop_panel.visible = false
