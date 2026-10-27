# 07 — Monetisation

> Depends on the singleplayer/multiplayer decision (doc 06). Prices are **typical genre ranges** to tune later, not commitments.

## Principles

- **No pay-to-win against others.** There's no PvP, so paying only speeds up *your own* progress or buys cosmetics.
- **Everything earnable for free** except convenience, speed and cosmetics.
- **Social purchases are good purchases.** Buying a server-wide boost helps everyone, so people cheer instead of resenting it.
- **Never sell the hook.** The first run's cinematic moments are never paywalled or skippable-for-Robux.

## Singleplayer version (if chosen)

| Item | Type | Price (R$) |
|---|---|---|
| 2× Applause | Game pass | ~149 |
| Auto Clap | Game pass | ~99 |
| Supporter (cosmetic hands + name tag) | Game pass | ~49–99 |

Expect low revenue. A 30-minute game gives little reason to buy.

## Multiplayer version (recommended)

### Game passes (one-time, permanent)

| Pass | Effect | Typical price (R$) |
|---|---|---|
| **2× Applause** | Doubles all Applause | 199–399 |
| **2× Clap Power** | Doubles CP (faster stages) | 249–499 |
| **Auto Clap** | Claps for you on the beat while idle/AFK | 149–299 |
| **VIP** | VIP seat/area, chat tag, +10% everything, exclusive hand skin | 299–499 |
| **Lucky Lockers** | Better odds for rare Fans | 199–399 |
| **Triple Open** | Open 3 Lockers at once | 199–349 |
| **+3 Fan Slots** | Equip more Fans | 149–249 |
| **Auto-Buy Upgrades** | Spends Applause on best upgrade automatically | 99–199 |

### Developer products (repeatable)

| Product | Effect | Typical price (R$) |
|---|---|---|
| **Applause Boost** | 2× Applause for 15 min (stackable time) | 25–49 |
| **Standing Ovation** | Instantly triggers the server-wide ×2 for 5 min, buyer's name announced | 49–99 |
| **Frenzy Now** | Instantly fills the Encore Frenzy meter | 15–29 |
| **Applause packs** | Lump of currency scaled to current progress | 25 / 99 / 399 |
| **Starter Pack** (one-time offer) | Boosts + a rare Fan + cosmetic, heavily discounted | 49–99 |
| **Robux Lockers** (if allowed, see below) | Premium Locker with exclusive Fans | 49–149 |

### Other revenue

- **Private servers** (cheap, e.g. 50–100 R$/month): popular for AFK grinding with friends.
- **Premium payouts:** Roblox pays for engagement time from Premium subscribers. Long sessions count, which is another argument for multiplayer.
- **Experience subscriptions** (monthly perks: daily Applause, exclusive monthly cosmetic) if eligible.

### Free retention rewards (non-monetised but drive monetisation)

- Daily login streak rewards
- Playtime gifts (claim after 5/10/20/40 min)
- Group join bonus (+10% Applause)
- Codes (social media / update codes)
- Free spin wheel, first-run achievement rewards

## Policy constraints (must-do)

- **Paid random items (Lockers bought with Robux):** odds must be **clearly shown before purchase**. Some regions restrict paid random items entirely. Check `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` and hide or disable Robux Lockers for those players. Lockers bought with in-game Applause are fine.
- **Purchase handling:** `ProcessReceipt` must be idempotent and only grant once the save succeeds (doc 08).
- **Maturity questionnaire:** content is cartoon destruction with no gore, which should land at the mildest rating. We avoid "nuke" wording anyway.
- **No misleading offers:** "limited time" must actually be limited; clear what a purchase does.

## Where monetisation hooks appear in the flow

| Moment | Offer |
|---|---|
| ~5 min, after first Breakthrough | Starter Pack popup (once) |
| Hitting a slow stage | Applause Boost suggestion button on HUD (subtle, never a blocking popup) |
| Opening a Locker | Lucky Lockers / Triple Open passes |
| Server Ovation ending | "Start another Ovation" product |
| Shop tab | Everything, always browsable |
