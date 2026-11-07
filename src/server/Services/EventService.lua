--!strict
-- EventService — eventos globais de servidor (Golden Hour, Chuva de Comida, Boss Faminto, Lucky Boxes).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local GiantService = require(script.Parent.GiantService)
local Guard = require(script.Parent.Parent.Guard)

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
		local r = math.random() * 80
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

local function runHungryBoss(def)
	local pad = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("EventPad") :: Part?
	local origin = if pad then pad.CFrame * CFrame.new(0, 2, 0) else CFrame.new(0, 3, 60)
	local boss = Instance.new("Model")
	boss.Name = "HungryBoss"
	local body = Util.makePart({
		Name = "Body",
		Size = Vector3.new(14, 18, 10),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
		CFrame = origin * CFrame.new(0, 9, 0),
		Parent = boss,
	})
	local head = Util.makePart({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(10, 10, 10),
		Color = Color3.fromRGB(255, 120, 120),
		Material = Enum.Material.SmoothPlastic,
		CFrame = origin * CFrame.new(0, 23, 0),
		Parent = boss,
	})
	boss.PrimaryPart = body
	local label = Util.makeBillboard(
		head,
		"BOSS FAMINTO\nClique em mim com comida no inventário!",
		UDim2.fromOffset(320, 80),
		Vector3.new(0, 8, 0),
		Color3.fromRGB(255, 90, 90)
	)
	boss.Parent = Workspace

	local scores: { [Player]: number } = {}
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 40
	click.Parent = body
	local lastFeed: { [Player]: number } = {}
	click.MouseClick:Connect(function(plr)
		if not Guard.withinReach(plr, body, click.MaxActivationDistance) then
			return
		end
		local now = os.clock()
		if (lastFeed[plr] or 0) + 0.2 > now then
			return
		end
		lastFeed[plr] = now
		local profile = DataService.get(plr)
		if not profile or #profile.inventory == 0 then
			Remotes.Notify:FireClient(
				plr,
				{ text = "Você precisa de comida no inventário!", color = Color3.fromRGB(255, 90, 90) }
			)
			return
		end
		local item = table.remove(profile.inventory, 1)
		if not item then
			return
		end
		local d = Config.FoodById[item.id]
		local pts = d and Config.Rarities[d.rarity].xp or 10
		scores[plr] = (scores[plr] or 0) + pts
		profile.coins += pts * 2
		DataService.markDirty(plr)
		PlotService.pushState(plr)
		local s = body.Size
		body.Size = s * 1.03
		label.Text = Locale.fmt("boss_score", "pt-br", { p = plr.DisplayName, n = scores[plr] })
	end)

	task.wait(def.duration)
	boss:Destroy()
	local ranking = {}
	for plr, pts in scores do
		table.insert(ranking, { plr = plr, pts = pts })
	end
	table.sort(ranking, function(a, b)
		return a.pts > b.pts
	end)
	for i = 1, math.min(3, #ranking) do
		local plr = ranking[i].plr
		if plr.Parent then
			ShopService.openBox(plr, "legendary", { free = true, minRarity = "Legendary", force = true })
			Remotes.Notify:FireAllClients(
				Locale.msg("boss_rank", { p = plr.DisplayName, n = i }, Color3.fromRGB(255, 180, 20))
			)
		end
	end
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
	local ok, err = pcall(RUNNERS[id], def)
	if not ok then
		warn("[EventService]", err)
	end
	Remotes.EventEnded:FireAllClients({ id = id })
	active = nil
end

function EventService.init()
	task.spawn(function()
		task.wait(90)
		while true do
			local list = Config.Events.List
			local pick = list[math.random(1, #list)]
			EventService.start(pick.id)
			task.wait(math.random(Config.Events.MinInterval, Config.Events.MaxInterval))
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
