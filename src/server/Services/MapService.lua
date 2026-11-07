--!strict
-- MapService — constrói a ilha central, loja, pedestais e as 8 bases 100% por código.
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)

local MapService = {}

export type BaseInfo = {
	index: number,
	model: Model,
	origin: CFrame,
	slots: { Part },
	giantAnchor: Part,
	sign: TextLabel,
	zone: Part,
	owner: Player?,
}

MapService.Bases = {} :: { BaseInfo }
MapService.ShopPad = nil :: Part?
MapService.Center = CFrame.new(0, 0, 0)

local function buildCenterIsland(root: Folder)
	local island = Util.makePart({
		Name = "CenterIsland",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 180, 180),
		CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 220, 160),
		Material = Enum.Material.Sand,
		Parent = root,
	})
	island.Name = "CenterIsland"

	-- Loja central
	local shop = Util.makePart({
		Name = "ShopPad",
		Size = Vector3.new(24, 1, 24),
		CFrame = CFrame.new(0, 2.5, 0),
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		Parent = root,
	})
	MapService.ShopPad = shop
	local shopSign = Util.makePart({
		Name = "ShopSign",
		Size = Vector3.new(26, 8, 2),
		CFrame = CFrame.new(0, 10, -12),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		Parent = root,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = shopSign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "LUNCHBOX SHOP"
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = Color3.fromRGB(255, 120, 40)
	lbl.Parent = gui
	Util.makeBillboard(
		shop,
		"LOJA — entre para abrir",
		UDim2.fromOffset(300, 60),
		Vector3.new(0, 6, 0),
		Color3.fromRGB(255, 220, 120)
	)

	-- Pedestal do evento
	local eventPad = Util.makePart({
		Name = "EventPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 30, 30),
		CFrame = CFrame.new(0, 2.5, 60) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 60, 255),
		Material = Enum.Material.Neon,
		Parent = root,
	})
	eventPad.Name = "EventPad"

	-- Leaderboards
	for i, title in { "MAIORES GIGANTES", "MAIS REBIRTHS", "REIS DA ARENA" } do
		local board = Util.makePart({
			Name = "Leaderboard" .. i,
			Size = Vector3.new(18, 24, 2),
			CFrame = CFrame.new(({ -46, 0, 46 })[i], 14, -62),
			Color = Color3.fromRGB(30, 30, 40),
			Material = Enum.Material.SmoothPlastic,
			Parent = root,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.PixelsPerStud = 25
		sg.Parent = board
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.Size = UDim2.fromScale(1, 0.12)
		t.BackgroundTransparency = 1
		t.Text = title
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.fromRGB(255, 220, 80)
		t.Parent = sg
		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromScale(0, 0.14)
		list.Size = UDim2.fromScale(1, 0.86)
		list.BackgroundTransparency = 1
		list.Text = "Carregando..."
		list.TextScaled = true
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.Font = Enum.Font.GothamBold
		list.TextColor3 = Color3.new(1, 1, 1)
		list.Parent = sg
	end

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 2.5, -40)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = root
end

local function buildBase(index: number, root: Folder): BaseInfo
	local angle = (index - 1) / Config.MaxPlayers * math.pi * 2
	local origin = CFrame.new(math.cos(angle) * Config.BaseRadius, 0, math.sin(angle) * Config.BaseRadius)
		* CFrame.Angles(0, -angle + math.pi / 2, 0)

	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = root

	local size = Config.BaseSize
	local floor = Util.makePart({
		Name = "Floor",
		Size = Vector3.new(size, 2, size),
		CFrame = origin * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(90, 90, 110),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local zone = Util.makePart({
		Name = "Zone",
		Size = Vector3.new(size, 20, size),
		CFrame = origin * CFrame.new(0, 12, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Caminho até o centro
	local dir = (Vector3.zero - origin.Position).Unit
	local dist = origin.Position.Magnitude - size / 2 - 88
	Util.makePart({
		Name = "Path",
		Size = Vector3.new(10, 1, dist),
		CFrame = CFrame.lookAt(origin.Position + dir * (size / 2 + dist / 2), Vector3.zero) * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(200, 180, 140),
		Material = Enum.Material.Cobblestone,
		Parent = model,
	})

	-- Pedestal do Gigante (fundo da base)
	local giantAnchor = Util.makePart({
		Name = "GiantAnchor",
		Size = Vector3.new(16, 1, 16),
		CFrame = origin * CFrame.new(0, 2.5, -size / 2 + 14),
		Color = Color3.fromRGB(255, 220, 80),
		Material = Enum.Material.Neon,
		Parent = model,
	})

	-- Slots do pátio (grade 4x4; os 12 primeiros padrão, 4 extras para VIP)
	local slots = {}
	local cols = 4
	local spacing = 9
	local startX = -(cols - 1) * spacing / 2
	for i = 1, Config.PlotSlotsVIP do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local slot = Util.makePart({
			Name = "Slot" .. i,
			Size = Vector3.new(6, 0.4, 6),
			CFrame = origin * CFrame.new(startX + col * spacing, 2.2, 8 + row * spacing - 10),
			Color = if i <= Config.PlotSlots then Color3.fromRGB(60, 200, 120) else Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		slot:SetAttribute("SlotIndex", i)
		slot:SetAttribute("BaseIndex", index)
		table.insert(slots, slot)
	end

	-- Placa com nome
	local signPart = Util.makePart({
		Name = "Sign",
		Size = Vector3.new(size, 6, 1),
		CFrame = origin * CFrame.new(0, 10, -size / 2),
		Color = Color3.fromRGB(40, 40, 50),
		Parent = model,
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = signPart
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Text = "BASE LIVRE"
	sign.TextScaled = true
	sign.Font = Enum.Font.FredokaOne
	sign.TextColor3 = Color3.new(1, 1, 1)
	sign.Parent = sg

	-- Paredes laterais baixas (decorativas)
	for _, side in { -1, 1 } do
		Util.makePart({
			Name = "Wall",
			Size = Vector3.new(1, 4, size),
			CFrame = origin * CFrame.new(side * size / 2, 4, 0),
			Color = Color3.fromRGB(70, 70, 90),
			Parent = model,
		})
	end

	floor:SetAttribute("BaseIndex", index)
	zone:SetAttribute("BaseIndex", index)

	return {
		index = index,
		model = model,
		origin = origin,
		slots = slots,
		giantAnchor = giantAnchor,
		sign = sign,
		zone = zone,
		owner = nil,
	}
end

function MapService.init()
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = Workspace
	buildCenterIsland(root)
	for i = 1, Config.MaxPlayers do
		MapService.Bases[i] = buildBase(i, root)
	end

	-- Decoração: nuvens
	for i = 1, 20 do
		local a = math.random() * math.pi * 2
		local r = 150 + math.random() * 400
		Util.makePart({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(20 + math.random() * 30, 10, 14 + math.random() * 10),
			CFrame = CFrame.new(math.cos(a) * r, 140 + math.random() * 60, math.sin(a) * r),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Transparency = 0.1,
			Parent = root,
		})
	end
end

function MapService.getBaseOf(player: Player): BaseInfo?
	for _, base in MapService.Bases do
		if base.owner == player then
			return base
		end
	end
	return nil
end

function MapService.claimBase(player: Player): BaseInfo?
	for _, base in MapService.Bases do
		if base.owner == nil then
			base.owner = player
			base.sign.Text = Locale.fmt("owner_sign", Locale.of(player), { p = string.upper(player.DisplayName) })
			return base
		end
	end
	return nil
end

function MapService.releaseBase(player: Player)
	local base = MapService.getBaseOf(player)
	if base then
		base.owner = nil
		base.sign.Text = "BASE LIVRE"
	end
end

return MapService
