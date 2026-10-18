# AdMob interface contract

The interface keeps the existing one-tap launch, portrait HUD, paused upgrade choices, independent audio switches, and results screen. Native ads are controlled by `Ads` and `game.gd`; `game_ui.gd` only reserves the space reported by that service and displays the player's decisions.

## Banner placement and units

`set_ad_banner_space(top_px, bottom_px)` accepts **physical pixels**, using the native SDK's measured banner height. The interface converts each height to logical viewport units with:

```text
logical height = physical banner height × logical viewport height / native window height
```

The window height comes from `DisplayServer.window_get_size()`. A screen-height fallback handles an unavailable window size. Conversion runs again on a viewport resize. Negative, zero, or non-finite heights reserve no space.

| Overlay kind | Effective reserved space |
| --- | --- |
| `launch` | Top banner only |
| `pause` | Top banner only |
| `upgrade` | Bottom banner only |
| `audio`, `scores`, `achievements`, `end`, `continue`, `ad_waiting` | None |
| Empty string: active gameplay | None |

The caller must hide or destroy native banners on the excluded screens. The interface immediately ignores stale measured heights on those screens as an additional layout safeguard. It does not create a banner placeholder or request an ad.

Existing mobile safe-area margins remain in force. An eight-logical-pixel gap separates a loaded banner from interactive content. A zero-height/no-inventory callback restores the original spacing without an empty advertisement slot. Paused health, score and pause/audio controls move below a top banner. Level-up choices remain above a bottom banner.

Overlay content is centered in a vertically clipped scroll container inside the available safe band. Unusually tall cards remain reachable by scrolling rather than drawing over a native banner. Upgrade choices preserve their exact pending data when opening and returning from audio settings, and keep their existing one-selection lock.

## Overlay notifications

`overlay_changed(kind: String)` is emitted after each overlay is constructed, and with `""` after hiding it. The root uses this to select native banner placement. Current kinds are `launch`, `pause`, `upgrade`, `audio`, `scores`, `achievements`, `end`, `continue`, `ad_waiting`, and `""`.

## Rewarded continue

The root calls `show_continue_offer(data = {})` only when the current death is eligible and a rewarded ad is available. The paused offer contains:

- **Watch ad • Full restore** → `rewarded_continue_requested`.
- **End run** → `continue_declined`.

Either decision immediately disables both buttons. A card-identity guard also rejects callbacks from a replaced card, duplicate taps, and the competing choice. `show_ad_waiting(message)` replaces the offer with a paused, non-interactive waiting screen while the native ad is opening. Auxiliary Back/close actions cannot dismiss the continue offer or skip a pending level-up choice.

`game.gd` owns the once-per-run limit and reward validation. A completed reward restores full health and full guard with brief protection, while the run's score, counters, choices, achievement progress, and leaderboard eligibility are retained. The interface never resets or changes those values. Declining, an unavailable/failed ad, closure without a reward, or a later death uses the existing `show_end(data)` results flow.

## Privacy options

`set_privacy_options_required(required)` exposes **PRIVACY CHOICES** within the existing audio/settings panel only when Google's consent service requires the entry point. The panel title becomes SETTINGS and its entry button reads AUDIO & PRIVACY. Pressing the privacy button emits `privacy_options_requested`; the root/service opens the native UMP form. Music/SFX controls and the previous overlay data remain intact. The root handles gameplay/audio freezing during native consent/privacy forms.

## Verification

- `tests/test_ad_ui.gd`: **236 checks, zero failures**, both headless and with the actual OpenGL renderer, at 540×960, 540×1110, and 1080×1920 physical window sizes. Checks use actual GUI input and cover banner conversion, safe clipping, reachable touch targets, privacy visibility, audio return state, exact upgrade choices, duplicate reward decisions, old results buttons, invalid heights, and no-inventory layout.
- `tests/ui_layout_test.gd`: existing complete portrait UI regression suite passed at all three sizes, including class cards, rare/legendary/trade choices, independent audio, locked pending choices, local score/badge views, HUD and real one-tap input.
- `tests/capture_ad_ui.gd`: **24 rendered screenshots**, eight states at all three sizes, under `output/review/ad-ui/`. `captures.json` records window, image and logical viewport dimensions and the effective banner insets.
- At a physical 1080×1920 window and logical 540×960 viewport, 100/160 physical banner pixels reserve **50/80 logical pixels**. The smaller two captures use a scale of one. Home, pause, level-up, settings/privacy, continue, waiting, results and no-inventory layouts were reviewed visually.

The screenshot script draws clearly labeled **test-only native-space fixtures** to make reserved areas inspectable. Those strips are not served ads and are never part of the game UI. These checks establish layout and input behavior, not native ad delivery, fill rate, UMP account configuration, or real-device ad presentation. Native SDK/Android results are documented separately by the root integration report.

Evidence: `output/review/ad_ui_validation.json`, `ad_ui_rendered_tests.log`, `ad_ui_legacy_runtime.log`, `ad_ui_capture.log`, and `ad-ui/captures.json`.
