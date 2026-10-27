# 08 — Technical Architecture

Built **multiplayer-ready from day one**, even if we ship singleplayer. Server-authoritative data costs almost nothing extra, and it means the mode decision never forces a rewrite.

## Tooling (proposal)

| Concern | Proposal | Notes |
|---|---|---|
| Code | Luau source files in this repo, synced into Studio with **Rojo** | Version control, diffs, I can edit files directly. Needs Rojo installed (CLI + Studio plugin) |
| World building | Built in Studio via the **Roblox Studio MCP** (and by hand) | Dioramas, lighting, UI layout prototyping |
| Version control | `git init` this folder | Not a git repo yet |
| Data | **ProfileStore** (community library) on top of DataStoreService | Session locking, safe saves; avoids duplication bugs |
| Testing | Studio playtests via MCP (`start_stop_play`, console output), unit tests for economy maths | Pacing simulator script for balance |

*Alternative without Rojo:* write scripts directly into Studio through the MCP. Faster to start, worse for history and review. **Decision needed.**

## Place hierarchy

```
ReplicatedStorage/
  Shared/
    Config/
      Stages.luau          -- thresholds, display ranges, camera rig names, captions
      Upgrades.luau        -- costs, effects, gating
      Classmates.luau
      Fans.luau            -- (MP) rarities, odds, multipliers
      Products.luau        -- game pass / dev product IDs
    BigNum.luau            -- log-space number type + formatting
    Formulas.luau          -- CP, Applause, costs, prestige (pure, unit-tested)
    Format.luau            -- K/M/B…, units, JP 万/億/兆/京
  Remotes/                 -- RemoteEvents / RemoteFunctions
  Assets/                  -- hands viewmodel, VFX, UI templates

ServerScriptService/
  Services/
    DataService            -- ProfileStore load/save, session lock
    ClapService            -- receives claps, validates rate/timing, awards Applause
    UpgradeService         -- purchases with Applause
    StageService           -- breakthrough detection, moves player to stage world
    PrestigeService        -- Graduate
    AutoClapService        -- server tick for classmates
    MonetisationService    -- passes, ProcessReceipt (idempotent)
    SocialService          -- (MP) Ovation meter, In Sync, broadcasts, friend bonus
    LeaderboardService     -- (MP) OrderedDataStore
    FanService             -- (MP) Lockers, equip

StarterPlayerScripts/
  Controllers/
    InputController        -- mouse/tap/Space/gamepad → clap
    ClapFeedbackController -- hands anim, VFX, screen punch (predicted locally)
    CameraController       -- per-stage camera rigs, breakthrough tweens
    HUDController          -- numbers, meter, captions, beat ring
    AudioController        -- layered clap, beds, space silence
    CinematicController    -- breakthrough sequences
    ShopController / MenusController

Workspace/
  Stages/
    S1_Ceremony/   S2_Gym/   S3_Town/   … (each far apart, own CameraRig parts)
```

## Clap flow (networking)

1. Client input → **immediate local feedback** (animation, sound, VFX, predicted number pop). Zero perceived latency.
2. Client batches claps and sends `ClapBatch {count, beatHits}` every ~0.1–0.2 s (not one remote per clap).
3. Server validates:
   - rate cap (e.g. ≤ 20 claps/s, plus Auto Clap pass rules),
   - beat hits ≤ claps and plausible for elapsed time,
   - then computes Applause **server-side** from its own copy of the player's stats.
4. Server replicates authoritative values (Applause, CP, stage) via attributes or a replica module. Client reconciles the HUD smoothly.
5. Breakthrough detection happens **on the server**, which tells the client to play the cinematic and moves the character to the next stage world (MP).

## Environment effects (multiplayer)

Destruction and bystander reactions are **client-side**, driven by each player's own stage progress. Only positions, players and numbers are shared. Other players' claps are shown as a throttled, scaled-down layer; Ovation, In Sync and Breakthroughs are server-timed shared events. Full design: [10-multiplayer-effects.md](10-multiplayer-effects.md).

Additional client controller: `EnvironmentController` (applies `DamageState(stage, t)`, plays pooled per-clap bursts, renders other players' `ClapPulse`s).

## Stage / camera system

- Each stage `Model` contains: `CameraRig` parts (start/end), player spawn points/seats, NPC reaction rigs, VFX anchors, lighting preset (attributes).
- `CameraController` uses `Camera.CameraType = Scriptable` for cinematic stages and tweens between rigs.
- **Scale limits:** max part size is 2048 studs per axis. Planet-scale scenes use *perceived* scale (camera distance, FOV, fog, small but detailed models), not real size.
- **Lighting presets** are swapped client-side per stage (Lighting properties + Atmosphere + ColorCorrection + Sky).
- **StreamingEnabled** on, so only nearby stage worlds stream to each client. Stages sit far apart so they don't overlap.
- Mini-planet (MP option): custom gravity via `VectorForce` / `AlignOrientation` toward the planet centre for characters at stages 7–8.

## Data model (per player)

```lua
{
  version = 1,
  applause = BigNum,        -- log-space
  cpBase = number,          -- Strong Hands level etc.
  upgrades = { [id] = level },
  techniques = { [id] = true },
  classmates = { [id] = count },
  stage = 1, highestStage = 1,
  peakCP = BigNum,
  diplomas = BigNum, diplomaUpgrades = { [id] = level },
  graduations = 0,
  fans = { owned = {...}, equipped = {...} },   -- MP
  stats = { totalClaps = 0, playTime = 0, breakthroughs = 0 },
  settings = { music = 0.6, sfx = 0.8, skipSeenCinematics = true },
  purchases = { [receiptId] = true },             -- idempotency
  firstSeen = os.time(),
}
```

## Big numbers

- `BigNum` stored as `log10` value (single float) for currencies/power. Simple, fast and fine for incremental maths (multiplication becomes addition; addition uses `log10(10^a + 10^b)` helpers).
- Saved to DataStore as a number (log value), so it's tiny.

## Security & anti-exploit

- All currency/stage changes on the server; clients only *request*.
- Rate caps per player; ignore impossible batches.
- Purchases validated with `MarketplaceService`; receipts recorded in the profile.
- Remotes validate argument types.

## Performance targets

- 60 FPS on mid-range mobile in the Ceremony hall with 20 players clapping.
- VFX pooled; clap sounds throttled (doc 05).
- Classmate NPCs: simple rigs, client-side animation, LOD/hidden at distance.
