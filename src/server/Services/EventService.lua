--!strict
-- EventService — eventos globais de servidor (Golden Hour, Chuva de Comida, Boss Faminto, Lucky Boxes).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local GiantService = require(script.Parent.GiantService)
local DropService = require(script.Parent.DropService)
local WorldFx = require(script.Parent.Parent.WorldFx)

local EventService = {}
local active: string? = nil
local boardLabel: TextLabel? = nil -- cronômetro em cima do caldeirão
local activeEndsAt = 0
local activeName = ""

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

local RUNNERS = {
	GoldenHour = runGoldenHour,
	LuckyBoxes = runLuckyBoxes,
	FoodRain = runFoodRain,
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
	activeName = def.name
	activeEndsAt = os.time() + def.duration
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

-- Cronômetro em cima do Caldeirão do Banquete (item 10): mostra o próximo evento da panela ou o
-- evento que está rolando. Atualizado pelo servidor a cada segundo (todos veem o mesmo).

local function buildBoard()
	local map = Workspace:WaitForChild("Map", 60)
	local m = map and map:FindFirstChild("BanquetCauldron", true)
	local soup = m and m:FindFirstChild("Soup")
	if not soup or not soup:IsA("BasePart") then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "EventTimer"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(soup.Position + Vector3.new(0, 34, 0))
	anchor.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(46, 11)
	bb.LightInfluence = 0
	bb.MaxDistance = 600
	bb.Parent = anchor
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(44, 47, 55)
	bg.BackgroundTransparency = 0.15
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 176, 40)
	stroke.Thickness = 4
	stroke.Parent = bg
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 70)
	label.TextStrokeTransparency = 0.2
	label.Parent = bg
	boardLabel = label
end

local function mmss(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

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
	task.spawn(buildBoard)
	task.spawn(function()
		while true do
			task.wait(1)
			local label = boardLabel
			if label then
				if active then
					label.Text =
						string.format("AGORA: %s  %s", string.upper(activeName), mmss(activeEndsAt - os.time()))
				elseif schedule then
					local plan = schedule :: any
					label.Text = string.format("%s EM %s", string.upper(plan.nextName), mmss(plan.at - os.time()))
				end
			end
		end
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
