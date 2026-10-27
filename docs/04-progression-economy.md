# 04 — Progression & Economy

> Numbers here are **starting points for tuning**, not final. Once the mode is decided, we'll build a pacing simulator (a small script that simulates a player clicking and buying optimally) to tune them.

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
