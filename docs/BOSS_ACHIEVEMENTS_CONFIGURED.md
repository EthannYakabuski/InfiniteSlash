# Boss achievement IDs configured — 2026-10-15

Both owner-supplied IDs are now in `config/play_services.json` as **Standard** achievements. The original twelve achievement mappings, four Incremental targets, three leaderboards, package and saved-game slot remain unchanged.

| Key | Name | Google ID |
| --- | --- | --- |
| `rare_boss` | Royal Upset | `CgkI5NXU8p0YEAIQEA` |
| `all_bosses` | Crown Census | `CgkI5NXU8p0YEAIQEQ` |

There are now **14 configured online achievements**, representing 14 distinct goals. The game retains 15 local keys because the two historical 180-second keys share a goal; remote `survivor_180` remains intentionally blank.

Existing local rare-boss and all-boss awards are retained. After eligible Google authentication/account binding, the adapter submits their earned Standard unlocks through the new IDs. Successful acknowledgements clear the corresponding pending awards; unsuccessful attempts retain them for a later session. No progress reset or save migration is needed.

The full services suite passed **166 checks**, including exact ID mapping, Standard-versus-Incremental dispatch, offline award persistence/replay, duplicate submission protection and acknowledgement handling. Evidence: `output/review/configured_boss_achievements_services.log`. These checks use simulated clients and do not establish a live Google server result. Gameplay logic is unchanged from the tested 0.2.0 update.

The [boss icon archive](../store/boss-achievements/InfiniteSlash-new-boss-achievements.zip), [registration record](../store/boss-achievements/README.md) and [complete store kit](../store/README.md) now contain both real IDs. The two icon PNGs are unchanged. Asset validation passes with 43 images, 14 configured achievements, zero pending IDs and three boards.

Updated Android builds are version **0.2.1 / code 7**, so they can replace the previous code-6 upload. Use a higher unused code if your track has already consumed 7. [Current build and signature evidence](BOSS_ACHIEVEMENTS_BUILD.md). Earlier versioned bundles and their verification records are retained.

The owner still controls Play Games definition publication and tester access. If the two new definitions remain drafts, publish them when ready for the intended release audience; publishing the Android app and publishing Play Games definitions are separate owner actions.
