# The Endless Little Road

`music_loop.wav` is an original 32-second fantasy chiptune composed for InfiniteSlash. It combines a light bell melody, harp arpeggios, bass and soft percussion at 120 BPM. No third-party sound recording or melody was used.

The audio is mono, 24 kHz, 16-bit PCM. `AudioManager` configures its seamless forward loop and keeps music quieter than combat cues. Its raw audio payload is approximately 1.5 MB. The first-to-last sample difference is below 0.001 of full scale.

`tools/generate_music.py` reproduces the track deterministically. Composition and waveform are project-owned assets. The existing sound effects retain their bundled Kenney CC0 licenses.
