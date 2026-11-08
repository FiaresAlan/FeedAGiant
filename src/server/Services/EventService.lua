--!strict
-- EventService — eventos globais de servidor (Golden Hour, Chuva de Comida, Boss Faminto, Lucky Boxes).
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local GiantService = require(script.Parent.GiantService)
local BossService = require(script.Parent.BossService)
local DropService = require(script.Parent.DropService)
local WorldFx = require(script.Parent.Parent.WorldFx)

local EventService = {}
local active: string? = nil

local function broadcast(def)
	Remotes.EventStarted:FireAllClients({ id = def.id, name = def.name, duration = def.duration, color = def.color })
end

local function runGoldenHour(def)
	PlotService.setGlobalMultiplier(2)
	task.wait(def.duration)
	PlotService.setGlobalMultiplier(1)
end

local function runLuckyBoxes(def)
	ShopService.setLuckBonus(0.5)
	task.wait(def.duration)
	ShopService.setLuckBonus(0)
end

-- Chuva de Comida (reforma de 08/11, pedido do usuário): poucas comidas que caem em volta do
-- caldeirão e seguem a regra dos drops (cronômetro curto, pegar com E/toque, carregar até a base).
-- Antes: ~75 comidas por evento que entravam na mochila só de encostar.
local function runFoodRain(def)
	local t0 = os.clock()
	local spawned = 0
	while os.clock() - t0 < def.duration and spawned < Config.Drops.RainItems do
		local pool = {}
		for _, f in Config.Foods do
			if f.rarity == "Common" or f.rarity == "Uncommon" or (f.rarity == "Rare" and math.random() < 0.15) then
				table.insert(pool, f)
			end
		end
		local food = pool[math.random(1, #pool)]
		local a = math.random() * math.pi * 2
		-- fora do caldeirão central (raio ~29) para a comida não ficar presa no alto dele
		local r = 40 + math.random() * 50
		DropService.spawnAt(Vector3.new(math.cos(a) * r, 4.5, math.sin(a) * r), "food", food.id, true)
		spawned += 1
		task.wait(Config.Drops.RainEvery)
	end
	-- o evento dura o tempo todo mesmo depois das comidas (a disputa continua)
	local left = def.duration - (os.clock() - t0)
	if left > 0 then
		task.wait(left)
	end
end

-- 08/11/2026: o "Boss Faminto" (bloco + bola clicável) virou o Dragão Faminto da arena (BossService).
local function runHungryBoss(def)
	BossService.run(def.duration)
end

local RUNNERS = {
	GoldenHour = runGoldenHour,
	LuckyBoxes = runLuckyBoxes,
	FoodRain = runFoodRain,
	HungryBoss = runHungryBoss,
}

function EventService.start(id: string)
	if active then
		return
	end
	local def
	for _, d in Config.Events.List do
		if d.id == id then
			def = d
		end
	end
	if not def then
		return
	end
	active = id
	broadcast(def)
	WorldFx.setEventBoost(true, def.color)
	local ok, err = pcall(RUNNERS[id], def)
	if not ok then
		warn("[EventService]", err)
	end
	WorldFx.setEventBoost(false)
	Remotes.EventEnded:FireAllClients({ id = id })
	active = nil
end

-- Próximo evento já sorteado e anunciado (pedido do usuário: "ansiedade" de ver a contagem).
local schedule: { nextId: string, nextName: string, at: number, color: Color3 }? = nil

local function sendSchedule(target: Player?)
	if not schedule then
		return
	end
	local payload = { nextId = schedule.nextId, nextName = schedule.nextName, at = schedule.at, color = schedule.color }
	if target then
		Remotes.EventSchedule:FireClient(target, payload)
	else
		Remotes.EventSchedule:FireAllClients(payload)
	end
end

local function planNext(waitSeconds: number)
	local list = Config.Events.List
	local pick = list[math.random(1, #list)]
	-- Não repete o mesmo evento duas vezes seguidas.
	if schedule and pick.id == schedule.nextId and #list > 1 then
		pick = list[(table.find(list, pick) :: number) % #list + 1]
	end
	schedule = { nextId = pick.id, nextName = pick.name, at = os.time() + waitSeconds, color = pick.color }
	sendSchedule(nil)
end

function EventService.init()
	Players.PlayerAdded:Connect(function(p)
		sendSchedule(p)
	end)
	task.spawn(function()
		planNext(Config.Events.FirstDelay)
		while true do
			local plan = schedule :: any
			while os.time() < plan.at do
				task.wait(1)
			end
			EventService.start(plan.nextId)
			planNext(math.random(Config.Events.MinInterval, Config.Events.MaxInterval))
		end
	end)
	-- Reforça visual dos gigantes de vez em quando (segurança)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, plr in Players:GetPlayers() do
				GiantService.refresh(plr)
			end
		end
	end)
end

return EventService
