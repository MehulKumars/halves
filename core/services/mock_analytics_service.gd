class_name MockAnalyticsService
extends AnalyticsService
## Prints analytics events to the output panel instead of sending them anywhere.


func log_event(event_name: String, params: Dictionary = {}) -> void:
	print("[Analytics] %s %s" % [event_name, params])
