# 03 — Stages

Each stage is a **separate hand-built diorama** at its own scale, with its own camera rig. Moving between stages is a short **Breakthrough** cinematic (flash, shockwave, camera pull-back), not one continuous zoom. One seamless zoom from a hall to outer space isn't practical in Roblox (part size limits, float precision, streaming), and the source video cuts between scenes too.

Stages 1–9 are the **core run** (the video). Stages 10–14 are **extended stages** we'd add for a long-form multiplayer game (see doc 06).

## Display units

Stage progress uses the internal **Clap Power** number; each stage maps it onto its own display unit (doc 04 has the mapping). Display ranges are loosely realistic:

| Unit | Used in |
|---|---|
| dB (110 → 194) | Stage 1 |
| kg TNT → tons TNT | Stages 2–3 |
| kilotons → megatons TNT | Stages 4–6 |
| "× the dinosaur meteor" | Stage 7–8 |
| "× Earth's binding energy" | Stage 9+ |
| "× the Sun's output", "supernovae" | Extended stages |

Reference points: 1 kg TNT ≈ 4.2 MJ. Largest human explosion ever ≈ 50 Mt. Chicxulub (dinosaur) impact ≈ 10⁸ Mt. Earth's gravitational binding energy ≈ 2.2 × 10³² J ≈ 5 × 10¹⁶ Mt.

---

## Stage 1 — The Ceremony 卒業式
- **Setting:** School assembly hall during the diploma ceremony. Banner `卒業証書授与式`, deep red curtains, red/white bunting, flower stands, rows of black folding chairs, wood floor, lectern.
- **Camera:** First-person from your seat, with your stylised hands in view. Slight sway; punch-in on each clap.
- **Display:** dB meter, 110 → 194 dB. Bar goes green → amber → red, tick labels "Noisy" / "Pain threshold" / "Limit of air".
- **Reactions by progress:** classmates' heads turn → ears covered → chairs scoot away → windows rattle → lights swing.
- **Mid-stage cut (flavour):** at ~170 dB a short 2-second cut outside: a passer-by and their dog flinch on the street. Optional in v1.
- **Captions:** "Everyone stopped clapping." → "You didn't." → "Pain threshold." → "194 dB. Air can't get any louder."
- **Breakthrough → 2:** dust bursts outward, screen goes white, camera snaps to top-down.

## Stage 2 — The Shockwave (Gym) 体育館
- **Setting:** Gym / hall interior with a basketball court floor; chairs scattered by previous claps.
- **Camera:** **Top-down** on the player in their chair (like the video's 20th clap shot), slowly rising with progress.
- **Display:** kg TNT, 1 kg → 1,000 kg.
- **Reactions:** chairs slide out in rings, dust shockwave ring, ceiling lights swing, windows blow out.
- **Captions:** "Your clap became a shockwave."
- **Breakthrough → 3:** the roof lifts off, camera rockets up into the sky.

## Stage 3 — The Town 町
- **Setting:** Aerial view of a small town: school in the middle, houses on a grid, a covered shopping arcade (shōtengai).
- **Camera:** High aerial, slight tilt. Optional quick street-level cut of the arcade with townsfolk tumbling past (comedic, no injuries).
- **Display:** tons TNT, 1 t → 1,000 t.
- **Reactions (built 2026-10-27, `build/stage3_town.luau`):** about 550 houses with pitched roofs,
  chimneys and cars around the school. The ~330 studs nearest the school also get windows, doors,
  fences, mailboxes, bins and street lamps. Every clap shoves them by strength at that spot,
  weakest first: balls, bins, mailboxes, fences, glass, lamps and trees (bend), cars, chimneys,
  doors, roof slabs, then the school roofs; whole houses jump only for very strong visitors.
  Everything heals. The only lasting damage is the sports field cracking as your progress grows.
- **Breakthrough → 4:** a crater ring blooms outward; camera pulls up to satellite height.

## Stage 4 — The City 市
- **Setting:** Satellite view of farmland grid, river, city blocks; crater rings expanding.
- **Camera:** Straight down, very high.
- **Display:** kilotons, 1 kt → 1,000 kt.
- **Captions:** "Clap #N flattened the town. Nobody asked you to."
- **Breakthrough → 5:** dust wall rises to the horizon.

## Stage 5 — The Region 地方
- **Setting:** Low-angle city skyline against green mountains, a dust front coming in.
- **Camera:** Near ground level, looking at the horizon, for scale contrast before the big pull-back.
- **Display:** megatons, 1 Mt → 100 Mt.
- **Captions:** "Bigger than the largest explosion humans ever made."
- **Breakthrough → 6:** camera lifts through clouds to the edge of space.

## Stage 6 — The Country 日本
- **Setting:** Stylised map of Japan on a deep blue ocean with the curve of the Earth at the top (our own art: flat beige land, soft white coastline glow).
- **Camera:** Orbital, then slowly pulling back to show Asia.
- **Display:** megatons, 100 Mt → 100,000 Mt. Badges: "Heard across the whole country", "The sound circles the Earth".
- **Breakthrough → 7:** the glow spreads across the ocean; pull back to the full globe.

## Stage 7 — The Planet 地球
- **Setting:** Whole Earth in space, a glowing radial blast centred on your location, concentric light rings.
- **Camera:** Space, globe filling ~70% of the frame.
- **Display:** "× dinosaur meteor", 0.001× → 1×.
- **Captions:** "Rivals the meteor that ended the dinosaurs." / "Molten rock rains worldwide."
- **Breakthrough → 8:** the whole planet flushes orange.

## Stage 8 — Molten Earth 灼熱
- **Setting:** Earth turns orange, white steam (oceans boiling), then the crust cracks into glowing lava plates.
- **Display:** "× dinosaur meteor", 1× → 10⁸×.
- **Captions:** "The oceans boiled away." → "The surface is melting."
- **Breakthrough → 9:** the hands appear in front of the planet; one clap and it shatters.

## Stage 9 — Space 宇宙 (end of the core run)
- **Setting:** You float in space among glowing Earth fragments, still in uniform, still clapping.
- **Camera:** Third-person orbit around the floating student.
- **Display:** "× Earth's binding energy".
- **Audio:** **total silence** on arrival. Caption: "In space, no one can hear you clap." After a few seconds a soft, low "felt, not heard" score fades in (see doc 05) so this stage isn't silent forever.
- **End of run:** ending card ("What will you clap at next?"), then the **Graduate** (prestige) prompt.

---

## Extended stages (long-form / multiplayer only)

Unlocked by prestige count. Still silent-space rules: no clap sound, only felt thumps and music.

| # | Stage | Scene | Display |
|---|---|---|---|
| 10 | **The Moon** 月 | Moon cracks, debris ring forms around where Earth was | × Earth binding energy |
| 11 | **Solar System** 太陽系 | Planets wobble off their orbits; asteroid belt scatters | × Moon / × planets |
| 12 | **The Sun** 太陽 | Sun flickers; solar flares follow your claps | × Sun's output per second |
| 13 | **Supernova** 超新星 | Your clap out-shines a supernova | × supernovae |
| 14 | **The Galaxy** 銀河 | Spiral arms ripple outward; final "Big Clap" teaser | × galaxies |

## Breakthrough cinematic template (all stages)

1. Freeze-frame on the threshold clap (0.2 s), HUD number flashes gold.
2. White flash + low boom (or silent flash in space).
3. Shockwave ring expands past the camera.
4. Camera tweens to the next stage's rig (1.5–3 s); new scene streams in behind the flash.
5. HUD unit swaps with a counter roll; new caption fades in.
6. First clap in the new stage gets an extra big feedback punch.

Skippable after the first time a player sees it.
