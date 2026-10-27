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
- Shockwave ring decal/particle from the hands.
- Floating `+1.2K` pop (gold on crit).
- On-beat clap: ring flashes white, combo counter ticks up.

**Mobile:** tap anywhere (outside buttons) to clap. Buttons ≥ 44 px, bottom tabs in the thumb zone. Respect safe areas / notches.

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
