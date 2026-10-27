# 01 — Source Video Reference

Source: `wBufiLdl3memQPRV.mp4` (user-supplied). 78 s, 720×1280 vertical (9:16), 30 fps, stereo 44.1 kHz.
Japanese 3D explainer. Premise: **"もし拍手の音が、1回ごとに2倍になっていったら？"** — *"What if the sound of a clap doubled every time?"*

> We use this for **concept, pacing and mood only**. All models, text, scenes and layout in the game are our own.

## Timeline

| Video time | Clap # | Scene & camera | HUD readout | Caption (translated) |
|---|---|---|---|---|
| 0:00 | (16 teaser) | First-person hands, gym, red/white curtains | "Clap = 260 g gunpowder" | "What if every clap doubled?" |
| 0:02–0:05 | — | First-person in graduation hall; countdown "2倍まで 0:03.5" (*until 2×*) | Countdown timer | "Everyone's applause stopped…" |
| 0:06–0:09 | 1–3 | Same; classmate "Suzuki" (鈴木) labelled with a callout | **dB meter**: 110 → 122 dB, bar labelled *"noisy"* → *"pain threshold"* | "Only Suzuki's clapping won't stop" |
| 0:10–0:15 | 5–9 | Hall; classmates turn around, cover ears | 134 → 158 dB, bar turning orange | "The clap's pressure doubles each time" |
| 0:16–0:19 | 11–13 | Cut **outside**: street with school, cherry tree, man walking a dog ("Max") — both flinch | 170 → 182 dB, bar red | — |
| 0:20 | 15 | Gym interior, dust blowing outward | **194 dB** (max) | "Clap reached the limit sound can make in air" |
| 0:22–0:25 | 17–19 | Gym; units switch to **TNT mass** | "Clap = 1 kg → 16 kg gunpowder" | (same) |
| 0:26–0:27 | 20–21 | **Top-down** on student in chair, gym floor | 66 kg → 260 kg | "The clap became a shockwave" |
| 0:28 | 23 | **Aerial**: gym in town, ring of debris around it | 4 tons | — |
| 0:30–0:33 | 25–27 | Covered shopping arcade, people blown along | 67 → 1,100 tons | — |
| 0:34–0:39 | 29–33 | **Satellite view**: expanding crater over farmland/city, river | "≈1 nuke" → 18 → 290 | "Clap #29 = one nuke" |
| 0:40–0:43 | 35–37 | Low city skyline vs green mountains | 4,700 → 75,000 | "Clap #35 beats the largest ever test" |
| 0:44–0:47 | 39–41 | **Map of Japan** on blue ocean, curve of Earth | 1.2 M → 19 M | badge: "heard across all of Japan" |
| 0:48 | 43 | Wider: Asia, glowing blast centred on Japan | 310 M | badge: "34 h to circle the Earth" |
| 0:50–0:55 | 45–49 | **Whole Earth** from space; radial shockwave covers globe | 4.9 B → 1.3 T | "Clap rivals the dinosaur-killing meteor" / "Molten rock rains worldwide" |
| 0:56–0:59 | 51–53 | Earth glowing orange, concentric rings | 20 T → 320 T | (same) |
| 1:00 | 55 | Earth white/steam | 5,200 T | "All the ocean water evaporates" |
| 1:02–1:05 | 57–59 | Earth crust cracked into glowing lava plates | 8.2 Q → 130 Q | "Earth's surface melts" |
| 1:06–1:09 | 61–63 | Hands clap **in front of** shattering Earth | (HUD only shows count) | "Earth breaks apart on clap #60" |
| 1:10–1:13 | 65–67 | Student floating in space among Earth fragments | count only | **"From clap #61, claps are silent in space"** |
| 1:14–1:18 | — | Black end card | — | "What *what-if* do you want next?" / disclaimer |

*(Timestamps approximate. Pace is roughly **one clap per second** throughout, with every other clap shown; a "早送り" (fast-forward) badge appears in later sections.)*

## Key observations for the game

1. **Two growth phases:** sound *pressure* doubles per clap (dB +6 each), and once it becomes a shockwave the **energy** readout grows ~×4 per clap (×16 every 2 claps). We don't need physics accuracy, but "numbers explode faster as you go" is the feel.
2. **Units change as scale changes:** dB → kg TNT → tons → "nukes" → "meteor" comparisons. Each unit switch is a mini-milestone.
3. **Camera escalates with power:** first-person → outside street → top-down → aerial → satellite → country map → globe → space. Every camera pull-back is a "stage" moment.
4. **Bystander reactions sell the power:** classmates turn and cover ears, dog flinches, people blown down the arcade.
5. **Captions do the storytelling:** one short bold line per beat.
6. **The silence beat:** once in space, there is no sound at all. Strongest moment in the video.

## HUD layout (as seen)

```
┌──────────────────────────────┐
│  [卒業証書授与式]  title banner (stage 1 only, cream, serif)
│                               │
│  20 回目          @channel    │  ← big serif clap count + small 回目 ("-th time")
│  (輪は早送り)                  │  ← small pill badge (status/notes)
│  拍手1回 =                     │  ← small label "1 clap ="
│  火薬 66kg                     │  ← unit word white + value in GOLD serif
│  [====------] dB bar           │  ← stage 1 only, green→red gradient, two tick labels
│                               │
│                               │
│   The clap became a shockwave │  ← caption: centred, white bold, soft shadow
└──────────────────────────────┘
```

## Audio (measured)

- **0–20 s (claps 1–15):** discrete claps roughly **once per second**, clearly separated, with quiet gaps between (loudness swings −13 to −48 dB RMS).
- **~21–66 s (claps 16–61, shockwave → Earth breaking):** continuous loud bed (≈ −11 to −14 dB RMS): claps layered over rumble/booms/music. Slight dip and pulsing in 43–60 s (Japan map → globe), with a ~1 s rhythm still audible.
- **67–74 s (claps 62+ in space): digital silence** (true zero) — the "silent in space" beat.
- **74–78 s:** quiet outro sting fading out.
- No obvious voice-over detected by loudness analysis alone (captions carry the narrative); to confirm by ear.

## Visual style notes

- Soft low-poly 3D, matte materials, gentle ambient occlusion; slightly desaturated except accents.
- Student: navy school uniform (gakuran-like), large stylised skin-tone hands.
- Stage 1 palette: deep red stage curtains, red/white striped bunting, black chairs, pink/white flower arrangements, wood floor.
- Later stages: satellite/map palette (greens, beige land, deep blue ocean), then space black with orange/gold glow.
- Shockwave look: translucent white/grey ring with dust; at planet scale, a glowing radial blast and concentric light rings.
