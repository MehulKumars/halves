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


## True when show_board() opens the platform's own screen (Google Play Games). When false the
## game shows its own ranks popup (ui/popups/ranks_popup.tscn).
func has_native_ui() -> bool:
	return false


func get_local_best(_board_id: String) -> int:
	return 0


## Times are lower-is-better boards (ms); Play Games boards for them are set to "smaller is better".
func submit_time(_board_id: String, _ms: int) -> void:
	pass


## The best (lowest) time submitted this session, 0 if none.
func get_local_best_time(_board_id: String) -> int:
	return 0
