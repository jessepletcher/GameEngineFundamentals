# GameState.gd
extends Node

var money: float = 0.0

signal money_changed(new_amount: float)

func add_money(amount: float) -> void:
	money += amount
	print("$%.2f  (+$%.2f)" % [money, amount])
	money_changed.emit(money)
