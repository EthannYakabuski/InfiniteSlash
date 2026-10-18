"""Probe the real test-ad SDK on the project's isolated Android emulator.

No consent decision is fabricated. A required native form is captured for
observed interaction; an owner CMP configuration failure is reported distinctly
from missing native plugins or a broken JNI bridge. Original app JSON files are
restored even on failure. This does not sign in to Google Play Games.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
from zipfile import ZipFile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--serial", default="emulator-5582")
    parser.add_argument("--server-port", type=int, default=5038)
    parser.add_argument("--output", type=Path, default=Path("output/android-test/admob_0_4_0"))
    parser.add_argument("--skip-install", action="store_true")
    parser.add_argument("--exercise-gameplay", action="store_true", help="Use explicit saved-state fixtures to exercise real rewarded/interstitial callbacks")
    parser.add_argument("--placements-only", action="store_true", help="Capture actual top-pause and bottom-upgrade test banners using a saved-state fixture")
    args = parser.parse_args()
    assert not (args.exercise_gameplay and args.placements_only)
    assert re.fullmatch(r"emulator-\d+", args.serial)
    assert args.server_port != 5037, "Use the isolated test server"
    package = "com.slash.game"
    args.output.mkdir(parents=True, exist_ok=True)
    original: dict[str, bytes] = {}
    filenames = [base + suffix for base in ("infiniteslash_profile.json", "infiniteslash_ad_frequency.json")
                 for suffix in ("", ".bak", ".tmp")]
    events: list[dict] = []
    logs: dict[str, str] = {}
    result: dict = {"status": "RUNNING", "google_play_signed_in": False, "production_ad_units_requested": False}

    def adb(*command: object, raw: bool = False, payload: bytes | None = None, timeout: float = 30):
        response = subprocess.run([str(args.adb), "-P", str(args.server_port), "-s", args.serial, *map(str, command)],
                                  input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        if response.returncode:
            raise RuntimeError(f"ADB {command}: {response.stderr.decode(errors='replace')}")
        return response.stdout if raw else response.stdout.decode(errors="replace").strip()

    def event(kind: str, **details):
        events.append({"event": kind, "time": time.time(), **details})
        (args.output / "events.json").write_text(json.dumps(events, indent=2) + "\n", encoding="utf-8")

    def capture(name: str):
        pixels = adb("exec-out", "screencap", "-p", raw=True)
        assert pixels.startswith(b"\x89PNG\r\n\x1a\n")
        (args.output / f"{name}.png").write_bytes(pixels)
        event("capture", name=name)

    def runtime() -> str:
        pid = adb("shell", "pidof", package).split()[0]
        output = adb("shell", "logcat", "-d", "--pid", pid)
        logs[pid] = output
        (args.output / "runtime.log").write_text("\n".join(logs.values()), encoding="utf-8")
        return output

    def native_events(output: str) -> list[dict]:
        rows = []
        for line in output.splitlines():
            if "INFINITESLASH_ADS " not in line:
                continue
            try:
                rows.append(json.loads(line.split("INFINITESLASH_ADS ", 1)[1]))
            except json.JSONDecodeError:
                pass
        return rows

    def wait_for(predicate, label: str, timeout: float = 60):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            text = runtime()
            if predicate(text, native_events(text)):
                event("verified", label=label)
                time.sleep(.35)
                return
            time.sleep(.7)
        capture("timeout_" + label)
        raise AssertionError("Native wait timed out: " + label)

    def overlay(name: str):
        wait_for(lambda text, _: (re.findall(r"INFINITESLASH_UI\s+([a-z_]+)", text) or [""])[-1] == name, name)

    def tap(x: int, y: int):
        adb("shell", "input", "tap", x, y)
        time.sleep(.4)

    def profile() -> dict:
        return json.loads(adb("shell", "run-as", package, "cat", "files/infiniteslash_profile.json"))

    def start_app():
        adb("shell", "am", "force-stop", package)
        adb("logcat", "-c")
        adb("shell", "am", "start", "-W", "-n", package + "/com.godot.game.GodotApp", timeout=60)
        overlay("launch")

    def write_json(name: str, data: dict):
        adb("shell", "run-as", package, "sh", "-c", "'cat > files/" + name + "'", payload=json.dumps(data).encode())

    def loaded_all():
        wait_for(lambda _, items: {"banner", "rewarded", "interstitial"}.issubset(
            {item.get("kind") for item in items if item.get("event") == "loaded"}), "all_three_formats_loaded", 120)

    def ad_event(kind: str, format_name: str | None = None, timeout: float = 60):
        wait_for(lambda _, items: any(item.get("event") == kind and (format_name is None or item.get("kind") == format_name)
                                     for item in items), kind + ("_" + format_name if format_name else ""), timeout)

    def exercise_gameplay():
        # Coordinates are centers from the visually reviewed 540x1110 UI fixture,
        # scaled to this explicitly checked 1080x2220 owned device.
        assert "1080x2220" in adb("shell", "wm", "size")
        tap(298, 1272)
        overlay("running")
        adb("shell", "input", "keyevent", "4")
        overlay("pause")
        baseline = profile()
        baseline_runs = int(baseline["profile"]["total_runs"])
        fixture = copy.deepcopy(baseline)
        active = fixture["active_run"]
        active.update(level=12, xp=0, xp_goal=100, score=13337, kills=17, bosses=2, best_combo=23,
                      combo=0, health=1, guard_reserve=0, guard_regen_wait=2, guard_contact_cooldown=0,
                      player=[270, 740], next_boss=9999, spawn_timer=30, bullets=[], drops=[], hazards=[],
                      rewarded_continue_used=False, ad_death_pending=False, hurt_timer=0)
        monster = json.loads(Path("data/monsters.json").read_text(encoding="utf-8"))[0]
        active["enemies"] = [{"kind": 0, "monster_id": monster["id"], "pos": [270, 740], "hp": 100000,
                              "max_hp": 100000, "radius": 20, "speed": 10, "damage": 2,
                              "behavior": "chaser", "boss": False, "minion": False, "alive": True,
                              "age": 0, "cooldown": 10, "windup": 0, "charge": 0, "aim": [0, 1],
                              "knock": [0, 0], "flash": 0, "phase": 0, "anim": 0, "last_slash": -1}]
        adb("shell", "am", "force-stop", package)
        write_json("infiniteslash_profile.json", fixture)
        write_json("infiniteslash_ad_frequency.json", {"schema": 1, "completed_since_interstitial": 2})
        (args.output / "rewarded_death_fixture.json").write_text(json.dumps(fixture, indent=2), encoding="utf-8")
        start_app()
        loaded_all()
        capture("04_home_actual_test_banner")
        tap(540, 1144)
        overlay("continue")
        capture("05_actual_continue_offer")
        assert profile()["profile"]["total_runs"] == baseline_runs
        tap(540, 1272)
        ad_event("shown", "rewarded")
        capture("06_actual_rewarded_test_ad")
        print("ACTUAL_REWARDED_TEST_AD_VISIBLE", flush=True)
        ad_event("reward_earned", timeout=150)
        capture("07_reward_earned")
        print("REWARD_EARNED_READY_TO_CLOSE", flush=True)
        # This close center was observed on the real Google test endcard in
        # this exact 1080x2220 emulator. Never tap an ad's install/content area.
        time.sleep(2)
        tap(1015, 65)
        # Inspect the saved restoration immediately, before normal combat can
        # spend its guard. Waiting for multiple slow host/logcat calls first
        # can legitimately consume the 1.5 second return grace period.
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            restored = profile()["active_run"]
            if restored.get("rewarded_continue_used") is True and restored.get("ad_death_pending") is False:
                break
            time.sleep(.1)
        else:
            raise AssertionError("No earned restoration snapshot was persisted")
        assert restored["health"] == restored["max_health"] and restored["guard_reserve"] == restored["guard_capacity"]
        (args.output / "earned_restore_snapshot.json").write_text(json.dumps(restored, indent=2), encoding="utf-8")
        tap(986, 82)  # Actual HUD Pause is idempotent if focus already paused.
        ad_event("closed", "rewarded", 60)
        overlay("pause")
        continued = profile()
        resumed = continued["active_run"]
        for key in ("level", "score", "kills", "bosses", "best_combo", "damage", "attack_interval",
                    "attack_range", "move_speed", "max_health", "guard_capacity", "dash_recharge",
                    "guard_regen", "guard_delay", "lifesteal", "thorns", "execute_threshold", "combo_grace"):
            assert resumed[key] == active[key], "Rewarded continue changed " + key
        assert resumed["rewarded_continue_used"] is True and not resumed["ad_death_pending"]
        assert resumed["health"] > 0 and 0 <= resumed["guard_reserve"] <= resumed["guard_capacity"]
        assert continued["profile"]["total_runs"] == baseline_runs
        capture("08_continued_run_paused")
        result["actual_rewarded_continue_verified"] = True
        event("rewarded_continue_preserved_stats_and_run_count", score=resumed["score"], level=resumed["level"])

        # Resume the same consumed-continue run into a second death. The fixture
        # counter represents two earlier completions; this third completion must
        # show the real cached interstitial and reset its local cadence counter.
        resumed.update(health=1, guard_reserve=0, guard_regen_wait=2, hurt_timer=0, guard_contact_cooldown=0)
        resumed["enemies"] = copy.deepcopy(active["enemies"])
        adb("shell", "am", "force-stop", package)
        write_json("infiniteslash_profile.json", continued)
        start_app()
        loaded_all()
        tap(540, 1144)
        ad_event("shown", "interstitial")
        capture("09_actual_interstitial_test_ad")
        print("ACTUAL_INTERSTITIAL_TEST_AD_VISIBLE", flush=True)
        time.sleep(12)
        tap(1015, 65)  # Observed actual interstitial close button on this AVD.
        ad_event("closed", "interstitial", 60)
        overlay("end")
        final = profile()
        assert final["active_run"] == {} and final["profile"]["total_runs"] == baseline_runs + 1
        frequency = json.loads(adb("shell", "run-as", package, "cat", "files/infiniteslash_ad_frequency.json"))
        assert frequency["completed_since_interstitial"] == 0
        capture("10_final_results_no_fake_resume")
        result.update(actual_interstitial_verified=True, one_continue_per_run_verified=True,
                      final_completion_count=baseline_runs + 1, synthetic_saved_state_fixture=True)

    def exercise_without_inventory():
        """A real native consent refusal must leave combat/results usable."""
        assert "1080x2220" in adb("shell", "wm", "size")
        tap(298, 1272)
        overlay("running")
        adb("shell", "input", "keyevent", "4")
        overlay("pause")
        fixture = profile()
        baseline_runs = int(fixture["profile"]["total_runs"])
        active = fixture["active_run"]
        active.update(health=1, guard_reserve=0, guard_regen_wait=2, hurt_timer=0,
                      guard_contact_cooldown=0, player=[270, 740], next_boss=9999,
                      spawn_timer=30, bullets=[], drops=[], hazards=[],
                      rewarded_continue_used=False, ad_death_pending=False)
        monster = json.loads(Path("data/monsters.json").read_text(encoding="utf-8"))[0]
        active["enemies"] = [{"kind": 0, "monster_id": monster["id"], "pos": [270, 740], "hp": 100000,
                              "max_hp": 100000, "radius": 20, "speed": 10, "damage": 999,
                              "behavior": "chaser", "boss": False, "minion": False, "alive": True,
                              "age": 0, "cooldown": 10, "windup": 0, "charge": 0, "aim": [0, 1],
                              "knock": [0, 0], "flash": 0, "phase": 0, "anim": 0, "last_slash": -1}]
        capture("04_no_inventory_pause")
        adb("shell", "am", "force-stop", package)
        write_json("infiniteslash_profile.json", fixture)
        write_json("infiniteslash_ad_frequency.json", {"schema": 1, "completed_since_interstitial": 2})
        (args.output / "no_inventory_death_fixture.json").write_text(json.dumps(fixture, indent=2), encoding="utf-8")
        start_app()
        tap(540, 1066)
        overlay("end")
        final = profile()
        frequency = json.loads(adb("shell", "run-as", package, "cat", "files/infiniteslash_ad_frequency.json"))
        assert final["active_run"] == {} and final["profile"]["total_runs"] == baseline_runs + 1
        assert frequency["completed_since_interstitial"] == 3
        assert not any(item.get("event") in ("shown", "reward_earned", "initialized", "loaded")
                       for item in native_events(runtime()))
        capture("05_no_inventory_final_results")
        result.update(no_inventory_gameplay_verified=True, no_inventory_results_verified=True,
                      due_interstitial_retained=True, synthetic_saved_state_fixture=True)
        event("consent_blocked_gameplay_and_results_verified", completed_runs=baseline_runs + 1)

    def exercise_banner_placements():
        initial_banners = sum(item.get("event") == "loaded" and item.get("kind") == "banner"
                              for item in native_events(runtime()))
        tap(298, 1272)
        overlay("running")
        adb("shell", "input", "keyevent", "4")
        overlay("pause")
        wait_for(lambda _, items: sum(item.get("event") == "loaded" and item.get("kind") == "banner"
                                     for item in items) > initial_banners, "actual_pause_banner_loaded", 90)
        capture("11_pause_actual_top_test_banner")
        fixture = profile()
        active = fixture["active_run"]
        active.update(level=12, xp=0, xp_goal=100, enemies=[], bullets=[], drops=[], hazards=[],
                      next_boss=9999, spawn_timer=30, ad_death_pending=False, rewarded_continue_used=False,
                      upgrade_choices=["sharper_steel", "heart_of_a_knight"])
        active.update(health=active["max_health"], guard_reserve=active["guard_capacity"])
        adb("shell", "am", "force-stop", package)
        write_json("infiniteslash_profile.json", fixture)
        (args.output / "upgrade_banner_fixture.json").write_text(json.dumps(fixture, indent=2), encoding="utf-8")
        start_app()
        loaded_all()
        initial_banners = sum(item.get("event") == "loaded" and item.get("kind") == "banner"
                              for item in native_events(runtime()))
        tap(540, 1144)
        overlay("upgrade")
        wait_for(lambda _, items: sum(item.get("event") == "loaded" and item.get("kind") == "banner"
                                     for item in items) > initial_banners, "actual_upgrade_banner_loaded", 90)
        capture("12_upgrade_actual_bottom_test_banner")
        result.update(actual_pause_top_banner_verified=True, actual_upgrade_bottom_banner_verified=True,
                      synthetic_saved_state_fixture=True)
        event("native_test_banner_placements_verified")

    with ZipFile(args.apk) as archive:
        config = json.loads(archive.read(next(name for name in archive.namelist() if name.endswith("assets/config/admob.json"))))
    assert config["test_mode"] is True
    assert config["ad_units"] == {"banner": "ca-app-pub-3940256099942544/6300978111",
                                  "interstitial": "ca-app-pub-3940256099942544/1033173712",
                                  "rewarded": "ca-app-pub-3940256099942544/5224354917"}
    assert not any(config["production_ad_units"].values())
    assert adb("get-state") == "device" and adb("shell", "getprop", "sys.boot_completed") == "1"
    # The restricted host process may not open the emulator console socket;
    # its guest identity is still available through the private ADB transport.
    avd_name = adb("emu", "avd", "name").splitlines()
    if "InfiniteSlash_PGS" not in avd_name:
        assert adb("shell", "getprop", "ro.kernel.qemu.avd_name") == "InfiniteSlash_PGS"
    accounts = re.findall(r"Accounts:\s*(\d+)", adb("shell", "dumpsys", "account"))
    assert accounts and all(int(count) == 0 for count in accounts), "Use an account-free AVD for synthetic gameplay fixtures"
    adb("shell", "am", "force-stop", package)
    for name in filenames:
        try:
            original[name] = adb("shell", "run-as", package, "cat", "files/" + name, raw=True)
            (args.output / ("before_" + name)).write_bytes(original[name])
        except RuntimeError:
            pass
    (args.output / "original_files.json").write_text(json.dumps({name: {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                                                                 for name, data in original.items()}, indent=2), encoding="utf-8")
    try:
        apk_hash = hashlib.sha256(args.apk.read_bytes()).hexdigest()
        if args.skip_install:
            path = next(line.removeprefix("package:") for line in adb("shell", "pm", "path", package).splitlines() if line.startswith("package:"))
            assert re.fullmatch(r"/data/app/[A-Za-z0-9_./~+=-]+/base\.apk", path)
            assert adb("shell", "sha256sum", path).split()[0] == apk_hash
        else:
            assert "Success" in adb("install", "-r", args.apk.resolve(), timeout=240)
        metadata = adb("shell", "dumpsys", "package", package)
        assert "versionCode=10" in metadata and "versionName=0.4.0" in metadata
        event("installed_verified", sha256=apk_hash, app_id=config["app_id"])
        adb("logcat", "-c")
        adb("shell", "am", "start", "-W", "-n", package + "/com.godot.game.GodotApp", timeout=60)
        started = time.monotonic()
        latest: list[dict] = []
        captures = 0
        while time.monotonic() - started < 120:
            text = runtime()
            latest = native_events(text)
            elapsed = time.monotonic() - started
            if elapsed > 8 and captures == 0:
                capture("01_native_startup")
                captures += 1
                print("ADMOB_NATIVE_STARTUP_CAPTURE_READY", flush=True)
            if elapsed > 22 and captures == 1:
                capture("02_native_consent_or_inventory")
                captures += 1
                print("ADMOB_NATIVE_CONSENT_CAPTURE_READY", flush=True)
            failures = [item for item in latest if item.get("event") == "consent_bridge_unavailable"]
            assert not failures, f"Native consent bridge failed: {failures}"
            loaded = {item.get("kind") for item in latest if item.get("event") == "loaded"}
            getter = [item for item in latest if item.get("event") == "consent_getter"]
            if {"banner", "interstitial", "rewarded"}.issubset(loaded) and getter:
                result["status"] = "ALL_THREE_TEST_FORMATS_LOADED"
                break
            if elapsed > 40 and any(item.get("event") == "consent_completed" and item.get("allowed") is False for item in latest):
                result["status"] = "CONSENT_BLOCKED_NO_AD_REQUESTS"
                break
            time.sleep(1)
        else:
            result["status"] = "NATIVE_INVENTORY_NOT_FULLY_AVAILABLE"
        text = runtime()
        assert any(item.get("event") == "backend" and item.get("available") is True for item in latest), "Native plugin registration failed"
        getters = [item for item in latest if item.get("event") == "consent_getter" and item.get("bridge") == "jni"]
        assert getters, "Real UMP JNI getter was not confirmed"
        assert not re.search(r"SCRIPT ERROR|FATAL EXCEPTION|Fatal signal", text), "Runtime error; see log"
        assert "GodotPlayGameServices plugin initialized successfully" in text
        result.update(native_getter=getters[-1], native_events=latest,
                      api=adb("shell", "getprop", "ro.build.version.sdk"), page_size=adb("shell", "getconf", "PAGE_SIZE"),
                      apk_sha256=apk_hash, prior_files_preserved=True,
                      all_three_sdk_formats_loaded=result["status"] == "ALL_THREE_TEST_FORMATS_LOADED",
                      owner_cmp_forms_missing="no form(s) configured for the input app ID" in text)
        capture("03_native_probe_result")
        if args.exercise_gameplay and result["status"] == "ALL_THREE_TEST_FORMATS_LOADED":
            exercise_gameplay()
        elif args.exercise_gameplay and result["status"] == "CONSENT_BLOCKED_NO_AD_REQUESTS":
            exercise_without_inventory()
        elif args.placements_only:
            assert result["status"] == "ALL_THREE_TEST_FORMATS_LOADED", "Native banner inventory is unavailable"
            exercise_banner_placements()
        text = "\n".join(logs.values())
        assert not re.search(r"SCRIPT ERROR|FATAL EXCEPTION|Fatal signal", text), "Runtime error during ad gameplay"
        event("native_probe_completed", status=result["status"])
        print("ADMOB_ANDROID_PROBE " + json.dumps(result), flush=True)
    except Exception as error:
        result.update(status="FAILED", error=str(error))
        try:
            runtime()
            capture("native_failure")
        except Exception:
            pass
        raise
    finally:
        adb("shell", "am", "force-stop", package)
        for name in filenames:
            if name in original:
                adb("shell", "run-as", package, "sh", "-c", "'cat > files/" + name + "'", payload=original[name])
                assert adb("shell", "run-as", package, "cat", "files/" + name, raw=True) == original[name]
            else:
                adb("shell", "run-as", package, "rm", "-f", "files/" + name)
        result["original_profile_and_frequency_restored"] = True
        (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        event("original_files_restored", files=list(original))


if __name__ == "__main__":
    main()
