# Asset credits and provenance

The supplied Tiny Town, Tiny Farm, UI Pack Adventure, Fantasy UI Borders, Mobile Controls, Impact Sounds, RPG Audio and Interface Sounds packs are by **Kenney**. Their original `License.txt` files remain in `Assets`; these packs use CC0. Thank you, Kenney. Source: https://kenney.nl/assets.

The 200 generated monster sheets were exported through the real **Kenney Creature Mixer v1.6.0** browser interface: full Randomize, scale 8×, Save spritesheet. This includes the original 100 generated creatures and the expansion's 50 level-30 veterans plus 50 night-only monsters. The supplied `creature-sheet (2).png` is also preserved. The roster records filenames, names, stats and SHA-256 hashes; original exported pixels remain intact. Creature Mixer permits personal, educational and commercial use, with an exclusion for NFT/blockchain projects. This is its own license rather than CC0; see https://kenney.itch.io/creature-mixer.

`Assets/Generated/monster_atlas.png` is a nearest-neighbor packing of all 101 source sheets at their native 24×24 frame resolution. It does not replace the user's original sheets. Its license follows those source creatures.

`Assets/Generated/knight_sheet.png` was created for this project using OpenAI ImageGen, with the supplied creature and Tiny Town art as style references. It contains four walk frames and separate sword and shield cells. The atlas has actual alpha transparency and is rendered with nearest filtering.

`Assets/Generated/music_loop.wav` is an original 32-second, 24 kHz mono fantasy chiptune composed procedurally for this project. Its reproducible synthesis is in `tools/generate_music.py`; no existing song or third-party recording was sampled.

The bundled **Godot Play Game Services v3.4.0** plugin uses its preserved MIT license at `addons/GodotPlayGameServices/LICENSE`. Its source and setup documentation are linked from `PLAY_SERVICES_SETUP.md`. Vendor scripts and Android binaries were retained without modification.

Godot's built-in fallback font supplies interface text; no font was extracted from an asset sample image.
