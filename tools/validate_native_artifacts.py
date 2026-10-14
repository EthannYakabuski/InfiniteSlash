"""Report the packaged Play Games bridge and native-library alignment.

This is a static inspection, not a substitute for signed-in Play testing or a
16 KB device run. The release bundle must deliberately remain unsigned here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from zipfile import ZipFile


def elf_segments(data: bytes) -> list[dict]:
    if data[:4] != b"\x7fELF" or data[5] != 1:
        raise ValueError("Expected a little-endian ELF library")
    bits = data[4]
    offset = struct.unpack_from("<Q" if bits == 2 else "<I", data, 32 if bits == 2 else 28)[0]
    size, count = struct.unpack_from("<HH", data, 54 if bits == 2 else 42)
    segments = []
    for index in range(count):
        fields = struct.unpack_from("<IIQQQQQQ" if bits == 2 else "<IIIIIIII", data, offset + index * size)
        kind = fields[0]
        if kind not in (1, 0x6474E552):
            continue
        virtual, memory, align = (fields[3], fields[6], fields[7]) if bits == 2 else (fields[2], fields[5], fields[7])
        segments.append({"type": "LOAD" if kind == 1 else "GNU_RELRO", "virtual_address": virtual,
                         "memory_size": memory, "alignment": align,
                         "relro_end_modulo_16k": (virtual + memory) % 16384 if kind != 1 else None})
    for row in segments:
        if row["type"] != "GNU_RELRO":
            continue
        # Android's linker exempts RELRO covering the entire LOAD segment.
        # A raw nonzero end modulo alone would incorrectly reject Godot's
        # current prebuilt engine and libc++, whose RELRO covers that LOAD.
        matching = next((load for load in segments if load["type"] == "LOAD"
                         and load["virtual_address"] == row["virtual_address"]), None)
        whole_load = matching is not None and matching["memory_size"] <= row["memory_size"]
        row["covers_whole_load"] = whole_load
        row["static_16kb_accepted"] = row["relro_end_modulo_16k"] == 0 or whole_load
        row["assessment"] = "whole_LOAD_exception" if whole_load else ("aligned_end" if row["relro_end_modulo_16k"] == 0 else "unaligned_prefix_end")
    return segments


def inspect(path: Path) -> dict:
    result = {"path": str(path), "bytes": path.stat().st_size,
              "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    with ZipFile(path) as archive:
        names = archive.namelist()
        dex = b"".join(archive.read(name) for name in names if name.endswith(".dex"))
        result["bridge_dex"] = {label: value in dex for label, value in {
            "plugin_class": b"com/jacobibanez/plugin/android/godotplaygameservices/GodotAndroidPlugin",
            "resolve_conflict": b"resolveConflict", "load_failure_signal": b"gameLoadFailed",
            "google_games_sdk": b"com/google/android/gms/games/PlayGames",
        }.items()}
        if not all(result["bridge_dex"].values()):
            raise ValueError(f"Missing native bridge or Play Games SDK in {path}")
        result["native_libraries"] = []
        for name in names:
            if name.endswith(".so"):
                info = archive.getinfo(name)
                segments = elf_segments(archive.read(name))
                result["native_libraries"].append({"name": name, "compressed": info.compress_type != 0,
                    "segments": segments,
                    "load_alignment_16k": all(row["alignment"] >= 16384 for row in segments if row["type"] == "LOAD"),
                    "relro_raw_end_alignment_16k": all(row["relro_end_modulo_16k"] == 0 for row in segments if row["type"] == "GNU_RELRO"),
                    "relro_static_16kb_accepted": all(row["static_16kb_accepted"] for row in segments if row["type"] == "GNU_RELRO")})
        result["signing_entries"] = [name for name in names if name.upper().endswith((".RSA", ".DSA", ".EC", ".SF"))]
        result["is_bundle"] = "BundleConfig.pb" in names
        result["resource_exclusions"] = not any(name.startswith(("assets/store/", "assets/docs/", "assets/tests/", "assets/native/")) for name in names)
        if result["is_bundle"]:
            if result["signing_entries"]:
                raise ValueError("Preparation bundle unexpectedly contains a signing certificate")
            if any("/lib/x86/" in name or "/lib/x86_64/" in name for name in names):
                raise ValueError("Release preparation must contain ARM64 only")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, default=Path("output/review/native_artifacts.json"))
    args = parser.parse_args()
    report = {"status": "PASS", "scope": "Packaged bridge, SDK, ARM64 bundle, unsigned release and ELF static inspection",
              "relro_rule_source": "https://android.googlesource.com/platform/bionic/+/android16-qpr2-release/linker/linker_phdr_16kib_compat.cpp#427",
              "device_16kb_tested": False, "google_account_backend_tested": False,
              "artifacts": [inspect(path) for path in args.artifacts]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Artifact structure checks passed; saved {args.output}. Alignment limitations are recorded separately.")


if __name__ == "__main__":
    main()
