# Playable Web demo

The GitHub Actions **Test and deploy Web demo** workflow imports Godot 4.5.1,
tests gameplay/services/UI/audio, exports the `Web` preset and deploys only
`builds/web` to GitHub Pages after the checks pass on `main`.

Expected URL: https://ethannyakabuski.github.io/InfiniteSlash/
`build-info.json` identifies the exact deployed source commit. Actions also
retains a downloadable `infiniteslash-web` artifact for seven days.

## Local build

With Godot 4.5.1 and matching export templates installed:

```sh
godot --headless --editor --path . --import --quit
mkdir -p builds/web
godot --headless --path . --export-release Web builds/web/index.html
python3 tools/package_web.py builds/web
python3 -m http.server 8000 --directory builds/web
```

Open http://localhost:8000/; opening `index.html` as a filesystem URL is unsupported.
Tests write fixture reports: run them in an isolated checkout if owner review
evidence or unrelated edits are present. Android export presets remain separate.

## Controls and embedding

Drag one pointer to steer; attacks happen automatically. Keyboard movement also
works, with optional Space dash and Escape pause. Click/tap inside the game to
give it focus and permit browser audio. Native Google Play Games and AdMob are
unavailable in Web; progress stays in that browser's local storage.

The single-threaded Compatibility export needs WebGL 2 and WebAssembly, without
SharedArrayBuffer or cross-origin isolation headers. Keep every generated file's
name and relative location. For a later website integration, use this game's
HTTPS URL as the iframe source with a portrait-friendly responsive container and
allow fullscreen. No parent website is modified by this repository's deployment.

Browser policy can partition or block iframe storage, especially in private mode;
iframe persistence, mobile-browser performance and audible output need separate
testing. A successful build or absence of frame-blocking headers does not prove
interactive iframe acceptance. Asset credits and preserved license notices ship
beside the game under `CREDITS.md` and `licenses/`.
