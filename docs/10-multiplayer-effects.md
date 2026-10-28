# 10 — Clap Effects in Multiplayer

**The problem:** a clap has to *visibly wreck the environment*: chairs fly, windows burst, dust rings, the crater grows, the planet cracks. With up to ~20 players sharing one stage world, each at a different power level, whose clap wrecks what? If one player's clap really destroyed the shared hall, everyone else would see their world wrecked by someone else, and a fresh player would walk into a ruin.

## Options considered

| Option | How it works | Verdict |
|---|---|---|
| **A. Shared server physics** | Server simulates destruction; everyone sees the same debris | ❌ Chaotic and laggy (physics replication for 20 players clapping 5–10×/s), griefable, a new player's world is already destroyed, hard to "reset" |
| **B. Private copy per player** | Each player gets their own copy of the stage diorama | ❌ Memory heavy (20 copies of every stage), and you lose the "we're all in the hall together" feeling |
| **C. Local destruction, shared presence** ✅ | The world *layout* is shared; destruction is simulated **on each player's own device**, driven by *their* power | ✅ Recommended |

## Recommended model: local destruction, shared presence

### 1. Shared: where everyone is
The server owns the stage worlds and the player characters. You see other players sitting, standing and clapping, their Fans, cosmetics and name tags. This is the multiplayer part.

### 2. Local: what *your* claps do to the world
All destruction and environment reactions run **client-side**, on your device only, at full power:

- **Persistent damage = your progress.** The state of your world is a function of how far through the stage *you* are. At 30% the chairs are pushed back, at 60% the windows are cracked, at 90% the curtains are torn and the lights hang loose. Because it depends only on your progress, it can always be recalculated. Rejoin, teleport or switch device and your world looks exactly as it should.
- **Per-clap bursts on top.** Every clap fires a temporary burst: shockwave ring, dust, chairs hopping, NPCs flinching, camera shake, sound. Debris springs out, then settles or drifts back so the scene never becomes a pile of junk (the "breathing world").
- **Bystander NPCs are local too.** Each player has their own crowd of classmates and townsfolk reacting to *their* claps. With nothing replicated, there's no lag.

So two players in the same gym see the same building and each other, but each sees **their own level of destruction**. Nobody can ruin anyone else's world, and a new player always starts in a pristine hall.

### 3. Every clap pushes the world, for everyone (2026-10-27)
The lasting damage (section 2) stays yours. But each clap, yours or anyone's, also gives the
stage a **temporary shove** that heals after a few seconds. Every client applies every clap the same
way (yours right away, others' from their clap pulse), so all players in the stage see the same
chairs fly. Nothing is replicated except the pulse.

**Clap force** `F = Formulas.clapForce × grade × "clap power shown"`. F is 1 once a stage is
maxed, and a visitor adds 1 per stage they're ahead. In the hall it starts at 0 (the first claps
barely register). Later stages start higher (0.15 in the gym, 0.3 from the Town on), since you've
already wrecked a hall by then. Perfect hits hardest (×1), Great ×0.85, Good ×0.7 and Miss ×0.2.
The reach grows with F (hall scale: `6 + 25·min(F,1) + 30·max(F−1,0)` studs, times the stage's
reach scale below). The force at an item falls off with distance: `F·(1−d/reach)^1.5`. Each kind
of item needs a minimum force before it reacts. Items can set their own `Resist` / `Launch`
attributes (the Town tunes every prop for its own force range: see 03-stages). Parts in a Model
marked with a `DamageKind` move as one (cars, trees, fences). Default thresholds:

| Force (clap force F for the clapper's own effects, force at the item for props) | What happens |
|---|---|
| any | The hands pop (a white disc in rays); nothing else on a fresh stage |
| 0.04 | Small props hop |
| 0.05 | Dust puff at the clapper's feet |
| 0.1 | Chairs scoot, then fly; the classmates ride along. Players' chairs fly with their seat and whoever is sitting in it (never from your own clap) |
| 0.12 | Shockwave ring |
| 0.25 | Sparks, flying chips |
| 0.3 | Windows shatter into shards (reaching twice as far: sound carries), and the panes come back 6–8 s later. Trees bend and spring back |
| 0.45 | Roofs lift off and fall back. Trees, lamps, pylons and towers bend harder the stronger the clap; 0.7 past their resistance they're uprooted and thrown, then replant themselves |
| 0.7 | Cracks in the ground under the clapper; your screen flashes |
| 1 | A second, wider gold wave, and debris erupts from the ground |
| 0.45+ | City buildings: a maxed City player makes them hop; a Region-level visitor (force 1+) throws them across the blocks |
| 2 | A shockwave dome; nearby cameras shake |
| 4 | A pillar of light |

Things fly with gravity, bounce, then glide home after about 2–6 s (longer for stronger claps).
Lava cracks on the globes flare when a clap reaches them.

**Players get pushed too.** If another player's clap reaches you with force ≥ 1 (at most once
every 4 s), your own client launches your character. You own its physics, so everyone sees you
fly. Walking players get knocked back. Seated players get knocked out of their seat at force ≥ 1.5;
below that, the seat shakes.

Pulses are throttled to one burst per player per 0.25 s.

### Visiting is for showing off, not farming
A visitor's Applause per clap is capped at the stage's breakthrough power, then divided by 10 per
stage back (`VisitorGainPerStageBack`). Their claps hit hardest of all, so visiting is where the
biggest effects live.

### 4. Shared spectacle moments (synced for everyone)
Some moments *should* hit everyone at once, because that's what makes multiplayer exciting:

- **Standing Ovation triggers:** the server sends one event, every client plays the same huge server-wide effect at the same moment (golden shockwave through the whole stage, confetti, crowd roar, music sting).
- **In Sync claps:** when 3+ players clap on the same beat, a linked ring connects them, all their shockwaves merge into one bigger wave, and the bonus pops up.
- **Someone breaks through:** others see a bright flash and the player warping out, plus the server-wide banner ("Player123 just shattered the Earth!"). The full cinematic plays only for that player.
- **Server firsts / big milestones:** an optional brief "aftershock" that rattles everyone's scene a little, as a reminder that the strongest player is out there.

### How it plays per stage

| Stage | Every clap shoves (shared, heals) | Lasting damage (your progress only) |
|---|---|---|
| 1 Ceremony | Chairs, classmates and players' chairs fly; small props hop; windows shatter; lamps swing | Chairs scooted back, classmates covering ears, dB meter |
| 2 Gym | Chairs, basketballs, cones, ball cart and mats fly; high windows shatter; bunting tears off; hoops and scoreboard crash down; lamps swing | Chairs blown to the walls, lamps swinging, cracks up the end walls |
| 3 Town | Glass, fences, mailboxes, bins, cars, doors, chimneys and roof slabs fly; trees and street lamps bend; birds burst up; very strong claps make houses jump | The sports field cracks open |
| 4 City | Cars fly; trees and radio masts bend, then get uprooted; buildings hop, then get thrown | Crater growth; buildings flatten from the centre out |
| 5 Region | Skyline towers sway and topple; trees and pylons bend, then get uprooted; cars and billboards fly; birds | The dust wall rolls in and flattens the towers it reaches |
| 6 Country | Clouds, ships, planes, the bullet train and city blocks get tossed | The glow spreads; pressure rings ripple out over the sea |
| 7–8 Planet / Molten | Clouds blow off the globe, satellites get knocked about (only a Space-level visitor nudges the Moon); lava cracks flare | Light rings spread round the Planet; it turns orange, oceans steam, crust cracks |
| 9 Space | Fragments and rocks pushed away | Fragments drift away as your progress grows |

Reach is set per stage (`REACH_SCALE` in Environment.luau: hall 1, gym 2, town 8, city 40,
region 30, country 60, globes 40, space 20). The effect visuals (rings, chunks, birds) use the
camera's scale instead (`RING_SCALE`). Past force 1 at an item, extra force throws it less and less further (so a Space-level visitor doesn't empty the view). Dust and ground cracks are capped so even a Space-level
visitor doesn't fog out the City. Floating things (clouds, ships, satellites, Space fragments)
travel about a third as far as things with gravity, so they stay in view. On the globes, the
lasting blast glow is a flattened sphere hugging the surface (at most 45% of the globe's radius),
not a flat disc.

## Technical notes

- **World state function:** `DamageState(stage, t)` returns which pre-made damage variants are visible (e.g. `Window_Broken`, `Chair_Displaced`) plus parameters (crack amount, glow intensity). Dioramas are built with **damage variants baked in** (intact + broken versions toggled locally). This is much cheaper than real-time fracture.
- **Per-clap bursts:** pooled `ParticleEmitter`s, `Beam`/ring meshes scaled by power, `TweenService` for debris hops. Loose debris uses **client-only parts** (created locally, never replicated) with simple physics, then cleaned up.
- **Remotes:** server broadcasts a compact `ClapPulse {playerId, power tier, beatHit}` at ~5 Hz per player, enough to drive others' ambient effects. Big events (`Ovation`, `InSync`, `Breakthrough`) are separate reliable events with a server timestamp so clients play them in sync.
- **Anti-grief:** since only numbers are server-side and no shared geometry ever changes, players can't damage each other's experience.
- **Settings:** "Show other players' effects: All / Nearby / Off" for low-end phones.

## Open questions

1. At town/city scale, are other players **giants standing in the diorama** (funny, readable) or tiny figures seen from the aerial camera?
2. Should the **Breakthrough aftershock** rattle everyone's scene, or would that be annoying?
3. Do we want a short **"rebuild" animation** between claps (debris flying back like rewinding), or just a gentle settle?
