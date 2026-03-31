extends Control

const ShopItem = preload("res://ShopItem.tscn")

@onready var ball_list = $HBoxContainer/BallsColumn/BallList
@onready var club_list = $HBoxContainer/ClubsColumn/ClubList
@onready var back_button: Button = $BackButton
@onready var money_label: Label = $MoneyLabel

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    money_label.text = "$%.2f" % GameState.money
    GameState.money_changed.connect(_on_money_changed)
    _populate_shop()


func _populate_shop() -> void:
    print("populating shop, balls: ", GameState.balls.keys())
    print("populating shop, clubs: ", GameState.clubs.keys())
    for child in ball_list.get_children():
        child.queue_free()
    for child in club_list.get_children():
        child.queue_free()
    
    for id in GameState.balls:
        var data = GameState.balls[id]
        var item = ShopItem.instantiate()
        ball_list.add_child(item)
        item.setup(id, data["name"], data["desc"], data["cost"], null, data["owned"], GameState.equipped_ball == id)
        item.purchase_requested.connect(_on_ball_purchase)

    for id in GameState.clubs:
        var data = GameState.clubs[id]
        var item = ShopItem.instantiate()
        club_list.add_child(item)
        item.setup(id, data["name"], data["desc"], data["cost"], null, data["owned"], GameState.equipped_club == id)
        item.purchase_requested.connect(_on_club_purchase)

func _on_ball_purchase(id: String) -> void:
    print("Purchase requested for: ", id)
    var data = GameState.balls[id]
    if data["owned"]:
        print("Already owned, equipping: ", id)
        GameState.equipped_ball = id
    elif GameState.money >= data["cost"]:
        GameState.money -= data["cost"]
        GameState.money_changed.emit(GameState.money)
        GameState.balls[id]["owned"] = true
        GameState.equipped_ball = id
    print("Equipped ball is now: ", GameState.equipped_ball)
    _populate_shop()

func _on_club_purchase(id: String) -> void:
    var data = GameState.clubs[id]
    if data["owned"]:
        GameState.equipped_club = id
    elif GameState.money >= data["cost"]:
        GameState.money -= data["cost"]
        GameState.money_changed.emit(GameState.money)
        GameState.clubs[id]["owned"] = true
        GameState.equipped_club = id
    _populate_shop()

func _on_money_changed(amount: float) -> void:
    money_label.text = "$%.2f" % amount

func _on_back_pressed() -> void:
    GameState.save()
    get_tree().change_scene_to_file("res://scenes/Main.tscn")
