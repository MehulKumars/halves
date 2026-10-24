class_name HalvesRun
extends RefCounted
## The clock and move log of one board: active play time (from the first tap, pauses left out)
## and every pair, mistake, undo, shuffle, hint and (v3) mend. Kept for best times; replay() re-checks
## a run with HalvesState, which is what a future leaderboard server would do before trusting a time.

## Saved logs store the kind as an int: only ever append (MEND: [t_ms, MEND, a, -1]).
enum Event { PAIR, MISMATCH, UNDO, SHUFFLE, HINT, MEND }

const FORMAT: int = 1
## A frame longer than this (a hitch, or time in the background) only counts this much.
const MAX_STEP_MS: int = 250

var board: String = ""
var level: int = 0
var gen_version: int = 0
var free_mistakes: int = 0
var strict: bool = false
var active_ms: int = 0
var started: bool = false
var finished: bool = false
## [[t_ms, kind, a, b], ...] oldest first.
var events: Array = []


func start() -> void:
	started = true


func advance(delta_ms: int) -> void:
	if started and not finished:
		active_ms += clampi(delta_ms, 0, MAX_STEP_MS)


func record(kind: Event, a: int = -1, b: int = -1) -> void:
	if finished:
		return
	started = true
	events.append([active_ms, int(kind), a, b])


func finish() -> void:
	finished = true


func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"board": board,
		"level": level,
		"gen": gen_version,
		"free_mistakes": free_mistakes,
		"strict": strict,
		"active_ms": active_ms,
		"events": events.duplicate(true),
	}


static func from_dict(data: Dictionary) -> HalvesRun:
	var run := HalvesRun.new()
	run.board = str(data.get("board", ""))
	run.level = int(data.get("level", 0))
	run.gen_version = int(data.get("gen", 0))
	run.free_mistakes = int(data.get("free_mistakes", 0))
	run.strict = bool(data.get("strict", false))
	run.active_ms = int(data.get("active_ms", 0))
	for entry: Variant in data.get("events", []):
		var e: Array = entry
		run.events.append([int(e[0]), int(e[1]), int(e[2]) if e.size() > 2 else -1, int(e[3]) if e.size() > 3 else -1])
	run.started = not run.events.is_empty() or run.active_ms > 0
	return run


## Plays `run` back on `level`: {"ok", "error", "cleared", "stars", "slips"}.
## `level_gen` is the gen version the board was baked with (HalvesLevels or HalvesPools).
static func replay(level: HalvesLevelData, run: Dictionary, level_gen: int = -1, allowance: int = 0) -> Dictionary:
	var out := {"ok": false, "error": "", "cleared": false, "stars": 0, "slips": 0}
	var parsed := from_dict(run)
	var expected_gen := level_gen if level_gen >= 0 else HalvesLevels.gen_version()
	if parsed.gen_version != expected_gen:
		out.error = "run was made with gen %d, the board is gen %d" % [parsed.gen_version, expected_gen]
		return out
	var state := level.new_state()
	state.free_mistakes = parsed.free_mistakes
	state.strict = parsed.strict
	var last_t := 0
	for n in parsed.events.size():
		var e: Array = parsed.events[n]
		var t: int = e[0]
		if t < last_t or t > parsed.active_ms:
			out.error = "event %d: time %d ms is out of order" % [n, t]
			return out
		last_t = t
		match int(e[1]):
			Event.PAIR:
				if state.try_pair(e[2], e[3]) != HalvesState.Result.MATCH:
					out.error = "event %d: (%d, %d) is not a free match" % [n, e[2], e[3]]
					return out
			Event.MISMATCH:
				if state.try_pair(e[2], e[3]) != HalvesState.Result.MISMATCH:
					out.error = "event %d: (%d, %d) is not a mistake" % [n, e[2], e[3]]
					return out
			Event.UNDO:
				if not state.undo():
					out.error = "event %d: nothing to undo" % n
					return out
			Event.SHUFFLE:
				var stuck := int(e[3]) == 1
				if stuck != state.is_stuck():
					out.error = "event %d: the shuffle's stuck flag does not match the board" % n
					return out
				var dealt := HalvesFill.shuffle(state, level.solution, HalvesFill.shuffle_rng(parsed.level, e[2]))
				if dealt.is_empty():
					out.error = "event %d: nothing to shuffle" % n
					return out
				state.apply_deal(dealt.remaining, dealt.faces, stuck)
			Event.HINT:
				pass
			Event.MEND:
				if state.try_mend(e[2]) != HalvesState.Result.MATCH:
					out.error = "event %d: tile %d can not be mended" % [n, e[2]]
					return out
			_:
				out.error = "event %d: unknown kind %d" % [n, e[1]]
				return out
	out.ok = true
	out.cleared = state.is_cleared()
	out.stars = state.stars(allowance)
	out.slips = state.slips()
	return out
