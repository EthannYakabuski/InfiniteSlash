extends SceneTree
## Focused runtime check: cached pool bounds, priority, settings and loop metadata.

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _run() -> void:
	var audio: Variant = root.get_node_or_null("AudioManager")
	var owns_node: bool = audio == null
	if owns_node:
		audio = load("res://scripts/audio_manager.gd").new()
		root.add_child(audio)
	await process_frame
	_check(audio.get_child_count() == 13, "AudioManager must have twelve fixed effect players and one music player")
	audio.set_enabled(true)
	for iteration in 200:
		audio.play_sound("hurt", 1.0)
		audio.play_sound("boss", 1.0)
	_check(audio.active_effect_count() <= 12, "Audio effect count exceeded the fixed pool")
	_check(audio.get_child_count() == 13, "Combat sound bursts allocated new audio nodes")
	audio.play_sound("unknown_sound_should_be_ignored")
	audio.set_sfx_enabled(false)
	_check(audio.active_effect_count() == 0, "Disabling effects did not stop playing effects")
	audio.play_sound("start")
	_check(audio.active_effect_count() == 0, "Muted sound effects still played")
	var music: AudioStreamPlayer = audio.get_node("Music") as AudioStreamPlayer
	var stream: AudioStreamWAV = music.stream as AudioStreamWAV
	_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music forward loop is not enabled")
	_check(stream.loop_begin == 0 and stream.loop_end == 768000, "Music loop bounds do not cover all 32 seconds")
	_check(is_equal_approx(stream.get_length(), 32.0), "Music has unexpected duration")
	audio.set_music_enabled(false)
	_check(not music.playing, "Disabling music did not stop the loop")
	audio.set_music_enabled(true)
	_check(music.playing, "Re-enabling music did not start the loop")
	audio.refresh_settings()
	audio.stop_for_shutdown()
	# Audio stop/replacement is released on the mixer thread. Two unlimited
	# headless frames may take less than one mix block and can exit too early.
	await create_timer(0.35, true, false, true).timeout
	if owns_node:
		audio.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("PASS: AudioManager bounded polyphony, mute gates, unknown cues, settings refresh, and 32-second loop")
	quit(0 if _failures.is_empty() else 1)
