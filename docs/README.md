# Clap Incremental — Design Docs

Title: **👏 Clap Clap** (with a hook subtitle where space allows, e.g. "👏 Clap Clap: Destroy the Earth!"; logo flavour: パチパチ).

A Roblox incremental game inspired by the *"What if every clap were twice as loud?"* video: you keep clapping at your graduation ceremony, each clap gets stronger, and the camera pulls back further and further — hall → gym → town → city → country → Earth → space.

## Status

**Phase 1 (v1 vertical slice) playable in Studio** — stages 1–3 with breakthroughs, clapping, upgrades, classmates, combo/beat, Encore, Standing Ovation, In Sync, local destruction. Mode: **multiplayer, singleplayer-first**. Remaining open questions are in [09-roadmap.md](09-roadmap.md). How to work on the code: [../DEVELOPMENT.md](../DEVELOPMENT.md).

## Documents

| # | Doc | What it covers | Depends on SP/MP decision? |
|---|-----|----------------|---------------------------|
| 01 | [Video reference](01-video-reference.md) | Breakdown of the source video: timeline, scenes, HUD, audio | No |
| 02 | [Game concept](02-game-concept.md) | Pillars, core loop, what the player does minute to minute | Mostly no |
| 03 | [Stages](03-stages.md) | Every stage: scene, camera, units, cinematic, reactions, sound | Mostly no |
| 04 | [Progression & economy](04-progression-economy.md) | Currencies, upgrades, stage gating, prestige, pacing targets | **Yes** (pacing) |
| 05 | [Art, UI & audio](05-art-ui-audio.md) | Visual style guide, HUD spec, colours, fonts, sound design | No |
| 06 | [Singleplayer vs multiplayer](06-singleplayer-vs-multiplayer.md) | Options, how multiplayer would work, recommendation | — (this *is* the decision) |
| 07 | [Monetisation](07-monetisation.md) | Game passes, dev products, policy constraints | **Yes** |
| 08 | [Technical architecture](08-technical-architecture.md) | Roblox services, scripts, data, camera/stage system, tooling | Slightly |
| 09 | [Roadmap](09-roadmap.md) | Phases, v1 scope, open questions | **Yes** |
| 10 | [Multiplayer effects](10-multiplayer-effects.md) | How clap power affects the environment when several players share a stage | — (multiplayer) |

## Decisions made so far

| Decision | Choice | Date |
|---|---|---|
| UI language | English main UI, Japanese labels as flavour (e.g. `回目`, `卒業証書授与式`) | 2026-10-27 |
| PvP | None. Co-operative / parallel incremental only | 2026-10-27 |
| Session length target | ~30 min if singleplayer; ~10 h to "complete" if multiplayer | 2026-10-27 |
| Originality | Own models, text and layout; concept inspired by the video, no copied scenes, script or watermark | 2026-10-27 |
| Wording | Use TNT / megatons / "meteor impacts" instead of "nukes" | 2026-10-27 (proposed) |
| Singleplayer vs multiplayer | **Multiplayer, singleplayer-first** (doc 06) | 2026-10-27 |
| Social features | Standing Ovation meter + In Sync bonus confirmed as wanted | 2026-10-27 |
| Title | **👏 Clap Clap** (check Roblox for name clashes before launch) | 2026-10-27 |
| Environment effects in MP | Local destruction, shared presence (doc 10) — proposed | 2026-10-27 |
