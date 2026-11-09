--!strict
-- ArenaService — Giant Clash: duelos 1v1 de BOXE DE VERDADE no coliseu (Fase 3) + campeonato a cada 15 min.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)
local ShopService = require(script.Parent.ShopService)
local Guard = require(script.Parent.Parent.Guard)
local World = require(script.Parent.Parent.World)
local MapService = require(script.Parent.MapService)
local CombatService = require(script.Parent.CombatService)
local StealService = require(script.Parent.StealService)
local DropService = require(script.Parent.DropService)
local BotService = require(script.Parent.BotService)
local Speed = require(script.Parent.Parent.Speed)

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
	if p:GetAttribute("CarryingEgg") then
		return false, "Entregue o ovo roubado antes de lutar."
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

local function transferArenaFood(wp: DataService.Profile, lp: DataService.Profile): { string }
	local n = if wp.passes.ArenaVIP then A.WinStealFoodCount + 1 else A.WinStealFoodCount
	local slots = {}
	for key, food in lp.plot do
		local def = Config.FoodById[food.id]
		if def then
			table.insert(slots, { key = key, order = Config.Rarities[def.rarity].order, item = food, name = def.name })
		end
	end
	table.sort(slots, function(a, b)
		return a.order > b.order
	end)
	local names = {}
	for i = 1, math.min(n, #slots) do
		if not PlotService.hasInventorySpace(wp, 1, true) then
			break
		end
		local entry = slots[i]
		table.insert(wp.inventory, entry.item)
		lp.plot[entry.key] = nil
		table.insert(names, entry.name)
	end
	return names
end

local function stealFromLoser(winner: Player, loser: Player): { string }
	local wp, lp = DataService.get(winner), DataService.get(loser)
	if not wp or not lp then
		return {}
	end
	local names = transferArenaFood(wp, lp)
	local coins = math.min(A.WinCoinsCap, math.floor(lp.coins * A.WinCoinsPct))
	lp.coins -= coins
	wp.coins += coins
	if #names > 0 then
		PlotService.rebuildPlot(loser)
	end
	return names
end

---------------------------------------------------------------------------
-- Fase 3: LUTA DE VERDADE na arena física (pedido do usuário: "mecânica de luta nas arenas").
-- Antes: luta encenada (servidor sorteava o vencedor e mandava ticks). Agora os dois lutadores
-- são levados ao coliseu (World.buildArena) e lutam com o boxe do CombatService (socos validados no
-- servidor). Vence quem: nocautear o outro, empurrá-lo para fora do ringue, ou tiver mais vida no
-- fim do tempo. Quem sai do jogo perde. Ninguém de fora acerta os lutadores (HitFilter).
---------------------------------------------------------------------------
local FIGHT_SECONDS = 60
local COUNTDOWN = 3
local fighting: { [Player]: Player } = {} -- lutador -> adversário
local frozen: { [Player]: boolean } = {} -- na contagem (sem andar, pular nem socar)
-- Revisão independente (Fase 3): UMA luta por vez no coliseu (duelos e campeonato).
local arenaInUse = false
-- Quem saiu no meio da luta (o castigo já foi aplicado ao sair, ver onReleasing).
local leftMidFight: { [Player]: boolean } = {}
-- Duelo contra bot (09/11, item 7): jogador -> uid do bot.
local botFight: { [Player]: number } = {}
local BOT_DUEL_HP = 150 -- mesma vida da "luta justa" de um jogador (CombatService.FAIR_HP)

local function arenaSpots(): (CFrame?, CFrame?)
	local map = Workspace:FindFirstChild("Map")
	local arena = map and map:FindFirstChild("Arena")
	local sa = arena and arena:FindFirstChild("SpawnA")
	local sb = arena and arena:FindFirstChild("SpawnB")
	if sa and sb and sa:IsA("BasePart") and sb:IsA("BasePart") then
		return sa.CFrame, sb.CFrame
	end
	return nil, nil
end

local function humanoidOf(p: Player): Humanoid?
	local char = p.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function sendTo(p: Player, at: CFrame, face: Vector3)
	local char = p.Character
	if char then
		local pos = at.Position + Vector3.new(0, 3, 0)
		char:PivotTo(CFrame.lookAt(pos, Vector3.new(face.X, pos.Y, face.Z)))
	end
end

local function sendHome(p: Player)
	if fighting[p] or busy[p] then
		return -- já está em outra luta (campeonato): não tirar do ringue
	end
	local base = MapService.getBaseOf(p)
	local char = p.Character
	if base and char and p.Parent then
		char:PivotTo(base.origin * CFrame.new(0, 6, 20))
	end
end

-- Espera o personagem existir (quem aceitou morto/renascendo), até `timeout` segundos.
local function waitCharacter(p: Player, timeout: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			return true
		end
		if not p.Parent then
			return false
		end
		task.wait(0.2)
	end
	return false
end

-- Quem não está lutando e entra no ringue durante uma luta é levado para a rampa do portão
-- (o filtro de golpes não impede empurrões de corpo).
local function clearIntruders(a: Player, b: Player)
	local c = World.Arena.center
	local gateOut = CFrame.lookAt(c, Vector3.new(0, 0, 0)) * CFrame.new(0, 3, -(World.Arena.outerR + 8))
	for _, p in Players:GetPlayers() do
		if p ~= a and p ~= b then
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local flat = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude
				if flat < World.Arena.floorR + 2 and root.Position.Y < World.Arena.floorTop + 12 then
					(char :: Model):PivotTo(gateOut)
					notify(p, "Luta em andamento! Assista das arquibancadas.", Color3.fromRGB(255, 200, 80))
				end
			end
		end
	end
end

-- Fora do ringue: longe do centro da arena (no plano) ou caiu abaixo do chão.
local function ringedOut(p: Player): boolean
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return true
	end
	local c = World.Arena.center
	local flat = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude
	return flat > World.Arena.floorR + 1
		or root.Position.Y < World.Arena.floorTop - 4
		or root.Position.Y > World.Arena.floorTop + 40 -- voar acima do ringue também conta como fora
end

-- Congela/solta guardando os valores originais (UseJumpPower ligado para JumpPower valer).
local saved: { [Player]: { walk: number, jump: number, useJP: boolean } } = {}
local function setFrozen(p: Player, on: boolean)
	local hum = humanoidOf(p)
	if on then
		frozen[p] = true
		if hum and not saved[p] then
			saved[p] = { walk = hum.WalkSpeed, jump = hum.JumpPower, useJP = hum.UseJumpPower }
			hum.UseJumpPower = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	else
		frozen[p] = nil
		local s = saved[p]
		saved[p] = nil
		if hum and s then
			hum.WalkSpeed = s.walk
			hum.JumpPower = s.jump
			hum.UseJumpPower = s.useJP
			Speed.refresh(p) -- velocidade certa na hora (eventos, ponte, carga), não a guardada
		end
	end
end

-- Resultado da luta: vencedor, perdedor e o motivo ("ko" | "ring" | "time" | "left").
local function fight(a: Player, b: Player): (Player?, Player?, string)
	local spotA, spotB = arenaSpots()
	if not spotA or not spotB then
		return nil, nil, "noarena"
	end
	-- Quem aceitou morto/renascendo: espera o personagem (até 6 s), senão perde por desistência.
	local readyA, readyB = waitCharacter(a, 6), waitCharacter(b, 6)
	if not readyA or not readyB then
		if not readyA and not readyB then
			return nil, nil, "left"
		end
		return if readyA then a else b, if readyA then b else a, "noshow"
	end
	StealService.dropCarried(a)
	StealService.dropCarried(b)
	DropService.dropCarried(a) -- ninguém entra na luta com comida/caixa do mapa na cabeça
	DropService.dropCarried(b)
	fighting[a], fighting[b] = b, a
	CombatService.resetFighter(a)
	CombatService.resetFighter(b)
	CombatService.setFightMode(a, true) -- luta da arena: modo de luta ligado para os dois
	CombatService.setFightMode(b, true)
	sendTo(a, spotA, spotB.Position)
	sendTo(b, spotB, spotA.Position)
	setFrozen(a, true)
	setFrozen(b, true)
	clearIntruders(a, b)
	task.wait(COUNTDOWN)
	setFrozen(a, false)
	setFrozen(b, false)

	local t0 = os.clock()
	local lastTick = 0
	local winner, loser, reason = nil, nil, "time"
	while true do
		task.wait(0.2)
		if not a.Parent or not b.Parent then
			winner = if a.Parent then a elseif b.Parent then b else nil
			loser = if winner == a then b else a
			reason = "left"
			break
		end
		local koA, koB = CombatService.isKO(a), CombatService.isKO(b)
		local outA, outB = ringedOut(a), ringedOut(b)
		if koA or koB then
			winner, loser, reason = if koB then a else b, if koB then b else a, "ko"
			break
		elseif outA or outB then
			-- se os dois saíram juntos, perde quem tem menos vida
			if outA and outB then
				local aBetter = CombatService.hpFraction(a) >= CombatService.hpFraction(b)
				winner, loser = if aBetter then a else b, if aBetter then b else a
			else
				winner, loser = if outB then a else b, if outB then b else a
			end
			reason = "ring"
			break
		end
		local now = os.clock()
		if now - lastTick >= 0.5 then
			lastTick = now
			clearIntruders(a, b)
			Remotes.ArenaState:FireAllClients({
				kind = "Tick",
				a = a.UserId,
				b = b.UserId,
				hpA = math.floor(CombatService.hpFraction(a) * 100),
				hpB = math.floor(CombatService.hpFraction(b) * 100),
				left = math.max(0, math.ceil(FIGHT_SECONDS - (now - t0))),
			})
		end
		if now - t0 >= FIGHT_SECONDS then
			local fa, fb = CombatService.hpFraction(a), CombatService.hpFraction(b)
			local aWins = if fa == fb then math.random() < 0.5 else fa > fb
			winner, loser, reason = if aWins then a else b, if aWins then b else a, "time"
			break
		end
	end
	fighting[a], fighting[b] = nil, nil
	setFrozen(a, false)
	setFrozen(b, false)
	return winner, loser, reason
end

local function duelBody(a: Player, b: Player, tournament: boolean): Player?
	local pa, pb = ArenaService.power(a), ArenaService.power(b)
	Remotes.ArenaState:FireAllClients({
		kind = "Start",
		a = a.UserId,
		b = b.UserId,
		aName = a.DisplayName,
		bName = b.DisplayName,
		powerA = math.floor(pa),
		powerB = math.floor(pb),
		seconds = FIGHT_SECONDS,
		countdown = COUNTDOWN,
		real = true,
		tournament = tournament,
	})
	local winnerOrNil, loserOrNil, reason = fight(a, b)
	if reason == "noarena" then
		notify(a, "A arena não está disponível agora.", Color3.fromRGB(255, 120, 80))
		notify(b, "A arena não está disponível agora.", Color3.fromRGB(255, 120, 80))
		Remotes.ArenaState:FireAllClients({ kind = "End", a = a.UserId, b = b.UserId, winner = 0, aborted = true })
		return nil
	end
	-- Volta para casa depois de alguns segundos (vencedor comemora na arena)
	task.delay(3, function()
		sendHome(a)
		sendHome(b)
	end)
	if reason == "left" or reason == "noshow" or not winnerOrNil or not loserOrNil then
		-- Desistência: quem ficou leva a vitória. Quem SAIU do jogo já levou a derrota e o castigo
		-- no momento da saída (onReleasing); quem não apareceu (morto/renascendo) só leva a derrota.
		local stayed = winnerOrNil or (if a.Parent then a elseif b.Parent then b else nil)
		local sp = stayed and DataService.get(stayed)
		if stayed and sp then
			sp.arenaWins += 1
			sp.arenaStreak += 1
			DataService.markDirty(stayed)
			PlotService.pushState(stayed)
		end
		local quitter = if reason == "noshow" then loserOrNil else nil
		local qp = quitter and DataService.get(quitter)
		if quitter and qp then
			qp.arenaLosses += 1
			qp.arenaStreak = 0
			DataService.markDirty(quitter)
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
	local winner: Player = winnerOrNil
	local loser: Player = loserOrNil
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
		reason = reason, -- "ko" | "ring" | "time"
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

-- Envolve a luta: trava a arena (uma luta por vez) e limpa TUDO no fim, mesmo com erro no meio
-- (revisão independente: `fighting` e o congelamento ficavam presos depois de um erro).
local currentTournament = false
local function runDuel(a: Player, b: Player, tournament: boolean): Player?
	busy[a], busy[b] = true, true
	local waited = 0
	while arenaInUse and waited < 90 do
		task.wait(0.5)
		waited += 0.5
	end
	if arenaInUse or not a.Parent or not b.Parent then
		busy[a], busy[b] = nil, nil
		return nil
	end
	arenaInUse = true
	currentTournament = tournament
	local ok, result = pcall(duelBody, a, b, tournament)
	arenaInUse = false
	fighting[a], fighting[b] = nil, nil
	setFrozen(a, false)
	setFrozen(b, false)
	busy[a], busy[b] = nil, nil
	leftMidFight[a], leftMidFight[b] = nil, nil
	if not ok then
		warn("[ArenaService] duelo:", result)
		Remotes.ArenaState:FireAllClients({ kind = "End", a = a.UserId, b = b.UserId, winner = 0, aborted = true })
		return nil
	end
	return result
end

-- Coliseu compartilhado (item 9.4): boxe, Dragão e gigantes, um de cada vez.
ArenaService.OtherBusy = nil :: (() -> boolean)?
function ArenaService.isBusy(): boolean
	return next(fighting) ~= nil or next(botFight) ~= nil
end

-- Luta de boxe contra um bot: mesma arena, contagem, tempo, nocaute e "fora do ringue" da luta entre
-- jogadores. Ninguém perde comida para bot nem tira comida de bot: vale vitória/derrota e a sequência.
local function botRingedOut(pos: Vector3?): boolean
	if not pos then
		return true
	end
	local c = World.Arena.center
	local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
	return flat > World.Arena.floorR + 1 or pos.Y < World.Arena.floorTop - 4
end

local function botDuelBody(a: Player, bot: any)
	local spotA, spotB = arenaSpots()
	if not spotA or not spotB or not waitCharacter(a, 6) then
		notify(a, "A arena não está disponível agora.", Color3.fromRGB(255, 120, 80))
		return
	end
	if not BotService.duelStart(bot.uid, spotB, spotA.Position, BOT_DUEL_HP) then
		notify(a, bot.name .. " já está em outra luta.", Color3.fromRGB(255, 170, 60))
		return
	end
	botFight[a] = bot.uid
	local pa = ArenaService.power(a)
	Remotes.ArenaState:FireAllClients({
		kind = "Start",
		a = a.UserId,
		b = bot.uid,
		aName = a.DisplayName,
		bName = bot.name,
		powerA = math.floor(pa),
		powerB = math.floor(pa * (0.85 + math.random() * 0.3)),
		seconds = FIGHT_SECONDS,
		countdown = COUNTDOWN,
		real = true,
		tournament = false,
	})
	StealService.dropCarried(a)
	DropService.dropCarried(a)
	CombatService.resetFighter(a)
	CombatService.setFightMode(a, true)
	sendTo(a, spotA, spotB.Position)
	setFrozen(a, true)
	task.wait(COUNTDOWN)
	setFrozen(a, false)
	BotService.duelGo(bot.uid, a, FIGHT_SECONDS)
	local t0 = os.clock()
	local lastTick = 0
	local playerWon: boolean? = nil
	local reason = "time"
	while a.Parent do
		task.wait(0.2)
		if not BotService.byUid(bot.uid) then
			reason = "botgone"
			break
		end
		local hpB, koB, posB = BotService.duelState(bot.uid)
		if CombatService.isKO(a) or koB then
			playerWon, reason = koB, "ko"
			break
		end
		local outA, outB = ringedOut(a), botRingedOut(posB)
		if outA or outB then
			playerWon = if outA and outB then CombatService.hpFraction(a) >= hpB else outB
			reason = "ring"
			break
		end
		local now = os.clock()
		if now - lastTick >= 0.5 then
			lastTick = now
			Remotes.ArenaState:FireAllClients({
				kind = "Tick",
				a = a.UserId,
				b = bot.uid,
				hpA = math.floor(CombatService.hpFraction(a) * 100),
				hpB = math.floor(hpB * 100),
				left = math.max(0, math.ceil(FIGHT_SECONDS - (now - t0))),
			})
		end
		if now - t0 >= FIGHT_SECONDS then
			local fa = CombatService.hpFraction(a)
			playerWon = if fa == hpB then math.random() < 0.5 else fa > hpB
			break
		end
	end
	if reason == "botgone" then
		-- o bot saiu do servidor (vaga para jogador real): luta anulada, ninguém ganha nem perde
		notify(a, bot.name .. " saiu do servidor. Luta anulada.", Color3.fromRGB(255, 200, 80))
		Remotes.ArenaState:FireAllClients({ kind = "End", a = a.UserId, b = bot.uid, winner = 0, aborted = true })
		task.delay(2, function()
			sendHome(a)
		end)
		return
	end
	if playerWon == nil then
		playerWon = false
		reason = "left"
	end
	BotService.duelEnd(bot.uid)
	BotService.arenaResult(bot.uid, not playerWon)
	local prof = DataService.get(a)
	if prof and reason ~= "left" then
		if playerWon then
			prof.arenaWins += 1
			prof.arenaStreak += 1
		else
			prof.arenaLosses += 1
			prof.arenaStreak = 0
		end
		DataService.markDirty(a)
		PlotService.pushState(a)
	end
	Remotes.ArenaState:FireAllClients({
		kind = "End",
		a = a.UserId,
		b = bot.uid,
		winner = if playerWon then a.UserId else bot.uid,
		winnerName = if playerWon then a.DisplayName else bot.name,
		stolen = {},
		tournament = false,
		reason = reason,
	})
	Remotes.Notify:FireAllClients(Locale.msg("arena_won_broadcast", {
		a = if playerWon then a.DisplayName else bot.name,
		b = if playerWon then bot.name else a.DisplayName,
	}, Color3.fromRGB(255, 200, 60)))
	task.delay(3, function()
		sendHome(a)
	end)
end

local function runBotDuel(a: Player, bot: any)
	busy[a] = true
	arenaInUse = true
	local ok, err = pcall(botDuelBody :: any, a, bot)
	arenaInUse = false
	botFight[a] = nil
	setFrozen(a, false)
	busy[a] = nil
	if not ok then
		warn("[ArenaService] duelo com bot:", err)
		BotService.duelEnd(bot.uid)
		Remotes.ArenaState:FireAllClients({ kind = "End", a = a.UserId, b = bot.uid, winner = 0, aborted = true })
		if a.Parent then
			CombatService.resetFighter(a)
			sendHome(a) -- não fica preso no ringue com as luvas depois de um erro
		end
	end
end

-- Desafio a um bot: ele "pensa" 1,5 a 3 s e aceita, como um jogador faria.
local function requestBotDuel(challenger: Player, uid: number)
	local bot = BotService.byUid(uid)
	if not bot then
		return
	end
	local other = ArenaService.OtherBusy
	if other and other() then
		return notify(
			challenger,
			"O coliseu está ocupado (Dragão ou batalha de gigantes). Tente já já!",
			Color3.fromRGB(255, 170, 60)
		)
	end
	local ok, why = canFight(challenger)
	if not ok then
		return notify(challenger, why :: string, Color3.fromRGB(255, 120, 80))
	end
	local cd = cooldownLeft(challenger)
	if cd > 0 then
		return notify(
			challenger,
			Locale.fmt("arena_wait", Locale.of(challenger), { n = cd }),
			Color3.fromRGB(255, 120, 80)
		)
	end
	if arenaInUse or bot.inDuel then
		return notify(challenger, "A arena está ocupada. Tente quando a luta acabar.", Color3.fromRGB(255, 120, 80))
	end
	Remotes.ArenaState:FireClient(challenger, { kind = "Sent", to = uid, toName = bot.name })
	busy[challenger] = true
	task.delay(1.5 + math.random() * 1.5, function()
		busy[challenger] = nil
		local other2 = ArenaService.OtherBusy
		local b2 = BotService.byUid(uid)
		if
			not challenger.Parent
			or arenaInUse
			or not b2
			or b2.inDuel
			or (other2 and other2())
			or not canFight(challenger)
			or CombatService.isKO(challenger)
		then
			Remotes.ArenaState:FireClient(challenger, { kind = "Declined", by = uid })
			return
		end
		local cp = DataService.get(challenger)
		if cp then
			cp.lastDuel = os.time()
		end
		PlotService.pushState(challenger)
		task.spawn(runBotDuel, challenger, bot)
	end)
end

-- Jogador em luta, esperando a vez no campeonato ou com desafio aceito (a viagem rápida consulta).
function ArenaService.inFight(p: Player): boolean
	return busy[p] ~= nil or inTournament[p] ~= nil or (fighting :: { [Player]: any })[p] ~= nil or botFight[p] ~= nil
end

local function requestDuel(challenger: Player, targetId: number)
	if targetId < 0 and BotService.byUid(targetId) then
		return requestBotDuel(challenger, targetId)
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == challenger then
		return
	end
	local other = ArenaService.OtherBusy
	if other and other() then
		return notify(
			challenger,
			"O coliseu está ocupado (Dragão ou batalha de gigantes). Tente já já!",
			Color3.fromRGB(255, 170, 60)
		)
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
	if arenaInUse then
		return notify(challenger, "A arena está ocupada. Tente quando a luta acabar.", Color3.fromRGB(255, 120, 80))
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
			ShopService.awardBox(champ, A.TournamentPrizeBox)
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
	-- Isola a luta: lutadores só acertam o adversário; ninguém de fora acerta quem luta.
	local previousFilter = CombatService.HitFilter
	CombatService.HitFilter = function(attacker: Player, victim: Player): boolean
		if botFight[attacker] or botFight[victim] then
			return false -- luta contra bot: nenhum jogador acerta nem é acertado por outro jogador
		end
		local oa, ov = fighting[attacker], fighting[victim]
		if oa or ov then
			return oa == victim
		end
		return if previousFilter then previousFilter(attacker, victim) else true
	end
	CombatService.IgnoreSafeZone = function(victim: Player): boolean
		return (fighting :: { [Player]: any })[victim] ~= nil or botFight[victim] ~= nil
	end
	-- Na luta: sem soco durante a contagem e sem recuperar vida (senão quem só bloqueia ganha
	-- no tempo: revisão independente, regen de ~16 HP/s > dano de quem ataca um bloqueio).
	CombatService.CanPunch = function(attacker: Player): boolean
		return not frozen[attacker]
	end
	CombatService.NoRegen = function(player: Player): boolean
		return (fighting :: { [Player]: any })[player] ~= nil or botFight[player] ~= nil
	end
	CombatService.FairFight = function(player: Player): boolean
		return (fighting :: { [Player]: any })[player] ~= nil or botFight[player] ~= nil
	end
	-- Sair do jogo no meio da luta = derrota com o mesmo castigo (aplicado ANTES do save final).
	DataService.onReleasing(function(player: Player, data: DataService.Profile)
		if botFight[player] then
			data.arenaLosses += 1 -- saiu no meio da luta com bot: derrota, sem castigo de comida
			data.arenaStreak = 0
			return
		end
		local opponent = fighting[player]
		if not opponent then
			return
		end
		leftMidFight[player] = true
		data.arenaLosses += 1
		data.arenaStreak = 0
		if currentTournament or not opponent.Parent then
			return
		end
		local wp = DataService.get(opponent)
		if not wp then
			return
		end
		local coins = math.min(A.WinCoinsCap, math.floor(data.coins * A.WinCoinsPct))
		data.coins -= coins
		wp.coins += coins
		transferArenaFood(wp, data)
		DataService.markDirty(opponent)
		PlotService.pushState(opponent)
		notify(opponent, player.DisplayName .. " fugiu da luta! A vitória é sua.", Color3.fromRGB(255, 220, 80))
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
