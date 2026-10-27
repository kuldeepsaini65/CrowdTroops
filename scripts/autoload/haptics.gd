extends Node
## Short vibration pulses on mobile, gated by the vibration setting and
## rate-limited so a busy frame cannot spam the motor.

const MIN_INTERVAL_MS := 60

var _last_pulse_ms: int = -MIN_INTERVAL_MS


func pulse(duration_ms: int = 20) -> void:
	if not bool(SaveManager.settings.get("vibration", true)):
		return
	if not OS.has_feature("mobile"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_pulse_ms < MIN_INTERVAL_MS:
		return
	_last_pulse_ms = now
	Input.vibrate_handheld(duration_ms)
