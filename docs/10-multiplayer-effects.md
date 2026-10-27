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

### 3. Other players' claps: you see them, scaled down
You still see and feel other players' power, as a lighter "ambient" layer:

| Your own clap | Another player's clap |
|---|---|
| Full shockwave, full debris, full camera shake | Smaller shockwave ring around *them*, tinted their colour |
| Full sound, layered for your stage | Quieter, positional sound (fades with distance) |
| Big number pop | Small pop above their head (optional, togglable) |
| Damages your world state | Never changes your world state |

Players clap 5–10×/s, so others' effects are **throttled** (e.g. max ~4 visible bursts per player per second, nearest players prioritised) to protect FPS on mobile.

### 4. Shared spectacle moments (synced for everyone)
Some moments *should* hit everyone at once, because that's what makes multiplayer exciting:

- **Standing Ovation triggers:** the server sends one event, every client plays the same huge server-wide effect at the same moment (golden shockwave through the whole stage, confetti, crowd roar, music sting).
- **In Sync claps:** when 3+ players clap on the same beat, a linked ring connects them, all their shockwaves merge into one bigger wave, and the bonus pops up.
- **Someone breaks through:** others see a bright flash and the player warping out, plus the server-wide banner ("Player123 just shattered the Earth!"). The full cinematic plays only for that player.
- **Server firsts / big milestones:** an optional brief "aftershock" that rattles everyone's scene a little, as a reminder that the strongest player is out there.

### How it plays per stage

| Stage | Shared (everyone sees) | Local (your power only) |
|---|---|---|
| 1 Ceremony | Hall, seats, other players clapping in their seats | Classmates covering ears, chairs scooting, dB meter, windows rattling |
| 2 Gym | Gym building, players standing on the court | Chair rings blowing out, dust waves, lights swinging, wall cracks |
| 3–4 Town / City | Town diorama, players as giants standing in it (or tiny figures in an aerial view) | Roofs peeling, debris rings, crater growth |
| 5–6 Region / Country | Diorama / map, players in it | Dust fronts, shockwave glow spreading over the map |
| 7–8 Planet / Molten | Mini-planet players stand on together | Glow rings, ocean steam, crust cracks (crack amount = your progress) |
| 9 Space | Everyone floating among fragments | Fragments drift away from your claps; felt pulses |

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
