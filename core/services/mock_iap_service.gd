class_name MockIAPService
extends IAPService
## Test purchases for the editor: every purchase succeeds and lasts for the session.
## Like a real store it answers later (after a short delay), never inside purchase(), so code
## that calls purchase() and then awaits purchase_finished works with both.

var simulated_delay_sec: float = 0.3

var _owned: Dictionary[String, bool] = {}


func is_owned(product_id: String) -> bool:
	return _owned.get(product_id, false)


func purchase(product_id: String) -> void:
	print("[MockIAP] purchase '%s'" % product_id)
	await get_tree().create_timer(simulated_delay_sec, true, false, true).timeout
	_owned[product_id] = true
	purchase_finished.emit(product_id, true)
