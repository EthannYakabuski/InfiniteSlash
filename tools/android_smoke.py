"""Functional Android checks on an explicitly selected emulator, with screenshots.

No SDK installation, device data wipe, global ADB restart, or other-device command.
Run ui_layout_test.gd first to supply measured Godot Control button rectangles.
"""
from __future__ import annotations

import argparse
import io
import json
import re
import subprocess
import time
from pathlib import Path

from PIL import Image


# Deliberate test oracle: fresh choices must use the contrasting class health.
# Keep this explicit rather than reading the implementation under test.
STARTING_CLASSES = {
    "sword": {"max_health": 80, "damage": 32, "attack_interval": .36,
              "attack_range": 92, "guard_capacity": 65},
    "shield": {"max_health": 170, "damage": 24, "attack_interval": .60,
               "attack_range": 80, "guard_capacity": 165},
}
CURRENT_BALANCE_VERSION = 3


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True, type=Path)
    parser.add_argument("--serial", default="emulator-5580")
    parser.add_argument("--apk", type=Path, help="Optionally install/update this debug APK")
    parser.add_argument("--package", default="org.infiniteslash.game")
    parser.add_argument("--layout", type=Path, default=Path("output/review/ui_layouts.json"))
    parser.add_argument("--output", type=Path, default=Path("output/android-test/smoke"))
    parser.add_argument("--quick", action="store_true", help="Recheck latest APK launch, shield choice and Android Back only")
    parser.add_argument("--verify-shield-resume-buff", action="store_true",
                        help="Resume the retained version-two Shield18 fixture and verify its damage-only migration")
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-\d+", args.serial):
        parser.error("This automated smoke script is restricted to a named emulator.")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_.]+", args.package):
        parser.error("Invalid Android package name.")
    args.output.mkdir(parents=True, exist_ok=True)
    events: list[dict] = []
    all_logs: list[str] = []

    def adb(*command: object, binary: bool = False, timeout: float = 30):
        result = subprocess.run(
            [str(args.adb), "-s", args.serial, *(str(item) for item in command)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, check=False,
        )
        if result.returncode:
            error = result.stderr.decode("utf-8", errors="replace")
            output = result.stdout.decode("utf-8", errors="replace")
            raise RuntimeError(f"ADB {' '.join(str(item) for item in command)} failed (exit{result.returncode}): {(error or output).strip()}")
        return result.stdout if binary else result.stdout.decode("utf-8", errors="replace").strip()

    def event(kind: str, **details):
        events.append({"event": kind, "wall_time": time.time(), **details})
        (args.output / "events.json").write_text(json.dumps(events, indent=2), encoding="utf-8")

    def capture(name: str):
        target = args.output / f"{name}.png"
        payload = adb("exec-out", "screencap", "-p", binary=True)
        if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Emulator screenshot did not return a PNG.")
        target.write_bytes(payload)
        event("screenshot", name=name, path=str(target))

    def read_active() -> dict:
        files = adb("shell", "run-as", args.package, "ls", "files")
        if "infiniteslash_profile.json" not in files.splitlines():
            return {}
        envelope = json.loads(adb("shell", "run-as", args.package, "cat", "files/infiniteslash_profile.json"))
        return envelope.get("active_run", {})

    def collect_logs():
        pid = adb("shell", "pidof", args.package).split()[0]
        all_logs.append(adb("shell", "logcat", "-d", "--pid", pid, timeout=30))
        (args.output / "godot.log").write_text("\n".join(all_logs), encoding="utf-8")

    def wait_overlay(expected: str):
        deadline = time.monotonic() + 18
        while time.monotonic() < deadline:
            pid = adb("shell", "pidof", args.package).split()[0]
            text = adb("shell", "logcat", "-d", "--pid", pid, timeout=30)
            states = re.findall(r"INFINITESLASH_UI\s+([a-z]+)", text)
            if states and states[-1] == expected:
                event("ui_state_verified", state=expected, pid=pid)
                time.sleep(.7)
                return
            time.sleep(.3)
        collect_logs()
        raise RuntimeError(f"Actual Android UI did not enter {expected}.")

    try:
        ready = False
        for _ in range(15):
            try:
                ready = adb("get-state") == "device" and adb("shell", "getprop", "sys.boot_completed") == "1"
            except RuntimeError:
                ready = False
            if ready:
                break
            time.sleep(1)
        if not ready:
            raise RuntimeError("Selected emulator is not fully booted.")
        if args.apk:
            if not args.apk.is_file():
                raise FileNotFoundError(args.apk)
            install = adb("install", "-r", args.apk.resolve(), timeout=120)
            if "Success" not in install:
                raise RuntimeError(f"APK installation failed: {install}")
            event("installed", apk=str(args.apk.resolve()), result=install)
        dimensions = re.findall(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
        if not dimensions:
            raise RuntimeError("Could not determine the emulator display size.")
        width, height = map(int, dimensions[-1])
        layouts = json.loads(args.layout.read_text(encoding="utf-8"))
        event("device", serial=args.serial, width=width, height=height,
              api=adb("shell", "getprop", "ro.build.version.sdk"),
              abi=adb("shell", "getprop", "ro.product.cpu.abilist"))

        def tap_button(name: str, overlay: str, can_resume: bool = False):
            candidates = [layout for layout in layouts
                          if layout["overlay"] == overlay and name in layout["buttons"]
                          and (overlay != "launch" or layout["can_resume"] == can_resume)]
            if not candidates:
                raise RuntimeError(f"No measured {overlay}/{name} layout in {args.layout}")
            layout = min(candidates, key=lambda item: abs(item["viewport"][1] / item["viewport"][0] - height / width))
            x, y, button_width, button_height = layout["buttons"][name]
            point = (round((x + button_width / 2) * width / layout["viewport"][0]),
                     round((y + button_height / 2) * height / layout["viewport"][1]))
            adb("shell", "input", "tap", *point)
            event("tap", button=name, overlay=overlay, point=point)
            expected = {
                "SwordButton": "running", "ShieldButton": "running", "ResumeButton": "running",
                "PauseButton": "pause", "LeaderboardButton": "scores", "AchievementsButton": "achievements",
                "ScoresBackButton": "pause", "AchievementsBackButton": "pause",
            }.get(name)
            if expected:
                wait_overlay(expected)
            else:
                time.sleep(.7)

        def start_app():
            activity = adb("shell", "cmd", "package", "resolve-activity", "--brief", args.package)
            component = next((line.strip() for line in reversed(activity.splitlines()) if "/" in line), "")
            if not component:
                raise RuntimeError(f"Package has no launch activity: {activity}")
            result = adb("shell", "am", "start", "-W", "-n", component, timeout=60)
            if "Error" in result:
                raise RuntimeError(result)
            event("launch", component=component, result=result)
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                frame = adb("exec-out", "screencap", "-p", binary=True)
                extrema = Image.open(io.BytesIO(frame)).convert("RGB").getextrema()
                if max(high - low for low, high in extrema) > 45:
                    event("rendered_frame_ready")
                    time.sleep(.5)
                    return
                time.sleep(1)
            collect_logs()
            raise RuntimeError("Application stayed on a uniform blank startup screen for45seconds.")

        def verify_fresh_style(expected_style: str) -> dict:
            active = read_active()
            expected = STARTING_CLASSES[expected_style]
            if active.get("style") != expected_style:
                raise RuntimeError(f"{expected_style.title()} choice started {active.get('style')}.")
            for key, value in expected.items():
                actual = active.get(key)
                if not isinstance(actual, (int, float)) or abs(actual - value) > .0001:
                    raise RuntimeError(f"Fresh {expected_style} {key} should be {value}, received {actual}.")
            if active.get("balance_version") != CURRENT_BALANCE_VERSION:
                raise RuntimeError(f"Fresh class snapshot did not record balance version {CURRENT_BALANCE_VERSION}.")
            event("fresh_class_verified", style=expected_style, max_health=active["max_health"],
                  damage=active.get("damage"), attack_interval=active.get("attack_interval"),
                  attack_range=active.get("attack_range"), guard_capacity=active.get("guard_capacity"),
                  balance_version=active.get("balance_version"))
            return active

        start_app()
        capture("01_launch")
        # A first install has no recoverable run. Existing profiles may show Resume;
        # the Sword button remains in both layouts, but its position differs.
        has_resume = bool(read_active())
        legacy = read_active()
        if args.verify_shield_resume_buff:
            if not legacy or legacy.get("style") != "shield" or legacy.get("balance_version") != 2 or legacy.get("damage") != 18:
                raise RuntimeError("Damage-only resume check requires the retained version-two Shield18 run.")
            tap_button("ResumeButton", "launch", True)
            tap_button("PauseButton", "")
            migrated = verify_fresh_style("shield")
            untouched = ["max_health", "attack_interval", "attack_range", "guard_capacity", "style", "seed", "level"]
            for key in untouched:
                if migrated.get(key) != legacy.get(key):
                    raise RuntimeError(f"Shield damage update changed saved {key}.")
            if migrated.get("score", 0) < legacy.get("score", 0) or migrated.get("elapsed", 0) < legacy.get("elapsed", 0):
                raise RuntimeError("Shield damage update restarted run progress.")
            event("shield_saved_damage_updated", old_damage=legacy["damage"], damage=migrated["damage"],
                  balance_version=migrated["balance_version"], preserved_stats={key: migrated.get(key) for key in untouched},
                  old_elapsed=legacy["elapsed"], elapsed=migrated["elapsed"])
            capture("00_saved_shield_buff_pause")
            collect_logs()
            adb("shell", "am", "force-stop", args.package)
            start_app()
            capture("00_resume_after_damage_buff")
            persisted = read_active()
            if persisted.get("damage") != 24 or persisted.get("balance_version") != CURRENT_BALANCE_VERSION:
                raise RuntimeError("Migrated Shield damage/version did not persist across process restart.")
            has_resume = bool(persisted)
        # The retained emulator fixture has a level-one run from the original MVP.
        # Exercise its real upgrade before replacing it with either fresh choice.
        if not args.quick and legacy and legacy.get("balance_version", 1) < 2 and legacy.get("level") == 1:
            tap_button("ResumeButton", "launch", True)
            tap_button("PauseButton", "")
            migrated = verify_fresh_style(legacy["style"])
            for key in ("style", "seed"):
                if migrated.get(key) != legacy.get(key):
                    raise RuntimeError(f"Legacy migration reset {key}.")
            if migrated.get("score", 0) < legacy.get("score", 0) or migrated.get("elapsed", 0) < legacy.get("elapsed", 0):
                raise RuntimeError("Legacy migration restarted run progress.")
            event("legacy_run_migrated", style=migrated["style"], old_max_health=legacy["max_health"],
                  new_max_health=migrated["max_health"], balance_version=migrated["balance_version"],
                  old_elapsed=legacy["elapsed"], elapsed=migrated["elapsed"], preserved_seed=migrated.get("seed"))
            capture("00_legacy_migrated_pause")
            collect_logs()
            adb("shell", "am", "force-stop", args.package)
            start_app()
            capture("00_migrated_resume_launch")
            has_resume = bool(read_active())
        if args.quick:
            tap_button("ShieldButton", "launch", has_resume)
            shield = verify_fresh_style("shield")
            event("shield_started", max_health=shield["max_health"])
            capture("02_quick_shield")
            adb("shell", "input", "keyevent", "KEYCODE_BACK")
            wait_overlay("pause")
            capture("03_quick_back_pause")
            collect_logs()
            bad_lines = [line for line in "\n".join(all_logs).splitlines()
                         if "SCRIPT ERROR" in line or "FATAL EXCEPTION" in line or "Fatal signal" in line
                         or ("E godot" in line and "ERROR:" in line)]
            if bad_lines:
                raise RuntimeError("Latest APK runtime errors: " + "\n".join(bad_lines[:8]))
            event("completed", mode="quick", runtime_errors=0,
                  note="Latest APK launch/style/Android Back follow-up; preceding full suite remains separate evidence.")
            print(f"ANDROID_QUICK_CAPTURED: {args.output.resolve()}")
            return 0
        tap_button("SwordButton", "launch", has_resume)
        initial = verify_fresh_style("sword")
        event("sword_started", max_health=initial["max_health"], player=initial["player"])
        time.sleep(2)
        capture("02_sword_action")
        adb("shell", "input", "swipe", round(width * .47), round(height * .77),
            round(width * .70), round(height * .62), "850")
        event("drag", duration_ms=850)
        adb("shell", "input", "swipe", round(width * .55), round(height * .78),
            round(width * .80), round(height * .70), "100")
        event("flick", duration_ms=100)
        time.sleep(1)
        capture("03_drag_guard_dash")
        tap_button("PauseButton", "")
        paused = read_active()
        if not paused or paused.get("elapsed", 0) <= 0:
            raise RuntimeError("Pause did not persist a running game.")
        movement = sum((a - b) ** 2 for a, b in zip(initial["player"], paused["player"])) ** .5
        if movement < 20:
            raise RuntimeError("The actual Android drag did not move the knight.")
        event("touch_movement_verified", distance=movement, player=paused["player"])
        capture("04_pause")
        time.sleep(11.5)  # Longer than the running-game periodic autosave interval.
        still_paused = read_active()
        if still_paused.get("elapsed") != paused.get("elapsed"):
            raise RuntimeError("Simulation elapsed advanced while the pause overlay was open.")
        event("pause_verified", elapsed=paused["elapsed"], minimum_wait_seconds=11.5)
        tap_button("LeaderboardButton", "pause")
        capture("05_local_scores")
        tap_button("ScoresBackButton", "scores")
        tap_button("AchievementsButton", "pause")
        capture("06_badges")
        tap_button("AchievementsBackButton", "achievements")
        tap_button("ResumeButton", "pause")
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(1)
        start_app()
        capture("07_background_return")
        background_saved = read_active()
        if not background_saved:
            raise RuntimeError("Android backgrounding did not preserve an active run.")
        collect_logs()
        # Recreate only the test app process, preserving its saved profile.
        adb("shell", "am", "force-stop", args.package)
        start_app()
        capture("08_process_resume")
        restored = read_active()
        for key in ["style", "elapsed", "score", "health", "player"]:
            if restored.get(key) != background_saved.get(key):
                raise RuntimeError(f"Process recovery changed persisted {key}.")
        event("process_recovery_verified", elapsed=restored["elapsed"], style=restored["style"])
        tap_button("ShieldButton", "launch", True)
        shield = verify_fresh_style("shield")
        time.sleep(1)
        capture("09_shield_action")
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        wait_overlay("pause")
        capture("10_android_back_pause")
        if read_active().get("style") != "shield":
            raise RuntimeError("Android Back did not preserve the shield run.")
        event("shield_and_back_verified", max_health=shield["max_health"])
        collect_logs()
        bad_lines = [line for line in "\n".join(all_logs).splitlines()
                     if "SCRIPT ERROR" in line or "FATAL EXCEPTION" in line or "Fatal signal" in line
                     or ("E godot" in line and "ERROR:" in line)]
        if bad_lines:
            raise RuntimeError("Android runtime errors: " + "\n".join(bad_lines[:8]))
        event("completed", runtime_errors=0,
              note="Screenshots require visual review; this is functional emulator evidence, not phone performance certification.")
        print(f"ANDROID_SMOKE_CAPTURED: {args.output.resolve()}")
        return 0
    except Exception as error:
        event("failed", error=str(error))
        print(f"ANDROID_SMOKE_FAILED: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
