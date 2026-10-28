--!strict
-- Live events. Each event is data: dates, currency, shop and a client theme name.
-- A new event is a new entry here (plus a theme in src/client/EventTheme.luau if it needs a
-- new look). Times are UTC unix seconds. See docs/11-live-ops.md.
--
-- Event currency drops from on-beat claps (Perfect always, Great/Good sometimes, never Misses),
-- doubled during the "Witching Minute" style rush that runs for RushSeconds every RushEvery
-- seconds, in step on every server.

export type ShopItem = {
	id: string,
	icon: string, -- icon image name on the shop card (see shared/Icons)
	name: string,
	cost: number,
	kind: "wings" | "trail" | "title" | "boost",
	style: string?, -- wings/trail look, or the title text
	minutes: number?, -- boost length
}

export type Event = {
	id: string,
	name: string,
	jp: string,
	emoji: string,
	image: string, -- icon image name for the banner and shop title
	theme: string,
	startsAt: number,
	endsAt: number,
	announceBefore: number, -- seconds before start to show the countdown
	currency: { name: string, icon: string, image: string },
	dropChance: { [string]: number }, -- per grade
	rush: { name: string, every: number, seconds: number, multiplier: number },
	shop: { ShopItem },
}

local DAY = 24 * 60 * 60

local Events = {}

Events.List = {
	{
		id = "halloween2026",
		name = "Halloween Night",
		jp = "ハロウィン",
		emoji = "🎃",
		image = "item_pumpkin",
		theme = "halloween",
		startsAt = 1793239200, -- 2026-10-28 22:00 US Eastern, with the update
		endsAt = 1793595600, -- end of 2026-11-01 US Eastern
		announceBefore = 7 * DAY,
		currency = { name = "Candy", icon = "🍬", image = "cur_candy" },
		dropChance = { Perfect = 1, Great = 0.5, Good = 0.25 },
		rush = { name = "Witching Minute", every = 20 * 60, seconds = 60, multiplier = 2 },
		shop = {
			{ id = "title_pumpkin", icon = "item_pumpkin", name = "Pumpkin Clapper Title", cost = 600, kind = "title", style = "🎃 PUMPKIN CLAPPER" },
			{ id = "boost_candy", icon = "item_boost", name = "2× Applause (10 min)", cost = 300, kind = "boost", minutes = 10 },
			{ id = "wings_bat", icon = "item_bat", name = "Bat Wings", cost = 2500, kind = "wings", style = "bat" },
			{ id = "trail_ghost", icon = "item_ghost", name = "Ghost Trail", cost = 4000, kind = "trail", style = "ghost" },
		},
	},
	{
		id = "christmas2026",
		name = "Winter Clap-tacular",
		jp = "クリスマス",
		emoji = "🎄",
		image = "item_santa",
		theme = "christmas",
		startsAt = 1797033600, -- 2026-12-12
		endsAt = 1799020800, -- 2027-01-04
		announceBefore = 7 * DAY,
		currency = { name = "Presents", icon = "🎁", image = "cur_present" },
		dropChance = { Perfect = 1, Great = 0.5, Good = 0.25 },
		rush = { name = "Snowstorm Minute", every = 20 * 60, seconds = 60, multiplier = 2 },
		shop = {
			{ id = "title_holiday", icon = "item_santa", name = "Holiday Clapper Title", cost = 600, kind = "title", style = "🎅 HOLIDAY CLAPPER" },
			{ id = "boost_present", icon = "item_boost", name = "2× Applause (10 min)", cost = 300, kind = "boost", minutes = 10 },
			{ id = "wings_snow", icon = "item_snowflake", name = "Snowflake Wings", cost = 2500, kind = "wings", style = "snow" },
			{ id = "trail_star", icon = "item_star", name = "Starlight Trail", cost = 4000, kind = "trail", style = "star" },
		},
	},
} :: { Event }

-- The "Next update" countdown board. Add the next date here when one is planned; after the
-- last date passes the board says the update is out for a day, then hides.
Events.Updates = {
	{ at = 1793239200, name = "Next update" }, -- 2026-10-28 22:00 US Eastern
}

-- the update to count down to (or the one just released, with released = true)
function Events.nextUpdate(now: number): ({ at: number, name: string }?, boolean)
	local latest = nil
	for _, update in Events.Updates do
		if update.at > now then
			return update, false
		end
		if not latest or update.at > latest.at then
			latest = update
		end
	end
	if latest and now - latest.at < DAY then
		return latest, true
	end
	return nil, false
end

function Events.get(id: string?): Event?
	for _, event in Events.List do
		if event.id == id then
			return event
		end
	end
	return nil
end

-- the event running at `now`, if any (forceId lets Studio test any event)
function Events.active(now: number, forceId: string?): Event?
	if forceId and forceId ~= "" then
		return Events.get(forceId)
	end
	for _, event in Events.List do
		if now >= event.startsAt and now < event.endsAt then
			return event
		end
	end
	return nil
end

-- the next event inside its announcement window, for the "starts in" countdown
function Events.upcoming(now: number): Event?
	local best: Event? = nil
	for _, event in Events.List do
		if now < event.startsAt and now >= event.startsAt - event.announceBefore then
			if not best or event.startsAt < best.startsAt then
				best = event
			end
		end
	end
	return best
end

-- is the rush (double drops) on right now? returns seconds left in it
function Events.rushLeft(event: Event, now: number): number
	local into = (now - event.startsAt) % event.rush.every
	return math.max(0, event.rush.seconds - into)
end

-- every cosmetic from every event, by id (owned cosmetics outlive their event)
function Events.item(id: string): ShopItem?
	for _, event in Events.List do
		for _, item in event.shop do
			if item.id == id then
				return item
			end
		end
	end
	return nil
end

return Events
