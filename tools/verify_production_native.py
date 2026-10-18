"""Verify versioned signed Android artifacts using installed offline tools.

Checks the actual packaged config/creature data, signatures, package versions,
native bridge and static 16 KB properties. Does not publish or authenticate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

from validate_native_artifacts import elf_segments


ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "output/review"
SDK = Path("C:/Users/swimr/AppData/Local/Android/Sdk")
JAVA = Path("C:/Program Files/Java/jdk-17/bin")
BUILD_TOOLS = SDK / "build-tools/36.0.0"
ANDROID = "{http://schemas.android.com/apk/res/android}"


def command(arguments: list[str | Path], log: str) -> str:
    result = subprocess.run(list(map(str, arguments)), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    text = result.stdout.decode(errors="replace")
    (REVIEW / log).write_text(text, encoding="utf-8")
    if result.stderr:
        (REVIEW / (log + ".stderr.txt")).write_text(result.stderr.decode(errors="replace"), encoding="utf-8")
    assert result.returncode == 0, f"Tool failed; see {log}"
    return text


def bundletool(mode: str, bundle: Path, log: str) -> str:
    dependencies = json.loads((REVIEW / "production_bundletool_classpath.json").read_text(encoding="utf-8"))
    return command([JAVA / "java.exe", "-cp", ";".join(dependencies),
                    "com.android.tools.build.bundletool.BundleToolMain", "dump", mode, f"--bundle={bundle}"], log)


def inspect(path: Path, expected_config: dict, expected_admob: dict | None = None) -> dict:
    result = {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
              "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    expected_monsters = json.loads((ROOT / "data/monsters.json").read_text(encoding="utf-8"))
    with ZipFile(path) as archive:
        assert archive.testzip() is None, "ZIP CRC failure"
        names = archive.namelist()
        config_paths = [name for name in names if name.endswith("assets/config/play_services.json")]
        monster_paths = [name for name in names if name.endswith("assets/data/monsters.json")]
        assert len(config_paths) == len(monster_paths) == 1
        actual_config = json.loads(archive.read(config_paths[0]))
        actual_monsters = json.loads(archive.read(monster_paths[0]))
        assert actual_config == expected_config and actual_monsters == expected_monsters
        result["packaged_config_matches"] = True
        result["packaged_monster_count"] = len(actual_monsters)
        result["configured_achievements"] = sum(bool(value) for value in actual_config["achievements"].values())
        result["configured_leaderboards"] = sum(bool(value) for value in actual_config["leaderboards"].values())
        result["packaged_feature_ids"] = {key: actual_config[key] for key in ("achievements", "leaderboards")}
        assert len(actual_monsters) == 200
        assert sum(bool(item.get("night_only")) for item in actual_monsters) == 50
        assert sum(int(item.get("stage_min", 1)) == 30 and not item.get("night_only", False) for item in actual_monsters) == 50
        result["packaged_scripts"] = [name for name in names if "/scripts/" in name and name.endswith(".gdc")]
        result["game_script_sha256"] = {name[name.index("assets/scripts/") + len("assets/"):]: hashlib.sha256(archive.read(name)).hexdigest()
                                         for name in names if "assets/scripts/" in name and name.endswith(".gdc")}
        for source in ["game", "game_ui", "world", "class_profiles", "upgrade_catalog", "progression", "boss_hazards"]:
            assert any(name.endswith(f"scripts/{source}.gdc") for name in names), f"Missing {source}"
        assert not any(re.search(r"(?:^|/)assets/(?:tests|tools|docs|output|store)/", name) for name in names)
        dex = b"".join(archive.read(name) for name in names if name.endswith(".dex"))
        result["bridge_dex"] = {label: token in dex for label, token in {
            "plugin_class": b"com/jacobibanez/plugin/android/godotplaygameservices/GodotAndroidPlugin",
            "resolve_conflict": b"resolveConflict", "load_failure_signal": b"gameLoadFailed",
            "google_games_sdk": b"com/google/android/gms/games/PlayGames"}.items()}
        assert all(result["bridge_dex"].values())
        if expected_admob is not None:
            ad_paths = [name for name in names if name.endswith("assets/config/admob.json")]
            assert len(ad_paths) == 1
            actual_admob = json.loads(archive.read(ad_paths[0]))
            assert actual_admob == expected_admob, "Packaged AdMob configuration differs"
            assert actual_admob["test_mode"] is True
            assert actual_admob["ad_units"] == {
                "banner": "ca-app-pub-3940256099942544/6300978111",
                "interstitial": "ca-app-pub-3940256099942544/1033173712",
                "rewarded": "ca-app-pub-3940256099942544/5224354917"}
            assert not any(actual_admob["production_ad_units"].values())
            assert actual_admob["child_directed"] is False and actual_admob["under_age_of_consent"] is False
            assert actual_admob["max_ad_content_rating"] == ""
            native_ads = {label: token in dex for label, token in {
                "mobile_ads": b"com/poingstudios/godot/admob/ads/PoingGodotAdMob;",
                "banner": b"com/poingstudios/godot/admob/ads/PoingGodotAdMobAdView;",
                "interstitial": b"com/poingstudios/godot/admob/ads/PoingGodotAdMobInterstitialAd;",
                "rewarded": b"com/poingstudios/godot/admob/ads/PoingGodotAdMobRewardedAd;",
                "gma_next_gen": b"com/google/android/libraries/ads/mobile/sdk/MobileAds;",
                "ump": b"com/google/android/ump/UserMessagingPlatform;",
                "ump_authoritative_getter": b"canRequestAds"}.items()}
            assert all(native_ads.values()), "A required Ads/UMP native class is missing"
            license_paths = [name for name in names if name.endswith("assets/addons/admob/LICENSE")]
            assert len(license_paths) == 1 and archive.read(license_paths[0]) == (ROOT / "addons/admob/LICENSE").read_bytes()
            for source in ("ads_service", "admob_backend", "ads_sdk_values"):
                assert any(name.endswith(f"scripts/services/{source}.gdc") for name in names)
            result["admob"] = {"packaged_config_matches": True, "test_mode": True,
                               "app_id": actual_admob["app_id"], "native_dex": native_ads,
                               "vendor_license_included": True, "production_ad_units": False}
        native = []
        for name in names:
            if not name.endswith(".so"):
                continue
            info = archive.getinfo(name)
            segments = elf_segments(archive.read(name))
            row = {"name": name, "compressed": info.compress_type != 0, "segments": segments,
                   "load_alignment_16k": all(item["alignment"] >= 16384 for item in segments if item["type"] == "LOAD"),
                   "relro_static_16kb_accepted": all(item["static_16kb_accepted"] for item in segments if item["type"] == "GNU_RELRO")}
            if "arm64-v8a" in name:
                assert row["load_alignment_16k"] and row["relro_static_16kb_accepted"]
            native.append(row)
        result["native_libraries"] = native
        if path.suffix == ".aab":
            assert native and all("arm64-v8a" in row["name"] for row in native)
            # An AAB is a publishing container: its ZIP compression is separate
            # from delivered APK compression/page alignment. BundleConfig below
            # is the authoritative delivery setting; still inspect the ELF here.
            assert any(name.upper().endswith(".RSA") for name in names), "Release bundle lacks a signing entry"
    adjacent = path.with_name(path.name + ".sha256")
    assert adjacent.read_text(encoding="utf-8").split()[0] == result["sha256"]
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="0.3.0")
    parser.add_argument("--code", type=int, default=8)
    parser.add_argument("--prefix", default="production")
    parser.add_argument("--frozen", type=Path)
    parser.add_argument("--prior", type=Path)
    parser.add_argument("--expected-config", type=Path, default=ROOT / "config/play_services.json")
    parser.add_argument("--achievements", type=int)
    parser.add_argument("--leaderboards", type=int)
    parser.add_argument("--baseline-version", help="Require all main compiled scripts to match this previous APK")
    parser.add_argument("--admob-config", type=Path, help="Verify test-only AdMob config, native classes, license and manifests")
    args = parser.parse_args()
    assert re.fullmatch(r"\d+\.\d+\.\d+", args.version) and args.code > 0
    assert re.fullmatch(r"[a-z0-9_]+", args.prefix)
    if args.baseline_version:
        assert re.fullmatch(r"\d+\.\d+\.\d+", args.baseline_version)
    def log(stem: str) -> str:
        return args.prefix + "_" + stem
    apk = ROOT / f"builds/InfiniteSlash-debug-{args.version}.apk"
    aab = ROOT / f"builds/InfiniteSlash-play-{args.version}.aab"
    expected_config = json.loads(args.expected_config.read_text(encoding="utf-8"))
    expected_admob = json.loads(args.admob_config.read_text(encoding="utf-8")) if args.admob_config else None
    report = {"status": "PASS", "package": "com.slash.game", "version_name": args.version, "version_code": args.code,
              "google_backend_tested": False, "real_16kb_device_tested": False,
              "scope": "Actual signed packages, config/data, bridge/SDK, manifests and static native alignment"}
    report["apk"] = inspect(apk, expected_config, expected_admob)
    report["aab"] = inspect(aab, expected_config, expected_admob)
    for artifact in ("apk", "aab"):
        if args.achievements is not None:
            assert report[artifact]["configured_achievements"] == args.achievements
        if args.leaderboards is not None:
            assert report[artifact]["configured_leaderboards"] == args.leaderboards
    badging = command([BUILD_TOOLS / "aapt.exe", "dump", "badging", apk], log("apk_badging.txt"))
    assert "name='com.slash.game'" in badging and f"versionCode='{args.code}'" in badging and f"versionName='{args.version}'" in badging
    assert "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
    signature = command([JAVA / "java.exe", "-jar", BUILD_TOOLS / "lib/apksigner.jar", "verify", "--print-certs", apk], log("debug_signature.txt"))
    assert "62ee05f2cac9953648bf3ad7c822558cc633cd24" in signature.lower()
    command([BUILD_TOOLS / "zipalign.exe", "-c", "-P", "16", "-v", "4", apk], log("apk_zipalign.txt"))
    command([JAVA / "jarsigner.exe", "-verify", aab], log("release_signature.txt"))
    release_certificate = command([JAVA / "keytool.exe", "-printcert", "-jarfile", aab], log("release_certificate.txt"))
    assert "D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB" in release_certificate.upper()
    manifest = ET.fromstring(bundletool("manifest", aab, log("bundle_manifest.xml")))
    assert manifest.get("package") == "com.slash.game"
    assert manifest.get(ANDROID + "versionCode") == str(args.code) and manifest.get(ANDROID + "versionName") == args.version
    assert manifest.get(ANDROID + "compileSdkVersion") == "36"
    uses_sdk = manifest.find("uses-sdk")
    assert uses_sdk is not None and uses_sdk.get(ANDROID + "minSdkVersion") == "24" and uses_sdk.get(ANDROID + "targetSdkVersion") == "36"
    if expected_admob is not None:
        application = manifest.find("application")
        assert application is not None
        metadata = {item.get(ANDROID + "name"): item.get(ANDROID + "value") for item in application.findall("meta-data")}
        assert metadata.get("com.google.android.gms.ads.APPLICATION_ID") == expected_admob["app_id"]
        assert "com.google.android.gms.games.APP_ID" in metadata
        assert metadata.get("org.godotengine.plugin.v2.GodotPlayGameServices") == "com.jacobibanez.plugin.android.godotplaygameservices.GodotAndroidPlugin"
        required_plugins = ("PoingGodotAdMob", "PoingGodotAdMobAdView", "PoingGodotAdMobInterstitialAd",
                            "PoingGodotAdMobRewardedAd", "PoingGodotAdMobConsentInformation", "PoingGodotAdMobUserMessagingPlatform")
        for plugin in required_plugins:
            assert "org.godotengine.plugin.v2." + plugin in metadata
        permissions = {item.get(ANDROID + "name") for item in manifest.findall("uses-permission")}
        assert "com.google.android.gms.permission.AD_ID" in permissions
        assert "android.permission.AD_ID" not in permissions
        apk_manifest = command([BUILD_TOOLS / "aapt.exe", "dump", "xmltree", apk, "AndroidManifest.xml"], log("apk_manifest.txt"))
        for value in (expected_admob["app_id"], "com.google.android.gms.ads.APPLICATION_ID", "com.google.android.gms.games.APP_ID"):
            assert value in apk_manifest
        assert "org.godotengine.plugin.v2.GodotPlayGameServices" in apk_manifest
        assert "com.jacobibanez.plugin.android.godotplaygameservices.GodotAndroidPlugin" in apk_manifest
        for plugin in required_plugins:
            assert "org.godotengine.plugin.v2." + plugin in apk_manifest
        report["admob_manifest_coexists_with_play_games"] = True
    delivery = json.loads(bundletool("config", aab, log("bundle_config.json")))
    native = delivery["optimizations"]["uncompressNativeLibraries"]
    assert native["enabled"] and native["alignment"] == "PAGE_ALIGNMENT_16K"
    report["delivery_native_alignment"] = native
    frozen = json.loads((args.frozen or REVIEW / log("frozen_sources.json")).read_text(encoding="utf-8"))
    for name, expected in frozen.items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, f"Runtime source changed after final export freeze: {name}"
    report["frozen_source_files"] = len(frozen)
    report["game_scripts_match_between_apk_and_aab"] = report["apk"]["game_script_sha256"] == report["aab"]["game_script_sha256"]
    assert report["game_scripts_match_between_apk_and_aab"], "Compiled main scripts differ between APK and AAB"
    if args.baseline_version:
        with ZipFile(ROOT / f"builds/InfiniteSlash-debug-{args.baseline_version}.apk") as baseline:
            prior_scripts = {name[name.index("assets/scripts/") + len("assets/"):]: hashlib.sha256(baseline.read(name)).hexdigest()
                             for name in baseline.namelist() if "assets/scripts/" in name and name.endswith(".gdc")}
        assert prior_scripts == report["apk"]["game_script_sha256"], "Main compiled gameplay scripts changed from baseline"
        report["unchanged_game_scripts_from_baseline"] = args.baseline_version
    preserved = json.loads((args.prior or REVIEW / log("prior_artifacts.json")).read_text(encoding="utf-8"))
    for name, expected in preserved.items():
        target = ROOT / "builds" / expected.get("preserved_as", "InfiniteSlash-debug-0.2.1.apk" if name == "InfiniteSlash-debug.apk" else name)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == expected["sha256"], f"Prior artifact changed: {name}"
    report["preserved_prior_artifacts"] = list(preserved)
    (REVIEW / log("native_artifacts.json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PRODUCTION_NATIVE_ARTIFACTS_PASS version={args.version} code={args.code}; signed APK/AAB, packaged data, native bridge, static 16KB and prior files verified")


if __name__ == "__main__":
    main()
