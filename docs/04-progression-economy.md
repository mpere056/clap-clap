# 04 — Progression & Economy

> Numbers here are **starting points for tuning**, not final. Once the mode is decided, we'll build a pacing simulator (a small script that simulates a player clicking and buying optimally) to tune them.

## Curtain Call, Space and Rebirth (implemented 2026-10-27)

- **Curtain Call 🎭** (replaces "Graduate"): available any time from the City (after breaking through stage 3), as often as you like. Bouquets 💐 = 5 × 10^(0.18 × (best power − 9)) × 2^rebirths; each Bouquet is +10% clap power until the next Rebirth.
- **Pacing** (`python tools/pacing_sim.py`): stages 1–3 ≈ 10 min; Space after ≈ 4.8 h with no Curtain Calls; ≈ 62 min with optimal Curtain Calls (≈ 17 calls, calling whenever the multiplier would grow ×1.5).
- **Beating Space:** the escape-velocity meter fills by grade × combo per on-beat clap in Space (goal 30,000 ≈ 58 min of good clapping). It survives Curtain Calls.
- **Rebirth 🕊:** resets everything including Bouquets; permanent ×10 clap power and ×2 Bouquets per Rebirth. Cosmetics: wings (1), halo (2), clap trail (3). Settings: "clap power shown" slider (10–100%, visual only) and a cosmetics/titles toggle.

## Leaderboards (implemented 2026-10-27)

Score = Rebirths × 1000 + best clap power ever (log10). World top 100 via an OrderedDataStore (refreshed every minute); server ranks every 10 s.

| Rank | Reward |
|---|---|
| World #1 / #2 / #3 | gold / silver / bronze crown, big aura (rainbow for #1), announced when they join |
| World 4–5 / 6–10 | purple / blue aura + title |
| World 11–25 / 26–50 / 51–100 | sparkles / title / title |
| Server #1–5 | 🥇🥈🥉 / "SERVER #n" title, small sparkle for #1 |

Also: 🏆 panel (World top 100 / This server), a World top 10 board in the hall, and Rebirths / Stage / Power columns in the player list.

## Rhythm (implemented 2026-10-27)

Every clap is graded by its distance from the nearest beat (100 BPM, one beat every 0.6 s). The server grades the clap's own timestamp, so the result can't be faked.

| Distance from beat | Grade | Effect |
|---|---|---|
| ≤ 0.06 s | Perfect | ×3 Applause, builds streak |
| ≤ 0.12 s | Great | ×2, builds streak |
| ≤ 0.20 s | Good | ×1, builds streak |
| further, or a 2nd clap in the same beat | Miss | lose 2 claps' worth of Applause, streak resets |

- Combo = 1 + 2 × min(streak, 20) / 20 (×3 at a 20-beat streak); skipping up to 2 beats keeps the streak.
- Practice (+1 base power per 10 claps), Encore (150 claps → 6 doubling claps) and the Standing Ovation only count on-beat claps. Spamming loses Applause.
- HUD: a ring shrinks onto a target that lights up inside the hit window; a soft metronome tick plays every beat.

## Visiting earlier stages (implemented 2026-10-27)

- 🗺 Stages lets you return to any stage up to your current one.
- While visiting, manual clap power is capped at that stage's breakthrough power, then divided by 10 for each stage back (`VisitorGainPerStageBack`), so visiting is for showing off, not farming; classmates still earn at full power.
- Visitors' claps look much bigger to others (gold double rings, sparks) and they get a "⭐ STAGE N CLAPPER" title.
- Each on-beat clap from a visitor adds (stages ahead) × 1 to the Encore meter of every other player in that stage, and counts ×3 towards the Standing Ovation.

## Currencies

| Currency | Earned by | Spent on | Resets on Graduate? |
|---|---|---|---|
| **Clap Power (CP)** | Not earned; it's a *stat* = how strong one clap is | — (drives stage progress) | Yes |
| **Applause** | Every clap (manual + auto): `+CP × combo × boosts` | Upgrades | Yes |
| **Diplomas** 卒業証書 | Graduating (prestige) | Permanent Diploma upgrades | No |
| *Fans* (MP only) | Opening Lockers with Applause/Robux | Equip for multipliers | No |

## Clap Power formula

```
CP = (1 + StrongHands)                  -- additive base from levelled upgrade
     × Π(Technique tiers owned)         -- one-off ×2 / ×3 / ×5 upgrades
     × DiplomaBonus                     -- permanent, from prestige
     × FanBonus                         -- MP only
     × Boosts                           -- temporary potions / passes / server events
```

Per-clap Applause earned:

```
Applause = CP × Combo × CritMultiplier(if crit) × FrenzyMultiplier(if in frenzy)
```

Auto-clappers earn `CP × AutoEfficiency` per auto-clap, with no combo. That makes active play ~2–4× better than idle, but idle still progresses.

## Stage gating

A stage is cleared when **one clap's effective power** (`CP × Combo`) ≥ the stage threshold. The clap that crosses it *is* the Breakthrough clap, just like "clap #29 = one bomb" in the video. Encore Frenzy only multiplies Applause, not breakthrough power: its ×256 would otherwise skip whole stages.

> Implemented values (src/shared/Config.luau) were calibrated with `tools/pacing_sim.py` and differ from the illustrative tables below: techniques in stages 2–3 are ×10 each, Strong Hands has no ×2 milestones, Encore is 8 doublings per 400 claps.

### Current pacing (all 9 stages, `python tools/pacing_sim.py`)

Engaged rhythm player: stage 1 ≈ 1.6 min, then +3.6, +5.8, +7.3, +7.9, +9.1, +9.5, +10.6 → Space at ≈ 55 min. A sloppier player (70% hits) reaches Space at ≈ 63 min. Graduate unlocks on reaching Space; Diplomas = 10 × (power above the stage 8 threshold + 1)^1.5.

### Early-game feedback (2026-10-27, after first playtest)

Playtest finding: clapping without buying upgrades never moved the meter, and the first breakthrough felt far away. Changes:

- **Practice:** every 25 claps in a run adds +1 base clap power, so clapping alone visibly raises the dB meter (≈151 dB after 2 min with no purchases).
- **Tiers:** each stage has 4–5 named milestones (stage 1: Loud 120 dB → Painful → Deafening → Window-rattling → Glass-breaking 180 dB). Each tier-up shows a banner, plays a sting, sends a wave through the room and pays `CP × 40 × tier` Applause.
- **Faster start, longer later stages:** Strong Hands from 8 Applause, cheaper first techniques/classmates. Simulated at 6 clicks/s: stage 1 ≈ 0.8 min, stage 2 +1.9 min, stage 3 +3.6 min (3 clicks/s: 1.3 / +2.3 / +3.8).
- **Shop discoverability:** the Upgrades button glows with a badge when anything is affordable, plus a one-time "Spend Applause in Upgrades ➜" tip.
- Meter progress follows the run's best power, so it never slides back when the combo decays.

Internal thresholds (log₁₀ of CP):

| Stage | Threshold (log₁₀ CP) | Gap |
|---|---|---|
| 1 → 2 | 3 | — |
| 2 → 3 | 6 | ×1,000 |
| 3 → 4 | 9 | ×1,000 |
| 4 → 5 | 12.5 | ×3,000 |
| 5 → 6 | 16 | ×3,000 |
| 6 → 7 | 20 | ×10,000 |
| 7 → 8 | 24 | ×10,000 |
| 8 → 9 | 30 | ×1,000,000 |
| Extended 10–14 | +8 to +15 each | (MP only) |

### Display mapping (decoupled from balance)

Each stage has a **display range** (e.g. Stage 2 shows 1 kg → 1,000 kg). The fraction of progress through the stage maps log-linearly onto that range:

```
t = (log10(CP) - log10(T_start)) / (log10(T_end) - log10(T_start))     -- 0..1
display = 10 ^ lerp(log10(D_start), log10(D_end), t)
```

This lets us rebalance freely without breaking the "realistic-feeling" numbers on screen.

## Upgrades (Applause shop)

| Upgrade | Effect | Cost curve |
|---|---|---|
| **Strong Hands** | +1 base CP per level (scaled by later tiers) | `10 × 1.15^L` |
| **Clap Technique** (tiered, one-off) | Polite ×2 → Firm ×2 → Cupped ×3 → Thunder ×3 → Sonic ×5 → Seismic ×5 → Tectonic ×10 → Cosmic ×10 | Gated by stage, ~10³–10⁴× current Applause rate |
| **Classmates** (auto-clappers) | Classmate → Homeroom Teacher → Brass Band → Cheer Squad → Whole School → Town Choir… Each adds auto-claps/sec | `base_i × 1.12^owned` (classic idle curve) |
| **Rhythm** | Wider beat window; higher combo cap (×3 → ×5 → ×8) | Few levels, steep |
| **Thunderclap** (crit) | Crit chance 1% → 15%, crit ×5 → ×25 | Steep |
| **Encore** (frenzy) | Faster frenzy fill; longer chain (10 → 12 → 15 doublings) | Steep |

Classmates are **visible**: hired helpers appear around you clapping, and later tiers swap in bigger groups (the band on stage, etc.). Watching the room fill up is part of the reward.

## Combo / rhythm

- Beat pulse at ~1 Hz (speeds up slightly with upgrades).
- On-beat window: ±150 ms (generous; widened for touch input).
- Each on-beat clap: combo +1 step; missed beat (no clap for 2 beats): combo decays by one step rather than resetting (forgiving).
- Off-beat claps still count, they just don't build combo.
- Server caps clap rate (see doc 08), so autoclickers don't break the economy.

## Graduate (prestige)

- **Unlock:** first time at Stage 7 (the globe). Recommended/natural point: Earth shatters (end of Stage 9).
- **Reward:** `Diplomas = floor( (log10(peakCP) - 18)^1.6 )` (illustrative), so deeper runs pay more.
- **Resets:** Applause, upgrades, stage, classmates.
- **Keeps:** Diplomas, Diploma upgrades, cosmetics, Fans (MP), stats.
- **Diploma upgrades:** +% CP (stacking), start with N classmates, keep Technique tiers up to stage X, faster frenzy, auto-buy upgrades, "Skip Stage 1 cinematic", higher combo cap.

## Pacing targets

### Singleplayer (~30 min to Earth shattering)

| Stage | Cumulative time |
|---|---|
| 1 Ceremony | 0 → 3 min |
| 2 Gym | → 6 |
| 3 Town | → 9 |
| 4 City | → 13 |
| 5 Region | → 16 |
| 6 Country | → 19 |
| 7 Planet | → 23 |
| 8 Molten | → 27 |
| 9 Space / ending | → 30 |

Optional New Game+ (Graduate) for players who want more, roughly 2–3 more hours total.

### Multiplayer (~10 h to "complete", long tail after)

| Milestone | Target playtime |
|---|---|
| First Breakthrough (Stage 2) | 2–3 min |
| First Earth shatter (end of run 1) | **45–60 min**: the video moment lands in session one |
| Graduate #1 → run 2 hits Earth in ~20 min | ~1.5 h |
| Unlock Stage 10 (Moon) | ~2.5 h (Graduate #3) |
| Stage 12 (Sun) | ~5 h |
| Stage 14 (Galaxy) | **~10 h** |
| Long tail | Graduate ranks, Fan collection, leaderboards, events |

## Big numbers

Values will exceed `1e308` (Lua double max) in the long-form version. We store numbers as **log₁₀ (or mantissa + exponent)** from the start, so this never becomes a rewrite. Display formats:

- Short suffixes: K, M, B, T, Qa, Qi, … then scientific `1.23e45`.
- Japanese flavour in captions only: 万 (10⁴), 億 (10⁸), 兆 (10¹²), 京 (10¹⁶), as in the video.
