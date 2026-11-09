--!strict
-- GameLogic — regras PURAS dos sistemas de 08/11/2026 (sem Players, DataStore, rede nem modelos).
-- Os serviços chamam estas funções, e tests/GameLogic.spec.luau testa exatamente o mesmo código
-- (S6 da rubrica: "teste automatizado sem publicar"). Nada aqui guarda estado.
local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local EggOdds = require(game.ReplicatedStorage.Shared.EggOdds)

local GameLogic = {}

---------------------------------------------------------------------------
-- 4.1 Sequência de alimentação
---------------------------------------------------------------------------
-- Próximo estado da sequência. `prevAt` nil = primeira alimentação.
function GameLogic.nextStreak(prevN: number, prevAt: number?, now: number, streakBonus: number): number
	local n = if prevAt == nil or now - prevAt > GameRules.Feed.StreakWindow then 0 else prevN
	return n + 1 + streakBonus
end

-- XP final de uma alimentação (servidor decide). rand ∈ [0,1).
function GameLogic.feedXp(foodId: string, rarity: string, streak: number, rand: number): (number, boolean, number)
	local F = GameRules.Feed
	local trait = GameRules.traitOf(foodId)
	local mult = GameRules.streakMult(streak)
	local crit = rand < F.CritChance * (if trait then trait.critMult else 1)
	local xp = Config.Rarities[rarity].xp * mult * (if trait then trait.xpMult else 1)
	if crit then
		xp *= F.CritMult
	end
	return math.floor(xp), crit, mult
end

---------------------------------------------------------------------------
-- Sistema 1: coleção (transferência de crescimento)
---------------------------------------------------------------------------
function GameLogic.totalXp(level: number, xp: number): number
	local total = xp
	for l = 1, level - 1 do
		total += Config.xpNeeded(l)
	end
	return total
end

function GameLogic.fromTotalXp(total: number): (number, number)
	local level = 1
	while level < Config.Giant.MaxLevel and total >= Config.xpNeeded(level) do
		total -= Config.xpNeeded(level)
		level += 1
	end
	return level, math.floor(total)
end

-- Nível/XP que uma espécie NOVA herda do gigante ativo (fração configurável, 30%).
function GameLogic.inherit(level: number, xp: number): (number, number)
	return GameLogic.fromTotalXp(math.floor(GameLogic.totalXp(level, xp) * GameRules.Roster.TransferFraction))
end

---------------------------------------------------------------------------
-- Sistema 2: exposição e renda offline
---------------------------------------------------------------------------
function GameLogic.displayRate(levels: { number }): number
	local R = GameRules.Roster
	local total = 0
	for i, lv in levels do
		if i > R.DisplaySlots then
			break
		end
		total += R.DisplayBase + R.DisplayPerLevel * lv
	end
	return total
end

-- Moedas pagas ao voltar (metade da taxa, teto de 8 h, mínimo para valer a mensagem).
function GameLogic.offlineGain(lastSettled: number, now: number, rate: number): number
	local R = GameRules.Roster
	if lastSettled <= 0 or now <= lastSettled or rate <= 0 then
		return 0
	end
	local away = math.min(now - lastSettled, R.OfflineCapSeconds)
	if away < R.OfflineMinSeconds then
		return 0
	end
	return math.floor(away * rate * R.OfflineRate)
end

---------------------------------------------------------------------------
-- Sistema 3: batalha por turnos
---------------------------------------------------------------------------
export type Fx = { stun: boolean, weak: number, guard: boolean }

-- Sorteio de um golpe. randHit/randDmg/randFx ∈ [0,1). Muda attFx/defFx (efeitos).
function GameLogic.rollMove(
	power: number,
	move: GameRules.MoveDef,
	attFx: Fx,
	defFx: Fx,
	randHit: number,
	randDmg: number,
	randFx: number
): (boolean, number, string?)
	local TB = GameRules.TurnBattle
	local acc = move.accuracy
	if defFx.guard then
		acc *= TB.GuardAccuracy
		defFx.guard = false
	end
	local hit = randHit < acc
	local dmg = 0
	local effect: string? = nil
	if hit then
		dmg = power * move.power * TB.DamageScale * (0.9 + randDmg * 0.2)
		if defFx.weak > 0 then
			dmg *= TB.WeakenMult
			defFx.weak -= 1
		end
		dmg = math.max(1, math.floor(dmg))
		if move.effect and move.effect ~= "guard" and randFx < (move.effectChance or 1) then
			effect = move.effect
			if effect == "stun" then
				defFx.stun = true
			elseif effect == "weaken" then
				defFx.weak = TB.WeakenTurns
			end
		end
	end
	if move.effect == "guard" then
		attFx.guard = true
		effect = "guard"
	end
	return hit, dmg, effect
end

-- Quem venceu e se ganha prêmio (AFK — nenhuma escolha — nunca ganha).
function GameLogic.battleOutcome(meHp: number, meMax: number, foeHp: number, foeMax: number, acted: number): boolean
	local won = foeHp <= 0 or (meHp > 0 and meHp / meMax > foeHp / foeMax)
	return won and acted > 0
end

---------------------------------------------------------------------------
-- Sistema 4: recompensas do Dragão (por UserId)
---------------------------------------------------------------------------
export type BossReward = { uid: number, coins: number, xp: number, bonus: number, share: number }

function GameLogic.bossRewards(
	damage: { [number]: number },
	hits: { [number]: number },
	levels: { [number]: number },
	won: boolean
): { BossReward }
	local BI = GameRules.BossIsland
	local total = 0
	for _, d in damage do
		total += d
	end
	local valid: { number } = {}
	for uid, d in damage do
		if d >= total * BI.MinShare or (hits[uid] or 0) >= BI.MinHits then
			table.insert(valid, uid)
		end
	end
	table.sort(valid)
	local pool = BI.BonusPoolPerPlayer * #valid
	local out: { BossReward } = {}
	for _, uid in valid do
		local level = levels[uid] or 1
		local share = if total > 0 then (damage[uid] or 0) / total else 0
		local k = if won then 1 else BI.FailFraction
		table.insert(out, {
			uid = uid,
			coins = math.floor((BI.JoinCoinsBase + BI.JoinCoinsPerLevel * level) * k),
			xp = math.floor((BI.JoinXpBase + BI.JoinXpPerLevel * level) * k),
			bonus = if won then math.floor(pool * share) else 0,
			share = share,
		})
	end
	return out
end

---------------------------------------------------------------------------
-- Recompensas pendentes: o que pagar agora (idempotente por id)
---------------------------------------------------------------------------
export type PendingEntry = { id: string, coins: number, xp: number, box: string? }

-- Devolve (entradas a pagar, nova lista de ids pagos). Ids já pagos e repetidos são ignorados.
function GameLogic.pendingToPay(claimed: { string }, entries: { any }, keep: number): ({ PendingEntry }, { string })
	local newClaimed = table.clone(claimed)
	local pay: { PendingEntry } = {}
	for _, e in entries do
		if type(e) == "table" and type(e.id) == "string" and not table.find(newClaimed, e.id) then
			table.insert(pay, {
				id = e.id,
				coins = math.max(0, math.floor(tonumber(e.coins) or 0)),
				xp = math.max(0, math.floor(tonumber(e.xp) or 0)),
				box = if type(e.box) == "string" then e.box else nil,
			})
			table.insert(newClaimed, e.id)
			while #newClaimed > keep do
				table.remove(newClaimed, 1)
			end
		end
	end
	return pay, newClaimed
end

---------------------------------------------------------------------------
-- 4.5 Carne Gigante
---------------------------------------------------------------------------
function GameLogic.meatPortions(players: number): number
	local M = GameRules.Meat
	return math.min(M.PortionsMax, M.PortionsBase + M.PortionsPerPlayer * math.max(players, 0))
end

-- Motivo da recusa (nil = pode cortar).
function GameLogic.meatRefusal(portionsLeft: number, cutsByPlayer: number, carrying: boolean): string?
	if portionsLeft <= 0 then
		return "gone"
	elseif cutsByPlayer >= GameRules.Meat.PerPlayer then
		return "limit"
	elseif carrying then
		return "carrying"
	end
	return nil
end

---------------------------------------------------------------------------
-- v3 (Features): limites éticos do roubo e proteção da sequência diária
---------------------------------------------------------------------------
-- Nível que conta para a proteção de novato: quem já renasceu nunca é novato (o rebirth volta o
-- nível para 1; revisão cega 08/11), e vale o MAIOR nível já alcançado (peakLevel).
function GameLogic.victimProgress(level: number, peakLevel: number?, rebirths: number?): number
	if (rebirths or 0) > 0 then
		return math.huge
	end
	return math.max(level, peakLevel or 0)
end

-- Pode tentar roubar? Devolve (ok, motivo). `day` = dia UTC (os.time() // 86400).
-- `victimLevel` = GameLogic.victimProgress(...) da vítima.
-- Motivos: "newbie" (vítima nova) ou "daily" (ladrão já fez o máximo hoje).
function GameLogic.stealAllowed(
	thiefStealDay: number,
	thiefStealsToday: number,
	victimLevel: number,
	day: number
): (boolean, string?)
	local L = GameRules.StealLimits
	if victimLevel < L.MinVictimLevel then
		return false, "newbie"
	end
	local today = if thiefStealDay == day then thiefStealsToday else 0
	if today >= L.MaxPerDay then
		return false, "daily"
	end
	return true, nil
end

-- Conta um roubo concluído. Devolve (novo stealDay, novo stealsToday).
function GameLogic.countSteal(thiefStealDay: number, thiefStealsToday: number, day: number): (number, number)
	local today = if thiefStealDay == day then thiefStealsToday else 0
	return day, today + 1
end

-- Sequência diária ao resgatar com `elapsed` segundos desde o último resgate.
-- Devolve (sequência antes de somar o dia de hoje, proteções restantes, usou proteção?).
function GameLogic.dailyStreakBase(
	streak: number,
	elapsed: number,
	backups: number,
	backupsOn: boolean
): (number, number, boolean)
	if elapsed <= 48 * 3600 or streak <= 0 then
		return streak, backups, false
	end
	if backupsOn and backups > 0 then
		return streak, backups - 1, true
	end
	return 0, backups, false
end

---------------------------------------------------------------------------
-- Sistema de Ovos (regras puras; EggService chama, tests/Eggs.spec.luau testa)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Missão semanal 1-de-3 (prompt v4; ProgressService chama, tests/Weekly.spec.luau testa)
---------------------------------------------------------------------------
export type Weekly = {
	week: number,
	chosenId: string,
	chosenAt: number,
	swappedThisWeek: boolean,
	progress: number,
	claimed: boolean,
}

local function weeklyReset(wq: Weekly, week: number)
	wq.week = week
	wq.chosenId = ""
	wq.chosenAt = 0
	wq.swappedThisWeek = false
	wq.progress = 0
	wq.claimed = false
end

local function isOption(week: number, id: string): boolean
	for _, q in GameRules.weeklyOptions(week) do
		if q.id == id then
			return true
		end
	end
	return false
end

-- Pronta para resgatar (vale para a semana passada também: nunca se perde).
function GameLogic.weeklyClaimable(wq: Weekly): boolean
	if wq.chosenId == "" or wq.claimed then
		return false
	end
	local def = GameRules.weeklyById(wq.chosenId)
	return def ~= nil and wq.progress >= def.goal
end

-- Ajusta a missão à semana atual. Missão completa e não resgatada fica ("carry") até o resgate.
-- Devolve "current" (semana atual) ou "carry" (resgate pendente de uma semana anterior).
function GameLogic.weeklyNormalize(wq: Weekly, week: number): string
	if wq.week == week then
		return "current"
	end
	if GameLogic.weeklyClaimable(wq) then
		return "carry"
	end
	weeklyReset(wq, week)
	return "current"
end

function GameLogic.weeklyChoose(wq: Weekly, week: number, id: string, now: number): (boolean, string?)
	if GameLogic.weeklyNormalize(wq, week) ~= "current" then
		return false, "carry"
	end
	if wq.chosenId ~= "" then
		return false, "chosen"
	end
	if not isOption(week, id) then
		return false, "option"
	end
	wq.chosenId = id
	wq.chosenAt = now
	wq.progress = 0
	return true, nil
end

-- Troca 1 vez por semana; o progresso recomeça do zero (senão a troca seria só "pular para a fácil").
function GameLogic.weeklySwap(wq: Weekly, week: number, id: string, now: number): (boolean, string?)
	if GameLogic.weeklyNormalize(wq, week) ~= "current" then
		return false, "carry"
	end
	if wq.chosenId == "" or wq.claimed then
		return false, "state"
	end
	if wq.swappedThisWeek then
		return false, "swapped"
	end
	if id == wq.chosenId or not isOption(week, id) then
		return false, "option"
	end
	wq.chosenId = id
	wq.chosenAt = now
	wq.progress = 0
	wq.swappedThisWeek = true
	return true, nil
end

-- Soma progresso se a missão escolhida desta semana é desse tipo. Devolve true se acabou de completar.
function GameLogic.weeklyBump(wq: Weekly, week: number, kind: string, amount: number): boolean
	if GameLogic.weeklyNormalize(wq, week) ~= "current" or wq.chosenId ~= kind or wq.claimed then
		return false
	end
	local def = GameRules.weeklyById(kind)
	if not def or amount <= 0 then
		return false
	end
	local before = wq.progress
	wq.progress = math.min(def.goal, before + amount)
	return before < def.goal and wq.progress >= def.goal
end

-- Resgata: marca ANTES de o serviço pagar. Se era de uma semana anterior, já abre a semana atual.
function GameLogic.weeklyClaim(wq: Weekly, week: number): GameRules.ObjectiveDef?
	if not GameLogic.weeklyClaimable(wq) then
		return nil
	end
	local def = GameRules.weeklyById(wq.chosenId)
	wq.claimed = true
	if wq.week ~= week then
		weeklyReset(wq, week)
	end
	return def
end

---------------------------------------------------------------------------
-- Gigante Ancestral (noite de 09/11): banquete coletivo do servidor
---------------------------------------------------------------------------
-- Meta de pontos para acordar (cresce com o número de jogadores reais).
function GameLogic.ancestralGoal(players: number): number
	local A = GameRules.Ancestral
	return A.GoalBase + A.GoalPerPlayer * math.max(1, players)
end

-- Pontos que uma alimentação vale (comida mais rara vale mais).
function GameLogic.ancestralPoints(rarity: string?): number
	local order = if rarity and Config.Rarities[rarity] then Config.Rarities[rarity].order else 1
	return GameRules.Ancestral.PointsByOrder[order] or 1
end

---------------------------------------------------------------------------
-- Mutações (noite de 09/11): sorteio numa rodada do evento
---------------------------------------------------------------------------
-- Para cada comida do pátio SEM mutação, `rand()` < chance dá a mutação. Devolve as chaves que mudaram.
-- Comida que já tem mutação nunca troca (sem perder uma Arco-íris por causa de uma Dourada).
function GameLogic.rollMutations(
	plot: { [string]: { id: string, mut: string? } },
	mutId: string,
	chance: number,
	rand: () -> number
): { string }
	local changed = {}
	local keys = {}
	for key in plot do
		table.insert(keys, key)
	end
	table.sort(keys) -- ordem fixa: o mesmo rand dá o mesmo resultado (teste)
	for _, key in keys do
		local food = plot[key]
		if food.mut == nil and rand() < chance then
			food.mut = mutId
			table.insert(changed, key)
		end
	end
	return changed
end

---------------------------------------------------------------------------
-- Espécies iniciais (prompt v4 §1)
---------------------------------------------------------------------------
-- starterSpecies no perfil: "" = nunca ofertada; "?" = ofertada e ainda não escolhida (vale entre
-- sessões); id = já escolheu (nunca mais).
function GameLogic.starterEligible(starterSpecies: string): boolean
	return starterSpecies == "?"
end

-- Na entrada: oferecer a escolha? Só para conta nova (nada comido nem comprado) ou já ofertada.
function GameLogic.starterShouldOffer(starterSpecies: string, totalFeeds: number, totalBoxes: number): boolean
	if starterSpecies == "?" then
		return true
	end
	return starterSpecies == "" and totalFeeds == 0 and totalBoxes == 0
end

-- Chances e sorteio: o módulo compartilhado EggOdds (a janela do cliente mostra a mesma tabela).
GameLogic.eggOdds = EggOdds.odds
GameLogic.eggRoll = EggOdds.roll

-- XP de "repetido": o equivalente a subir do nível 1 até o nível do ovo.
function GameLogic.eggDupXp(eggLevel: number): number
	local xp = 0
	for l = 1, math.max(1, eggLevel) do
		xp += Config.xpNeeded(l)
	end
	return xp
end

-- Soma XP a um gigante (nível, xp) e devolve o novo par, respeitando o nível máximo.
function GameLogic.addXp(level: number, xp: number, amount: number): (number, number)
	xp += math.max(0, amount)
	while level < Config.Giant.MaxLevel and xp >= Config.xpNeeded(level) do
		xp -= Config.xpNeeded(level)
		level += 1
	end
	return level, xp
end

-- Estrelas de cuidado de um ovo no ninho (Ovos v2): alimentado, aquecido e laço com o gigante.
GameLogic.eggStars = EggOdds.stars -- mesma função da janela do cliente

-- Eclosão para uma espécie. `rec` = progresso atual dela (nil = nova). Nova: nasce no nível do
-- ovo (+1 por estrela). Repetida: ganha o XP equivalente (+25% por estrela; nunca perde nível).
-- Devolve (nível, xp, repetida, xpGanho).
function GameLogic.eggApply(
	rec: { level: number, xp: number }?,
	eggLevel: number,
	stars: number?
): (number, number, boolean, number)
	local st = math.clamp(stars or 0, 0, 3)
	if rec == nil then
		return math.min(Config.Giant.MaxLevel, eggLevel + st * GameRules.Eggs.StarLevels), 0, false, 0
	end
	local gain = math.floor(GameLogic.eggDupXp(eggLevel) * (1 + st * GameRules.Eggs.StarDupBonus))
	local level, xp = GameLogic.addXp(rec.level, rec.xp, gain)
	return level, xp, true, gain
end

-- Quantos lugares do ninho estão abertos para quem já chegou ao nível `peakLevel`.
function GameLogic.eggSlots(peakLevel: number): number
	local n = 0
	for _, lvl in GameRules.Eggs.SlotLevels do
		if peakLevel >= lvl then
			n += 1
		end
	end
	return n
end

-- Acelera: corta `fraction` do tempo que FALTA. Nunca volta antes de agora.
function GameLogic.eggSpeedUp(hatchAt: number, now: number, fraction: number): number
	local left = math.max(0, hatchAt - now)
	return now + math.floor(left * (1 - fraction) + 0.5)
end

return GameLogic
