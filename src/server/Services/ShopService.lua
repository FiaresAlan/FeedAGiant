--!strict
-- ShopService — Lunchboxes, rebirth, códigos promocionais, recompensa diária, espécies.
--
-- Fase 0 (ver docs/DIAGNOSTICO_E_PLANO.md):
--   * H1: o anti-spam fica SÓ no pedido do jogador (RequestBuyBox). Caixas grátis/pagas
--     (diário, campeonato, Lucky Box, bônus de volta) nunca são descartadas em silêncio.
--   * Mochila cheia: a caixa comprada com moedas é recusada ANTES de cobrar.
--   * 0.5: sorteio pela tabela única LunchboxOdds (a mesma mostrada na loja).
--   * 0.6: códigos promocionais lidos de Server/Secrets (não replicado).
--   * Ficha de espécie: o produto "Trocar Espécie" dá uma ficha; o jogador ESCOLHE a
--     espécie (antes era sorteio pago sem chances visíveis).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Hooks = require(script.Parent.Parent.Hooks)
local LunchboxOdds = require(game.ReplicatedStorage.Shared.LunchboxOdds)
local Secrets = require(script.Parent.Parent.Secrets)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)
local StealService = require(script.Parent.StealService)
local TutorialService = require(script.Parent.TutorialService)
local Guard = require(script.Parent.Parent.Guard)

local ShopService = {}
local luckBonus = 0 -- alterado por EventService (Lucky Boxes)
local lastBuy: { [Player]: number } = {}
local rng = Random.new()

local BUY_COOLDOWN = 0.4
local FIREWORKS_GAP = 4
local lastFireworks = -math.huge
local RARE_BANNER_GAP = 6 -- segundos entre faixas de "comida rara" para o servidor todo
local lastRareBanner = -math.huge

export type OpenOptions = {
	free: boolean?, -- não cobra moedas (recompensas e produtos)
	minRarity: string?, -- Lucky Box: raridade mínima garantida
	force: boolean?, -- entrega mesmo com a mochila cheia (já pago ou prêmio único)
	-- paid: comprado com Robux. Sorteia SEM bônus de evento (as chances mostradas na
	-- compra não mudam se o recibo chegar depois do evento) e entrega sempre.
	paid: boolean?,
}

function ShopService.setLuckBonus(b: number)
	luckBonus = math.max(0, b)
	ReplicatedStorage:SetAttribute(LunchboxOdds.LUCK_ATTRIBUTE, luckBonus)
end

function ShopService.getLuckBonus(): number
	return luckBonus
end

-- Abre uma caixa. Retorna true se entregou. Nunca descarta em silêncio: toda recusa avisa.
function ShopService.openBox(player: Player, boxId: string, options: OpenOptions?): boolean
	local opts: OpenOptions = options or {}
	local profile = DataService.get(player)
	local box = Config.LunchboxById[boxId]
	if not profile or not box then
		return false
	end
	if not opts.force and not PlotService.hasInventorySpace(profile) then
		Remotes.Notify:FireClient(player, {
			text = "Mochila cheia! Alimente seu Gigante ou coloque comida no pátio.",
			color = Color3.fromRGB(255, 90, 90),
		})
		return false
	end
	if not opts.free then
		if profile.coins < box.price then
			Remotes.Notify:FireClient(player, { text = "Moedas insuficientes!", color = Color3.fromRGB(255, 90, 90) })
			return false
		end
		profile.coins -= box.price
	end
	profile.totalBoxes += 1
	local food = LunchboxOdds.roll(boxId, if opts.paid then 0 else luckBonus, opts.minRarity, rng)
	if not PlotService.giveFood(player, food.id, true, opts.paid == true) then
		return false -- teto duro da mochila (só prêmios grátis chegam aqui)
	end
	StealService.giveShield(player, Config.Steal.PurchaseShieldSec)
	Remotes.HatchResult:FireClient(
		player,
		{ foodId = food.id, rarity = food.rarity, name = food.name, color = food.color, boxId = boxId }
	)
	-- Pedido do usuário (08/11): comida Épica ou melhor = fogos de artifício no servidor inteiro.
	if Config.Rarities[food.rarity].order >= 4 then
		local now = os.clock()
		-- Lendária ou melhor anuncia SEMPRE (uma vez por conquista: fanfarra global); Épica respeita o intervalo.
		if now - lastFireworks >= FIREWORKS_GAP or Config.Rarities[food.rarity].order >= 5 then
			lastFireworks = now
			local char = player.Character
			Remotes.Fireworks:FireAllClients({
				userId = player.UserId,
				name = player.DisplayName,
				foodId = food.id,
				rarity = food.rarity,
				pos = if char then char:GetPivot().Position else nil,
				big = Config.Rarities[food.rarity].order >= 5,
			})
		end
	end
	if Config.Rarities[food.rarity].order >= 5 then
		-- Fase 3: faixa grande com a comida 3D para todos, no máximo 1 a cada 6 s (servidor cheio
		-- abrindo caixas não vira enxurrada); fora do limite fica só o aviso de texto.
		local now = os.clock()
		if now - lastRareBanner >= RARE_BANNER_GAP then
			lastRareBanner = now
			Remotes.RareFound:FireAllClients({
				userId = player.UserId,
				name = player.DisplayName,
				foodId = food.id,
				rarity = food.rarity,
			})
		end
		Remotes.Notify:FireAllClients(
			Locale.msg(
				"found_food",
				{ p = player.DisplayName, f = food.name, r = food.rarity },
				Config.Rarities[food.rarity].color
			)
		)
	end
	DataService.markDirty(player)
	PlotService.pushState(player)
	if not opts.free then
		TutorialService.signal(player, "BoughtBox")
	end
	return true
end

function ShopService.rebirth(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if profile.level < Config.Rebirth.MinLevel then
		Remotes.Notify:FireClient(
			player,
			Locale.msg("rebirth_req", { n = Config.Rebirth.MinLevel }, Color3.fromRGB(255, 90, 90))
		)
		return
	end
	profile.rebirths += 1
	profile.level = 1
	profile.xp = 0
	profile.hunger = 60
	DataService.markDirty(player)
	GiantService.refresh(player)
	PlotService.pushState(player)
	Remotes.Notify:FireAllClients(
		Locale.msg("rebirth_broadcast", { p = player.DisplayName, n = profile.rebirths }, Color3.fromRGB(255, 120, 255))
	)
end

function ShopService.redeem(player: Player, code: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	code = string.upper((string.gsub(string.sub(code, 1, 40), "%s", "")))
	code = string.sub(code, 1, 20)
	local reward = Secrets.PromoCodes[code]
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
	Remotes.Notify:FireClient(
		player,
		Locale.msg("code_ok", { n = Util.formatNumber(reward) }, Color3.fromRGB(80, 255, 120))
	)
end

function ShopService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	local elapsed = now - profile.lastDaily
	if elapsed < 20 * 3600 then
		Remotes.Notify:FireClient(
			player,
			{ text = "Volte amanhã para a próxima recompensa!", color = Color3.fromRGB(255, 200, 80) }
		)
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
		-- Prêmio do 7º dia: entregue mesmo com a mochila cheia (só acontece uma vez por ciclo).
		ShopService.openBox(player, "epic", { free = true, force = true })
		profile.dailyStreak = 0
	end
	DataService.markDirty(player)
	PlotService.pushState(player)
	Remotes.Notify:FireClient(
		player,
		Locale.msg("daily_ok", { n = Util.formatNumber(reward) }, Color3.fromRGB(80, 255, 120))
	)
end

-- Espécies compráveis com moedas que o jogador ainda não tem (alvo da ficha).
function ShopService.tokenTargets(profile: DataService.Profile): { string }
	local out = {}
	for _, sp in Config.Species do
		if not sp.robux and not profile.ownedSpecies[sp.id] then
			table.insert(out, sp.id)
		end
	end
	return out
end

local function unlockSpecies(player: Player, profile: DataService.Profile, sp: Config.SpeciesDef)
	-- Coleção (08/11/2026): a espécie nova herda 30% do crescimento do gigante ativo; o antigo
	-- continua salvo com o próprio nível (troca grátis a qualquer momento).
	local fromName = GiantService.species(profile).name
	local inherited = GiantService.grantSpecies(player, sp.id)
	DataService.markDirty(player)
	GiantService.setSpecies(player, sp.id)
	PlotService.pushState(player)
	Remotes.Notify:FireClient(
		player,
		Locale.msg(
			"transfer_ok",
			{ s = sp.name, n = inherited, f = fromName, p = math.floor(GameRules.Roster.TransferFraction * 100) },
			Color3.fromRGB(120, 255, 160)
		)
	)
	Hooks.fire("speciesUnlocked", player, sp.id)
	Remotes.Notify:FireAllClients(
		Locale.msg("species_unlocked_broadcast", { p = player.DisplayName, s = sp.name, r = sp.rarityTag }, sp.color)
	)
end

function ShopService.buySpecies(player: Player, speciesId: string, useToken: boolean)
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
	if useToken then
		if (profile.speciesTokens or 0) < 1 then
			Remotes.Notify:FireClient(
				player,
				{ text = "Você não tem Ficha de Espécie.", color = Color3.fromRGB(255, 90, 90) }
			)
			return
		end
		profile.speciesTokens -= 1
		unlockSpecies(player, profile, sp)
		return
	end
	if profile.coins < sp.price then
		Remotes.Notify:FireClient(
			player,
			Locale.msg(
				"need_coins",
				{ n = Util.formatNumber(sp.price - profile.coins), s = sp.name },
				Color3.fromRGB(255, 90, 90)
			)
		)
		return
	end
	profile.coins -= sp.price
	unlockSpecies(player, profile, sp)
end

function ShopService.init()
	ShopService.setLuckBonus(0)
	Remotes.RequestBuySpecies.OnServerEvent:Connect(function(player, id, useToken)
		if
			type(id) == "string"
			and #id <= 32
			and (useToken == nil or type(useToken) == "boolean")
			and Guard.allow(player, "Species")
		then
			ShopService.buySpecies(player, id, useToken == true)
		end
	end)
	Remotes.RequestEquipSpecies.OnServerEvent:Connect(function(player, id)
		local profile = DataService.get(player)
		if
			type(id) == "string"
			and profile
			and profile.ownedSpecies[id]
			and profile.species ~= id
			and Guard.allow(player, "Species")
		then
			GiantService.setSpecies(player, id)
			PlotService.pushState(player)
		end
	end)
	GiantService.OnReturnBonus = function(player, _away)
		ShopService.openBox(player, Config.Decay.ReturnBonusBox, { free = true, force = true })
	end
	Remotes.RequestBuyBox.OnServerEvent:Connect(function(player, boxId)
		if type(boxId) ~= "string" or not Config.LunchboxById[boxId] then
			return
		end
		local now = os.clock()
		if (lastBuy[player] or 0) + BUY_COOLDOWN > now then
			return -- anti-spam só aqui: pedido do próprio jogador, nada foi cobrado
		end
		lastBuy[player] = now
		ShopService.openBox(player, boxId)
	end)
	Remotes.RequestRebirth.OnServerEvent:Connect(function(player)
		if Guard.allow(player, "Rebirth") then
			ShopService.rebirth(player)
		end
	end)
	Remotes.RequestRedeemCode.OnServerEvent:Connect(function(player, code)
		if type(code) ~= "string" or #code > 64 then
			return
		end
		if not Guard.allow(player, "Redeem") then
			Remotes.Notify:FireClient(player, {
				text = "Calma! Espere alguns segundos para tentar outro código.",
				color = Color3.fromRGB(255, 200, 80),
			})
			return
		end
		ShopService.redeem(player, code)
	end)
	Remotes.RequestClaimDaily.OnServerEvent:Connect(function(player)
		if Guard.allow(player, "Daily") then
			ShopService.claimDaily(player)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return ShopService
