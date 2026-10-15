class_name MockLeaderboardService
extends LeaderboardService
## Keeps best scores in memory for the session.

var _best: Dictionary[String, int] = {}


func submit_score(board_id: String, score: int) -> void:
	if score > get_local_best(board_id):
		_best[board_id] = score
	print("[MockLeaderboard] %s <- %d (best %d)" % [board_id, score, get_local_best(board_id)])


func show_board(board_id: String) -> void:
	print("[MockLeaderboard] show '%s'" % board_id)


func get_local_best(board_id: String) -> int:
	return _best.get(board_id, 0)
