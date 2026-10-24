extends SceneTree
## Synthesises Halves' own calm sounds into assets/audio/sfx/ (original work, no samples): a soft bell
## "chime" (each crest family plays it at its own pentatonic note), a wooden "knock" for mistakes
## and a "seam" shimmer for the gold seam. Usage: godot --headless --path . -s tools/audio/synth_sfx.gd

const RATE: int = 44100
const OUT: String = "res://assets/audio/sfx/%s.wav"


func _initialize() -> void:
	_save("chime", _chime(1046.5, 1.4))
	_save("knock", _knock(196.0, 0.16))
	_save("seam", _seam(1567.98, 0.9))
	quit()


## A bell: a sine with quiet partials at 2x and 3.01x, a 4 ms attack and an exponential decay.
func _chime(freq: float, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 3.2)
		var s := sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0) \
				+ 0.08 * sin(TAU * freq * 3.01 * t) * exp(-t * 9.0)
		out[i] = s * env * 0.5
	return out


## Wood: a 3 ms noise click, then damped partials at the ratios of a wooden bar (1 : 2.76 : 5.40).
func _knock(freq: float, seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	for i in out.size():
		var t := float(i) / RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.35
		var body := sin(TAU * freq * t) * exp(-t * 28.0) + 0.5 * sin(TAU * freq * 2.76 * t) * exp(-t * 45.0) \
				+ 0.25 * sin(TAU * freq * 5.4 * t) * exp(-t * 70.0)
		out[i] = (click + body * 0.6) * minf(1.0, t / 0.001)
	return out


## A shimmer: a high bell with a slow tremolo and a faint octave above, fading in and out.
func _seam(freq: float, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.03) * exp(-t * 4.0)
		var tremolo := 0.75 + 0.25 * sin(TAU * 9.0 * t)
		var s := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t + 0.6)
		out[i] = s * env * tremolo * 0.3
	return out


## 16-bit mono WAV through AudioStreamWAV, so Godot imports it like the other effects.
func _save(id: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT % id))
	print("synth_sfx: %s %s (%d samples)" % [id, error_string(err), samples.size()])
