--!strict
-- EventService — eventos globais de servidor (Golden Hour, Chuva de Comida, Boss Faminto, Lucky Boxes).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local GiantService = require(script.Parent.GiantService)
local Guard = require(script.Parent.Parent.Guard)
local FoodModels = require(script.Parent.Parent.FoodModels)
local BossService = require(script.Parent.BossService)
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

local function runFoodRain(def)
	local folder = Instance.new("Folder")
	folder.Name = "FoodRain"
	folder.Parent = Workspace
	local t0 = os.clock()
	while os.clock() - t0 < def.duration do
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
		local p = Util.makePart({
			Name = "Drop",
			Anchored = false,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Color = food.color,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(math.cos(a) * r, 120, math.sin(a) * r),
			Parent = folder,
		})
		p.Shape = Enum.PartType.Ball
		FoodModels.dress(p, food.id, 3) -- Fase 2: comida 3D (sem modelo, fica a bola)
		-- Física da peça fica com o servidor: o cliente não consegue puxá-la até si.
		p:SetNetworkOwner(nil)
		Util.makeBillboard(
			p,
			food.name,
			UDim2.fromOffset(120, 36),
			Vector3.new(0, 2, 0),
			Config.Rarities[food.rarity].color
		)
		local taken = false
		-- fwjelaa-ignore: connect-in-loop - uma peça nova por volta; p:Destroy() (ao pegar ou em 25 s) desliga a conexão
		p.Touched:Connect(function(hit)
			if taken then
				return
			end
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			-- Touched dispara para peças do cliente a qualquer distância: confere no servidor.
			if plr and Guard.withinReach(plr, p, 6) and PlotService.giveFood(plr, food.id) then
				taken = true
				p:Destroy()
				Remotes.Notify:FireClient(
					plr,
					Locale.msg("rain_caught", { f = food.name }, Color3.fromRGB(80, 200, 255))
				)
			end
		end)
		task.delay(25, function()
			if p.Parent then
				p:Destroy()
			end
		end)
		task.wait(0.8)
	end
	task.wait(25)
	folder:Destroy()
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
