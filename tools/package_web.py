"""Validate a Godot Web export and add only public provenance and legal notices."""
import argparse
import json
import os
from pathlib import Path
import shutil


def package(destination: Path) -> None:
    project = Path(__file__).resolve().parents[1]
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        path = destination / name
        if not path.is_file() or path.is_symlink() or path.stat().st_size == 0:
            raise ValueError(f"Missing or unsafe export file: {name}")
    for name, magic in (("index.wasm", b"\x00asm"), ("index.pck", b"GDPC")):
        with (destination / name).open("rb") as handle:
            if handle.read(4) != magic:
                raise ValueError(f"Invalid binary: {name}")
    for path in destination.rglob("*"):
        if path.is_symlink():
            raise ValueError("Pages artifact must not contain links")
        if path.is_file() and path.stat().st_size >= 100 * 1024 * 1024:
            raise ValueError(f"Pages file exceeds 100 MiB: {path.name}")
    legal_sources = sorted(project.glob("Assets/**/License.txt"))
    legal_sources += [project / "addons/GodotPlayGameServices/LICENSE", project / "addons/admob/LICENSE"]
    for source in legal_sources:
        target = destination / "licenses" / source.relative_to(project)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    shutil.copyfile(project / "docs/CREDITS.md", destination / "CREDITS.md")
    public = {"source_commit": os.environ.get("GITHUB_SHA", "local-unpublished"),
              "repository": os.environ.get("GITHUB_REPOSITORY", "EthannYakabuski/InfiniteSlash")}
    (destination / "build-info.json").write_text(json.dumps(public, indent=2) + "\n", encoding="utf-8")
    print(f"Web artifact validated; {len(legal_sources)} license notices copied.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    package(parser.parse_args().destination)
