--!strict
-- ProgressService — recordes pessoais (4.6), objetivos do DIÁRIO (P5) e recompensas pendentes do
-- Dragão para quem saiu antes do fim (Sistema 4). Missão de 08/11/2026.
--
-- Um painel só: o Diário (recompensa diária que já existia + 3 tarefas do dia + recordes). Nada de
-- cinco telas parecidas. Tarefas pagam moedas e XP (sem moeda nova); fazer as 3 dá 1 caixa Rara
-- grátis. Tudo é contado no servidor a partir de eventos internos (Hooks), nunca do cliente.
--
-- Recordes ≠ sessão: `records` é salvo no perfil (para sempre); a contagem da sessão vive só na
-- memória deste servidor e só vira recorde se passar o anterior.
--
-- Recompensa pendente (jogador ajudou no Dragão e saiu): o servidor grava num DataStore separado
-- (FAG_PendingRewards_v1, chave = UserId) com UpdateAsync. Ao entrar, cada entrada cujo id NÃO está
-- em profile.bossClaimed é paga e o id entra em bossClaimed (salvo junto com as moedas). Só depois a
-- entrada é apagada do DataStore. Se apagar falhar, na próxima entrada o id já consta como pago:
-- nunca paga duas vezes (vault: Session Locking and Profile Libraries — idempotência por id).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)
local GameLogic = require(script.Parent.Parent.GameLogic)
local Analytics = require(script.Parent.Parent.Analytics)

local ProgressService = {}

local sessionLevels: { [Player]: number } = {}
local lastRecordToast: { [Player]: number } = {}
local pendingStore: any = nil

local function today(): number
	return os.time() // 86400
end

local function ensureDay(profile: DataService.Profile)
	if profile.objDay ~= today() then
		profile.objDay = today()
		profile.objProgress = {}
		profile.objClaimed = {}
		profile.objBonusClaimed = false
	end
end

function ProgressService.state(player: Player): { [string]: any }?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	ensureDay(profile)
	local objs = {}
	for i, o in GameRules.objectivesForDay(profile.objDay) do
		local prog = math.min(profile.objProgress[o.id] or 0, o.goal)
		table.insert(objs, {
			index = i,
			id = o.id,
			text = o.text,
			goal = o.goal,
			progress = prog,
			coins = o.coins,
			xp = o.xp,
			claimed = profile.objClaimed[o.id] == true,
		})
	end
	local now = os.time()
	local elapsed = now - profile.lastDaily
	return {
		daily = {
			streak = profile.dailyStreak,
			ready = elapsed >= 20 * 3600,
			nextIn = math.max(0, 20 * 3600 - elapsed),
			rewards = Config.DailyRewards,
			-- v3: proteções da sequência (nil com a função desligada: a tela não mostra nada)
			backups = if Features.on("StreakBackup") then profile.streakBackups else nil,
		},
		objectives = objs,
		bonusClaimed = profile.objBonusClaimed,
		bonusBox = GameRules.ObjectivesAllDoneBox,
		records = profile.records,
		session = sessionLevels[player] or 0,
		resetIn = 86400 - (now % 86400),
		weekly = ProgressService.weeklyState(profile, now),
	}
end

-- Missão semanal (Features.WeeklyQuest): nil com a função desligada (o Diário não mostra a seção).
function ProgressService.weeklyState(profile: DataService.Profile, now: number): { [string]: any }?
	if not Features.on("WeeklyQuest") then
		return nil
	end
	local week = GameRules.weekIndex(now)
	local wq = profile.weeklyQuest
	local status = GameLogic.weeklyNormalize(wq, week)
	local function pack(q: GameRules.ObjectiveDef): { [string]: any }
		return { id = q.id, text = q.text, goal = q.goal, coins = q.coins, xp = q.xp }
	end
	local options = {}
	for _, q in GameRules.weeklyOptions(week) do
		table.insert(options, pack(q))
	end
	local chosen = if wq.chosenId ~= "" then GameRules.weeklyById(wq.chosenId) else nil
	-- próxima segunda 00:00 UTC
	local nextWeekAt = ((week + 1) * 7 - 3) * 86400
	return {
		status = status, -- "current" ou "carry" (resgate pendente de semana passada)
		options = options,
		chosen = if chosen then pack(chosen) else nil,
		progress = wq.progress,
		swapped = wq.swappedThisWeek,
		claimed = wq.claimed,
		claimable = GameLogic.weeklyClaimable(wq),
		box = GameRules.WeeklyBox,
		resetIn = math.max(0, nextWeekAt - now),
	}
end

-- Soma progresso na missão semanal (só se a escolhida é desse tipo).
local function weeklyBump(player: Player, kind: string, amount: number)
	if not Features.on("WeeklyQuest") then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local wq = profile.weeklyQuest
	local before = wq.progress
	local done = GameLogic.weeklyBump(wq, GameRules.weekIndex(os.time()), kind, amount)
	if wq.progress ~= before then
		DataService.markDirty(player)
		if done then
			Remotes.Notify:FireClient(player, {
				text = "MISSÃO SEMANAL COMPLETA! Resgate no DIÁRIO.",
				color = Color3.fromRGB(255, 200, 80),
			})
			Remotes.DiaryState:FireClient(player, ProgressService.state(player))
		end
	end
end
ProgressService.weeklyBump = weeklyBump

local function push(player: Player)
	local st = ProgressService.state(player)
	if st then
		Remotes.DiaryState:FireClient(player, st)
	end
end

-- Soma progresso numa tarefa (só conta se ela é uma das 3 do dia).
function ProgressService.bump(player: Player, id: string, amount: number, setMax: boolean?)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	ensureDay(profile)
	local active = false
	local goal = 0
	for _, o in GameRules.objectivesForDay(profile.objDay) do
		if o.id == id then
			active = true
			goal = o.goal
		end
	end
	if not active or profile.objClaimed[id] then
		return
	end
	local before = profile.objProgress[id] or 0
	local after = if setMax then math.max(before, amount) else before + amount
	if after == before then
		return
	end
	profile.objProgress[id] = after
	DataService.markDirty(player)
	if before < goal and after >= goal then
		Remotes.Notify:FireClient(player, Locale.msg("objective_done", nil, Color3.fromRGB(120, 255, 160)))
	end
	push(player)
end

-- Recorde: grava se passou; avisa (no máximo 1 aviso a cada 20 s) e o gigante comemora.
function ProgressService.record(player: Player, id: string, value: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local prev = profile.records[id] or 0
	if value <= prev then
		return
	end
	profile.records[id] = value
	DataService.markDirty(player)
	-- Primeiro registro (prev 0) e o contador de entregas não fazem festa: seria toda hora.
	if prev > 0 and id ~= "delivered" and os.clock() - (lastRecordToast[player] or 0) > 20 then
		lastRecordToast[player] = os.clock()
		local name = ""
		for _, r in GameRules.Records do
			if r.id == id then
				name = r.name
			end
		end
		Remotes.Notify:FireClient(
			player,
			Locale.msg("record_new", { r = name, n = Util.formatNumber(value) }, Color3.fromRGB(255, 215, 80))
		)
		Remotes.GiantReact:FireAllClients({ userId = player.UserId, kind = "cheer" })
	end
end

local function claim(player: Player, index: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	ensureDay(profile)
	local list = GameRules.objectivesForDay(profile.objDay)
	if index == 0 then
		-- bônus por completar as 3
		if profile.objBonusClaimed then
			return
		end
		for _, o in list do
			if not profile.objClaimed[o.id] then
				return
			end
		end
		profile.objBonusClaimed = true
		DataService.markDirty(player)
		ShopService.openBox(player, GameRules.ObjectivesAllDoneBox, { free = true, force = true })
		push(player)
		return
	end
	local o = list[index]
	if not o or profile.objClaimed[o.id] or (profile.objProgress[o.id] or 0) < o.goal then
		return
	end
	profile.objClaimed[o.id] = true
	profile.coins += o.coins
	DataService.markDirty(player)
	if o.xp > 0 then
		GiantService.addXp(player, o.xp, nil, nil)
	end
	PlotService.pushState(player)
	Remotes.Notify:FireClient(
		player,
		Locale.msg("objective_claimed", { n = Util.formatNumber(o.coins), x = o.xp }, Color3.fromRGB(120, 255, 160))
	)
	push(player)
end

---------------------------------------------------------------------------
-- Recompensas pendentes (Dragão)
---------------------------------------------------------------------------
export type Pending = { id: string, coins: number, xp: number, box: string? }

local function store(): any
	if pendingStore then
		return pendingStore
	end
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("FAG_PendingRewards_v1")
	end)
	if ok and ds and not RunService:IsStudio() then
		pendingStore = ds
	else
		-- Studio sem DataStore (place de teste): memória da sessão, mesma API.
		local Vendor = ServerScriptService:WaitForChild("fwjelaa")
		local StudioMemoryStore = require(Vendor:WaitForChild("StudioMemoryStore")) :: any
		pendingStore = StudioMemoryStore.new()
	end
	return pendingStore
end

-- Guarda uma recompensa para quem não está mais no servidor. Até 3 tentativas.
function ProgressService.addPending(userId: number, entry: Pending)
	task.spawn(function()
		for attempt = 1, 3 do
			local ok = pcall(function()
				store():UpdateAsync(tostring(userId), function(old: any)
					local list = if type(old) == "table" then old else {}
					for _, e in list do
						if e.id == entry.id then
							return nil -- já está lá
						end
					end
					table.insert(list, entry)
					while #list > 20 do
						table.remove(list, 1)
					end
					return list
				end)
			end)
			if ok then
				return
			end
			task.wait(attempt * 2)
		end
		warn("[ProgressService] não gravou recompensa pendente de", userId)
	end)
end

function ProgressService.claimPending(player: Player)
	local profile = DataService.waitFor(player, 45) -- perfil pode ainda estar carregando
	if not profile or not player.Parent then
		return
	end
	local ok, list = pcall(function()
		return store():GetAsync(tostring(player.UserId))
	end)
	if not ok or type(list) ~= "table" or #list == 0 then
		return
	end
	local paid: { [string]: boolean } = {}
	local toPay, newClaimed = GameLogic.pendingToPay(profile.bossClaimed, list, GameRules.BossIsland.PendingKeep)
	profile.bossClaimed = newClaimed
	local claimed = newClaimed
	for _, e in toPay do
		profile.coins += e.coins
		paid[e.id] = true
		if e.xp > 0 then
			GiantService.addXp(player, e.xp, nil, nil)
		end
		if e.box and Config.LunchboxById[e.box] then
			ShopService.openBox(player, e.box, { free = true, force = true, minRarity = Config.Boss.RewardMinRarity })
		end
		Remotes.Notify:FireClient(
			player,
			Locale.msg("boss_pending", { n = Util.formatNumber(e.coins) }, Color3.fromRGB(255, 215, 80))
		)
	end
	DataService.markDirty(player)
	-- salva agora (moedas + ids juntos) e só depois limpa a fila. Se o save falhar, a fila fica:
	-- os ids já pagos estão em bossClaimed e não pagam de novo; os não salvos voltam na próxima.
	if not DataService.saveNow(player) then
		PlotService.pushState(player)
		return
	end
	pcall(function()
		store():UpdateAsync(tostring(player.UserId), function(old: any): any
			if type(old) ~= "table" then
				return nil
			end
			local keep: { any } = {}
			for _, e in old do
				if type(e) == "table" and not paid[e.id] and not table.find(claimed, e.id) then
					table.insert(keep, e)
				end
			end
			return keep
		end)
	end)
	PlotService.pushState(player)
end

function ProgressService.onJoin(player: Player)
	sessionLevels[player] = 0
	local profile = DataService.get(player)
	if profile then
		ensureDay(profile)
		ProgressService.record(player, "maxLevel", profile.level)
	end
	task.spawn(ProgressService.claimPending, player)
end

function ProgressService.init()
	Hooks.on("fed", function(player: Player, info: { [string]: any })
		ProgressService.bump(player, "feed", 1)
		ProgressService.bump(player, "streak", info.streak, true)
		if info.crit then
			ProgressService.bump(player, "crit", 1)
		end
		ProgressService.record(player, "bestStreak", info.streak)
		ProgressService.record(player, "bestFeedXp", info.xp)
	end)
	Hooks.on("leveled", function(player: Player, levels: number, level: number)
		sessionLevels[player] = (sessionLevels[player] or 0) + levels
		ProgressService.bump(player, "levels", levels)
		ProgressService.record(player, "maxLevel", level)
		ProgressService.record(player, "sessionLevels", sessionLevels[player])
	end)
	Hooks.on("delivered", function(player: Player, kind: string, foodId: string?)
		local profile = DataService.get(player)
		if not profile then
			return
		end
		ProgressService.bump(player, "deliver", 1)
		if foodId == GameRules.Meat.FoodId then
			ProgressService.bump(player, "meat", 1)
		end
		ProgressService.record(player, "delivered", (profile.records.delivered or 0) + 1)
		local _ = kind
	end)
	Hooks.on("battleWon", function(player: Player)
		ProgressService.bump(player, "battle", 1)
	end)
	Hooks.on("bossHelped", function(player: Player)
		ProgressService.bump(player, "boss", 1)
	end)
	-- Missão semanal: mesmos sinais das tarefas diárias.
	Hooks.on("fed", function(player: Player)
		weeklyBump(player, "feed", 1)
	end)
	Hooks.on("leveled", function(player: Player, levels: number)
		weeklyBump(player, "levels", levels)
	end)
	Hooks.on("delivered", function(player: Player, _kind: string, foodId: string?)
		weeklyBump(player, "deliver", 1)
		if foodId == GameRules.Meat.FoodId then
			weeklyBump(player, "meat", 1)
		end
	end)
	Hooks.on("battleWon", function(player: Player)
		weeklyBump(player, "battle", 1)
	end)
	Hooks.on("bossHelped", function(player: Player)
		weeklyBump(player, "boss", 1)
	end)
	Remotes.RequestWeekly.OnServerEvent:Connect(function(player, action, id)
		if not Features.on("WeeklyQuest") or type(action) ~= "string" or not Guard.allow(player, "Diary") then
			return
		end
		local profile = DataService.get(player)
		if not profile then
			return
		end
		local now = os.time()
		local week = GameRules.weekIndex(now)
		local wq = profile.weeklyQuest
		if action == "choose" or action == "swap" then
			if type(id) ~= "string" or #id > 32 then
				return
			end
			local ok: boolean, why: string?
			if action == "choose" then
				ok, why = GameLogic.weeklyChoose(wq, week, id, now)
			else
				ok, why = GameLogic.weeklySwap(wq, week, id, now)
			end
			if ok then
				DataService.markDirty(player)
				Analytics.event(player, "weekly_quest_chosen", 1, { id, action })
			elseif why == "swapped" then
				Remotes.Notify:FireClient(
					player,
					{ text = "Você já trocou a missão desta semana.", color = Color3.fromRGB(255, 170, 60) }
				)
			end
		elseif action == "claim" then
			-- marca antes de pagar (GameLogic.weeklyClaim), depois paga moedas, XP e a caixa grátis
			local def = GameLogic.weeklyClaim(wq, week)
			if def then
				profile.coins += def.coins
				DataService.markDirty(player)
				if def.xp > 0 then
					GiantService.addXp(player, def.xp, nil, nil)
				end
				ShopService.openBox(player, GameRules.WeeklyBox, { free = true, force = true })
				PlotService.pushState(player)
				Analytics.event(player, "weekly_quest_claimed", def.coins, { def.id })
				Remotes.Notify:FireClient(player, {
					text = string.format(
						"Missão semanal resgatada! +%s moedas e uma Lunchbox Épica.",
						Util.formatNumber(def.coins)
					),
					color = Color3.fromRGB(120, 255, 160),
				})
			end
		end
		push(player)
	end)
	Remotes.RequestDiary.OnServerEvent:Connect(function(player)
		if Guard.allow(player, "Diary") then
			push(player)
		end
	end)
	Remotes.RequestClaimObjective.OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" then
			return
		end
		if (index == 0 or Guard.isIndex(index, GameRules.ObjectivesPerDay)) and Guard.allow(player, "Diary") then
			claim(player, index)
		end
	end)
	Remotes.RequestClaimDaily.OnServerEvent:Connect(function(player)
		task.defer(push, player) -- depois do ShopService pagar o diário
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionLevels[player] = nil
		lastRecordToast[player] = nil
	end)
end

return ProgressService
