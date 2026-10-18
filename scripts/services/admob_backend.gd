extends Node
## Android-only adapter for the installed Poing v5.1.0 / GMA Next-Gen SDK.
## The service lazily loads this file on Android, avoiding editor mock ads.

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

const PLUGINS := ["PoingGodotAdMob", "PoingGodotAdMobAdView", "PoingGodotAdMobInterstitialAd",
	"PoingGodotAdMobRewardedAd", "PoingGodotAdMobConsentInformation", "PoingGodotAdMobUserMessagingPlatform"]
const SDK_VALUES := preload("res://scripts/services/ads_sdk_values.gd")
var _alive := true
var _foreground := true
var _consent_busy := false
var _consent_token := 0
var _consent_operation_token := 0
var _pending_form: ConsentForm
var _privacy_token := 0
var _initializing := false
var _initialized := false
var _initialize_token := 0
var _initialization_listener: OnInitializationCompleteListener
var _loading: Dictionary = {}
var _ads: Dictionary = {}
var _java_ump: Object
var _java_info: Object
var _diagnostics := false
var _last_bridge_result := ""

func set_diagnostics_enabled(enabled: bool) -> void:
	_diagnostics = enabled

func _bridge_error(reason: String) -> bool:
	if _diagnostics and _last_bridge_result != reason:
		print("INFINITESLASH_ADS ", JSON.stringify({"event": "consent_bridge_unavailable", "reason": reason}))
	_last_bridge_result = reason
	return false

func _sdk_permission(allowed: bool, bridge: String) -> bool:
	var result := bridge + str(allowed)
	if _diagnostics and _last_bridge_result != result:
		print("INFINITESLASH_ADS ", JSON.stringify({"event": "consent_getter", "bridge": bridge, "allowed": allowed}))
	_last_bridge_result = result
	return allowed

func is_available() -> bool:
	if OS.get_name() != "Android": return false
	for name: String in PLUGINS:
		if not Engine.has_singleton(name): return false
	return true

func set_app_active(active: bool) -> void:
	_foreground = active
	if active and _pending_form != null: _show_pending_form()

func can_request_ads() -> bool:
	if not _alive or not is_available(): return false
	var native := Engine.get_singleton("PoingGodotAdMobConsentInformation")
	if native.has_method("can_request_ads"): return _sdk_permission(SDK_VALUES.sdk_boolean(native.can_request_ads()), "native")
	# v5.1's GDScript wrapper omits this authoritative UMP getter. Call the
	# public SDK API via Godot's official JNI bridge, never cached consent text.
	if not Engine.has_singleton("JavaClassWrapper") or not Engine.has_singleton("AndroidRuntime"): return _bridge_error("runtime_unavailable")
	var java := Engine.get_singleton("JavaClassWrapper")
	if _java_ump == null:
		_java_ump = java.wrap("com.google.android.ump.UserMessagingPlatform")
		if java.get_exception() != null or _java_ump == null:
			_java_ump = null
			return _bridge_error("ump_class_unavailable")
	if _java_info == null:
		var runtime := Engine.get_singleton("AndroidRuntime")
		var activity: Variant = runtime.getActivity()
		if java.get_exception() != null or activity == null: return _bridge_error("activity_unavailable")
		_java_info = _java_ump.getConsentInformation(activity)
		if java.get_exception() != null or _java_info == null:
			_java_info = null
			return _bridge_error("consent_information_unavailable")
	var allowed: Variant = _java_info.canRequestAds()
	if java.get_exception() != null: return _bridge_error("can_request_ads_exception")
	return _sdk_permission(SDK_VALUES.sdk_boolean(allowed), "jni")

func _privacy_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func begin_consent(token: int) -> bool:
	if not _alive or not is_available() or _consent_busy or _privacy_token != 0: return false
	_consent_busy = true
	_consent_token = token
	_consent_operation_token = token
	var parameters := ConsentRequestParameters.new()
	parameters.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(parameters,
		func(): _consent_updated(token), func(_error): _complete_consent(token))
	return true

func _consent_updated(token: int) -> void:
	if not _alive or token != _consent_operation_token: return
	if token != _consent_token:
		_complete_consent(token)
		return
	var information := UserMessagingPlatform.consent_information
	if information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(func(form): _form_loaded(token, form), func(_error): _complete_consent(token))
	else:
		_complete_consent(token)

func _form_loaded(token: int, form: ConsentForm) -> void:
	if not _alive or token != _consent_operation_token: return
	if token != _consent_token:
		_complete_consent(token)
		return
	_pending_form = form
	if _foreground: _show_pending_form()

func _show_pending_form() -> void:
	if not _alive or _pending_form == null or _consent_token == 0: return
	var form := _pending_form
	var token := _consent_token
	_pending_form = null
	form_started.emit(token, "consent")
	form.show(func(_error): _complete_consent(token))

func _complete_consent(token: int) -> void:
	if token != _consent_operation_token: return
	_consent_operation_token = 0
	_consent_busy = false
	_pending_form = null
	if not _alive or token != _consent_token: return
	_consent_token = 0
	consent_completed.emit(token, can_request_ads(), _privacy_required())

func cancel_consent(token: int) -> void:
	if token != _consent_token: return
	_consent_token = 0
	# Info/form loader callbacks are untagged in the plugin. Keep the in-flight
	# operation serialized until its callback; do not launch overlapping requests.
	if _pending_form != null:
		_pending_form = null
		_consent_busy = false
		_consent_operation_token = 0

func show_privacy(token: int) -> bool:
	if not _alive or not is_available() or not _foreground or _consent_busy or _privacy_token != 0: return false
	_privacy_token = token
	UserMessagingPlatform.show_privacy_options_form(func(_error):
		if not _alive or _privacy_token != token: return
		_privacy_token = 0
		privacy_completed.emit(token, can_request_ads(), _privacy_required()))
	return true

func initialize_ads(token: int, _configuration: Dictionary) -> bool:
	if not can_request_ads(): return false
	if _initialized:
		initialized.emit.call_deferred(token)
		return true
	if _initializing: return false
	_initializing = true
	_initialize_token = token
	var request_configuration := RequestConfiguration.new()
	request_configuration.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	request_configuration.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	request_configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_UNSPECIFIED
	MobileAds.set_request_configuration(request_configuration)
	_initialization_listener = OnInitializationCompleteListener.new()
	_initialization_listener.on_initialization_complete = func(_status):
		_initializing = false
		_initialized = true
		if _alive: initialized.emit(_initialize_token)
	MobileAds.initialize(_initialization_listener)
	return true

func load_ad(kind: String, unit: String, token: int, placement: String) -> bool:
	if not _alive or not _initialized or not _foreground or not can_request_ads() or _loading.has(kind) or _ads.has(kind): return false
	if kind == "banner":
		var banner := AdView.new(unit, AdSize.BANNER, AdPosition.BOTTOM if placement == "upgrade" else AdPosition.TOP)
		banner.hide()
		_ads[kind] = {"token": token, "object": banner}
		_loading[kind] = {"token": token, "object": banner, "abandoned": false}
		banner.ad_listener.on_ad_loaded = func(): _banner_loaded(token)
		banner.ad_listener.on_ad_failed_to_load = func(_error): _failed(kind, token)
		banner.load_ad(AdRequest.new())
		return true
	if kind == "rewarded":
		var loader := RewardedAdLoader.new()
		var callback := RewardedAdLoadCallback.new()
		_loading[kind] = {"token": token, "object": loader, "abandoned": false}
		callback.on_ad_loaded = func(ad): _full_ad_loaded(kind, token, ad)
		callback.on_ad_failed_to_load = func(_error): _failed(kind, token)
		loader.load(unit, AdRequest.new(), callback)
		return true
	if kind == "interstitial":
		var loader := InterstitialAdLoader.new()
		var callback := InterstitialAdLoadCallback.new()
		_loading[kind] = {"token": token, "object": loader, "abandoned": false}
		callback.on_ad_loaded = func(ad): _full_ad_loaded(kind, token, ad)
		callback.on_ad_failed_to_load = func(_error): _failed(kind, token)
		loader.load(unit, AdRequest.new(), callback)
		return true
	return false

func _disconnect_vendor(object: Object) -> void:
	# Vendor destroy() removes native inventory, but its wrappers leave signal
	# connections behind. Detach only this instance to bound long-run listeners.
	for name: String in PLUGINS:
		if not Engine.has_singleton(name): continue
		var plugin := Engine.get_singleton(name)
		for entry: Dictionary in plugin.get_signal_list():
			for connection: Dictionary in plugin.get_signal_connection_list(entry.name):
				var callback: Callable = connection.callable
				if callback.get_object() == object: plugin.disconnect(entry.name, callback)

func _release_loader(kind: String) -> void:
	if not _loading.has(kind): return
	_disconnect_vendor(_loading[kind].object)
	_loading.erase(kind)

func _banner_loaded(token: int) -> void:
	if not _alive or not _ads.has("banner") or int(_ads.banner.token) != token: return
	if not _loading.has("banner") or int(_loading.banner.token) != token: return
	_loading.erase("banner")
	loaded.emit("banner", token, float(_ads.banner.object.get_height_in_pixels()))

func _full_ad_loaded(kind: String, token: int, ad: Object) -> void:
	if _ads.has(kind) and int(_ads[kind].token) == token:
		if ad != _ads[kind].object: _disconnect_vendor(ad)
		return
	var expected := _loading.has(kind) and int(_loading[kind].token) == token and not bool(_loading[kind].abandoned)
	if _loading.has(kind) and int(_loading[kind].token) == token: _release_loader(kind)
	if not _alive or not expected or not can_request_ads():
		ad.destroy()
		_disconnect_vendor(ad)
		return
	_ads[kind] = {"token": token, "object": ad}
	var callback := FullScreenContentCallback.new()
	callback.on_ad_showed_full_screen_content = func():
		if _alive: shown.emit(kind, token)
	callback.on_ad_dismissed_full_screen_content = func():
		if _alive: closed.emit(kind, token)
	callback.on_ad_failed_to_show_full_screen_content = func(_error):
		if _alive: show_failed.emit(kind, token)
	ad.full_screen_content_callback = callback
	loaded.emit(kind, token, 0.0)

func _failed(kind: String, token: int) -> void:
	if not _loading.has(kind) or int(_loading[kind].token) != token: return
	var abandoned: bool = _loading[kind].abandoned
	_release_loader(kind)
	if _alive and not abandoned: load_failed.emit(kind, token)

func show_banner(token: int) -> void:
	if _alive and _foreground and can_request_ads() and _ads.has("banner") and int(_ads.banner.token) == token:
		_ads.banner.object.show()

func show_ad(kind: String, token: int) -> bool:
	if not _alive or not _foreground or not can_request_ads() or not _ads.has(kind) or int(_ads[kind].token) != token: return false
	var ad: Object = _ads[kind].object
	if kind == "rewarded":
		var listener := OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item):
			if _alive: reward_earned.emit(token)
		ad.show(listener)
	else:
		ad.show()
	return true

func discard(kind: String, token: int) -> void:
	if _loading.has(kind) and int(_loading[kind].token) == token:
		if kind == "banner": _loading.erase(kind)
		else: _loading[kind].abandoned = true
	if not _ads.has(kind) or int(_ads[kind].token) != token: return
	var ad: Object = _ads[kind].object
	_ads.erase(kind)
	ad.destroy()
	_disconnect_vendor(ad)

func shutdown() -> void:
	_alive = false
	for kind: String in _ads.keys(): discard(kind, int(_ads[kind].token))
	for kind: String in _loading.keys(): _loading[kind].abandoned = true
	_pending_form = null
	_java_info = null
	_java_ump = null
