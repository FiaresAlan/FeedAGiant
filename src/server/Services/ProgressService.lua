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
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)

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
		},
		objectives = objs,
		bonusClaimed = profile.objBonusClaimed,
		bonusBox = GameRules.ObjectivesAllDoneBox,
		records = profile.records,
		session = sessionLevels[player] or 0,
		resetIn = 86400 - (now % 86400),
	}
end

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
	local claimed = profile.bossClaimed
	for _, e in list do
		if type(e) == "table" and type(e.id) == "string" and not table.find(claimed, e.id) then
			local coins = math.max(0, math.floor(tonumber(e.coins) or 0))
			local xp = math.max(0, math.floor(tonumber(e.xp) or 0))
			profile.coins += coins
			table.insert(claimed, e.id)
			while #claimed > GameRules.BossIsland.PendingKeep do
				table.remove(claimed, 1)
			end
			paid[e.id] = true
			if xp > 0 then
				GiantService.addXp(player, xp, nil, nil)
			end
			if type(e.box) == "string" and Config.LunchboxById[e.box] then
				ShopService.openBox(
					player,
					e.box,
					{ free = true, force = true, minRarity = Config.Boss.RewardMinRarity }
				)
			end
			Remotes.Notify:FireClient(
				player,
				Locale.msg("boss_pending", { n = Util.formatNumber(coins) }, Color3.fromRGB(255, 215, 80))
			)
		end
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
