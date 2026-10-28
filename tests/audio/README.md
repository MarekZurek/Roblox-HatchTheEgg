# Native Studio reward SFX regression

Requirement: user request 2026-10-28 — fix the two gift sound loading errors and verify actual playback. Each default `coin`/`pop` must reference Roblox Audio, preload successfully, play with an advancing cursor and clean up after its decoded duration. The oracle uses `Enum.AssetType.Audio`, fetch success, decoded duration and runtime observations, rather than a copied list of expected IDs. Lune counters alone cannot verify this.

`studio_asset_check.luau` returns a test function taking the actual AudioController ModuleScript. It requires a local Studio **Play client with client Main temporarily disabled** and no existing HatchTheEggAudio folder. Confirm Edit/local memory before starting your own Play; never stop someone else's test. Through Studio MCP, execute this file's source in a wrapper function to obtain `run`, then call:

```luau
local result = run(game.Players.LocalPlayer.PlayerScripts.HatchTheEggClient.AudioController)
```

The test clones the module to avoid require caching, creates its real SoundService objects and cleans up its own controller/module after PASS or assertion FAIL. Native sound signals and timing require Play, not Edit. AudioController destroys Sound inside Ended; with deferred signals a later test Ended callback can be disconnected by destruction. Assertions therefore observe cursor progression into the final quarter and destruction near decoded duration, before the four-second fallback. No manual sound asset IDs are duplicated in the oracle.

Regression reproduction: create an isolated module clone, restore only the old coin ID135483737426662→9069609203, then run it: intended assertion `coin: expected Audio asset, got type 9`. Repeat for pop140323850218372→9069609204: intended pop assertion. Corrected original must PASS again. Do not mutate the production module or leave test clones in the scene.

Then stop your own Play, restore client Main.Enabled=true and run the full game. Observe actual `DroneRewardPopup` plus SFX instances while collecting a naturally generated landed gift: both sounds loaded, cursor advances, nonzero PlaybackLoudness, one pair per pickup, no loading errors. This integration observation is separate from the isolated asset regression. Remove probes, stop own Play and restore exact source. Test file is outside default.project.json and is intentionally not a Lune suite or production script.

[Recorded FAIL→PASS and native integration](../../docs/workflow/gift_audio_2026_10_28.md).
