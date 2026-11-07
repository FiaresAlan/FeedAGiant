--!strict
-- MonetizationService — Game Passes e Developer Products (Robux).
--
-- Fase 0.4/0.5 (ver docs/DIAGNOSTICO_E_PLANO.md, C3/H1/H5/L1/L4):
--   * ProcessReceipt é do módulo Receipts (fwjelaa): PurchaseId gravado no MESMO documento
--     da entrega, PurchaseGranted só depois do save, recibo repetido nunca entrega 2x.
--   * Cada entrega é síncrona (sem yield) e retorna true só quando entregou de verdade.
--   * Checagens no momento do PROMPT (nunca recusar um recibo já pago): produto com ID 0,
--     itens aleatórios pagos (PolicyService), "Restaurar Níveis" sem níveis perdidos,
--     "Ficha de Espécie" sem espécie para escolher.
--   * Game Passes: conferidos na entrada (com retentativa). Erro nunca vira "não tem";
--     resposta "não tem" remove o passe (reembolso/revogação deixam de valer).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Vendor = ServerScriptService:WaitForChild("fwjelaa")
local Receipts = require(Vendor:WaitForChild("Receipts"))
local Policy = require(Vendor:WaitForChild("Policy"))
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local StealService = require(script.Parent.StealService)
local GiantService = require(script.Parent.GiantService)
local CombatService = require(script.Parent.CombatService)

local MonetizationService = {}

local PASS_CHECK_ATTEMPTS = 4
local PROMPT_COOLDOWN = 1
local lastPrompt: { [Player]: number } = {}

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, { text = text, color = color or Color3.fromRGB(255, 200, 80) })
end

---------------------------------------------------------------------------
-- Game Passes
---------------------------------------------------------------------------
local function ownsPassAsync(player: Player, id: number): boolean?
	for attempt = 1, PASS_CHECK_ATTEMPTS do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok then
			return owns == true
		end
		if player.Parent ~= Players then
			return nil
		end
		task.wait(2 ^ (attempt - 1))
	end
	return nil -- erro: não sabemos (mantém o valor salvo)
end

local function refreshPasses(player: Player)
	local profile = DataService.waitFor(player, 45)
	if not profile then
		return
	end
	local changed = false
	for rawKey, rawId in Config.GamePasses do
		local key, id = rawKey :: string, rawId :: number
		if id ~= 0 then
			local owns = ownsPassAsync(player, id)
			local current = DataService.get(player) -- pode ter saído durante a espera
			if not current then
				return
			end
			if owns ~= nil and (current.passes[key] == true) ~= owns then
				local passes: { [string]: boolean? } = current.passes :: any
				passes[key] = if owns then true else nil
				changed = true
			end
		end
	end
	if changed then
		DataService.markDirty(player)
	end
	GiantService.onPassesChanged(player)
	PlotService.pushState(player)
	PlotService.rebuildPlot(player)
end

---------------------------------------------------------------------------
-- Developer Products: entregas (síncronas, retornam true só se entregaram)
---------------------------------------------------------------------------
type Grant = (player: Player, profile: DataService.Profile) -> boolean

local GRANTS: { [string]: Grant } = {
	Coins10k = function(_player, profile)
		profile.coins += Config.DevProducts.Coins10k.coins
		return true
	end,
	Coins100k = function(_player, profile)
		profile.coins += Config.DevProducts.Coins100k.coins
		return true
	end,
	SuperShield = function(player, _profile)
		StealService.giveShield(player, Config.Steal.SuperShieldSec)
		return true
	end,
	LuckyBox = function(player, _profile)
		-- force: já foi pago, entrega mesmo com a mochila cheia.
		return ShopService.openBox(player, "rare", { free = true, minRarity = "Rare", force = true })
	end,
	FreezeDecay7d = function(player, profile)
		profile.freezeUntil = math.max(os.time(), profile.freezeUntil) + Config.Decay.FreezeProductSeconds
		notify(player, "Encolhimento CONGELADO por 7 dias!", Color3.fromRGB(120, 220, 255))
		return true
	end,
	RestoreLevels = function(player, profile)
		-- Sem níveis perdidos a compra é bloqueada no prompt; se ainda assim chegar,
		-- entrega o que der (nunca recusar recibo pago).
		local lost = profile.levelsLostToDecay
		profile.level = math.min(Config.Giant.MaxLevel, profile.level + lost)
		profile.levelsLostToDecay = 0
		GiantService.refresh(player, true)
		Remotes.Notify:FireClient(player, Locale.msg("restored", { n = lost }, Color3.fromRGB(255, 220, 80)))
		return true
	end,
	StaminaRefill = function(player, _profile)
		CombatService.refillStamina(player, 60)
		notify(player, "Stamina INFINITA por 60s!")
		return true
	end,
	ArenaRematch = function(player, profile)
		profile.lastDuel = 0
		notify(player, "Cooldown de duelo zerado!", Color3.fromRGB(255, 120, 120))
		return true
	end,
	SpeciesReroll = function(player, profile)
		profile.speciesTokens = (profile.speciesTokens or 0) + 1
		notify(player, "Você ganhou 1 Ficha de Espécie! Escolha sua espécie na Loja › Espécies.")
		return true
	end,
}

-- Checagens no momento do prompt. Retorna (pode, motivo).
local function canPrompt(player: Player, key: string): (boolean, string?)
	local def = (Config.DevProducts :: any)[key]
	if not def then
		return false, nil
	end
	if def.id == 0 then
		return false, "Produto ainda não configurado (ID 0 em Config.lua)."
	end
	if (def.paidRandom or def.fundsRandom) and not Policy.CanBuyPaidRandom(player) then
		return false, "Este item não está disponível para a sua conta."
	end
	local profile = DataService.get(player)
	if not profile then
		return false, "Seus dados ainda estão carregando."
	end
	if key == "RestoreLevels" and profile.levelsLostToDecay <= 0 then
		return false, "Seu Gigante não perdeu nenhum nível."
	end
	if key == "SpeciesReroll" and #ShopService.tokenTargets(profile) <= (profile.speciesTokens or 0) then
		return false, "Você já tem fichas suficientes para todas as espécies que faltam."
	end
	return true, nil
end

function MonetizationService.init()
	Policy.Init()

	-- Todos os produtos usam entregas próprias (Receipts sem o módulo Rewards).
	local products = {}
	for rawKey, def in Config.DevProducts do
		local key = rawKey :: string
		assert(GRANTS[key], `MonetizationService: produto {key} sem entrega`)
		products[key] = {
			id = (def :: any).id,
			custom = key,
			paidRandom = (def :: any).paidRandom == true,
		}
		Receipts.SetCustomGrant(key, function(player: Player, _p: any, _receipt: any): boolean
			local profile = DataService.get(player)
			if not profile then
				return false
			end
			local ok = GRANTS[key](player, profile)
			if ok then
				PlotService.pushState(player)
			end
			return ok
		end)
	end
	Receipts.Init({ products = products :: any })
	Receipts.Granted:Connect(function(player: Player, _key: string)
		notify(player, "Compra recebida. Obrigado!", Color3.fromRGB(80, 255, 120))
	end)
	Receipts.Start()

	Players.PlayerAdded:Connect(refreshPasses)
	for _, p in Players:GetPlayers() do
		task.spawn(refreshPasses, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local profile = DataService.get(player)
		if not profile then
			return
		end
		for rawKey, id in Config.GamePasses do
			local key = rawKey :: string
			if id ~= 0 and id == passId then
				profile.passes[key] = true
			end
		end
		GiantService.onPassesChanged(player)
		DataService.markDirty(player)
		PlotService.pushState(player)
		PlotService.rebuildPlot(player)
	end)

	local function promptAllowed(player: Player): boolean
		local now = os.clock()
		if (lastPrompt[player] or 0) + PROMPT_COOLDOWN > now then
			return false
		end
		lastPrompt[player] = now
		return true
	end

	Remotes.RequestPurchase.OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" or #key > 40 or not promptAllowed(player) then
			return
		end
		local ok, why = canPrompt(player, key)
		if not ok then
			if why then
				notify(player, why)
			end
			return
		end
		MarketplaceService:PromptProductPurchase(player, (Config.DevProducts :: any)[key].id)
	end)
	Remotes.RequestGamePass.OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" or #key > 40 or not promptAllowed(player) then
			return
		end
		local id = Config.GamePasses[key]
		if id and id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, id)
		elseif id then
			notify(player, "Game Pass ainda não configurado (ID 0 em Config.lua).")
		end
	end)
end

return MonetizationService
