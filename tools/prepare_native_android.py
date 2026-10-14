"""Prepare the installed Godot 4.5.1 Gradle template without global SDK edits."""
from pathlib import Path
from zipfile import ZipFile


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    template = Path.home() / "AppData/Roaming/Godot/export_templates/4.5.1.stable/android_source.zip"
    target = root / "android/build"
    target.mkdir(parents=True, exist_ok=True)
    if not (target / "gradlew.bat").is_file():
        with ZipFile(template) as archive:
            for entry in archive.infolist():
                destination = (target / entry.filename).resolve()
                if not destination.is_relative_to(target.resolve()):
                    raise ValueError("Template entry leaves the Android build directory")
                archive.extract(entry, target)
    (root / "android/.build_version").write_text("4.5.1.stable\n", encoding="utf-8")
    (target / ".gdignore").write_text("\n", encoding="utf-8")
    config = target / "config.gradle"
    source = config.read_text(encoding="utf-8")
    source = source.replace("androidGradlePlugin: '8.6.1'", "androidGradlePlugin: '8.10.1'")
    source = source.replace("compileSdk         : 35", "compileSdk         : 36")
    source = source.replace("targetSdk          : 35", "targetSdk          : 36")
    source = source.replace("buildTools         : '35.0.0'", "buildTools         : '36.0.0'")
    config.write_text(source, encoding="utf-8")
    wrapper = target / "gradle/wrapper/gradle-wrapper.properties"
    contents = wrapper.read_text(encoding="utf-8")
    import re
    contents = re.sub(r"gradle-[\d.]+-bin\.zip", "gradle-8.11.1-bin.zip", contents)
    wrapper.write_text(contents, encoding="utf-8")
    print("Native Android template prepared: API36, AGP8.10.1, Gradle8.11.1; engine template4.5.1.")


if __name__ == "__main__":
    main()
