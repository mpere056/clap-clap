# 05 — Art, UI & Audio

Goal: feel like the source video (soft, clean, deadpan "what-if" explainer) while being our own work and readable on a phone.

## Visual style

- **Soft low-poly 3D.** Simple shapes, matte `SmoothPlastic` / light `Plastic` materials, no busy textures. Rounded edges where cheap.
- **Lighting:** `Future` lighting technology, soft shadows, gentle `Atmosphere`, light `Bloom` (stronger in space stages), `ColorCorrection` per stage.
- **Characters:** blocky-but-soft students in **navy school uniforms** (gakuran / blazer). The player's **first-person hands** are larger than life and skin-tone, with a dark navy sleeve.
- **Destruction is cartoony:** dust rings, flying chairs, people tumbling comically with arms flailing. Never hurt.
- **Colour per stage:**

| Stage | Palette |
|---|---|
| Ceremony | Deep red curtains `#7A1E24`, white/red bunting, warm wood `#C9A27A`, black chairs, pink/white flowers |
| Gym | Pale wood court `#D8B98C`, orange line, grey dust |
| Town / City | Soft greens `#7FA36A`, beige roads, grey roofs, muted blue river |
| Country | Ocean `#1E3F7A`, land `#E6D3A8`, white coastline glow |
| Planet / Molten | Blue globe → orange `#F2A54A` → lava cracks `#FF7A1A` on dark `#3A1A0E` |
| Space | Near-black `#05060C`, star field, gold/white glow fragments |

## UI / HUD

**Layout (portrait-friendly, also works landscape):**

```
 ┌──────────────────────────────────────┐
 │ [卒業証書授与式]  ← stage banner      │  cream #F2EFE6, black serif, stage 1 only
 │                                      │
 │ 20 回目                    ☰ Shop    │  big serif count + small "回目"
 │ (Stage 2 · The Gym)                  │  pill badge: stage / status
 │ 1 clap =                             │  small white label
 │ TNT  66 kg                           │  unit white + value GOLD serif
 │ [■■■■■■■■□□□□]  Noisy · Pain · Limit │  dB bar (stage 1) / stage progress bar
 │                                      │
 │ Applause: 12.4K   (+1.2K/s)          │  currency, top-left or top-centre
 │                                      │
 │               ( ◯ )   ← beat pulse   │  rhythm ring around crosshair
 │                                      │
 │    Your clap became a shockwave.     │  caption: centred, white bold, soft shadow
 │                                      │
 │ [Upgrades] [Classmates] [Fans] [⚙]   │  bottom tabs (mobile thumb zone)
 └──────────────────────────────────────┘
```

**Typography (Roblox fonts, to verify in Studio):**
- Big numbers and the count: a **serif**, e.g. *Merriweather* or *Garamond*, to echo the video's elegant numerals.
- Labels, captions, buttons: *Builder Sans* / *Gotham* bold.
- Japanese flavour text uses Roblox's built-in CJK fallback.

**Colours:**
- Text white `#FFFFFF` with soft drop shadow (no heavy outlines)
- Accent gold `#E8B866` (the "power" number)
- Pill badge: dark translucent `#000000 @ 45%`, white 1px stroke, fully rounded
- Meter gradient: green `#8FD16A` → amber `#F2C14E` → red `#E0524A`

**Japanese flavour (English main UI):**

| Where | JP text | Meaning |
|---|---|---|
| After clap count | `回目` | "-th time" |
| Stage 1 banner | `卒業証書授与式` | Diploma ceremony |
| Stage name subtitles | `卒業式`, `体育館`, `町`, `地球`, `宇宙`… | Stage names |
| Captions (occasional, small under English) | 「みんなの拍手が、鳴りやんだ」 | "Everyone's applause stopped" |
| Big number captions | 万 / 億 / 兆 / 京 | As in the video |
| Prestige | `卒業` | Graduation |

**Juice on every clap:**
- Hands snap animation (≈120 ms), screen punch (FOV −2 → back), tiny camera shake scaled to stage.
- Avatars clap too, whenever we see them (walking, standing on later stages, other players): arms
  rise to chest height, the hands snap together on each clap and spring apart, stay up between
  claps and drop after about a second. It layers over the walk animation and works on every rig.
- A comic "pop" where the hands meet (white disc in a burst of rays, gold on Perfect) with sparks.
- Everything else scales with clap force, from nothing on the first claps up to a stage-wrecking
  visitor; see the ladder in [10-multiplayer-effects.md](10-multiplayer-effects.md).
- Shockwave ring decal/particle from the hands.
- Floating `+1.2K` pop (gold on crit).
- On-beat clap: ring flashes white, combo counter ticks up.

**Mobile:** tap anywhere (outside buttons) to clap. Buttons ≥ 44 px, bottom tabs in the thumb zone. Respect safe areas / notches.
On short screens the whole HUD is laid out on a virtual 1000 × 560 screen and scaled down (about
70% on a phone in landscape), so nothing overlaps. The event banner scales the same way, the dock
shrinks to at least 70%, and menus use nearly the full height (over the dock) so their cards stay
readable.

**Menus (2026-10-27):** two looks on purpose. The in-play HUD (clap count, meter, captions)
keeps the video's quiet serif style; the menus use the chunky simulator style players know from
the top Roblox simulators. That style is built from `src/client/UIKit.luau`:
- Fredoka One text with thick black outlines; buttons with a darker 3D bottom edge that press down.
- Menus open centred with a striped colour header, a big title with an emoji and a red **X**.
  Only one menu is open at a time; they shrink to fit phones.
- Icons are the game's own art, not emoji: ~70 custom icons (every technique, classmate,
  stage, event item, currency and dock button), each a small 3D toy-like model rendered in
  Blender: rounded glossy plastic shapes, bright saturated colours, three-point lighting, dark inner
  outlines, one thick outline around the whole silhouette and a drop shadow, like the item art of
  popular simulators. In cards they sit on slowly turning light rays (`ui_rays`). They're modelled
  in `tools/icons3d.py` (contact sheet `art/icons/sheet.png`) and uploaded as Roblox images; menus
  use them through `src/shared/Icons.luau`. Emoji only remain in chat-style toasts.
- Items are cards: the icon on a dark disc, a level pill (top left), a stage pill (top
  right), the name, a green stat line, the cost, and buy buttons (+1 / +10 / MAX). Locked cards
  get a 🔒 cover saying what unlocks them.
- Card colour = the stage the item belongs to, read like rarities: grey, green, blue, purple,
  orange, red, teal, magma, cosmic.
- The bottom-right dock: View (teal, stages 2–6: Aerial ↔ Close camera), Stages (blue), Upgrades
  (gold). There's no Walk/Sit button: moving or jumping while seated gets you up, and walking into
  a seat sits you down. Clap keys: click / tap / F (Space jumps).
  A red "!" badge pulses on the beat when an upgrade is affordable.
- No settings or leaderboard buttons (they clutter the screen). The leaderboard is a big framed
  board by the left corner of the stage in the hall ("TOP CLAPPERS": world top 8 with avatar
  headshots and clap power; this server's players when world rankings aren't available).

## Audio

| Layer | Behaviour |
|---|---|
| **Clap** | Core clap sample. Pitch/variance randomised ±5%. Each stage adds layers: Ceremony (dry → hall reverb) → Gym (+low thump) → Town (+boom, distant echo) → City+ (+sub-bass rumble, debris) → Planet (deep cinematic impact) |
| **Bed / music** | Calm, light ceremony music at start (piano/strings), increasingly epic through stages, staying tasteful |
| **Reactions** | Murmurs, gasps, "うるさい!" ("so loud!") shouts in the hall, dog bark on the street cut, glass shatter, wind |
| **Breakthrough** | Rising whoosh → impact → short silence → new bed |
| **Space** | **Total silence on arrival** (clap makes no sound, even the UI is quiet) for ~5 s, then a low, soft "felt" score fades in: muffled sub-thumps synced to claps, like a heartbeat. "You can't hear it, but you can feel it." |

Implementation notes:
- `SoundGroup`s for Music / SFX / UI / Ambience, each with a volume slider in settings.
- Audio from the Creator Store (licensed), or our own uploads.
- Clap rate can reach 10+/s with auto-clappers. Pool/throttle sounds so it never becomes noise: a rapid-clap "roar" loop crossfades in above ~6 claps/s.
