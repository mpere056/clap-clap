--!strict
-- Rewarded video ad card ("📺 2× Applause +5 min · Watch Now!") and the boost timer.
-- The card only appears when ads are configured (AdsEnabled) and Roblox has an ad ready.
-- Watching is always opt-in; the reward is granted by the server through ProcessReceipt.

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Icons = require(Shared.Icons)

local Store = require(script.Parent.Store)

local Ads = {}

local player = Players.LocalPlayer
local SANS = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local CHECK_INTERVAL = 45
local DISMISS_SECONDS = 600

local card: TextButton
local timer: TextLabel
local available = false
local dismissedUntil = 0

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = SANS
	l.RichText = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function refreshCard()
	local enabled = ReplicatedStorage:GetAttribute("AdsEnabled") == true
	card.Visible = enabled and available and os.clock() > dismissedUntil
end

local function checkAvailability()
	if ReplicatedStorage:GetAttribute("AdsEnabled") ~= true then
		available = false
		refreshCard()
		return
	end
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	available = ok and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
	refreshCard()
end

function Ads.init(watchRemote: RemoteEvent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClapAds"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("TextButton")
	card.Name = "WatchAd"
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 22, 0.56, 0)
	card.Size = UDim2.new(0, 230, 0, 84)
	card.BackgroundColor3 = Color3.fromRGB(120, 60, 170)
	card.AutoButtonColor = true
	card.Text = ""
	card.Visible = false
	card.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 12)
	round.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 220, 140)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local tv = Instance.new("ImageLabel")
	tv.BackgroundTransparency = 1
	tv.ScaleType = Enum.ScaleType.Fit
	tv.Position = UDim2.new(0, 6, 0, 10)
	tv.Size = UDim2.new(0, 56, 1, -20)
	tv.Image = Icons.get("ui_ad")
	tv.Parent = card
	label(card, { Position = UDim2.new(0, 64, 0, 8), Size = UDim2.new(1, -74, 0, 22), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%d× Applause", Config.Ads.BoostMultiplier) })
	label(card, { Position = UDim2.new(0, 64, 0, 30), Size = UDim2.new(1, -74, 0, 24), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 140), Text = string.format("+%d min", Config.Ads.BoostMinutes) })
	label(card, { Position = UDim2.new(0, 64, 0, 54), Size = UDim2.new(1, -74, 0, 20), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = "Watch an ad · Now!" })
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(22, 22)
	close.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.FontFace = SANS
	close.TextSize = 14
	close.Text = "✕"
	close.Parent = card
	local closeRound = Instance.new("UICorner")
	closeRound.CornerRadius = UDim.new(1, 0)
	closeRound.Parent = close

	timer = label(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.56, -60),
		Size = UDim2.new(0, 230, 0, 24),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 140),
		Visible = false,
		Text = "",
	})

	card.Activated:Connect(function()
		card.Visible = false
		available = false -- an "available" result is only good for one ad
		watchRemote:FireServer()
	end)
	close.Activated:Connect(function()
		dismissedUntil = os.clock() + DISMISS_SECONDS
		refreshCard()
	end)

	task.spawn(function()
		pcall(function()
			AdService:RegisterAdOpportunityAsync(card, Config.Ads.PlacementId)
		end)
		while true do
			checkAvailability()
			task.wait(CHECK_INTERVAL)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("AdsEnabled"):Connect(checkAvailability)

	RunService.RenderStepped:Connect(function()
		local left = ((Store.state.boostEndsAt :: number?) or 0) - workspace:GetServerTimeNow()
		timer.Visible = left > 0
		if left > 0 then
			timer.Text = string.format("%d× Applause · %s", Config.Ads.BoostMultiplier, Format.time(left))
		end
	end)
end

return Ads
