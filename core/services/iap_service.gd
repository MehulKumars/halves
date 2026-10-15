class_name IAPService
extends Node
## Interface for in-app purchases. The plan adds real billing only after a game passes Keep
## (Play Billing plugin 3.3.0 or later, which meets Google's Billing Library 8+ rule).
## Contract: purchase_finished fires after purchase() returns, never inside it (real stores show a
## payment sheet first), so callers can write `purchase(id)` then `await purchase_finished`.

signal purchase_finished(product_id: String, success: bool)


func initialize() -> void:
	pass


func is_owned(_product_id: String) -> bool:
	return false


func purchase(product_id: String) -> void:
	purchase_finished.emit.call_deferred(product_id, false)
