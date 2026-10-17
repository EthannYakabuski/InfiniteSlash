"""Production gameplay smoke checks on an explicitly owned workspace emulator.

Fixtures exercise late-stage rendering and save continuity without claiming an
organic level-50 run, phone FPS, 16 KB device testing, or live Google sign-in.
The selected emulator's original profile is preserved and restored in finally.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import subprocess
import time
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--serial", default="emulator-5582")
    parser.add_argument("--server-port", type=int, default=5038)
    parser.add_argument("--avd-name", choices=["InfiniteSlash_Test", "InfiniteSlash_PGS"], default="InfiniteSlash_PGS")
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--skip-install", action="store_true", help="Reuse only an installed APK whose SHA-256 matches --apk")
    parser.add_argument("--layout", type=Path, default=Path("output/review/ui_layouts.json"))
    parser.add_argument("--output", type=Path, default=Path("output/android-test/production"))
    args = parser.parse_args()
    assert re.fullmatch(r"emulator-\d+", args.serial), "Only an explicit emulator is supported"
    assert 1024 <= args.server_port <= 65535
    args.output.mkdir(parents=True, exist_ok=True)
    package = "com.slash.game"
    events: list[dict] = []
    logs: list[str] = []
    original: dict | None = None
    original_files: dict[str, bytes] = {}
    profile_names = ("infiniteslash_profile.json", "infiniteslash_profile.json.bak", "infiniteslash_profile.json.tmp")

    def adb(*command: object, raw: bool = False, payload: bytes | None = None, timeout: float = 30):
        result = subprocess.run([str(args.adb), "-P", str(args.server_port), "-s", args.serial, *map(str, command)],
                                input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        if result.returncode:
            raise RuntimeError(f"ADB {command}: {result.stderr.decode(errors='replace')} {result.stdout.decode(errors='replace')}")
        return result.stdout if raw else result.stdout.decode(errors="replace").strip()

    def event(kind: str, **details):
        events.append({"event": kind, "time": time.time(), **details})
        (args.output / "events.json").write_text(json.dumps(events, indent=2), encoding="utf-8")

    def profile() -> dict:
        return json.loads(adb("shell", "run-as", package, "cat", "files/infiniteslash_profile.json"))

    def write_fixture(envelope: dict, label: str):
        adb("shell", "am", "force-stop", package)
        content = json.dumps(envelope, separators=(",", ":")).encode("utf-8")
        # Fixed shell command; all fixture data arrives on stdin, not in syntax.
        adb("shell", "run-as", package, "sh", "-c", "'cat > files/infiniteslash_profile.json'", payload=content)
        (args.output / f"fixture_{label}.json").write_bytes(content)
        event("fixture_written", label=label, bytes=len(content))

    def runtime_log() -> str:
        pid = adb("shell", "pidof", package).split()[0]
        return adb("shell", "logcat", "-d", "--pid", pid)

    def collect_log():
        logs.append(runtime_log())
        (args.output / "runtime.log").write_text("\n".join(logs), encoding="utf-8")

    def wait_overlay(name: str, timeout: float = 40):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            overlays = re.findall(r"INFINITESLASH_UI\s+([a-z]+)", runtime_log())
            if overlays and overlays[-1] == name:
                event("overlay", name=name)
                time.sleep(.35)
                return
            time.sleep(.3)
        collect_log()
        raise AssertionError(f"Did not enter {name}")

    def launch():
        adb("shell", "am", "force-stop", package)
        adb("logcat", "-c")
        response = adb("shell", "am", "start", "-W", "-n", package + "/com.godot.game.GodotApp", timeout=60)
        assert "Error" not in response, response
        wait_overlay("launch", 60)

    def screenshot(name: str):
        data = adb("exec-out", "screencap", "-p", raw=True)
        assert data.startswith(b"\x89PNG\r\n\x1a\n")
        target = args.output / f"{name}.png"
        target.write_bytes(data)
        event("screenshot", name=name, path=str(target))

    assert adb("get-state") == "device"
    assert adb("shell", "getprop", "sys.boot_completed") == "1"
    assert args.avd_name in adb("emu", "avd", "name").splitlines(), "Selected AVD is not owned by this project"
    for name in profile_names:
        try:
            original_files[name] = adb("shell", "run-as", package, "cat", "files/" + name, raw=True)
            (args.output / ("before_" + name)).write_bytes(original_files[name])
        except RuntimeError:
            pass
    (args.output / "initial_profile_files.json").write_text(json.dumps({name: {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} for name, data in original_files.items()}, indent=2), encoding="utf-8")
    try:
        original = profile()
        (args.output / "profile_before_test.json").write_text(json.dumps(original, indent=2), encoding="utf-8")
    except RuntimeError:
        # A fresh AVD may not have this app/profile yet. Nothing is overwritten.
        original = None
    if args.skip_install:
        installed_path = next(line.removeprefix("package:") for line in adb("shell", "pm", "path", package).splitlines() if line.startswith("package:"))
        assert re.fullmatch(r"/data/app/[A-Za-z0-9_./~+=-]+/base\.apk", installed_path)
        installed_hash = adb("shell", "sha256sum", installed_path).split()[0]
        assert installed_hash == hashlib.sha256(args.apk.read_bytes()).hexdigest()
        event("reused_verified_installed_apk", sha256=installed_hash)
    else:
        result = adb("install", "-r", args.apk.resolve(), timeout=180)
        assert "Success" in result, result
        event("installed", apk=str(args.apk.resolve()))
    device = adb("shell", "dumpsys", "package", package)
    assert "versionCode=8" in device and "versionName=0.3.0" in device, "Wrong package version installed"
    dimensions = re.findall(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
    width, height = map(int, dimensions[-1])
    event("device", serial=args.serial, avd=args.avd_name, width=width, height=height,
          api=adb("shell", "getprop", "ro.build.version.sdk"), page_size=adb("shell", "getconf", "PAGE_SIZE"))
    layouts = json.loads(args.layout.read_text(encoding="utf-8"))
    roster = json.loads(Path("data/monsters.json").read_text(encoding="utf-8"))
    by_id = {str(item["id"]): item for item in roster}

    def tap(name: str, overlay: str, can_resume: bool = False):
        candidates = [item for item in layouts if item["overlay"] == overlay and name in item["buttons"]
                      and (overlay != "launch" or item["can_resume"] == can_resume)]
        assert candidates, f"No measured rectangle for {overlay}/{name}"
        layout = min(candidates, key=lambda item: abs(item["viewport"][1] / item["viewport"][0] - height / width))
        x, y, w, h = layout["buttons"][name]
        point = (round((x + w / 2) * width / layout["viewport"][0]),
                 round((y + h / 2) * height / layout["viewport"][1]))
        adb("shell", "input", "tap", *point)
        event("tap", button=name, point=point)
        time.sleep(.45)

    def resume_fixture(envelope: dict, label: str, overlay: str = "running"):
        write_fixture(envelope, label)
        launch()
        tap("ResumeButton", "launch", True)
        wait_overlay(overlay)

    def paused_active() -> dict:
        tap("PauseButton", "")
        wait_overlay("pause")
        return profile()["active_run"]

    def fixture(baseline: dict, level: int, elapsed: float) -> dict:
        envelope = copy.deepcopy(baseline)
        run = envelope["active_run"]
        run.update(level=level, xp=0, xp_goal=math.ceil(int(8 + level ** 1.28 * 3) * (1.25 if level <= 20 else 1.5 if level <= 40 else 2)),
                   combat_version=2, balance_version=4, elapsed=elapsed, player=[270, 740],
                   next_boss=elapsed+1000, spawn_timer=3, relief_until=0, score=12345,
                   enemies=[], bullets=[], drops=[], hazards=[], buffs={}, ward_hits=0,
                   upgrade_choices=[], upgrade_counts={}, guard_regen_wait=0, guard_contact_cooldown=0,
                   overdrive_charge=0, overdrive_time=0, second_wind=0, second_wind_used=False,
                   lifesteal=0, thorns=0, execute_threshold=0, combo_grace=0)
        if level == 1:
            run["xp_goal"] = 10
        return envelope

    def enemy(monster: dict, position: list[float], boss: bool = False) -> dict:
        item = {"kind": roster.index(monster), "monster_id": monster["id"], "pos": position,
                "hp": 150000 if boss else 3000, "max_hp": 150000 if boss else 3000,
                "radius": 35 if boss else monster.get("radius", 17), "speed": 140 if boss else monster["speed"],
                "damage": 45 if boss else 20, "behavior": "boss" if boss else monster["behavior"],
                "boss": boss, "minion": False, "alive": True, "age": 0, "cooldown": .2 if boss else .6,
                "windup": 0, "charge": 0, "aim": [0, 1], "knock": [0, 0], "flash": 0, "phase": 0,
                "anim": 0, "last_slash": -1}
        if boss:
            item["boss_id"] = "moonmallow_majesty"
        return item

    try:
        launch()
        if original is None:
            try:
                original = profile()
                (args.output / "profile_before_test.json").write_text(json.dumps(original, indent=2), encoding="utf-8")
            except RuntimeError:
                pass
        screenshot("01_launch")
        tap("SwordButton", "launch", bool(original and original.get("active_run")))
        wait_overlay("running")
        active = paused_active()
        assert active["damage"] == 32 and active["max_health"] == 80
        assert active["guard_delay"] == .5 and active["guard_regen"] == 22
        baseline = profile()
        event("sword_base_verified", guard_delay=active["guard_delay"], guard_regen=active["guard_regen"])
        guard_fixture = fixture(baseline, 1, 12)
        guard_fixture["active_run"].update(guard_reserve=5, guard_capacity=65, health=80, max_health=80)
        resume_fixture(guard_fixture, "guard_idle")
        time.sleep(.7)
        screenshot("02_guard_recharges_while_stationary")
        idle = paused_active()
        assert idle["guard_reserve"] > 5 and idle["health"] == 80, idle
        event("stationary_guard_regeneration_verified", reserve_before=5, reserve_after=idle["guard_reserve"])
        collect_log()

        launch()
        tap("ShieldButton", "launch", True)
        wait_overlay("running")
        shield = paused_active()
        assert shield["damage"] == 24 and shield["max_health"] == 170
        assert shield["guard_delay"] == .3 and shield["guard_regen"] == 28
        event("shield_base_verified", guard_delay=shield["guard_delay"], guard_regen=shield["guard_regen"])
        collect_log()

        build = fixture(baseline, 50, 30)
        run = build["active_run"]
        run.update(health=800, max_health=800, damage=220, attack_interval=.24, attack_range=140,
                   guard_capacity=500, guard_reserve=500, move_speed=350, dash_recharge=2.1,
                   guard_regen=60, guard_delay=.35,
                   upgrade_choices=["trade_dash_recharge_for_damage", "phoenix_oath"])
        resume_fixture(build, "legendary_and_tradeoff", "upgrade")
        screenshot("03_legendary_and_tradeoff")
        before = profile()["active_run"]
        assert abs(before["dash_recharge"] - 2.1) < .001, "A slower dash tradeoff was clamped back to the class baseline"
        time.sleep(3)
        adb("shell", "input", "keyevent", "3")
        time.sleep(.7)
        after = profile()["active_run"]
        for key in ["elapsed", "health", "guard_reserve", "player", "upgrade_choices"]:
            assert before[key] == after[key], f"Paused choice changed {key}"
        collect_log()
        launch()
        tap("ResumeButton", "launch", True)
        wait_overlay("upgrade")
        assert profile()["active_run"]["upgrade_choices"] == before["upgrade_choices"]
        tap("UpgradeChoice1", "upgrade")
        wait_overlay("running")
        selected = paused_active()
        assert selected["damage"] > 220 and abs(selected["dash_recharge"] - 2.3) < .001
        assert selected["upgrade_counts"]["trade_dash_recharge_for_damage"] == 1
        assert selected["second_wind"] == 0, "Unchosen legendary reward was applied"
        event("tradeoff_selected_after_restart", damage=selected["damage"], dash_recharge=selected["dash_recharge"])
        collect_log()

        advanced = [item for item in roster if int(item.get("stage_min", 1)) >= 30 and not item.get("night_only", False)]
        night = [item for item in roster if item.get("night_only", False)]
        assert len(advanced) == 50 and len(night) == 50, "New creature pools are incomplete"
        middle = fixture(baseline, 30, 30)
        run = middle["active_run"]
        run.update(health=1800, max_health=1800, guard_capacity=900, guard_reserve=900, guard_regen=75, damage=180)
        run["enemies"] = [enemy(item, [65 + index % 7 * 67, 180 + index // 7 * 95]) for index, item in enumerate(advanced[:21])]
        resume_fixture(middle, "stage30_specialists")
        time.sleep(2)
        screenshot("04_stage30_specialists")
        middle_active = paused_active()
        assert middle_active["level"] == 30 and len(middle_active["enemies"]) > 0
        assert any(by_id.get(item.get("monster_id"), {}).get("stage_min", 1) >= 30 for item in middle_active["enemies"])
        event("stage30_specialists_rendered", enemies=len(middle_active["enemies"]))
        collect_log()

        late = fixture(baseline, 50, 110)
        run = late["active_run"]
        # Extra durability is an explicit stress fixture, not an organic build.
        run.update(health=100000, max_health=100000, guard_capacity=10000, guard_reserve=10000,
                   guard_regen=75, damage=200, attack_interval=.24, attack_range=135, boss_number=8)
        visible = night[:35] + roster[:28]
        run["enemies"] = [enemy(item, [45 + index % 9 * 55, 165 + index // 9 * 70]) for index, item in enumerate(visible)]
        run["enemies"].append(enemy(next(item for item in roster if item["id"] == "moon_mallow"), [270, 250], True))
        original_creature = enemy(roster[0], [485, 160])
        original_creature.update(kind=200, monster_id="original_tinpot", hp=150000, max_hp=150000)
        run["enemies"].append(original_creature)
        run["hazards"] = [{"kind": kind, "pos": position, "aim": [0, 1], "size": [116, 420], "age": 0,
                           "warning": .9, "duration": 4.5, "damage": 20, "radius": 72, "gap_angle": 1.57, "gap_half": .78}
                          for kind, position in [("fire", [125, 580]), ("quake", [405, 460]), ("pulse", [270, 310])]]
        run["bullets"] = [{"pos": [35 + index % 12 * 42, 180 + index // 12 * 70],
                           "vel": [30 * (-1 if index % 2 else 1), 100], "damage": 4, "life": 7,
                           "boss": False, "radius": 5} for index in range(96)]
        resume_fixture(late, "stage50_night_stress")
        time.sleep(.7)
        screenshot("05_crownfall_night_elemental_hazards")
        for sample in range(3):
            time.sleep(3)
            screenshot(f"06_stage50_stress_{sample}")
        late_active = paused_active()
        assert late_active["level"] == 50 and late_active["elapsed"] > 115
        assert any(item.get("boss_id") == "moonmallow_majesty" for item in late_active["enemies"])
        assert any(by_id.get(item.get("monster_id"), {}).get("night_only") for item in late_active["enemies"])
        assert any(item.get("monster_id") == "original_tinpot" for item in late_active["enemies"]), "Original 201st roster entry did not survive native restore"
        event("stage50_night_stress_verified", enemies=len(late_active["enemies"]), bullets=len(late_active["bullets"]),
              hazards=len(late_active["hazards"]), elapsed=late_active["elapsed"], player_health=late_active["health"])
        (args.output / "meminfo.txt").write_text(adb("shell", "dumpsys", "meminfo", package), encoding="utf-8")
        (args.output / "gfxinfo.txt").write_text(adb("shell", "dumpsys", "gfxinfo", package, "framestats"), encoding="utf-8")
        collect_log()
        combined = "\n".join(logs)
        bad = [line for line in combined.splitlines() if re.search(
            r"SCRIPT ERROR|FATAL EXCEPTION|Fatal signal|ERROR:.*res://|Active run contains unsupported|Progress snapshot is too large|Could not (?:write|finish saving|replace|keep) progress", line, re.I)]
        assert not bad, "\n".join(bad)
        event("production_android_smoke_pass", runtime_errors=0, google_backend_tested=False, organic_level50_run=False)
        print("PRODUCTION_ANDROID_SMOKE_PASS")
    except Exception as error:
        try:
            collect_log()
        except Exception:
            pass
        event("failed", error=str(error))
        raise
    finally:
        adb("shell", "am", "force-stop", package)
        for name in profile_names:
            if name in original_files:
                # Names come only from the three fixed profile filenames above.
                adb("shell", "run-as", package, "sh", "-c", "'cat > files/" + name + "'", payload=original_files[name])
                assert adb("shell", "run-as", package, "cat", "files/" + name, raw=True) == original_files[name]
            else:
                adb("shell", "run-as", package, "rm", "-f", "files/" + name)
        event("original_emulator_profile_restored", files_restored=list(original_files), fresh_profile_absence_restored=not original_files)


if __name__ == "__main__":
    main()
