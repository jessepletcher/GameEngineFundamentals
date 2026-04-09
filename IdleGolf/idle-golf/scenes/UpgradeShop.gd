extends CanvasLayer

@onready var shop_panel = $LeftVBox/LeftMenu/ScrollContainer
@onready var menu_background = $LeftVBox/LeftMenu/MenuBackground
@onready var upgrades_button: Button = $LeftVBox/LeftMenu/TopBar/UpgradesButton
@onready var rows = {
	"ball_speed":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/BallSpeedRow,
	"fire_rate":   $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FireRateRow,
	"money_mult":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MoneyMultRow,
	"consistency": $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/ConsistencyRow,
	"xp_mult":     $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/XPMultRow,
	"flat_distance": $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FlatDistanceRow,
	"multi_ball":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MultiBallRow,
}

func _ready() -> void:
	shop_panel.visible = false
	menu_background.visible = false
	GameState.money_changed.connect(_refresh)
	upgrades_button.pressed.connect(toggle)

	for key in rows:
		var btn = rows[key].get_node("BuyButton")
		btn.pressed.connect(_on_buy_pressed.bind(key))

	_refresh(GameState.money)

func toggle() -> void:
	shop_panel.visible = !shop_panel.visible
	menu_background.visible = shop_panel.visible
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
