# 02 — Game Concept

## Elevator pitch

> Everyone else has stopped clapping at the graduation ceremony. You haven't. Every clap gets stronger, from rattling the hall to flattening the town to cracking the planet in half, and the camera keeps pulling back to show it.

## Title: **👏 Clap Clap** (decided 2026-10-27)

- Emoji leads, so it stays visible on truncated game tiles; "Clap Clap" stays searchable and easy to say.
- Hook subtitle where space allows: **"👏 Clap Clap: Destroy the Earth!"** / "Every Clap Doubles!"
- Update format: **"[🌙 MOON] 👏 Clap Clap"**
- Logo flavour: パチパチ (*pachi pachi*, Japanese for the sound of clapping); logo idea: two hands with a shockwave ring as the second "clap".
- To do before launch: search Roblox for existing games with the same name.

### Other names considered

- **Clap Harder**
- **Don't Stop Clapping**
- **Applause Simulator** (simulator-style naming does well on Roblox if we go multiplayer)
- **One More Clap**
- **Graduation Clap 卒業**
- **Clap Simulator** / **Clapping Simulator**: most discoverable via search, genre-standard
- **Clap to Destroy the Earth**: says the whole promise in one line
- **Every Clap Doubles**: the video's hook as a title
- **Standing Ovation**: ties into the server meter
- **Applause Incremental**
- **Clap Clap Boom 💥**
- **The Loudest Clap**
- **Planet Clapper**

Common Roblox pattern: a searchable name plus a hook subtitle, e.g. *"Clap Simulator 👏 Destroy the Earth!"*

## Design pillars

1. **Escalation you can see.** Every power milestone changes what's on screen: the camera pulls back, the units change, bystanders react. Growth isn't only a number going up.
2. **The clap feels good.** Hands snap together, the screen punches, the sound thumps, a ring of force bursts out. Clicking has to feel satisfying 10,000 times over.
3. **Deadpan absurdity.** Calm captions in the video's style ("Clap #29 levelled the city.") played completely straight. Light, funny, never gory.
4. **Tiny moments of awe.** The first shockwave, the first view of the globe, the silence in space. Cinematic beats are rewards in themselves.
5. **No PvP.** Other players (if any) are fellow clappers, never opponents.

## Core loop (mode-agnostic)

```
 Clap (click / tap / key)            ← active
   │   + on-beat timing → combo multiplier
   ▼
 Earn Applause (currency) = Clap Power × multipliers
   │
   ▼
 Buy upgrades: stronger hands, clap techniques, classmates (auto-clap), rhythm, crits
   │
   ▼
 Clap Power rises → crosses stage threshold
   │
   ▼
 BREAKTHROUGH CLAP: cinematic, camera pulls back, new scene, new units, new caption
   │
   ▼
 …repeat until the Earth breaks → Graduate (prestige) for permanent bonuses → faster runs
```

### Two numbers on screen
- **Clap Power**, written "1 clap = …": the strength of a single clap. This is the number the video shows (dB, kg TNT, megatons…). It drives **stage progress**.
- **Applause**: the currency you spend on upgrades. Each clap earns Applause.

Keeping these separate means you're always buying things (incremental loop) while the hero number stays the one from the video.

## Minute-to-minute

- **Clap:** click, tap anywhere, Space, or gamepad R2. Each clap plays the hands animation, a shockwave ring, a sound, and a number pop.
- **Rhythm beat:** a soft pulse ring on the HUD beats at about 1 Hz, echoing the video's steady one-clap-per-second pace. Clapping on the beat builds a **combo** (×1 → ×3 or more). Mashing still works, but rhythm is rewarded. This keeps active play skilful without punishing mobile players (the timing window is generous).
- **Encore Frenzy:** a meter fills as you clap. When it's full, the next 10 claps **each double the last** (×2, ×4 … ×1024), a direct homage to the video's premise. Big moment, big numbers.
- **Classmates:** auto-clappers you hire. They visibly sit around you clapping, so the room fills up as you progress.
- **Captions:** each new milestone shows one bold deadpan line at the bottom of the screen.

## Session arc

| Moment | What happens |
|---|---|
| First 10 seconds | Ceremony ends, applause dies out, prompt: "Keep clapping." First clap is loud and satisfying. |
| First minute | dB meter climbing, classmates turn around, first upgrade bought. |
| First ~5 min | Hits 194 dB, "sound can't get louder than this…", first **Breakthrough**: the clap becomes a shockwave, the camera pulls up out of the gym. |
| Mid-run | Aerial → satellite → country → globe; unit switches; auto-clappers carry more of the load. |
| End of first run | Oceans boil, crust cracks, the Earth shatters, **silence** in space. Ending card, then **Graduate** (prestige). |
| After | Faster runs with permanent bonuses; extended stages beyond Earth if we go long-form (see doc 06). |

## Tone & captions (examples, English with JP flavour)

- "Everyone stopped clapping." / 「みんなの拍手が、鳴りやんだ」
- "You didn't."
- "194 dB. Air can't carry a louder sound."
- "Your clap became a shockwave."
- "Clap #29 flattened the town. Nobody asked you to."
- "Heard across the whole country."
- "Rivals the meteor that ended the dinosaurs."
- "The oceans have left the chat."
- "Earth broke on clap #60."
- "In space, no one can hear you clap."

## Out of scope

- PvP, combat, damaging other players
- Realistic injury or gore: people are comically blown away, never hurt on-screen
- Real-world political framing of weapons (we use TNT and meteor comparisons)
