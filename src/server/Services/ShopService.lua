--!strict
-- ShopService — compra de Lunchboxes, rebirth, códigos promocionais, daily reward.
local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)
local StealService = require(script.Parent.StealService)

local ShopService = {}
local luckBonus = 0 -- alterado por EventService (Lucky Boxes)
local lastBuy: { [Player]: number } = {}

function ShopService.setLuckBonus(b: number)
	luckBonus = b
end

function ShopService.rollFood(box: Config.LunchboxDef, forceMinRarity: string?): Config.FoodDef
	local rarity = Util.weightedPick(box.weights, luckBonus)
	if forceMinRarity and Config.Rarities[rarity].order < Config.Rarities[forceMinRarity].order then
		rarity = forceMinRarity
	end
	local pool = {}
	for _, f in Config.Foods do
		if f.rarity == rarity then
			table.insert(pool, f)
		end
	end
	return pool[math.random(1, #pool)]
end

function ShopService.openBox(player: Player, boxId: string, free: boolean?, forceMinRarity: string?)
	local profile = DataService.get(player)
	local box = Config.LunchboxById[boxId]
	if not profile or not box then
		return
	end
	local now = os.clock()
	if (lastBuy[player] or 0) + 0.4 > now then
		return
	end
	lastBuy[player] = now
	if not free then
		if profile.coins < box.price then
			Remotes.Notify:FireClient(player, { text = "Moedas insuficientes!", color = Color3.fromRGB(255, 90, 90) })
			return
		end
		profile.coins -= box.price
	end
	profile.totalBoxes += 1
	local food = ShopService.rollFood(box, forceMinRarity)
	PlotService.giveFood(player, food.id)
	StealService.giveShield(player, Config.Steal.PurchaseShieldSec)
	Remotes.HatchResult:FireClient(player, { foodId = food.id, rarity = food.rarity, name = food.name, color = food.color })
	if Config.Rarities[food.rarity].order >= 5 then
		Remotes.Notify:FireAllClients(Locale.msg("found_food", { p = player.DisplayName, f = food.name, r = food.rarity }, Config.Rarities[food.rarity].color))
	end
	DataService.markDirty(player)
	PlotService.pushState(player)
end

function ShopService.rebirth(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if profile.level < Config.Rebirth.MinLevel then
		Remotes.Notify:FireClient(player, Locale.msg("rebirth_req", { n = Config.Rebirth.MinLevel }, Color3.fromRGB(255, 90, 90)))
		return
	end
	profile.rebirths += 1
	profile.level = 1
	profile.xp = 0
	profile.hunger = 60
	DataService.markDirty(player)
	GiantService.refresh(player)
	PlotService.pushState(player)
	Remotes.Notify:FireAllClients(Locale.msg("rebirth_broadcast", { p = player.DisplayName, n = profile.rebirths }, Color3.fromRGB(255, 120, 255)))
end

function ShopService.redeem(player: Player, code: string)
	local profile = DataService.get(player)
	if not profile or type(code) ~= "string" then
		return
	end
	code = string.upper(string.sub(code, 1, 20))
	local reward = Config.PromoCodes[code]
	if not reward then
		Remotes.Notify:FireClient(player, { text = "Código inválido.", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	if profile.redeemedCodes[code] then
		Remotes.Notify:FireClient(player, { text = "Código já usado.", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	profile.redeemedCodes[code] = true
	profile.coins += reward
	DataService.markDirty(player)
	PlotService.pushState(player)
	Remotes.Notify:FireClient(player, Locale.msg("code_ok", { n = Util.formatNumber(reward) }, Color3.fromRGB(80, 255, 120)))
end

function ShopService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	local elapsed = now - profile.lastDaily
	if elapsed < 20 * 3600 then
		Remotes.Notify:FireClient(player, { text = "Volte amanhã para a próxima recompensa!", color = Color3.fromRGB(255, 200, 80) })
		return
	end
	if elapsed > 48 * 3600 then
		profile.dailyStreak = 0
	end
	profile.dailyStreak = math.min(profile.dailyStreak + 1, #Config.DailyRewards)
	profile.lastDaily = now
	local reward = Config.DailyRewards[profile.dailyStreak]
	profile.coins += reward
	if profile.dailyStreak == #Config.DailyRewards then
		ShopService.openBox(player, "epic", true)
		profile.dailyStreak = 0
	end
	DataService.markDirty(player)
	PlotService.pushState(player)
	Remotes.Notify:FireClient(player, Locale.msg("daily_ok", { n = Util.formatNumber(reward) }, Color3.fromRGB(80, 255, 120)))
end

function ShopService.buySpecies(player: Player, speciesId: string)
	local profile = DataService.get(player)
	local sp = Config.SpeciesById[speciesId]
	if not profile or not sp then
		return
	end
	if profile.ownedSpecies[speciesId] then
		GiantService.setSpecies(player, speciesId)
		PlotService.pushState(player)
		return
	end
	if sp.robux then
		Remotes.Notify:FireClient(player, Locale.msg("pass_only", { s = sp.name }, Color3.fromRGB(255, 200, 80)))
		return
	end
	if profile.coins < sp.price then
		Remotes.Notify:FireClient(player, Locale.msg("need_coins", { n = Util.formatNumber(sp.price - profile.coins), s = sp.name }, Color3.fromRGB(255, 90, 90)))
		return
	end
	profile.coins -= sp.price
	profile.ownedSpecies[speciesId] = true
	DataService.markDirty(player)
	GiantService.setSpecies(player, speciesId)
	PlotService.pushState(player)
	Remotes.Notify:FireAllClients(Locale.msg("species_unlocked_broadcast", { p = player.DisplayName, s = sp.name, r = sp.rarityTag }, sp.color))
end

function ShopService.init()
	Remotes.RequestBuySpecies.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			ShopService.buySpecies(player, id)
		end
	end)
	Remotes.RequestEquipSpecies.OnServerEvent:Connect(function(player, id)
		local profile = DataService.get(player)
		if type(id) == "string" and profile and profile.ownedSpecies[id] then
			GiantService.setSpecies(player, id)
			PlotService.pushState(player)
		end
	end)
	GiantService.OnReturnBonus = function(player, _away)
		ShopService.openBox(player, Config.Decay.ReturnBonusBox, true, nil)
	end
	Remotes.RequestBuyBox.OnServerEvent:Connect(function(player, boxId)
		if type(boxId) == "string" then
			ShopService.openBox(player, boxId)
		end
	end)
	Remotes.RequestRebirth.OnServerEvent:Connect(ShopService.rebirth)
	Remotes.RequestRedeemCode.OnServerEvent:Connect(function(player, code)
		ShopService.redeem(player, code)
	end)
	Remotes.RequestClaimDaily.OnServerEvent:Connect(ShopService.claimDaily)
end

return ShopService
