extends Node
## Reuses the supplied Kenney effects and a single original looping music track.
## The bounded pool never creates audio players during combat.

const POOL_SIZE: int = 12
const MUSIC_STREAM: AudioStreamWAV = preload("res://Assets/Generated/music_loop.wav")
const SOUNDS: Dictionary = {
	"slash": preload("res://Assets/Audio/RPG/Audio/knifeSlice.ogg"),
	"hit": preload("res://Assets/Audio/Impact/Audio/impactSoft_medium_000.ogg"),
	"hurt": preload("res://Assets/Audio/RPG/Audio/chop.ogg"),
	"block": preload("res://Assets/Audio/Impact/Audio/impactMetal_light_000.ogg"),
	"boss": preload("res://Assets/Audio/Impact/Audio/impactBell_heavy_000.ogg"),
	"pickup": preload("res://Assets/Audio/RPG/Audio/handleCoins.ogg"),
	"level": preload("res://Assets/Audio/UI/Audio/confirmation_001.ogg"),
	"death": preload("res://Assets/Audio/UI/Audio/error_001.ogg"),
	"start": preload("res://Assets/Audio/UI/Audio/pluck_001.ogg"),
	"dash": preload("res://Assets/Audio/RPG/Audio/drawKnife1.ogg"),
}
const VOLUMES: Dictionary = {
	"slash": -15.0, "hit": -17.0, "hurt": -8.0, "block": -11.0,
	"boss": -8.0, "pickup": -14.0, "level": -10.0, "death": -11.0,
	"start": -10.0, "dash": -14.0,
}
const PRIORITY: Dictionary = {
	"slash": 0, "hit": 0, "pickup": 0, "dash": 1, "block": 1,
	"hurt": 2, "start": 2, "level": 3, "boss": 3, "death": 3,
}
const MIN_INTERVAL_MS: Dictionary = {"slash": 60, "hit": 35, "pickup": 65, "block": 45}

var _pool: Array[AudioStreamPlayer] = []
var _last_sound_ms: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_enabled: bool = true
var _music_enabled: bool = true
var _external_paused: bool = false
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.max_polyphony = 1
		player.set_meta("priority", -1)
		player.set_meta("started_ms", 0)
		add_child(player)
		_pool.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.max_polyphony = 1
	_music_player.volume_db = -16.0
	# This resource has one music consumer. Reuse its imported PCM payload
	# rather than duplicating another 1.5 MB of sample data on a phone.
	var loop: AudioStreamWAV = MUSIC_STREAM
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_music_player.stream = loop
	add_child(_music_player)
	refresh_settings()
	if _music_enabled and not _music_player.playing:
		_music_player.play()


func play_sound(kind: String, pitch: float = 1.0) -> void:
	if _external_paused or not _sfx_enabled or not SOUNDS.has(kind) or _pool.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var min_interval: int = int(MIN_INTERVAL_MS.get(kind, 0))
	if _last_sound_ms.has(kind) and now - int(_last_sound_ms[kind]) < min_interval:
		return
	var priority: int = int(PRIORITY.get(kind, 0))
	var selected: AudioStreamPlayer = null
	for player in _pool:
		if not player.playing:
			selected = player
			break
	# Quiet frequent effects may be dropped; significant cues can replace an
	# older effect of equal or lower importance when all twelve players are busy.
	if selected == null and priority > 0:
		var oldest: int = 9223372036854775807
		for player in _pool:
			var started: int = int(player.get_meta("started_ms", 0))
			if int(player.get_meta("priority", 0)) <= priority and started < oldest:
				oldest = started
				selected = player
	if selected == null:
		return
	_last_sound_ms[kind] = now
	selected.stop()
	selected.stream = SOUNDS[kind] as AudioStream
	selected.volume_db = float(VOLUMES.get(kind, -12.0))
	selected.pitch_scale = clampf(pitch * _random.randf_range(0.96, 1.04), 0.6, 1.6)
	selected.set_meta("priority", priority)
	selected.set_meta("started_ms", now)
	selected.play()


func set_enabled(enabled: bool) -> void:
	set_sfx_enabled(enabled)
	set_music_enabled(enabled)


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	if not enabled:
		for player in _pool:
			player.stop()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if _music_player == null:
		return
	if enabled and not _music_player.playing:
		_music_player.play()
	elif not enabled:
		_music_player.stop()
	_music_player.stream_paused = _external_paused


## Native ads and backgrounding suspend playback without changing saved preferences.
func set_external_paused(paused: bool) -> void:
	_external_paused = paused
	if _music_player != null:
		_music_player.stream_paused = paused
	if paused:
		for player in _pool:
			player.stop()


func refresh_settings() -> void:
	# Resolve the save autoload at runtime so this component can also be tested
	# independently. The settings UI owns saving toggles to disk.
	var save_data: Node = get_node_or_null("/root/SaveData")
	if save_data == null:
		return
	var profile: Variant = save_data.get("profile")
	if profile is Dictionary:
		var settings: Dictionary = profile.get("settings", {}) as Dictionary
		set_sfx_enabled(bool(settings.get("sfx", true)))
		set_music_enabled(bool(settings.get("music", true)))


func is_sfx_enabled() -> bool:
	return _sfx_enabled


func is_music_enabled() -> bool:
	return _music_enabled


func active_effect_count() -> int:
	var count: int = 0
	for player in _pool:
		if player.playing:
			count += 1
	return count


func stop_for_shutdown() -> void:
	# Release playback before the audio server shuts
	# down. Test runners can invoke this before yielding their final frames.
	for player in _pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null


func _exit_tree() -> void:
	stop_for_shutdown()
