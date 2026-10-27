# 09 — Roadmap

## Phase 0 — Decisions (now)

- [x] Singleplayer vs multiplayer → **multiplayer, singleplayer-first** (2026-10-27)
- [ ] Confirm the multiplayer effects model: local destruction, shared presence (doc 10)
- [ ] Fans/Lockers in or out (doc 06 Q2)
- [ ] Mini-planet vs space camera for Earth stages (doc 06 Q3)
- [ ] Tooling: Rojo + git, or direct-in-Studio via MCP (doc 08)
- [x] Title → **👏 Clap Clap** (2026-10-27)
- [ ] Reference games to study (optional)

## Phase 1 — v1 vertical slice (proves the fun) — **first playable built 2026-10-27**

Built and tested in Studio: all items below except saving (needs the place published) and a real multi-client test of Ovation / In Sync (code paths smoke-tested solo).
Known rough edges: blocky placeholder hands, Creator Store placeholder audio, no shopping-arcade cut, no "street cut".

**Goal:** someone plays for 10–15 minutes and wants to keep clapping.

Scope:
- Stages **1 Ceremony**, **2 Gym shockwave**, **3 Town** (aerial), with Breakthrough cinematics between them
- First-person hands + clap feedback (anim, VFX, screen punch, number pops)
- HUD in the video's style: clap count `回目`, "1 clap =", gold number, dB meter, captions, beat ring
- Applause + upgrades: Strong Hands, 3–4 Technique tiers, 3 Classmate types (visible), Rhythm combo, Encore Frenzy
- Layered clap audio per stage + ceremony ambience
- Saving (ProfileStore), server-authoritative clap flow
- Works on PC and mobile
- Multiplayer from the start: several players share the hall, local destruction + scaled-down effects from others (doc 10)
- **Standing Ovation** meter and **In Sync** bonus (cheap to build, and they prove the multiplayer fun early)

Exit criteria: playtest feels good, clap feedback is satisfying, pacing roughly 3 min per stage.

## Phase 2 — Full core run

- Stages 4–9 including Earth melting, shattering and the space silence beat
- All captions, reactions and unit switches
- Graduate (prestige) + Diploma upgrades
- Ending card
- Balance pass with the pacing simulator

*If singleplayer:* polish + minimal passes → **launch**.

## Phase 3 — Multiplayer layer (if chosen)

- Stage worlds shared by players, seats/spawns, warping on Breakthrough
- Standing Ovation meter, In Sync bonus, broadcasts, friend bonus
- Leaderboards
- Fans + Lockers (if chosen), with odds display + PolicyService checks
- Monetisation set (doc 07), daily/playtime rewards, codes

## Phase 4 — Long form & launch

- Extended stages 10–14 (Moon → Galaxy)
- Tuning to the ~10 h target
- Thumbnails, icon, trailer clip (the Earth-shatter + silence moment is the obvious clip)
- Soft launch → watch retention/session length → iterate

## Phase 5 — Live ops

- Events (Encore Hour, seasonal stages, e.g. a cherry-blossom spring ceremony)
- New Fans, cosmetics
- Trading (if ever)

## Open questions (master list)

| # | Question | Doc |
|---|---|---|
| 1 | ~~Singleplayer or multiplayer?~~ Multiplayer | 06 |
| 1b | Other players at town scale: giants or tiny figures? Breakthrough aftershock? Rebuild animation? | 10 |
| 2 | Include Fans/Lockers? | 06, 07 |
| 3 | Mini-planet or space camera for Earth stages? | 06 |
| 4 | Trading ever? | 06 |
| 5 | Rojo + git, or MCP-only? | 08 |
| 6 | ~~Working title?~~ 👏 Clap Clap | 02 |
| 7 | Keep Japan as the setting for Stage 6, or a fictional island nation? | 03 |
| 8 | Include the "street cut" (passer-by + dog) in v1? | 03 |
