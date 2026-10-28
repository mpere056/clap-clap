--!strict
-- Developer products and rewarded video ads.
--
-- The 2x Applause boost is a developer product. Watching a rewarded video ad grants it for free
-- (Roblox delivers it through ProcessReceipt with ProductPurchaseChannel.AdReward); it can also be
-- bought with Robux. Receipts are recorded in the save so a product is never granted twice.

local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local MonetisationService = {}

local remotes: Folder
local grantBoost: (Player, number) -> ()

local function onWatchAd(player: Player)
	local productId = Config.Ads.BoostProductId
	if productId == 0 then
		return
	end
	local ok, err = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(productId)
		AdService:ShowRewardedVideoAdAsync(player, reward, Config.Ads.PlacementId)
	end)
	if not ok then
		warn("[Ads] Couldn't show rewarded video:", err)
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local state = player and DataService.get(player)
	if not (player and state) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchases = state.purchases
	if purchases[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if receipt.ProductId == Config.Ads.BoostProductId then
		grantBoost(player, Config.Ads.BoostMinutes * 60)
		local fromAd = receipt.ProductPurchaseChannel == Enum.ProductPurchaseChannel.AdReward;
		(remotes.Broadcast :: RemoteEvent):FireClient(player, "BoostGranted", { minutes = Config.Ads.BoostMinutes, fromAd = fromAd })
	else
		-- unknown product: leave it for a future version rather than eating the purchase
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	purchases[receipt.PurchaseId] = true
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetisationService.init(remoteFolder: Folder, boost: (Player, number) -> ())
	remotes = remoteFolder
	grantBoost = boost;
	(remotes.WatchAd :: RemoteEvent).OnServerEvent:Connect(onWatchAd)
	MarketplaceService.ProcessReceipt = processReceipt
	-- lets clients know whether ads are configured yet
	game:GetService("ReplicatedStorage"):SetAttribute("AdsEnabled", Config.Ads.BoostProductId ~= 0)
end

return MonetisationService
