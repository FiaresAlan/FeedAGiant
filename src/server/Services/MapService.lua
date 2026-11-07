--!strict
-- MapService — constrói a ilha central, loja, pedestais e as 8 bases 100% por código.
-- Fase 1: o cenário (ilha, praça, marco, caminhos, natureza) vem do World.lua; aqui ficam as
-- peças de jogo das bases (piso, zona, slots, pedestal do gigante, placa).
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local World = require(script.Parent.Parent.World)

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

local function buildBase(index: number, root: Folder): BaseInfo
	local angle = (index - 1) / Config.MaxPlayers * math.pi * 2
	local origin = CFrame.new(math.cos(angle) * Config.BaseRadius, 0, math.sin(angle) * Config.BaseRadius)
		* CFrame.Angles(0, -angle + math.pi / 2, 0)

	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = root

	local size = Config.BaseSize
	local theme = World.BaseThemes[(index - 1) % #World.BaseThemes + 1]
	local floor = Util.makePart({
		Name = "Floor",
		Size = Vector3.new(size, 2, size),
		CFrame = origin * CFrame.new(0, 1, 0),
		Color = Color3.fromHex(theme.light),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	floor.TopSurface = Enum.SurfaceType.Studs
	local zone = Util.makePart({
		Name = "Zone",
		Size = Vector3.new(size, 20, size),
		CFrame = origin * CFrame.new(0, 12, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Caminho até a praça (World: cor clara com bordas, termina no degrau da praça)
	World.buildPath(origin, model)

	-- Pedestal do Gigante (fundo da base)
	local giantAnchor = Util.makePart({
		Name = "GiantAnchor",
		Size = Vector3.new(16, 1, 16),
		CFrame = origin * CFrame.new(0, 2.5, -size / 2 + 14),
		Color = Color3.fromHex(theme.color),
		Material = Enum.Material.SmoothPlastic,
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
		Color = Color3.fromHex(theme.color),
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

	World.decorateBase(index, origin, model)

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
	-- Chão primeiro e sem pcall: sem ele os jogadores cairiam no vazio.
	World.buildGround(root)
	MapService.ShopPad = World.buildHub(root)
	local origins = {}
	for i = 1, Config.MaxPlayers do
		MapService.Bases[i] = buildBase(i, root)
		table.insert(origins, MapService.Bases[i].origin)
	end
	root.Parent = Workspace
	-- Natureza depois (o Scatter usa raycast no chão já parentado). Falha aqui não quebra o jogo.
	local ok, err = pcall(World.buildNature :: any, root, origins)
	if not ok then
		warn("[MapService] natureza não construída:", err)
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
