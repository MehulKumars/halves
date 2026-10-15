class_name AnalyticsService
extends Node
## Interface for analytics. Log the first-time funnel (tutorial_step_1, first_win,
## level_3_start) and the level seed, so drop-offs and bugs can be traced.


func initialize() -> void:
	pass


func log_event(_event_name: String, _params: Dictionary = {}) -> void:
	pass
