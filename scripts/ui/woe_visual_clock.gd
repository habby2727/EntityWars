extends RefCounted

# Simulation runs at 10 ticks/s. A short interpolation buffer absorbs delivery
# jitter; time beyond the last authoritative sample is strictly bounded.
const TICKS_PER_SECOND := 10.0
const MAX_EXTRAPOLATION_TICKS := 2.0
const MIN_BUFFER_TICKS := 10.0
const MAX_BUFFER_TICKS := 20.0
const MAX_BEHIND_TICKS := 30.0
var render_tick := 0.0
var latest_tick := -1
var buffer_ticks := MIN_BUFFER_TICKS
var _last_arrival := 0.0
var _elapsed_since_sample := 0.0
var _jitter_seconds := 0.0

func observe(tick: int, arrival_seconds: float) -> void:
	if tick < 0 or tick <= latest_tick:
		return
	if latest_tick < 0:
		latest_tick = tick
		render_tick = maxf(0.0, float(tick) - buffer_ticks)
		_last_arrival = arrival_seconds
		_elapsed_since_sample = 0.0
		return
	var server_gap := float(tick - latest_tick) / TICKS_PER_SECOND
	var arrival_gap := maxf(0.0, arrival_seconds - _last_arrival)
	# Outages are handled by the bounded timeline, not treated as endless jitter.
	var deviation := minf(1.0, absf(arrival_gap - server_gap))
	_jitter_seconds = lerpf(_jitter_seconds, deviation, 0.2)
	var cadence_ticks := maxf(MIN_BUFFER_TICKS, minf(MAX_BUFFER_TICKS, server_gap * TICKS_PER_SECOND - MAX_EXTRAPOLATION_TICKS))
	buffer_ticks = clampf(cadence_ticks + _jitter_seconds * 20.0, MIN_BUFFER_TICKS, MAX_BUFFER_TICKS)
	latest_tick = tick
	render_tick = maxf(render_tick, float(tick) - MAX_BEHIND_TICKS)
	_last_arrival = arrival_seconds
	_elapsed_since_sample = 0.0

func advance(delta: float) -> void:
	if latest_tick < 0 or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	_elapsed_since_sample += delta
	var estimate := float(latest_tick) + _elapsed_since_sample * TICKS_PER_SECOND - buffer_ticks
	var target := minf(estimate, float(latest_tick) + MAX_EXTRAPOLATION_TICKS)
	var debt := maxf(0.0, target - render_tick)
	var rate := 1.0 + minf(0.25, debt * 0.05)
	render_tick = minf(maxf(render_tick, target), render_tick + delta * TICKS_PER_SECOND * rate)
