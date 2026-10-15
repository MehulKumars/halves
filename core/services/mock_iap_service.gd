class_name MockIAPService
extends IAPService
## Test purchases for the editor: every purchase succeeds and lasts for the session.

var _owned: Dictionary[String, bool] = {}


func is_owned(product_id: String) -> bool:
	return _owned.get(product_id, false)


func purchase(product_id: String) -> void:
	print("[MockIAP] purchase '%s'" % product_id)
	_owned[product_id] = true
	purchase_finished.emit(product_id, true)
