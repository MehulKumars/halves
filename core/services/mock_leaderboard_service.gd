class_name MockLeaderboardService
extends LeaderboardService
## Keeps best scores (highest) and best times (lowest) in memory for the session.

var _best: Dictionary[String, int] = {}
var _best_time: Dictionary[String, int] = {}


func submit_score(board_id: String, score: int) -> void:
	if score > get_local_best(board_id):
		_best[board_id] = score
	print("[MockLeaderboard] %s <- %d (best %d)" % [board_id, score, get_local_best(board_id)])


func show_board(board_id: String) -> void:
	print("[MockLeaderboard] show '%s'" % board_id)


func get_local_best(board_id: String) -> int:
	return _best.get(board_id, 0)


func submit_time(board_id: String, ms: int) -> void:
	var best := get_local_best_time(board_id)
	if ms > 0 and (best == 0 or ms < best):
		_best_time[board_id] = ms
	print("[MockLeaderboard] %s <- %d ms (best %d ms)" % [board_id, ms, get_local_best_time(board_id)])


func get_local_best_time(board_id: String) -> int:
	return _best_time.get(board_id, 0)
