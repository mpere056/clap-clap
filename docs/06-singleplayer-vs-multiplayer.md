# 06 — Singleplayer vs Multiplayer

**Status: DECIDED (2026-10-27) — multiplayer, built singleplayer-first.** Standing Ovation and In Sync are confirmed favourites. How clap effects on the environment work with several players is in [10-multiplayer-effects.md](10-multiplayer-effects.md). The rest of this doc is kept as the reasoning behind the decision.

## First: what "multiplayer incremental" means on Roblox

Most popular Roblox incremental / simulator games are multiplayer, but **not interactive in a competitive way**. A server holds roughly 10–20 players who:

- each have **their own progress** (own currency, upgrades, stage),
- **share a world**, so you see other people clapping, their pets/helpers, their flashy titles,
- get **soft social features**: leaderboards, server-wide boosts, events, friend bonuses, trading, chat.

Nobody can hurt anyone else's progress. "Multiplayer" mostly means *company, comparison and shared hype*, which fits a non-PvP incremental game well.

## The core problem multiplayer has to solve here

The video's magic is the **camera pulling back** as power grows. In a shared world, players are at different stages at the same time. Player A is in the ceremony hall, player B is clapping at the globe.

**Solution: stages are "worlds".** Each stage diorama exists once in the server, far apart. Your character is placed in the stage you've reached (or any earlier one you choose to revisit). Everyone at the same stage shares that diorama:

- **Ceremony:** a big hall with ~20 seats. Players at Stage 1 sit in the seats, in first-person view, and see each other clapping.
- **Gym / Town / City:** players stand on the shared diorama; the camera rig follows each player at that stage's scale.
- **Planet / Molten:** the globe is a **mini-planet** players stand on, giant-sized, like tiny-planet games. Everyone's clap blasts ripple across the same globe.
- **Space:** everyone floats among the Earth fragments together.

Breakthrough cinematics play **locally** for the player who broke through; others see a flash and that player "warping" to the next world. A broadcast ("**Player123** just shattered the Earth! 🌍💥") gives everyone else a reason to keep going.

Each player's camera, hands, HUD and audio are **client-side**, so each player sees their own personal view. Only the world itself is shared.

## Multiplayer features (non-PvP)

| Feature | What it does | Why |
|---|---|---|
| **Standing Ovation** (server meter) | Every clap from everyone fills a shared meter. When full: server-wide ×2 Applause for 5 min + celebration effects | Makes other players *helpful*; cooperative hype |
| **In Sync bonus** | 3+ players clapping on the same beat get a combo bonus | Leans on the rhythm mechanic; spontaneous co-op |
| **Breakthrough broadcasts** | Announce milestones server-wide | Social proof, aspiration |
| **Leaderboards** | Highest Clap Power, total claps, Graduations | Long-term goals, bragging |
| **Fans / Cheer Squad** (pets equivalent) | Collectible helpers from "Lockers" (eggs). They follow you, cheer, give multipliers | Core long-tail and monetisation loop in this genre |
| **Friend bonus** | +10% Applause per friend in server | Invites, retention |
| **Titles & cosmetics** | Clap trails, hand skins, auras, uniform colours | Self-expression, visible status |
| **Events** | Timed "Encore Hour", seasonal stages | Live-ops, return visits |
| **Trading** (later, optional) | Trade Fans | Big engagement driver but adds scam/moderation risk; post-launch only |

## Comparison

| | **Singleplayer (~30 min)** | **Multiplayer (~10 h)** |
|---|---|---|
| Matches the video | ✅ Closest, a tight cinematic experience | ✅ Same core; video moment lands in session 1 |
| Build effort | Lower | Higher (worlds, social systems, Fans, more stages, live-ops) |
| Time to first playable | Fastest | Same core first; extra layers after |
| Roblox discovery | ⚠️ Weak. Short sessions and low return rate make it hard for Roblox to recommend the game | ✅ Long sessions, daily returns and concurrent players are what the genre thrives on |
| Monetisation | Minimal (a pass or two; little reason to buy in a 30-min game) | ✅ Standard simulator model (passes, boosts, Lockers) |
| Replayability | Low (seen it once) | High (prestige, collection, events, leaderboards) |
| Risk | Low build risk, high "nobody finds it" risk | Higher build risk, competing in a crowded genre |
| Fits "short viral hook" | ✅ | ✅ (if run 1 is fast) |

## Recommendation: **Multiplayer, built as "singleplayer-first"**

1. **The first run plays like the singleplayer version.** A tight, cinematic 45–60 minutes from ceremony to Earth shattering. That's the hook and what people will clip and share.
2. **Then it opens up into a multiplayer simulator:** Graduate (prestige), Fans, extended stages (Moon → Galaxy), events, leaderboards, for the ~10 h target.
3. **Build order de-risks it.** The core (clapping, upgrades, stages, cinematics, HUD, audio, saving) is ~80% identical in both modes. We build that first in a way that already supports several players per server. If the core isn't fun, we find out before spending time on Fans and monetisation.

Why not pure singleplayer: on Roblox, a 30-minute experience with no reason to return is very hard to get discovered, and there's little to monetise. Why not jump straight into a big multiplayer build: the hook is the cinematic escalation, and that must feel great first.

## What changes depending on the decision

| Area | Singleplayer | Multiplayer |
|---|---|---|
| Stage dioramas | Built for 1 player | Built for ~20 (seats, mini-planet, spawn points) |
| Max players per server | 1 | ~16–20 |
| Economy pacing | 30-min curve | Hybrid curve (doc 04) |
| Extended stages 10–14 | Not needed | Needed for 10 h |
| Fans / Lockers | No | Yes |
| Monetisation | 1–3 passes | Full set (doc 07) |
| Social systems | None | Ovation, In Sync, broadcasts, leaderboards |

## Questions for you before we decide

1. Happy with **"singleplayer-first multiplayer"** (cinematic first run → simulator after)?
2. **Fans / Lockers** (the pets-and-eggs equivalent): include them? They're the backbone of monetisation and long-term play in most popular simulators, but they add the most build work and policy requirements (doc 07).
3. **Mini-planet** for the Earth stages (players standing on a small globe together), or keep a pure "camera in space" view where other players appear as glowing dots?
4. **Trading:** never, or maybe post-launch?
5. Any **reference games** you like on Roblox whose feel or monetisation we should study?
