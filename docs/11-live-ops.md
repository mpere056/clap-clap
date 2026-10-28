# 11 — Live ops: events and keeping players coming back

Popular simulators stay on the charts because the game is a little different every week: a
banner counting down to something, a limited shop, a rush hour, and an "update in 1d 7h" board
that makes people come back the next day. This doc covers what's built for that in 👏 Clap Clap
and the calendar we plan to run.

## What's built (2026-10-27)

| Piece | Where | What it does |
|---|---|---|
| Event data | `src/shared/Events.luau` | Each event is one table: dates, currency, drop chances, rush, shop. No code changes to add one. |
| Event service | `src/server/EventService.luau` | Publishes the running/next event to every client, rolls currency drops for on-beat claps, starts the rush on every server at the same moment. |
| Event look | `src/client/EventTheme.luau` | Colour grade, decorations around the stage (jack-o'-lanterns, presents), ambient particles (bats, snow). One `THEMES` entry per look. |
| Banner + shop | `src/client/EventUI.luau` | Top-centre banner with countdown ("ends in 6D 05:47:10"), currency balance and rush timer; click opens the shop. Shows "starts in …" for the next event before it begins. |
| Cosmetics | `src/client/Environment.luau` | Event wings/trails replace the Rebirth defaults; event titles show above the player under any rank title. Everyone sees them. |
| Your collection | shop panel | Items bought in past events stay yours and can be worn/taken off any time (also between events). |
| Next update board | `src/client/UpdateBoard.luau` | In-world "NEXT UPDATE 1d 7h 37m" board by the stage (stages 1–6). Times live in `Events.Updates`. After the time passes it says "UPDATE IS OUT!" for a day, then hides. |

### How an event plays

- **Currency drops from rhythm.** Perfect claps always drop one, Great 50 %, Good 25 %, misses
  nothing. This rewards the core skill (clapping on the beat) instead of AFK.
- **Rush every 20 minutes** (Witching Minute / Snowstorm Minute): 60 s of double drops. It's
  synchronised to the clock, so everyone in every server gets it together, and a toast plus a
  camera shake announce it. It makes people stay "just until the next one".
- **Shop:** a title (cheap, ~10 min), a 2× Applause boost (consumable, a currency sink),
  wings (~40 min) and a trail (~70 min). Prices assume roughly one drop per second of steady on-beat clapping (to be tuned from real play).
- **Limited:** shop items are only buyable during their event. That's the reason to play that
  week, and owning a past item becomes a flex later.

### Testing an event in Studio

```lua
game.ServerStorage.DevEvent:Invoke("christmas2026") -- force an event ("" = real calendar)
game.ServerStorage.DevGrant:Invoke(0, nil, nil, nil, nil, 5000) -- +5000 of the event currency
```

The banner says "Studio test" while an event is forced.

## Calendar

| When | Event | Currency | Look | Status |
|---|---|---|---|---|
| Oct 28, 10 pm ET | Next update (board countdown) | — | — | Board live |
| Oct 28, 10 pm ET – end of Nov 1, 2026 | 🎃 Halloween Night ハロウィン | 🍬 Candy | purple grade, jack-o'-lanterns, bats | Starts with the update; banner already shows "starts in …" |
| Dec 12, 2026 – Jan 4, 2027 | 🎄 Winter Clap-tacular クリスマス | 🎁 Presents | cool grade, presents, snow | **Built and tested**; banner shows "starts in" from Dec 5 |
| Late Jan / Feb 2027 | 🧧 New Year / Setsubun 節分 | — | — | Idea |
| Late Mar – Apr 2027 | 🌸 Cherry blossom ceremony 桜 | — | petals, pink grade | Idea (fits the graduation theme perfectly: Japanese graduations are in March) |

Adding the next one is: copy an entry in `Events.List`, change the id/dates/names/shop, and
(if it needs a new look) add a `THEMES` entry in `EventTheme.luau`. Styles for new wings and
trails go in `WING_STYLES` / `TRAIL_STYLES` in `Environment.luau`.

## Update cadence

- **Weekly update, same day and time each week.** The board gives players a reason to
  come back at that time, and a regular slot also helps with Roblox discovery.
- Every update should carry at least one visible new thing: a shop item, a new look, a
  technique, or a balance pass. Put the date in `Events.Updates` before shipping.
- Between seasonal events, run a short **mini-event** (a weekend 2× rush, or a one-day item).

## Ideas for later (not built)

- **Daily rewards and login streaks.** Day 1–7 escalating; day 7 gives an exclusive title.
- **Daily quests.** "Get 50 Perfects", "Join an In Sync streak of 10", "Visit a friend's stage".
- **Global Mega Ovation.** A shared meter across all servers during an event (MessagingService).
  When it fills, everyone online gets a bonus. It turns the playerbase into one team.
- **Event leaderboard.** Most currency earned this event, with a top-100 frame/title reward.
- **Gifting.** Buy a boost for another player in your server.
- **Group rewards.** A bonus for joining the Roblox group, which builds the notification list
  for update announcements.
