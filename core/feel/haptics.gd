class_name Haptics
extends RefCounted
## Short vibration pulses for phones.
## Needs the VIBRATE permission in the Android export preset, or it silently does nothing.
## Never carry information by vibration alone: players and devices can turn it off.

## Mirror the player's "Haptics" setting here.
static var enabled: bool = true


static func pulse(duration_ms: int = 15, amplitude: float = 0.5) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)


## Taps and matches (10-30 ms).
static func tick() -> void:
	pulse(12, 0.4)


## A clear success, such as a container closing.
static func success() -> void:
	pulse(40, 0.6)


## Big moments: level complete, a large reward (50-100 ms).
static func big() -> void:
	pulse(80, 0.8)
