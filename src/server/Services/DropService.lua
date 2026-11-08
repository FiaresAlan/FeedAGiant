--!strict
-- DropService — COMIDA CAI DO CÉU e precisa ser DEFENDIDA.
-- Um círculo aparece no chão. Quem fica dentro acumula progresso; o tempo necessário depende da raridade.
-- Socos empurram rivais para fora (e eles perdem metade do progresso). Quem fecha a barra leva a comida.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CombatService = require(script.Parent.CombatService)
local FoodModels = require(script.Parent.Parent.FoodModels)

local DropService = {}
local D = Config.Drops
-- Diferença máxima de altura entre o jogador e o centro do círculo (studs).
-- Personagem em pé fica ~3 acima do chão; pulos chegam a ~7.
local MAX_DROP_HEIGHT = 9

type Drop = {
	id: number,
	food: Config.FoodDef,
	pos: Vector3,
	model: Model,
	ring: Part,
	label: TextLabel,
	holdTime: number,
	progress: { [Player]: number },
	inside: { [Player]: boolean },
	landedAt: number,
	done: boolean,
}

local drops: { [number]: Drop } = {}
local nextId = 0
local folder: Folder

local function activeCount(): number
	local n = 0
	for _ in drops do
		n += 1
	end
	return n
end

local function rollFood(): Config.FoodDef
	-- Com poucos jogadores, raridades altas não caem do céu.
	local noRare = #Players:GetPlayers() < D.MinPlayersForRare
	local weights: { [string]: number } = {}
	for rawRarity, w in D.Weights do
		local r = rawRarity :: string
		if not (noRare and (r == "Legendary" or r == "Mythic" or r == "Secret")) then
			weights[r] = w :: number
		end
	end
	local rarity = Util.weightedPick(weights, 0)
	local pool = {}
	for _, f in Config.Foods do
		if f.rarity == rarity then
			table.insert(pool, f)
		end
	end
	if #pool == 0 then
		return Config.Foods[1]
	end
	return pool[math.random(1, #pool)]
end

local function buildDropModel(food: Config.FoodDef, pos: Vector3): (Model, Part, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Drop_" .. food.id
	local rar = Config.Rarities[food.rarity]
	local body = Util.makePart({
		Name = "Body",
		Size = Vector3.new(4, 4, 4),
		Color = food.color,
		Material = if rar.order >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(pos + Vector3.new(0, D.FallHeight, 0)),
		CanCollide = false,
		Parent = model,
	})
	if FoodModels.has(food.id) then
		-- Fase 2: comida 3D, maior que a do pátio (destaque do evento de disputa).
		FoodModels.dress(body, food.id, 5)
	else
		body.Shape = if food.shape == "Ball"
			then Enum.PartType.Ball
			elseif food.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
	end
	local light = Instance.new("PointLight")
	light.Color = rar.color
	light.Range = 12 + rar.order * 3
	light.Brightness = 2
	light.Parent = body
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(rar.color)
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(0.5, 1)
	trail.Speed = NumberRange.new(2, 5)
	trail.Size = NumberSequence.new(1.5, 0)
	trail.LightEmission = 1
	trail.Parent = body
	model.PrimaryPart = body

	local ring = Util.makePart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, D.ZoneRadius * 2, D.ZoneRadius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rar.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local label = Util.makeBillboard(ring, "", UDim2.fromOffset(320, 90), Vector3.new(0, 10, 0), rar.color)
	label.Text = string.format("%s\n%s — caindo!", food.name, Locale.rarity(food.rarity))
	return model, ring, label
end

local function award(drop: Drop, winner: Player)
	drop.done = true
	drops[drop.id] = nil
	local profile = DataService.get(winner)
	if profile then
		profile.dropsWon += 1
		DataService.markDirty(winner)
	end
	-- force: prêmio disputado; perder depois de vencer seria frustrante (1 item por drop).
	PlotService.giveFood(winner, drop.food.id, true)
	local rar = Config.Rarities[drop.food.rarity]
	Remotes.Notify:FireClient(winner, Locale.msg("drop_defended", { f = drop.food.name }, rar.color))
	if rar.order >= 3 then
		Remotes.Notify:FireAllClients(
			Locale.msg(
				"drop_won_broadcast",
				{ p = winner.DisplayName, f = drop.food.name, r = drop.food.rarity },
				rar.color
			)
		)
	end
	Remotes.DropState:FireAllClients({ id = drop.id, removed = true })
	-- efeito de coleta
	local body = drop.model.PrimaryPart
	if body then
		task.spawn(function()
			for i = 1, 10 do
				body.CFrame = body.CFrame * CFrame.new(0, 1.5, 0)
				body.Transparency = i / 10
				task.wait(0.03)
			end
			drop.model:Destroy()
		end)
	else
		drop.model:Destroy()
	end
end

local function expire(drop: Drop)
	drop.done = true
	drops[drop.id] = nil
	Remotes.DropState:FireAllClients({ id = drop.id, removed = true })
	drop.model:Destroy()
end

local function broadcastState(drop: Drop)
	local list = {}
	for plr, prog in drop.progress do
		if plr.Parent then
			table.insert(list, {
				userId = plr.UserId,
				name = plr.DisplayName,
				progress = prog / drop.holdTime,
				inside = drop.inside[plr] == true,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.progress > b.progress
	end)
	Remotes.DropState:FireAllClients({
		id = drop.id,
		foodId = drop.food.id,
		name = drop.food.name,
		rarity = drop.food.rarity,
		pos = drop.pos,
		holdTime = drop.holdTime,
		contenders = list,
	})
end

local function runDrop(drop: Drop)
	-- Aviso no chão antes de cair
	drop.label.Text =
		string.format("%s (%s)\nCaindo em %ds!", drop.food.name, Locale.rarity(drop.food.rarity), D.WarnBeforeFall)
	Remotes.Notify:FireAllClients(
		Locale.msg(
			"drop_incoming",
			{ f = drop.food.name, r = drop.food.rarity, n = drop.holdTime },
			Config.Rarities[drop.food.rarity].color
		)
	)
	broadcastState(drop)
	task.wait(D.WarnBeforeFall)
	if drop.done then
		return
	end
	-- Queda
	local body = drop.model.PrimaryPart :: Part
	local t0 = os.clock()
	local startY = D.FallHeight
	while os.clock() - t0 < D.FallTime do
		local a = (os.clock() - t0) / D.FallTime
		a = a * a -- aceleração
		body.CFrame = CFrame.new(drop.pos + Vector3.new(0, startY * (1 - a) + 2.5, 0)) * CFrame.Angles(a * 6, a * 9, 0)
		task.wait()
	end
	body.CFrame = CFrame.new(drop.pos + Vector3.new(0, 2.5, 0))
	drop.landedAt = os.clock()
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = drop.pos })

	-- Disputa
	local lastBroadcast = 0
	local emptySince = os.clock()
	while not drop.done do
		local dt = task.wait(0.2)
		local anyone = false
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local flat = Vector3.new(root.Position.X - drop.pos.X, 0, root.Position.Z - drop.pos.Z)
			-- Fase 0.6: altura também conta (quem flutua acima do círculo não pode ser socado).
			local height = math.abs(root.Position.Y - drop.pos.Y)
			local isIn = flat.Magnitude <= D.ZoneRadius and height <= MAX_DROP_HEIGHT and not CombatService.isKO(plr)
			local wasIn = drop.inside[plr] == true
			if isIn then
				anyone = true
				drop.inside[plr] = true
				drop.progress[plr] = math.min(drop.holdTime, (drop.progress[plr] or 0) + dt)
				if drop.progress[plr] >= drop.holdTime then
					award(drop, plr)
					return
				end
			else
				drop.inside[plr] = nil
				if wasIn and drop.progress[plr] then
					drop.progress[plr] = drop.progress[plr] * (1 - D.ProgressLossWhenOut)
					Remotes.Notify:FireClient(
						plr,
						{ text = "Saiu do círculo! Perdeu metade do progresso.", color = Color3.fromRGB(255, 120, 80) }
					)
				end
			end
		end
		if anyone then
			emptySince = os.clock()
		elseif os.clock() - emptySince > D.ExpireIfNobody then
			expire(drop)
			return
		end
		-- Label do mundo: líder atual
		local leader: Player? = nil
		local lp = 0
		for plr, prog in drop.progress do
			if prog > lp then
				lp = prog
				leader = plr
			end
		end
		if leader then
			drop.label.Text = string.format(
				"%s (%s)\n%s está defendendo: %d%%",
				drop.food.name,
				Locale.rarity(drop.food.rarity),
				leader.DisplayName,
				math.floor(lp / drop.holdTime * 100)
			)
		else
			drop.label.Text =
				string.format("%s (%s)\nENTRE NO CÍRCULO E DEFENDA!", drop.food.name, Locale.rarity(drop.food.rarity))
		end
		if os.clock() - lastBroadcast > 0.4 then
			lastBroadcast = os.clock()
			broadcastState(drop)
		end
		body.CFrame = body.CFrame * CFrame.Angles(0, 0.04, 0)
	end
end

function DropService.spawn(forceRarity: string?)
	if activeCount() >= D.MaxActive then
		return
	end
	local food = rollFood()
	if forceRarity then
		local pool = {}
		for _, f in Config.Foods do
			if f.rarity == forceRarity then
				table.insert(pool, f)
			end
		end
		if #pool > 0 then
			food = pool[math.random(1, #pool)]
		end
	end
	-- posição aleatória na praça: depois do caldeirão (raio ~29) e antes da loja/evento (r 98+).
	-- Com o círculo de raio 14, a disputa fica entre r 36 e r 96 (World.lua).
	local a = math.random() * math.pi * 2
	local r = 50 + math.random() * 32
	local pos = Vector3.new(math.cos(a) * r, 2.5, math.sin(a) * r)
	nextId += 1
	local model, ring, label = buildDropModel(food, pos)
	model.Parent = folder
	local drop: Drop = {
		id = nextId,
		food = food,
		pos = pos,
		model = model,
		ring = ring,
		label = label,
		holdTime = D.HoldTimeByRarity[food.rarity] or 10,
		progress = {},
		inside = {},
		landedAt = 0,
		done = false,
	}
	drops[drop.id] = drop
	task.spawn(function()
		local ok, err = pcall(runDrop :: any, drop)
		if not ok then
			warn("[DropService]", err)
			if not drop.done then
				expire(drop)
			end
		end
	end)
end

function DropService.init()
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = Workspace

	-- Quem é nocauteado dentro do círculo perde TODO o progresso daquele drop
	local prevKO = CombatService.OnKO
	CombatService.OnKO = function(attacker: Player, victim: Player)
		if prevKO then
			prevKO(attacker, victim)
		end
		for _, drop in drops do
			if drop.progress[victim] and drop.progress[victim] > 0 then
				drop.progress[victim] = 0
				drop.inside[victim] = nil
				Remotes.Notify:FireClient(
					victim,
					{ text = "Nocauteado! Progresso da disputa zerado.", color = Color3.fromRGB(255, 80, 80) }
				)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, drop in drops do
			drop.progress[player] = nil
			drop.inside[player] = nil
		end
	end)

	task.spawn(function()
		task.wait(20)
		while true do
			if #Players:GetPlayers() > 0 then
				DropService.spawn()
			end
			local scale = math.clamp(#Players:GetPlayers() / 4, 0.7, 1.6)
			task.wait(math.random(D.MinInterval, D.MaxInterval) / scale)
		end
	end)
end

return DropService
