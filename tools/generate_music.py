"""Compose InfiniteSlash's original 32-second looping fantasy chiptune.

No third-party melody or sound recording is used. The restrained harp melody,
pentatonic arpeggio, bass and soft percussion leave room for combat effects.
"""
import json
import math
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Assets/Generated/music_loop.wav"
RATE = 24000
BPM = 120
BEAT = 60.0 / BPM
BARS = 16
DURATION = BARS * 4 * BEAT
music = np.zeros(round(DURATION * RATE), dtype=np.float64)
rng = np.random.default_rng(713)

def frequency(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12)

def mix(start, samples):
    """Wrap instrument tails at the loop boundary to keep timing seamless."""
    offset = round(start * RATE)
    indexes = (np.arange(len(samples)) + offset) % len(music)
    np.add.at(music, indexes, samples)

def note(midi, start, length, amplitude, instrument="harp"):
    count = round(length * RATE)
    t = np.arange(count) / RATE
    phase = t * frequency(midi)
    if instrument == "bass":
        signal = np.sin(2 * np.pi * phase) + 0.18 * np.sin(4 * np.pi * phase)
        envelope = (1 - np.exp(-t * 190)) * np.exp(-t * 7)
    elif instrument == "bell":
        signal = np.sin(2 * np.pi * phase) + 0.18 * np.sin(2 * np.pi * phase * 3)
        envelope = (1 - np.exp(-t * 380)) * np.exp(-t * 7.5)
    else:
        signal = np.sin(2 * np.pi * phase) + 0.24 * np.sin(4 * np.pi * phase) + 0.10 * np.sin(6 * np.pi * phase)
        envelope = (1 - np.exp(-t * 350)) * np.exp(-t * 10)
    # Every note releases before its buffer ends. This avoids boundary clicks.
    envelope *= np.minimum(1, np.maximum(0, (length - t) / 0.045))
    mix(start, amplitude * signal * envelope)

def percussion(start, kind, amplitude):
    length = 0.18 if kind == "kick" else 0.10
    t = np.arange(round(length * RATE)) / RATE
    if kind == "kick":
        phase = 55 * t + (105 / 26) * (1 - np.exp(-26 * t))
        signal = np.sin(2 * np.pi * phase) * np.exp(-t * 28)
    else:
        noise = rng.uniform(-1, 1, len(t))
        signal = (noise - np.roll(noise, 1)) * np.exp(-t * (60 if kind == "shaker" else 38))
    signal *= np.minimum(1, t / 0.003) * np.minimum(1, (length - t) / 0.025)
    mix(start, signal * amplitude)

progression = [(40, [64, 67, 71]), (36, [60, 64, 67]), (43, [62, 67, 71]), (38, [62, 66, 69])]
# E-minor/G-major pentatonic phrase, independently composed for this game.
melodies = [
    [76, None, 79, 78, 74, None, 71, 74],
    [72, None, 76, 79, 76, None, 74, 72],
    [79, None, 83, 81, 79, None, 76, 74],
    [74, None, 78, 81, 78, 74, 71, None],
]
for bar in range(BARS):
    start = bar * 4 * BEAT
    bass, chord = progression[bar % 4]
    for beat in range(4):
        note(bass + (12 if beat == 2 else 0), start + beat * BEAT, 0.34, 0.15, "bass")
        percussion(start + beat * BEAT, "kick" if beat % 2 == 0 else "clack", 0.08 if beat % 2 == 0 else 0.025)
    for step in range(8):
        arp = chord[[0, 1, 2, 1, 0, 2, 1, 2][step]] + 12
        note(arp, start + step * BEAT / 2, 0.22, 0.045, "harp")
        percussion(start + step * BEAT / 2, "shaker", 0.010)
        melody = melodies[bar % 4][step]
        if melody is not None:
            # Higher phrase on bars 9-12, then return to home register.
            octave = 12 if 8 <= bar < 12 and step in {2, 4} else 0
            note(melody + octave, start + step * BEAT / 2, 0.31, 0.095, "bell")

# Periodic short room reflections preserve the seam while softening the tone.
music += np.roll(music, round(0.077 * RATE)) * 0.12
music += np.roll(music, round(0.137 * RATE)) * 0.055
peak = float(np.max(np.abs(music)))
music *= 0.76 / peak
pcm = np.rint(music * 32767).astype("<i2")
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUTPUT), "wb") as target:
    target.setnchannels(1)
    target.setsampwidth(2)
    target.setframerate(RATE)
    target.writeframes(pcm.tobytes())
report = {"title": "The Endless Little Road", "composer": "Original InfiniteSlash procedural composition", "seconds": DURATION, "bpm": BPM, "sample_rate": RATE, "mono": True, "peak": float(np.max(np.abs(pcm))) / 32767, "rms": float(np.sqrt(np.mean((pcm.astype(float) / 32767) ** 2))), "seam_step": abs(int(pcm[0]) - int(pcm[-1])) / 32767, "license": "Project-owned original composition; no external recordings or melodies."}
(ROOT / "output/review").mkdir(parents=True, exist_ok=True)
(ROOT / "output/review/music_analysis.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
