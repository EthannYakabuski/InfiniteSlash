"""Install the pinned upstream Android binaries into the existing AdMob addon.

The local v5.1.0 source copy and Play Games addon are not replaced. Only the
official matching Android template is extracted, after its release hash check.
Run with --download if the cached archive is absent and network is available.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from urllib.request import Request, urlopen
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
URL = "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.5.1.zip"
SHA256 = "f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee"


def configure_android_build() -> bool:
    """Reproduce settings inside Godot's intentionally untracked template."""
    build = ROOT / "android/build"
    manifest = build / "AndroidManifest.xml"
    gradle = build / "build.gradle"
    if not manifest.is_file() or not gradle.is_file():
        return False  # Install the Godot Android build template, then rerun.
    text = manifest.read_text(encoding="utf-8")
    before = text
    if 'xmlns:tools="http://schemas.android.com/tools"' not in text:
        assert '<manifest xmlns:android="http://schemas.android.com/apk/res/android"' in text
        text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
                            '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"', 1)
    if 'android:name="com.google.android.gms.permission.AD_ID"' not in text:
        assert "<application" in text
        text = text.replace("<application", '<uses-permission android:name="com.google.android.gms.permission.AD_ID" />\n    <application', 1)
    removal = '<uses-permission android:name="android.permission.AD_ID" tools:node="remove" />'
    if removal not in text:
        assert 'android:name="android.permission.AD_ID"' not in text, "Review the existing AD_ID declaration before changing it"
        text = text.replace("<application", removal + "\n    <application", 1)
    if text != before:
        manifest.write_text(text, encoding="utf-8", newline="\n")
    text = gradle.read_text(encoding="utf-8")
    if 'resolutionStrategy.force "androidx.browser:browser:1.8.0"' not in text:
        marker = "apply from: 'config.gradle'"
        assert marker in text and 'module: "play-services-ads"' not in text
        patch = ('// Added by Poing Godot AdMob Plugin to support GMA Next-Gen SDK.\n'
                 'configurations.configureEach {\n'
                 '    exclude group: "com.google.android.gms", module: "play-services-ads"\n'
                 '    exclude group: "com.google.android.gms", module: "play-services-ads-lite"\n'
                 '    resolutionStrategy.force "androidx.browser:browser:1.8.0"\n}\n\n')
        gradle.write_text(text.replace(marker, patch + marker, 1), encoding="utf-8", newline="\n")
    rules = build / "proguard-rules.pro"
    text = rules.read_text(encoding="utf-8") if rules.is_file() else "# Preserve the public UMP/AdMob/PGS bridge when enabling R8.\n"
    required = ('-keep class com.google.android.ump.** { *; }',
                '-keep interface com.google.android.ump.** { *; }',
                '-keep class com.poingstudios.godot.admob.** { *; }',
                '-keep class com.jacobibanez.plugin.android.godotplaygameservices.** { *; }')
    missing = [line for line in required if line not in text]
    if missing:
        rules.write_text(text.rstrip() + "\n" + "\n".join(missing) + "\n", encoding="utf-8", newline="\n")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    archive = ROOT / "output/dependencies/admob-v5.1.0-android-template-v4.5.1.zip"
    target = ROOT / "addons/admob/android/bin"
    assert (ROOT / "addons/admob/LICENSE").is_file(), "Copy the supplied source addon first"
    if not archive.is_file():
        assert args.download, "Cached archive missing; pass --download to fetch the pinned release"
        archive.parent.mkdir(parents=True, exist_ok=True)
        with urlopen(Request(URL, headers={"User-Agent": "InfiniteSlash-local-integration"}), timeout=90) as response:
            data = response.read()
        assert hashlib.sha256(data).hexdigest() == SHA256, "Upstream archive hash mismatch"
        archive.write_bytes(data)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == SHA256
    target.mkdir(parents=True, exist_ok=True)
    files = {}
    with ZipFile(archive) as package:
        assert package.testzip() is None
        for info in package.infolist():
            path = PurePosixPath(info.filename)
            assert not path.is_absolute() and ".." not in path.parts and "\\" not in info.filename
            destination = target.joinpath(*path.parts)
            assert destination.resolve().is_relative_to(target.resolve())
            if info.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            data = package.read(info)
            if destination.exists():
                assert destination.read_bytes() == data, f"Refusing to replace a modified native file: {path}"
            else:
                destination.write_bytes(data)
            files[str(path)] = hashlib.sha256(data).hexdigest()
    report = {"source": URL, "sha256": SHA256, "version": "5.1.0", "files": files}
    review = ROOT / "output/review"
    review.mkdir(parents=True, exist_ok=True)
    (review / "admob_android_template.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"ADMOB_NATIVE_READY version=5.1.0 files={len(files)}; upstream SHA256 verified")
    configured = configure_android_build()
    print("ADMOB_ANDROID_BUILD " + ("configured; manifest/dependencies/keep rules ready" if configured else "template missing; install it and rerun this helper"))


if __name__ == "__main__":
    main()
