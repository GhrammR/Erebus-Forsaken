class_name EndlessDirector extends SpawnDirector
## Stage 9.7 — wave-scaling spawn director for the endless arena.
## Inherits SpawnDirector's anchor + cap + cooldown machinery and
## adds:
##   - per-wave quota: wave N requires `6 + N*2` kills before advance
##   - per-wave reweighting of species, concurrent_cap, respawn_delay,
##     and elite_chance via _apply_wave_tuning()
##   - a 1.5s lull between waves (suppresses new spawns; living enemies
##     persist and continue to count toward the next wave's quota when
##     killed — readable falloff, no jarring despawn)
##   - deterministic species picks off `EndlessRun.seed` so the
##     shareable seed string actually reproduces the same run shape
##
## AD-08 — emits EventBus.endless_wave_started / _completed.
##
## Wave 0 is the "not yet started" sentinel; begin_run() (called by
## the zone on ready when EndlessRun.active) advances to wave 1.

const _LULL_SECONDS: float = 1.5
## Stage 9.7 polish — wave-start grace so the player has a beat to
## orient before mobs converge. Especially needed in the depths,
## where 4 corner anchors + cap 7+ would otherwise dogpile within a
## handful of frames.
const _WAVE_START_GRACE: float = 2.5
## Per-spawn stagger inside a wave. Without this the cap fills in
## consecutive frames the moment a wave begins.
const _SPAWN_INTERVAL: float = 0.45

var _wave: int = 0
var _kills_this_wave: int = 0
var _kills_required: int = 0
var _lull_remaining: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Per-wave species bands. Keys are inclusive lower bounds. Wave N
## uses the largest key ≤ N. Ids must resolve through EnemyRegistry —
## Stage 9.7 ships with only shade_wretch + bog_caller registered;
## variety beyond melee/ranged mix comes from the rising elite_chance,
## not new species. Ironbound / Fleet variants ride in as elite-tough
## and elite-fast rolls on the same base scenes.
const _SPECIES_BANDS: Dictionary = {
	1: [
		{ "id": &"shade_wretch", "weight": 10 },
	],
	3: [
		{ "id": &"shade_wretch", "weight": 7 },
		{ "id": &"bog_caller",   "weight": 3 },
	],
	5: [
		{ "id": &"shade_wretch", "weight": 5 },
		{ "id": &"bog_caller",   "weight": 5 },
	],
	8: [
		{ "id": &"shade_wretch", "weight": 4 },
		{ "id": &"bog_caller",   "weight": 6 },
	],
}

func _ready() -> void:
	# Seed RNG before super, so any spawns the parent fires read from
	# our deterministic stream.
	_rng.seed = EndlessRun.seed if EndlessRun.active else randi()
	# Force initial spawn count to zero — begin_run() drives the first
	# wave explicitly via _apply_wave_tuning + cap bump.
	initial_spawn_count = 0
	super._ready()
	if EndlessRun.active:
		begin_run()

func begin_run() -> void:
	_advance_wave_to(1)

func _process(delta: float) -> void:
	if _lull_remaining > 0.0:
		_lull_remaining = maxf(_lull_remaining - delta, 0.0)
		if _lull_remaining == 0.0:
			_advance_wave_to(_wave + 1)
		return
	super._process(delta)

func _on_tracked_died(killer: Node) -> void:
	super._on_tracked_died(killer)
	if not EndlessRun.active:
		return
	if _lull_remaining > 0.0:
		# Carry-over kill from the prior wave's living tail: still
		# counts for the player's run total, but does not satisfy
		# the next wave's quota (which hasn't started).
		EndlessRun.record_kill(false)
		return
	EndlessRun.record_kill(true)
	_kills_this_wave += 1
	if _kills_this_wave >= _kills_required:
		_complete_wave()

func _complete_wave() -> void:
	EventBus.endless_wave_completed.emit(_wave)
	_lull_remaining = _LULL_SECONDS
	# Suppress new spawns during the lull. SpawnDirector._process
	# checks _cooldown_remaining anyway; lull guard above is the
	# authoritative gate, this is just belt-and-braces.
	_cooldown_remaining = maxf(_cooldown_remaining, _LULL_SECONDS)

func _advance_wave_to(new_wave: int) -> void:
	_wave = new_wave
	_kills_this_wave = 0
	_kills_required = 6 + _wave * 2
	_apply_wave_tuning(_wave)
	# Wave-start grace: suppress new spawns for a couple of seconds so
	# the player isn't dogpiled the instant a wave begins (especially
	# the FIRST wave on entering the depths).
	_cooldown_remaining = maxf(_cooldown_remaining, _WAVE_START_GRACE)
	EndlessRun.advance_wave(_wave, _kills_required)
	EventBus.endless_wave_started.emit(_wave, _kills_required)

## Override the parent's _spawn_one to add an inter-spawn stagger.
## Without this the cap fills frame-by-frame and the player sees a
## sudden wall of enemies. The stagger paces the first wave fill
## (and any post-lull refill) into a more readable trickle.
func _spawn_one() -> void:
	super._spawn_one()
	if _cooldown_remaining < _SPAWN_INTERVAL:
		_cooldown_remaining = _SPAWN_INTERVAL

func _apply_wave_tuning(w: int) -> void:
	concurrent_cap = mini(6 + w, 14)
	respawn_delay = maxf(5.0 - float(w) * 0.25, 1.5)
	elite_chance = minf(0.05 + float(w) * 0.02, 0.30)
	species = _band_for(w)

func _band_for(w: int) -> Array[Dictionary]:
	var chosen_key: int = 1
	for key_v in _SPECIES_BANDS.keys():
		var key := int(key_v)
		if w >= key and key >= chosen_key:
			chosen_key = key
	var out: Array[Dictionary] = []
	for entry_v in (_SPECIES_BANDS[chosen_key] as Array):
		out.append(entry_v as Dictionary)
	return out

## Override the parent species picker so wave runs use our seeded
## RNG. Anchor pick stays global — it depends on the live player
## position, which is non-deterministic by nature.
func _pick_species() -> StringName:
	var total: int = 0
	for entry_v in species:
		var entry: Dictionary = entry_v as Dictionary
		total += int(entry.get("weight", 0))
	if total <= 0:
		return &""
	var r: int = _rng.randi() % total
	var acc: int = 0
	for entry_v in species:
		var entry: Dictionary = entry_v as Dictionary
		acc += int(entry.get("weight", 0))
		if r < acc:
			return StringName(entry.get("id", &""))
	return &""

func _maybe_pick_elite() -> EliteModifier:
	if elite_chance <= 0.0 or elite_table.is_empty():
		return null
	if _rng.randf() >= elite_chance:
		return null
	return elite_table[_rng.randi() % elite_table.size()]

# ---- introspection for verifier ------------------------------------------

func current_wave() -> int:
	return _wave

func kills_required() -> int:
	return _kills_required

func tuning_preview(w: int) -> Dictionary:
	## Pure function: returns the cap / delay / elite chance / species
	## the director WOULD use at wave w, without mutating state. Used
	## by --verify9_7 to assert scaling without spinning a full zone.
	return {
		"concurrent_cap": mini(6 + w, 14),
		"respawn_delay": maxf(5.0 - float(w) * 0.25, 1.5),
		"elite_chance": minf(0.05 + float(w) * 0.02, 0.30),
		"species": _band_for(w),
		"kills_required": 6 + w * 2,
	}
