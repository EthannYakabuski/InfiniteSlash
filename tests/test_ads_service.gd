extends SceneTree
## Deterministic service tests. No Google SDK or real ads are invoked.

const ADS = preload("res://scripts/services/ads_service.gd")
const SDK_VALUES = preload("res://scripts/services/ads_sdk_values.gd")
var checks := 0
var failures := 0
var fixtures: Array[Node] = []
var fixture_root := ""

class ClockAds extends ADS:
	var clock := 100.0
	func _now() -> float: return clock
	func advance(seconds: float) -> void:
		clock += seconds
		_process(0)

class FakeBackend extends Node:
	signal consent_completed(token: int, allowed: bool, privacy_required: bool)
	signal form_started(token: int, kind: String)
	signal privacy_completed(token: int, allowed: bool, privacy_required: bool)
	signal initialized(token: int)
	signal loaded(kind: String, token: int, height_px: float)
	signal load_failed(kind: String, token: int)
	signal shown(kind: String, token: int)
	signal closed(kind: String, token: int)
	signal reward_earned(token: int)
	signal show_failed(kind: String, token: int)
	var allowed := false
	var available := true
	var accept_consent := true
	var accept_initialize := true
	var accept_load := true
	var accept_show := true
	var accept_privacy := true
	var consent_calls: Array[int] = []
	var init_calls: Array[Dictionary] = []
	var requests: Array[Dictionary] = []
	var shows: Array[Dictionary] = []
	var banners: Array[int] = []
	var discards: Array[Dictionary] = []
	var cancellations: Array[int] = []
	var privacy_calls: Array[int] = []
	var active := true
	var stopped := false
	func is_available() -> bool: return available
	func set_app_active(value: bool) -> void: active = value
	func begin_consent(token: int) -> bool:
		consent_calls.append(token)
		return accept_consent
	func cancel_consent(token: int) -> void: cancellations.append(token)
	func can_request_ads() -> bool: return allowed
	func initialize_ads(token: int, config: Dictionary) -> bool:
		init_calls.append({"token": token, "config": config.duplicate(true)})
		return accept_initialize
	func show_privacy(token: int) -> bool:
		privacy_calls.append(token)
		return accept_privacy
	func load_ad(kind: String, unit: String, token: int, placement: String) -> bool:
		requests.append({"kind": kind, "unit": unit, "token": token, "placement": placement})
		return accept_load
	func show_banner(token: int) -> void: banners.append(token)
	func show_ad(kind: String, token: int) -> bool:
		shows.append({"kind": kind, "token": token})
		return accept_show
	func discard(kind: String, token: int) -> void: discards.append({"kind": kind, "token": token})
	func shutdown() -> void: stopped = true
	func latest(kind: String) -> int:
		for i in range(requests.size() - 1, -1, -1):
			if requests[i].kind == kind: return int(requests[i].token)
		return 0
	func count(kind: String) -> int:
		var total := 0
		for request: Dictionary in requests:
			if request.kind == kind: total += 1
		return total

func _initialize() -> void:
	fixture_root = "res://output/test-data/ads-tests/%s" % Time.get_ticks_usec()
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("ADS: " + message)

func make_fixture(name: String, path := "", initially_active := true) -> Dictionary:
	var service := ClockAds.new()
	var backend := FakeBackend.new()
	service._backend = backend
	service.configuration = JSON.parse_string(FileAccess.get_file_as_string("res://config/admob.json"))
	service.storage_path = fixture_root.path_join(name + ".json") if path.is_empty() else path
	service.add_child(backend)
	if not initially_active: service.set_app_active(false)
	root.add_child(service)
	service.set_process(false)
	fixtures.append(service)
	var events := {"starts": [], "finishes": [], "spaces": [], "availability": [], "privacy": []}
	service.fullscreen_started.connect(func(kind): events.starts.append(kind))
	service.fullscreen_finished.connect(func(kind, earned): events.finishes.append({"kind": kind, "earned": earned}))
	service.banner_space_changed.connect(func(top, bottom): events.spaces.append([top, bottom]))
	service.availability_changed.connect(func(ready): events.availability.append(ready))
	service.privacy_options_changed.connect(func(required): events.privacy.append(required))
	await process_frame
	return {"service": service, "backend": backend, "events": events}

func allow(fixture: Dictionary, privacy := false) -> void:
	var backend: FakeBackend = fixture.backend
	backend.allowed = true
	backend.consent_completed.emit(backend.consent_calls.back(), true, privacy)
	check(backend.init_calls.size() == 1, "valid consent initializes the SDK exactly once")
	backend.initialized.emit(backend.init_calls.back().token)
	check(backend.requests.size() == 2, "only the two fullscreen formats preload without an overlay")

func complete_load(fixture: Dictionary, kind: String, height := 0.0) -> int:
	var token: int = fixture.backend.latest(kind)
	check(token > 0, kind + " has a requested generation")
	fixture.backend.loaded.emit(kind, token, height)
	return token

func test_consent() -> void:
	var f := await make_fixture("consent")
	check(f.backend.consent_calls.size() == 1, "consent info is updated on service startup")
	check(f.backend.requests.is_empty() and f.backend.init_calls.is_empty(), "no SDK initialization or ad requests before consent")
	check(not f.service.show_rewarded_continue() and not f.service.show_interstitial_if_due(), "startup cannot display fullscreen ads")
	check(not f.service.is_privacy_options_required(), "privacy entry is initially hidden")
	var token: int = f.backend.consent_calls.back()
	f.backend.consent_completed.emit(token + 100, true, true)
	check(f.backend.init_calls.is_empty(), "late foreign consent callback is ignored")
	f.backend.form_started.emit(token, "consent")
	check(f.service.get_fullscreen_kind() == "consent" and f.events.starts == ["consent"], "consent form freezes through the shared fullscreen contract")
	f.service.advance(300)
	check(f.service.get_fullscreen_kind() == "consent", "a visible consent form never times out into live gameplay")
	f.backend.consent_completed.emit(token, true, true)
	check(f.backend.init_calls.is_empty(), "an allowed callback alone cannot bypass the authoritative SDK getter")
	check(f.service.get_fullscreen_kind().is_empty() and f.events.finishes.size() == 1, "consent dismissal always pairs its fullscreen event")
	check(f.service.is_privacy_options_required() and f.events.privacy == [true], "SDK-required privacy options become available")
	check(not f.service.is_rewarded_ready(), "false authoritative getter keeps ads unavailable")
	# Fresh fixture verifies the allowed route and explicit adult configuration.
	var valid := await make_fixture("consent_valid")
	allow(valid)
	check(valid.backend.init_calls[0].config.child_directed == false, "adult target does not set COPPA true")
	check(valid.backend.init_calls[0].config.under_age_of_consent == false, "under-age flag is false")
	check(valid.backend.init_calls[0].config.max_ad_content_rating == "", "adult target does not force a G rating filter")
	for request: Dictionary in valid.backend.requests:
		check(request.unit == ADS.TEST_UNITS[request.kind], "real Google test unit is selected for " + request.kind)
	valid.backend.consent_completed.emit(valid.backend.consent_calls.back(), true, false)
	check(valid.backend.init_calls.size() == 1, "duplicate consent does not reinitialize")
	var timeout := await make_fixture("consent_timeout")
	var old: int = timeout.backend.consent_calls.back()
	timeout.service.advance(31)
	check(timeout.backend.cancellations == [old] and timeout.service.get_fullscreen_kind().is_empty(), "consent loading timeout is nonblocking")
	timeout.backend.allowed = true
	timeout.backend.consent_completed.emit(old, true, false)
	check(timeout.backend.init_calls.is_empty(), "timed-out consent cannot enable ads later")
	timeout.service.advance(61)
	check(timeout.backend.consent_calls.size() == 2, "consent retries after a bounded delay")
	var background := await make_fixture("consent_background_retry")
	background.backend.consent_completed.emit(background.backend.consent_calls.back(), false, false)
	background.service.set_app_active(false)
	background.service.advance(61)
	check(background.backend.consent_calls.size() == 1 and background.service._consent_retry > 0, "due consent retry remains pending while backgrounded")
	background.service.set_app_active(true)
	check(background.backend.consent_calls.size() == 2, "foreground resumes a due consent retry without restarting the app")
	var asleep := await make_fixture("background_boot", "", false)
	check(asleep.backend.consent_calls.is_empty(), "background startup does not show a consent UI")
	asleep.service.set_app_active(true)
	check(asleep.backend.consent_calls.size() == 1, "first foreground starts consent even when initial boot was backgrounded")
	var busy := await make_fixture("consent_fullscreen_retry")
	busy.backend.consent_completed.emit(busy.backend.consent_calls.back(), false, true)
	check(busy.service.show_privacy_options(), "privacy retry fixture opens")
	busy.service.advance(61)
	check(busy.backend.consent_calls.size() == 1 and busy.service._consent_retry > 0, "consent retry is retained while another fullscreen form is open")
	busy.backend.privacy_completed.emit(busy.backend.privacy_calls.back(), false, true)
	busy.service.advance(61)
	check(busy.backend.consent_calls.size() == 2, "consent retry resumes after fullscreen dismissal")
	var no_native := ADS.new()
	no_native.storage_path = fixture_root.path_join("desktop.json")
	root.add_child(no_native)
	fixtures.append(no_native)
	await process_frame
	check(no_native._backend == null and not no_native.is_rewarded_ready(), "desktop never creates a native or mock backend")
	var init_timeout := await make_fixture("init_timeout")
	init_timeout.backend.allowed = true
	init_timeout.backend.consent_completed.emit(init_timeout.backend.consent_calls.back(), true, false)
	var init_token: int = init_timeout.backend.init_calls.back().token
	init_timeout.service.advance(31)
	init_timeout.backend.initialized.emit(init_token)
	check(init_timeout.backend.requests.is_empty(), "stale initialization callback cannot load ads after timeout")

func test_banners() -> void:
	var f := await make_fixture("banners")
	f.service.set_banner_placement("home")
	check(f.backend.count("banner") == 0, "banner placement cannot bypass consent")
	allow_with_banner(f)
	complete_load(f, "rewarded")
	var token := complete_load(f, "banner", 150)
	check(f.events.spaces.back() == [150.0, 0.0] and f.backend.banners == [token], "home banner reserves actual physical top pixels")
	var discard_count: int = f.backend.discards.size()
	f.backend.loaded.emit("banner", token, 150)
	check(f.backend.discards.size() == discard_count and f.service._ready_tokens.banner == token, "native banner auto-refresh preserves current inventory")
	check(f.events.spaces.back() == [150.0, 0.0] and f.backend.banners == [token], "banner auto-refresh preserves space without another display request")
	f.service.set_banner_placement("home")
	check(f.backend.count("banner") == 1, "same placement retains one banner")
	f.service.set_banner_placement("pause")
	check(f.events.spaces.back() == [0.0, 0.0], "placement transition releases previous space")
	var pause := complete_load(f, "banner", 100)
	check(f.events.spaces.back() == [100.0, 0.0], "pause banner uses the top center slot")
	f.backend.loaded.emit("banner", token, 900)
	check(f.backend.banners.back() == pause and f.events.spaces.back() == [100.0, 0.0], "stale old banner cannot replace the new generation")
	f.service.set_banner_placement("upgrade")
	var upgrade := complete_load(f, "banner", 120)
	check(f.events.spaces.back() == [0.0, 120.0], "upgrade banner reserves bottom physical pixels")
	check(f.backend.requests.back().placement == "upgrade", "native backend receives the bottom placement")
	f.service.set_app_active(false)
	check(f.events.spaces.back() == [0.0, 0.0] and not f.backend.active, "background removes banner and releases space")
	f.backend.loaded.emit("banner", upgrade, 120)
	check(f.events.spaces.back() == [0.0, 0.0], "late background load cannot reserve space")
	f.service.set_app_active(true)
	check(f.backend.count("banner") == 4, "foreground creates exactly one fresh placement generation")
	f.service.set_banner_placement("")
	check(not f.service._loads.has("banner"), "running play has no banner or banner request")
	f.service.set_banner_placement("unknown")
	check(f.service._placement.is_empty(), "unrecognized overlay cannot display a banner")
	f.service.set_banner_placement("home")
	complete_load(f, "banner", 0)
	check(not f.service._ready_tokens.has("banner") and f.events.spaces.back() == [0.0, 0.0], "invalid native height rejects the banner without invented padding")
	var count: int = f.backend.count("banner")
	f.service.advance(59)
	check(f.backend.count("banner") == count, "invalid banner height has a bounded retry delay")
	f.service.advance(2)
	check(f.backend.count("banner") == count + 1, "banner retries once after its delay")
	var fresh := complete_load(f, "banner", 90)
	check(fresh > token, "all placement generations are unique")
	check(f.service.show_rewarded_continue(), "loaded rewarded ad can start from an overlay")
	check(f.events.spaces.back() == [0.0, 0.0], "fullscreen ad hides the banner before its start signal")

func allow_with_banner(fixture: Dictionary) -> void:
	fixture.backend.allowed = true
	fixture.backend.consent_completed.emit(fixture.backend.consent_calls.back(), true, false)
	fixture.backend.initialized.emit(fixture.backend.init_calls.back().token)
	check(fixture.backend.requests.size() == 3, "a valid overlay adds only one banner preload")
	check(fixture.backend.requests.back().unit == ADS.TEST_UNITS.banner, "banner uses the official test ID")

func test_rewarded() -> void:
	var f := await make_fixture("rewarded")
	allow(f)
	var token := complete_load(f, "rewarded")
	check(f.service.is_rewarded_ready() and f.events.availability.back() == true, "rewarded availability follows a successful real-backend load")
	var discard_count: int = f.backend.discards.size()
	f.backend.loaded.emit("rewarded", token, 0)
	check(f.backend.discards.size() == discard_count and f.service.is_rewarded_ready(), "duplicate ready fullscreen callback does not destroy usable inventory")
	check(f.service.show_rewarded_continue(), "ready rewarded starts")
	discard_count = f.backend.discards.size()
	f.backend.loaded.emit("rewarded", token, 0)
	check(f.backend.discards.size() == discard_count, "duplicate load callback cannot destroy a displayed fullscreen ad")
	check(f.events.starts == ["rewarded"] and not f.service.is_rewarded_ready(), "fullscreen start precedes display and consumes its ready token")
	check(not f.service.show_rewarded_continue(), "cannot show the same rewarded ad twice")
	f.backend.shown.emit("rewarded", token)
	f.service.advance(400)
	check(f.service.get_fullscreen_kind() == "rewarded", "a shown ad is not dismissed by the load/show watchdog")
	f.backend.reward_earned.emit(token + 100)
	check(f.events.finishes.is_empty(), "foreign earned callback cannot complete a reward")
	f.backend.reward_earned.emit(token)
	check(f.events.finishes.is_empty(), "earned callback alone cannot resume the run")
	f.backend.closed.emit("rewarded", token)
	check(f.events.finishes == [{"kind": "rewarded", "earned": true}], "earned reward is delivered only once after actual dismissal")
	f.backend.reward_earned.emit(token)
	f.backend.closed.emit("rewarded", token)
	check(f.events.finishes.size() == 1, "late duplicate callbacks cannot grant another continue")
	var no_reward := complete_load(f, "rewarded")
	check(f.service.show_rewarded_continue(), "another run can use a newly loaded rewarded ad")
	f.backend.shown.emit("rewarded", no_reward)
	f.backend.closed.emit("rewarded", no_reward)
	check(f.events.finishes.back().earned == false, "closing without earned callback never grants a reward")
	var failed := complete_load(f, "rewarded")
	f.backend.accept_show = false
	check(not f.service.show_rewarded_continue(), "immediate SDK show rejection returns false")
	check(f.events.finishes.back() == {"kind": "rewarded", "earned": false}, "show rejection releases fullscreen state without a reward")
	f.backend.reward_earned.emit(failed)
	check(not f.events.finishes.back().earned, "earned callback after failure is ignored")
	f.backend.accept_show = true
	var handshake := complete_load(f, "rewarded")
	check(f.service.show_rewarded_continue(), "watchdog fixture starts")
	f.service.advance(13)
	check(f.service.get_fullscreen_kind().is_empty() and not f.events.finishes.back().earned, "missing show handshake cannot leave gameplay blocked")
	f.backend.shown.emit("rewarded", handshake)
	f.backend.reward_earned.emit(handshake)
	f.backend.closed.emit("rewarded", handshake)
	check(not f.events.finishes.back().earned, "watchdog-expired generation cannot later grant a reward")
	complete_load(f, "rewarded")
	f.backend.allowed = false
	check(not f.service.is_rewarded_ready() and not f.service.show_rewarded_continue(), "consent withdrawal prevents display of a cached rewarded ad")

func test_interstitials() -> void:
	var f := await make_fixture("interstitials")
	allow(f)
	var token := complete_load(f, "interstitial")
	check(f.backend.shows.is_empty() and not f.service.show_interstitial_if_due(), "preloading never produces a launch interstitial")
	for i in range(2):
		f.service.record_completed_game()
		check(not f.service.show_interstitial_if_due(), "first two completed games do not show interstitials")
	f.service.record_completed_game()
	check(f.service.show_interstitial_if_due(), "third completed game opens one interstitial opportunity")
	check(f.service._completed_since_interstitial == 3, "counter is preserved until SDK confirms actual presentation")
	check(not f.service.show_interstitial_if_due(), "one final result cannot show multiple interstitials")
	f.backend.show_failed.emit("interstitial", token)
	check(f.service._completed_since_interstitial == 3, "no-show failure keeps the due counter")
	token = complete_load(f, "interstitial")
	f.service.record_completed_game()
	check(not f.service.show_interstitial_if_due(), "fullscreen failure cooldown prevents chained ads")
	f.service.advance(31)
	check(not f.service.show_interstitial_if_due(), "cooldown expiry cannot auto-open a consumed opportunity")
	f.service.record_completed_game()
	check(f.service.show_interstitial_if_due(), "next final game can retry an already due interstitial")
	f.backend.shown.emit("interstitial", token)
	check(f.service._completed_since_interstitial == 0, "SDK shown callback resets frequency counter")
	f.backend.closed.emit("interstitial", token)
	check(f.events.finishes.back() == {"kind": "interstitial", "earned": false}, "interstitial dismissal never grants reward")
	# The saved due frequency cannot trigger on a fresh launch.
	var due := await make_fixture("saved_due")
	for i in range(3): due.service.record_completed_game()
	var restarted := await make_fixture("saved_due_restart", due.service.storage_path)
	allow(restarted)
	complete_load(restarted, "interstitial")
	check(restarted.service._completed_since_interstitial == 3, "device-only frequency survives process restart")
	check(not restarted.service.show_interstitial_if_due() and restarted.backend.shows.is_empty(), "saved due counter still cannot show an ad at launch")
	restarted.service.record_completed_game()
	check(restarted.service.show_interstitial_if_due(), "first later completed game can use carried-over due frequency")
	# A cancelled rewarded attempt on game three cannot chain into interstitial.
	var chain := await make_fixture("no_chain")
	allow(chain)
	complete_load(chain, "interstitial")
	var reward := complete_load(chain, "rewarded")
	for i in range(2): chain.service.record_completed_game()
	check(chain.service.show_rewarded_continue(), "failed-continue chain fixture starts")
	chain.service.fullscreen_finished.connect(func(kind, _earned):
		if kind == "rewarded":
			chain.service.record_completed_game()
			chain.service.show_interstitial_if_due())
	chain.backend.closed.emit("rewarded", reward)
	check(chain.backend.shows.size() == 1 and chain.service._completed_since_interstitial == 3, "synchronous final-game callback preserves due count without back-to-back ads")
	var no_fill := await make_fixture("no_fill_due")
	allow(no_fill)
	for i in range(3): no_fill.service.record_completed_game()
	check(not no_fill.service.show_interstitial_if_due() and no_fill.service._completed_since_interstitial == 3, "no inventory is nonblocking and preserves due frequency")
	complete_load(no_fill, "interstitial")
	check(no_fill.backend.shows.is_empty(), "late inventory does not interrupt the result screen")

func test_privacy_and_lifecycle() -> void:
	var f := await make_fixture("privacy")
	allow(f, true)
	complete_load(f, "rewarded")
	check(f.service.show_privacy_options(), "required privacy options open explicitly")
	check(f.service.get_fullscreen_kind() == "privacy" and not f.service.is_rewarded_ready(), "privacy form suspends inventory and gameplay")
	var token: int = f.backend.privacy_calls.back()
	var requests: int = f.backend.requests.size()
	f.backend.allowed = false
	f.backend.privacy_completed.emit(token, false, true)
	check(f.service.get_fullscreen_kind().is_empty() and f.backend.requests.size() == requests, "withdrawal closes privacy UI without further ad requests")
	check(f.service.is_privacy_options_required(), "privacy entry remains accessible when SDK requires it")
	f.service.advance(61)
	check(f.backend.consent_calls.size() == 2, "denied privacy state can refresh later rather than becoming stuck")
	f.backend.allowed = true
	f.backend.consent_completed.emit(f.backend.consent_calls.back(), true, false)
	check(not f.service.is_privacy_options_required() and f.backend.init_calls.size() == 1, "reconsent restores requests without duplicate SDK initialization")
	check(not f.service.show_privacy_options(), "privacy entry is inactive when SDK does not require it")
	complete_load(f, "rewarded")
	f.service.set_app_active(false)
	check(not f.service.is_rewarded_ready() and not f.service.show_rewarded_continue(), "background never shows a rewarded ad")
	f.service.set_app_active(true)
	check(f.service.is_rewarded_ready(), "unexpired cached inventory survives backgrounding")
	var prior: int = f.backend.latest("rewarded")
	f.service.advance(3301)
	check(not f.service.is_rewarded_ready() and f.backend.latest("rewarded") != prior, "cached inventory expires before one hour and reloads")
	var load_token: int = f.backend.latest("rewarded")
	f.service.advance(31)
	check(not f.service._loads.has("rewarded"), "load watchdog removes a stuck request")
	f.backend.loaded.emit("rewarded", load_token, 0)
	check(not f.service.is_rewarded_ready(), "late timed-out inventory is discarded")
	var count: int = f.backend.count("rewarded")
	f.service.advance(29)
	check(f.backend.count("rewarded") == count, "failed load cannot spin retry requests")
	f.service.advance(2)
	check(f.backend.count("rewarded") == count + 1, "failed load retries only after its backoff")
	for i in range(2):
		var failed_token: int = f.backend.latest("rewarded")
		f.backend.load_failed.emit("rewarded", failed_token)
		var expected_delay := 60 if i == 0 else 300
		count = f.backend.count("rewarded")
		f.service.advance(expected_delay - 1)
		check(f.backend.count("rewarded") == count, "successive no-fill uses bounded exponential backoff")
		f.service.advance(2)
		check(f.backend.count("rewarded") == count + 1, "bounded retry eventually permits a new attempt")
	var rejected := await make_fixture("privacy_rejected")
	allow(rejected, true)
	rejected.backend.accept_privacy = false
	check(not rejected.service.show_privacy_options(), "unavailable privacy form is nonblocking")
	check(rejected.service.get_fullscreen_kind().is_empty() and rejected.events.finishes.size() == 1, "privacy show failure pairs fullscreen signals")
	rejected.service.advance(61)
	check(rejected.backend.consent_calls.size() == 2, "privacy show failure schedules a consent refresh")

func write_fixture(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_counter_files() -> void:
	var malformed_path := fixture_root.path_join("malformed.json")
	write_fixture(malformed_path, "not JSON")
	write_fixture(malformed_path + ".bak", '{"schema":1,"completed_since_interstitial":2}')
	var restored := await make_fixture("malformed", malformed_path)
	check(restored.service._completed_since_interstitial == 2, "valid backup restores a corrupt current counter")
	var invalid_path := fixture_root.path_join("invalid.json")
	write_fixture(invalid_path, '{"schema":1,"completed_since_interstitial":"infinite"}')
	var invalid := await make_fixture("invalid", invalid_path)
	check(invalid.service._completed_since_interstitial == 0, "malformed counter values default safely")
	for value: int in [-200, 2000000000]:
		var path := fixture_root.path_join("bounds_%s.json" % value)
		write_fixture(path, JSON.stringify({"schema": 1, "completed_since_interstitial": value}))
		var bounded := await make_fixture("bounds", path)
		check(bounded.service._completed_since_interstitial == clampi(value, 0, 3), "counter remains bounded to zero through three")
	var future_path := fixture_root.path_join("future.json")
	var future_text := '{"schema":2,"completed_since_interstitial":3,"unknown":"preserve"}'
	write_fixture(future_path, future_text)
	var future := await make_fixture("future", future_path)
	future.service.record_completed_game()
	check(FileAccess.get_file_as_string(future_path) == future_text, "future-schema frequency data is never overwritten")
	var oversized_path := fixture_root.path_join("oversized.json")
	write_fixture(oversized_path, " ".repeat(ADS.MAX_COUNTER_FILE + 1))
	var oversized := await make_fixture("oversized", oversized_path)
	check(oversized.service._completed_since_interstitial == 0, "oversized frequency file is rejected")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/admob.json"))
	check(config.app_id == "ca-app-pub-7719473349082950~3864825368" and config.test_mode == true, "supplied app ID is configured with test ads enabled")
	for kind: String in ["banner", "interstitial", "rewarded"]:
		check(config.ad_units[kind] == ADS.TEST_UNITS[kind] and config.production_ad_units[kind] == "", "no invented production unit for " + kind)

func test_native_boolean_values() -> void:
	for sample: Array in [[true, true], [false, false], [1, true], [0, false],
		[null, false], ["true", false], ["1", false], [2, false], [-1, false],
		[1.0, false], [0.0, false], [{}, false], [[], false]]:
		check(SDK_VALUES.sdk_boolean(sample[0]) == sample[1],
			"SDK boolean normalization rejects coercion for type %s value %s" % [typeof(sample[0]), str(sample[0])])

func _run() -> void:
	await test_consent()
	await test_banners()
	await test_rewarded()
	await test_interstitials()
	await test_privacy_and_lifecycle()
	await test_counter_files()
	test_native_boolean_values()
	for node: Node in fixtures:
		if is_instance_valid(node): node.free()
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
		# Let the audio server release its stopped playback before SceneTree exits.
		await create_timer(0.35).timeout
	await process_frame
	var report := {"checks": checks, "failures": failures, "passed": failures == 0,
		"mode": "headless deterministic injected fake backend; no live Google ads/consent",
		"fixture_root": fixture_root, "generated_at_utc": Time.get_datetime_string_from_system(true)}
	write_fixture("res://output/review/ads_service_validation.json", JSON.stringify(report, "\t"))
	print("Ad service: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
