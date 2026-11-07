--!strict
-- ArenaService — Giant Clash: duelos 1v1 encenados entre Gigantes + campeonato automático a cada 15 min.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)
local ShopService = require(script.Parent.ShopService)
local Guard = require(script.Parent.Parent.Guard)

local A = Config.Arena
local ArenaService = {}
local pending: { [Player]: { challenger: Player, at: number } } = {} -- target -> desafio
local busy: { [Player]: boolean } = {}

local function notify(p: Player, text: string, color: Color3)
	Remotes.Notify:FireClient(p, { text = text, color = color })
end

function ArenaService.power(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	local sp = GiantService.species(profile)
	return sp.arenaPower
		* (1 + profile.level * A.LevelFactor)
		* (1 + profile.rebirths * A.RebirthFactor)
		* GiantService.moodMultiplier(profile)
end

-- Quem está no torneio (lutando ou esperando a vez) não aceita duelo comum em paralelo.
local inTournament: { [Player]: boolean } = {}

local function canFight(p: Player): (boolean, string?)
	local profile = DataService.get(p)
	if not profile then
		return false, Locale.t("Dados não carregados.", Locale.of(p))
	end
	if profile.level < A.MinLevelToFight then
		return false, Locale.fmt("arena_minlevel", Locale.of(p), { n = A.MinLevelToFight })
	end
	if busy[p] or inTournament[p] then
		return false, Locale.t("Já está em uma luta.", Locale.of(p))
	end
	return true, nil
end

local function cooldownLeft(p: Player): number
	local profile = DataService.get(p)
	if not profile then
		return 0
	end
	local cd = if profile.passes.ArenaVIP then A.DuelCooldown / 2 else A.DuelCooldown
	return math.max(0, profile.lastDuel + cd - os.time())
end

local function stealFromLoser(winner: Player, loser: Player): { string }
	local wp, lp = DataService.get(winner), DataService.get(loser)
	if not wp or not lp then
		return {}
	end
	local n = if wp.passes.ArenaVIP then A.WinStealFoodCount + 1 else A.WinStealFoodCount
	local slots = {}
	for key, food in lp.plot do
		local def = Config.FoodById[food.id]
		if def then
			table.insert(
				slots,
				{ slot = tonumber(key) :: number, order = Config.Rarities[def.rarity].order, id = food.id }
			)
		end
	end
	table.sort(slots, function(a, b)
		return a.order > b.order
	end)
	local names = {}
	for i = 1, math.min(n, #slots) do
		local item = PlotService.removeFromPlot(loser, slots[i].slot)
		if item then
			-- force: a comida já existia (saiu do pátio do perdedor); nunca pode sumir.
			PlotService.giveFood(winner, item.id, true)
			table.insert(names, Config.FoodById[item.id].name)
		end
	end
	local coins = math.min(A.WinCoinsCap, math.floor(lp.coins * A.WinCoinsPct))
	lp.coins -= coins
	wp.coins += coins
	return names
end

-- Luta encenada: servidor decide o vencedor por poder + sorte, manda ticks para os clientes animarem.
-- Os ticks são neutros (mesmo dano para os dois) e só o último revela o vencedor: assim
-- ninguém descobre que vai perder e sai do jogo para escapar da derrota.
local function duelBody(a: Player, b: Player, tournament: boolean): Player?
	local pa, pb = ArenaService.power(a), ArenaService.power(b)
	local ra = pa * (1 + (math.random() * 2 - 1) * A.LuckRange)
	local rb = pb * (1 + (math.random() * 2 - 1) * A.LuckRange)
	local winner, loser = if ra >= rb then a else b, if ra >= rb then b else a
	local hpA, hpB = 100, 100
	local pay = {
		kind = "Start",
		a = a.UserId,
		b = b.UserId,
		aName = a.DisplayName,
		bName = b.DisplayName,
		powerA = math.floor(pa),
		powerB = math.floor(pb),
		seconds = A.RoundSeconds,
		tournament = tournament,
	}
	Remotes.ArenaState:FireAllClients(pay)
	local ticks = 8
	for i = 1, ticks do
		task.wait(A.RoundSeconds / ticks)
		if not a.Parent or not b.Parent then
			break
		end
		local hitA = 6 + math.random(0, 8)
		local hitB = 6 + math.random(0, 8)
		hpB = math.max(if i == ticks and winner == a then 0 else 1, hpB - hitA)
		hpA = math.max(if i == ticks and winner == b then 0 else 1, hpA - hitB)
		Remotes.ArenaState:FireAllClients({
			kind = "Tick",
			a = a.UserId,
			b = b.UserId,
			hpA = hpA,
			hpB = hpB,
			attacker = if i % 2 == 0 then a.UserId else b.UserId,
		})
	end
	if not a.Parent or not b.Parent then
		-- Quem saiu desistiu: quem ficou leva a vitória (sem roubo nem moedas).
		local stayed = if a.Parent then a elseif b.Parent then b else nil
		local sp = stayed and DataService.get(stayed)
		if stayed and sp then
			sp.arenaWins += 1
			sp.arenaStreak += 1
			DataService.markDirty(stayed)
			PlotService.pushState(stayed)
		end
		Remotes.ArenaState:FireAllClients({
			kind = "End",
			a = a.UserId,
			b = b.UserId,
			winner = if stayed then stayed.UserId else 0,
			aborted = true,
		})
		return stayed
	end
	local wp, lp = DataService.get(winner), DataService.get(loser)
	local stolen = {}
	if wp and lp then
		wp.arenaWins += 1
		wp.arenaStreak += 1
		lp.arenaLosses += 1
		lp.arenaStreak = 0
		lp.duelProtectionUntil = os.time() + A.LoserProtectionSec
		if not tournament then
			stolen = stealFromLoser(winner, loser)
		end
		DataService.markDirty(winner)
		DataService.markDirty(loser)
		PlotService.pushState(winner)
		PlotService.pushState(loser)
	end
	Remotes.ArenaState:FireAllClients({
		kind = "End",
		a = a.UserId,
		b = b.UserId,
		winner = winner.UserId,
		winnerName = winner.DisplayName,
		stolen = stolen,
		tournament = tournament,
	})
	Remotes.Notify:FireAllClients(
		Locale.msg(
			"arena_won_broadcast",
			{ a = winner.DisplayName, b = loser.DisplayName },
			Color3.fromRGB(255, 200, 60)
		)
	)
	return winner
end

-- Envolve a luta: `busy` é limpo SEMPRE, mesmo se algo der erro no meio.
local function runDuel(a: Player, b: Player, tournament: boolean): Player?
	busy[a], busy[b] = true, true
	local ok, result = pcall(duelBody, a, b, tournament)
	busy[a], busy[b] = nil, nil
	if not ok then
		warn("[ArenaService] duelo:", result)
		Remotes.ArenaState:FireAllClients({ kind = "End", a = a.UserId, b = b.UserId, winner = 0, aborted = true })
		return nil
	end
	return result
end

local function requestDuel(challenger: Player, targetId: number)
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == challenger then
		return
	end
	local ok, why = canFight(challenger)
	if not ok then
		return notify(challenger, why :: string, Color3.fromRGB(255, 120, 80))
	end
	local ok2, why2 = canFight(target)
	if not ok2 then
		return notify(challenger, target.DisplayName .. ": " .. (why2 :: string), Color3.fromRGB(255, 120, 80))
	end
	local cd = cooldownLeft(challenger)
	if cd > 0 then
		return notify(
			challenger,
			Locale.fmt("arena_wait", Locale.of(challenger), { n = cd }),
			Color3.fromRGB(255, 120, 80)
		)
	end
	local tp = DataService.get(target)
	if tp and tp.duelProtectionUntil > os.time() then
		return notify(
			challenger,
			Locale.fmt(
				"arena_protected",
				Locale.of(challenger),
				{ p = target.DisplayName, n = tp.duelProtectionUntil - os.time() }
			),
			Color3.fromRGB(120, 200, 255)
		)
	end
	if pending[target] then
		return notify(
			challenger,
			Locale.fmt("arena_pending", Locale.of(challenger), { p = target.DisplayName }),
			Color3.fromRGB(255, 120, 80)
		)
	end
	pending[target] = { challenger = challenger, at = os.time() }
	Remotes.ArenaState:FireClient(target, {
		kind = "Challenge",
		from = challenger.UserId,
		fromName = challenger.DisplayName,
		power = math.floor(ArenaService.power(challenger)),
	})
	Remotes.ArenaState:FireClient(challenger, { kind = "Sent", to = target.UserId, toName = target.DisplayName })
	task.delay(20, function()
		local p = pending[target]
		if p and p.challenger == challenger then
			pending[target] = nil
			Remotes.ArenaState:FireClient(challenger, { kind = "Declined", by = target.UserId, timeout = true })
		end
	end)
end

local function answerDuel(target: Player, challengerId: number, accept: boolean)
	local p = pending[target]
	if not p or p.challenger.UserId ~= challengerId then
		return
	end
	pending[target] = nil
	local challenger = p.challenger
	if not accept or not challenger.Parent then
		Remotes.ArenaState:FireClient(challenger, { kind = "Declined", by = target.UserId })
		return
	end
	local ok1 = canFight(challenger)
	local ok2 = canFight(target)
	if not ok1 or not ok2 then
		return
	end
	local cp, tp = DataService.get(challenger), DataService.get(target)
	if cp then
		cp.lastDuel = os.time()
	end
	if tp then
		tp.lastDuel = os.time()
	end
	PlotService.pushState(challenger)
	PlotService.pushState(target)
	task.spawn(runDuel, challenger, target, false)
end

local function runTournament()
	local pool = {}
	for _, p in Players:GetPlayers() do
		local ok = canFight(p)
		if ok then
			table.insert(pool, p)
		end
	end
	if #pool < A.TournamentMinPlayers then
		return
	end
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for _, p in pool do
		inTournament[p] = true
	end
	Remotes.ArenaState:FireAllClients({ kind = "Tournament", players = #pool })
	Remotes.Notify:FireAllClients(Locale.msg("tourney_start", { n = #pool }, Color3.fromRGB(255, 220, 80)))
	task.wait(5)
	while #pool > 1 do
		local nextRound = {}
		for i = 1, #pool, 2 do
			local a, b = pool[i], pool[i + 1]
			if b and a.Parent and b.Parent then
				local w = runDuel(a, b, true)
				if w then
					table.insert(nextRound, w)
				end
				task.wait(3)
			else
				-- Sem adversário (ímpar) ou um dos dois saiu: quem ficou avança.
				local stays = if a.Parent then a elseif b and b.Parent then b else nil
				if stays then
					table.insert(nextRound, stays)
				end
			end
		end
		pool = nextRound
	end
	local champ = pool[1]
	if champ and champ.Parent then
		local profile = DataService.get(champ)
		if profile then
			profile.championships += 1
			profile.championUntil = os.time() + A.ChampionTrophyDays * 86400
			profile.coins += A.TournamentPrizeCoins
			DataService.markDirty(champ)
			ShopService.openBox(champ, A.TournamentPrizeBox, { free = true, force = true })
			GiantService.refresh(champ, true)
			PlotService.pushState(champ)
		end
		Remotes.ArenaState:FireAllClients({ kind = "Champion", winner = champ.UserId, winnerName = champ.DisplayName })
		Remotes.Notify:FireAllClients(
			Locale.msg(
				"tourney_champ",
				{ p = champ.DisplayName, n = A.TournamentPrizeCoins },
				Color3.fromRGB(255, 255, 255)
			)
		)
	end
end

function ArenaService.init()
	Remotes.RequestDuel.OnServerEvent:Connect(function(player, targetId)
		-- UserId inteiro e não zero (no teste local do Studio os jogadores têm ids negativos).
		if
			type(targetId) == "number"
			and targetId == targetId
			and targetId ~= 0
			and math.floor(targetId) == targetId
			and Guard.allow(player, "Duel")
		then
			requestDuel(player, targetId)
		end
	end)
	Remotes.RequestDuelAnswer.OnServerEvent:Connect(function(player, challengerId, accept)
		if
			type(challengerId) ~= "number"
			or challengerId ~= challengerId
			or type(accept) ~= "boolean"
			or not Guard.allow(player, "Duel")
		then
			return
		end
		answerDuel(player, challengerId, accept)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		busy[player] = nil
		inTournament[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(A.TournamentEvery)
			local ok, err = pcall(runTournament :: any)
			table.clear(inTournament) -- sempre, mesmo se o torneio der erro
			if not ok then
				warn("[ArenaService]", err)
			end
		end
	end)
end

return ArenaService
