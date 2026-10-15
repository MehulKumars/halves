class_name LeaderboardService
extends Node
## Interface for leaderboards. Start with Google Play Games Services plus local bests;
## move to Talo only if a game needs cross-device boards. Do not use SilentWolf (shut down).


func initialize() -> void:
	pass


func submit_score(_board_id: String, _score: int) -> void:
	pass


func show_board(_board_id: String) -> void:
	pass


func get_local_best(_board_id: String) -> int:
	return 0
