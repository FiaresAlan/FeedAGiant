--!strict
-- MonetizationService — Game Passes e Developer Products (Robux).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local StealService = require(script.Parent.StealService)
local GiantService = require(script.Parent.GiantService)
local CombatService = require(script.Parent.CombatService)

local MonetizationService = {}

local function refreshPasses(player: Player)
	local profile = DataService.waitFor(player)
	if not profile then
		return
	end
	for key, id in Config.GamePasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				profile.passes[key] = true
			end
		end
	end
	GiantService.onPassesChanged(player)
	PlotService.pushState(player)
end

local function grantProduct(player: Player, productId: number): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	for key, def in Config.DevProducts do
		if def.id == productId then
			if key == "Coins10k" or key == "Coins100k" then
				profile.coins += (def :: any).coins
			elseif key == "SuperShield" then
				StealService.giveShield(player, Config.Steal.SuperShieldSec)
			elseif key == "LuckyBox" then
				ShopService.openBox(player, "rare", true, "Rare")
			elseif key == "FreezeDecay7d" then
				profile.freezeUntil = math.max(os.time(), profile.freezeUntil) + Config.Decay.FreezeProductSeconds
				Remotes.Notify:FireClient(
					player,
					{ text = "Encolhimento CONGELADO por 7 dias!", color = Color3.fromRGB(120, 220, 255) }
				)
			elseif key == "RestoreLevels" then
				local lost = profile.levelsLostToDecay
				profile.level = math.min(Config.Giant.MaxLevel, profile.level + lost)
				profile.levelsLostToDecay = 0
				GiantService.refresh(player, true)
				Remotes.Notify:FireClient(player, Locale.msg("restored", { n = lost }, Color3.fromRGB(255, 220, 80)))
			elseif key == "StaminaRefill" then
				CombatService.refillStamina(player, 60)
				Remotes.Notify:FireClient(
					player,
					{ text = "Stamina INFINITA por 60s!", color = Color3.fromRGB(255, 200, 60) }
				)
			elseif key == "ArenaRematch" then
				profile.lastDuel = 0
				Remotes.Notify:FireClient(
					player,
					{ text = "Cooldown de duelo zerado!", color = Color3.fromRGB(255, 120, 120) }
				)
			elseif key == "SpeciesReroll" then
				local pool = {}
				for _, sp in Config.Species do
					if not sp.robux and not profile.ownedSpecies[sp.id] then
						table.insert(pool, sp)
					end
				end
				if #pool > 0 then
					local pick = pool[math.random(1, #pool)]
					profile.ownedSpecies[pick.id] = true
					GiantService.setSpecies(player, pick.id)
					Remotes.Notify:FireClient(player, Locale.msg("new_species", { s = pick.name }, pick.color))
				else
					profile.coins += 50000
					Remotes.Notify:FireClient(
						player,
						{
							text = "Você já tem todas as espécies! +50.000 moedas.",
							color = Color3.fromRGB(255, 220, 80),
						}
					)
				end
			end
			DataService.markDirty(player)
			PlotService.pushState(player)
			Remotes.Notify:FireClient(
				player,
				{ text = "Compra recebida. Obrigado!", color = Color3.fromRGB(80, 255, 120) }
			)
			return true
		end
	end
	return false
end

function MonetizationService.init()
	Players.PlayerAdded:Connect(refreshPasses)
	for _, p in Players:GetPlayers() do
		task.spawn(refreshPasses, p)
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok = grantProduct(player, receipt.ProductId)
		return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local profile = DataService.get(player)
			if profile then
				for key, id in Config.GamePasses do
					if id == passId then
						profile.passes[key] = true
					end
				end
				GiantService.onPassesChanged(player)
				DataService.markDirty(player)
				PlotService.pushState(player)
				PlotService.rebuildPlot(player)
			end
		end
	end)

	Remotes.RequestPurchase.OnServerEvent:Connect(function(player, key)
		local def = Config.DevProducts[key]
		if def and def.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, def.id)
		else
			Remotes.Notify:FireClient(
				player,
				{ text = "Produto ainda não configurado (ID 0 em Config.lua).", color = Color3.fromRGB(255, 200, 80) }
			)
		end
	end)
	Remotes.RequestGamePass.OnServerEvent:Connect(function(player, key)
		local id = Config.GamePasses[key]
		if id and id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			Remotes.Notify:FireClient(
				player,
				{ text = "Game Pass ainda não configurado (ID 0 em Config.lua).", color = Color3.fromRGB(255, 200, 80) }
			)
		end
	end)
end

return MonetizationService
