"""Round-two touch checks on the explicitly owned workspace Android emulator.

Uses only the selected emulator/package. Fixture writes are confined to that
test installation, with its prior JSON profile preserved as local evidence.
No global ADB restart, SDK install, account sign-in or physical-device access.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import time
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True, type=Path)
    parser.add_argument("--serial", default="emulator-5580")
    parser.add_argument("--server-port", default=5038, type=int)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--layout", default=Path("output/review/ui_layouts.json"), type=Path)
    parser.add_argument("--output", default=Path("output/android-test/round2"), type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-\d+", args.serial):
        parser.error("Only an explicit test emulator is supported.")
    if not 1024 <= args.server_port <= 65535:
        parser.error("Invalid ADB server port.")
    args.output.mkdir(parents=True, exist_ok=True)
    package = "com.slash.game"
    events: list[dict] = []
    logs: list[str] = []

    def adb(*cmd: object, raw=False, payload: bytes | None = None, timeout=30):
        result = subprocess.run(
            [str(args.adb), "-P", str(args.server_port), "-s", args.serial, *map(str, cmd)],
            input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
        )
        if result.returncode:
            raise RuntimeError(f"ADB {cmd}: {result.stderr.decode(errors='replace')} {result.stdout.decode(errors='replace')}")
        return result.stdout if raw else result.stdout.decode(errors="replace").strip()

    def event(kind, **data):
        events.append({"event": kind, "time": time.time(), **data})
        (args.output / "events.json").write_text(json.dumps(events, indent=2), encoding="utf-8")

    def profile():
        return json.loads(adb("shell", "run-as", package, "cat", "files/infiniteslash_profile.json"))

    def screenshot(name):
        content = adb("exec-out", "screencap", "-p", raw=True)
        assert content.startswith(b"\x89PNG\r\n\x1a\n"), "Screenshot must be PNG"
        path = args.output / f"{name}.png"
        path.write_bytes(content)
        event("screenshot", name=name, path=str(path))

    def runtime_log():
        pid = adb("shell", "pidof", package).split()[0]
        return adb("shell", "logcat", "-d", "--pid", pid)

    def collect_log():
        logs.append(runtime_log())
        (args.output / "runtime.log").write_text("\n".join(logs), encoding="utf-8")

    def wait_overlay(overlay, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            states = re.findall(r"INFINITESLASH_UI\s+([a-z]+)", runtime_log())
            if states and states[-1] == overlay:
                event("overlay", name=overlay)
                time.sleep(.6)
                return
            time.sleep(.4)
        collect_log()
        raise RuntimeError(f"Did not enter {overlay}")

    def launch():
        adb("shell", "am", "force-stop", package)
        adb("logcat", "-c")
        component = package + "/com.godot.game.GodotApp"
        response = adb("shell", "am", "start", "-W", "-n", component, timeout=60)
        assert "Error" not in response, response
        event("launch", result=response)
        wait_overlay("launch", 60)

    def write_fixture(envelope):
        adb("shell", "am", "force-stop", package)
        serialized = json.dumps(envelope, separators=(",", ":")).encode("utf-8")
        # Shell syntax is fixed; the JSON arrives on stdin without interpolation.
        adb("shell", "run-as", package, "sh", "-c", "'cat > files/infiniteslash_profile.json'", payload=serialized)
        event("emulator_fixture_written", bytes=len(serialized))

    assert adb("get-state") == "device"
    assert adb("shell", "getprop", "sys.boot_completed") == "1"
    assert "InfiniteSlash_Test" in adb("emu", "avd", "name"), "Selected AVD is not owned by this project"
    if args.apk:
        result = adb("install", "-r", args.apk.resolve(), timeout=180)
        assert "Success" in result, result
        event("installed", apk=str(args.apk.resolve()))
    dims = re.findall(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
    width, height = map(int, dims[-1])
    event("device", serial=args.serial, width=width, height=height,
          api=adb("shell", "getprop", "ro.build.version.sdk"),
          page_size=adb("shell", "getconf", "PAGE_SIZE"))
    layouts = json.loads(args.layout.read_text(encoding="utf-8"))

    def tap(name, overlay, resume=False):
        candidates = [item for item in layouts if item["overlay"] == overlay and name in item["buttons"]
                      and (overlay != "launch" or item["can_resume"] == resume)]
        assert candidates, f"Missing measured touch rectangle {overlay}/{name}"
        layout = min(candidates, key=lambda item: abs(item["viewport"][1] / item["viewport"][0] - height / width))
        x, y, w, h = layout["buttons"][name]
        point = [round((x + w / 2) * width / layout["viewport"][0]),
                 round((y + h / 2) * height / layout["viewport"][1])]
        adb("shell", "input", "tap", *point)
        event("touch", button=name, point=point)
        time.sleep(.75)

    try:
        launch()
        original = profile()
        (args.output / "profile_before_test.json").write_text(json.dumps(original, indent=2), encoding="utf-8")
        has_resume = bool(original.get("active_run"))
        tap("SwordButton", "launch", has_resume)
        wait_overlay("running")
        tap("PauseButton", "")
        wait_overlay("pause")
        baseline = profile()
        assert baseline["active_run"]["damage"] == 32
        fixture = json.loads(json.dumps(baseline))
        active = fixture["active_run"]
        active.update(level=2, xp=0, xp_goal=15, elapsed=30, health=80,
                      upgrade_choices=["sharper_steel", "heart_of_a_knight"], upgrade_version=1,
                      upgrade_counts={}, next_boss=1000, spawn_timer=3, drops=[],
                      buffs={"haste": 9}, ward_hits=0)
        # A moving projectile makes an accidental background simulation visible.
        active["bullets"] = [{"pos": [75, 350], "vel": [30, 40], "damage": 2,
                              "life": 5, "boss": False, "radius": 5}]
        active["enemies"] = []
        write_fixture(fixture)
        launch()
        tap("ResumeButton", "launch", True)
        wait_overlay("upgrade")
        screenshot("01_two_upgrade_choices")
        before = profile()["active_run"]
        started = time.monotonic()
        time.sleep(11.25)
        adb("shell", "input", "keyevent", "4")
        wait_overlay("upgrade")
        adb("shell", "input", "swipe", width // 2, height * 3 // 4, width // 3, height * 2 // 3, 200)
        wait_overlay("upgrade")
        # Android Home triggers a fresh combat snapshot from live memory, so
        # this compares the real simulation rather than an older disk save.
        adb("shell", "input", "keyevent", "3")
        time.sleep(1)
        current = profile()["active_run"]
        for key in ["elapsed", "health", "score", "player", "bullets", "enemies", "buffs", "xp", "upgrade_choices"]:
            assert current[key] == before[key], f"Upgrade pause changed {key}: {before[key]} -> {current[key]}"
        event("upgrade_pause_verified", duration=time.monotonic() - started,
              checked_fields=["elapsed", "health", "score", "player", "bullets", "enemies", "buffs", "xp", "upgrade_choices"])
        collect_log()
        launch()
        tap("ResumeButton", "launch", True)
        wait_overlay("upgrade")
        tap("AudioSettingsButton", "upgrade")
        wait_overlay("audio")
        # Verify all four independent settings combinations by actual button taps.
        settings = profile()["profile"]["settings"]
        if not settings["music"]:
            tap("MusicToggle", "audio")
        if not settings["sfx"]:
            tap("SfxToggle", "audio")
        for action, expected in [(None, (True, True)), ("MusicToggle", (False, True)),
                                 ("SfxToggle", (False, False)), ("MusicToggle", (True, False))]:
            if action:
                tap(action, "audio")
            actual = profile()["profile"]["settings"]
            assert (actual["music"], actual["sfx"]) == expected, actual
            event("audio_combination_saved", music=actual["music"], sfx=actual["sfx"])
        screenshot("02_music_on_effects_off")
        tap("AudioBackButton", "audio")
        wait_overlay("upgrade")
        collect_log()
        launch()
        actual = profile()["profile"]["settings"]
        assert actual["music"] and not actual["sfx"], "Audio selection did not persist across process restart"
        tap("ResumeButton", "launch", True)
        wait_overlay("upgrade")
        screenshot("03_pending_choice_survives_restart")
        tap("UpgradeChoice1", "upgrade")
        wait_overlay("running")
        time.sleep(1.5)
        screenshot("04_larger_status_hud")
        tap("PauseButton", "")
        wait_overlay("pause")
        selected = profile()["active_run"]
        assert abs(selected["damage"] - 36.48) < .001, selected["damage"]
        assert selected["upgrade_choices"] == []
        assert selected["upgrade_counts"].get("sharper_steel") == 1
        assert selected["elapsed"] > 30.5, selected["elapsed"]
        assert selected["max_health"] == 80, "Unchosen reward was applied"
        event("choice_resumes_combat", damage=selected["damage"], elapsed=selected["elapsed"],
              upgrade_counts=selected["upgrade_counts"], max_health=selected["max_health"])
        screenshot("05_paused_after_choice")
        collect_log()
        boss_fixture = profile()
        boss_active = boss_fixture["active_run"]
        roster = json.loads(Path("data/monsters.json").read_text(encoding="utf-8"))
        monster_index = next(i for i, item in enumerate(roster) if item["id"] == "moon_mallow")
        boss_active.update(elapsed=90, level=2, xp=0, next_boss=1000,
                           spawn_timer=3, bullets=[], drops=[], buffs={})
        boss_active["enemies"] = [{"kind": monster_index, "pos": [270, 230], "hp": 600,
            "max_hp": 600, "radius": 35, "speed": 58, "damage": 12, "behavior": "boss",
            "boss": True, "minion": False, "alive": True, "age": 0, "cooldown": 1.8,
            "windup": 0, "charge": 0, "aim": [0, 1], "knock": [0, 0], "flash": 0,
            "phase": 0, "anim": 0, "last_slash": -1, "boss_id": "moonmallow_majesty"}]
        write_fixture(boss_fixture)
        launch()
        tap("ResumeButton", "launch", True)
        wait_overlay("running")
        time.sleep(1)
        screenshot("06_rare_boss_and_large_hud")
        tap("PauseButton", "")
        wait_overlay("pause")
        boss_snapshot = profile()["active_run"]
        bosses = [item for item in boss_snapshot["enemies"] if item["boss"]]
        assert bosses and bosses[0]["boss_id"] == "moonmallow_majesty"
        assert bosses[0]["boss_rare"] and bosses[0]["boss_name"] == "Moonmallow Majesty"
        assert boss_snapshot["elapsed"] > 90.5 and bosses[0]["age"] > 1.0, "The live boss snapshot was not saved"
        event("rare_boss_identity_restored_and_saved", boss=bosses[0]["boss_id"],
              pattern=bosses[0]["boss_pattern"], elapsed=boss_snapshot["elapsed"], age=bosses[0]["age"])
        collect_log()
        combined = "\n".join(logs)
        bad_lines = [line for line in combined.splitlines()
                     if re.search(r"SCRIPT ERROR|FATAL EXCEPTION|Fatal signal|ERROR:.*(?:godot|res://)|Active run contains unsupported|Progress snapshot is too large|Could not (?:write|finish saving|replace|keep) progress", line, re.I)]
        assert not bad_lines, "\n".join(bad_lines)
        event("round2_android_smoke_pass", runtime_errors=0, storage_failures_observed=0)
        print("ROUND2_ANDROID_SMOKE_PASS")
    except Exception as error:
        try:
            collect_log()
        except Exception:
            pass
        event("failed", error=str(error))
        raise


if __name__ == "__main__":
    main()
