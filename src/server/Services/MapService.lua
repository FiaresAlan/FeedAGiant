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
		Material = Enum.Material.WoodPlanks,
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
			-- cor-tema contrasta com o piso claro da base; os slots extras (VIP) seguem dourados
			Color = if i <= Config.PlotSlots then Color3.fromHex(theme.color) else Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		slot:SetAttribute("SlotIndex", i)
		slot:SetAttribute("BaseIndex", index)
		table.insert(slots, slot)
	end

	-- Placa com nome: nos FUNDOS da base, alta, virada para o centro. Na frente ela tapava
	-- a vista do caldeirão (revisão da Fase 1); aqui ela é lida por quem chega pelo caminho.
	local signPart = Util.makePart({
		Name = "Sign",
		Size = Vector3.new(40, 7, 1),
		CFrame = origin * CFrame.new(0, 15, size / 2 + 1),
		Color = Color3.fromHex(theme.color),
		Parent = model,
	})
	for _, x in { -20.5, 20.5 } do
		Util.makePart({
			Name = "SignPost",
			Size = Vector3.new(1.6, 19, 1.6),
			CFrame = origin * CFrame.new(x, 9.5, size / 2 + 1),
			Color = Color3.fromHex("#F8F8F8"),
			Parent = model,
		})
	end
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
	-- contorno escuro: lê em qualquer cor-tema (o branco sumia no amarelo)
	sign.TextStrokeColor3 = Color3.fromRGB(30, 30, 40)
	sign.TextStrokeTransparency = 0
	sign.Parent = sg
	-- Verso da placa (visto de dentro da base) mostra o mesmo texto
	local sgBack = sg:Clone()
	sgBack.Face = Enum.NormalId.Back
	sgBack.Parent = signPart
	local signBack = sgBack:FindFirstChildOfClass("TextLabel") :: TextLabel
	sign:GetPropertyChangedSignal("Text"):Connect(function()
		signBack.Text = sign.Text
	end)

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

-- Versão do mapa gerado. AUMENTE este número sempre que mudar a geometria em World.lua/MapService:
-- um mapa "assado" (salvo no place pelo MapService.bake) com versão diferente é descartado ao rodar e
-- o jogo gera de novo (o place salvo não muda; é só re-assar para atualizar a visão no modo edição).
-- v2 (08/11/2026): arena física (World.buildArena) + estrada da praça até ela.
local MAP_VERSION = 2

-- Places antigos (ex.: o place oficial) ainda têm o Baseplate de 1200x4 com topo em y=2, acima do chão
-- novo (topo em 0): árvores, estrada e bases ficavam "enterradas". Move para o ServerStorage (não apaga).
local function stashLegacyBaseplate()
	local legacy = Workspace:FindFirstChild("Baseplate")
	if legacy then
		local storage = game:GetService("ServerStorage")
		local stash = storage:FindFirstChild("LegacyMap") or Instance.new("Folder")
		stash.Name = "LegacyMap"
		stash.Parent = storage
		legacy.Parent = stash
	end
end

-- Gera o mapa inteiro (chão, praça, bases, natureza) e o coloca no Workspace.
local function buildMap(): Folder
	local root = Instance.new("Folder")
	root.Name = "Map"
	-- Chão primeiro e sem pcall: sem ele os jogadores cairiam no vazio.
	World.buildGround(root)
	MapService.ShopPad = World.buildHub(root)
	-- Fase 4: alvo do passo "box" do tutorial (trilha até a loja)
	game:GetService("CollectionService"):AddTag(MapService.ShopPad :: Part, "TutorialShop")
	-- Fase 3: arena física das lutas (falha aqui não impede o jogo; a ArenaService avisa)
	local okArena, errArena = pcall(World.buildArena :: any, root)
	if not okArena then
		warn("[MapService] arena não construída:", errArena)
	end
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
	return root
end

-- Reaproveita uma base de um mapa assado (mesmos nomes e atributos que buildBase cria).
local function adoptBase(index: number, model: Model): BaseInfo?
	local floor = model:FindFirstChild("Floor") :: Part?
	local zone = model:FindFirstChild("Zone") :: Part?
	local giantAnchor = model:FindFirstChild("GiantAnchor") :: Part?
	local signPart = model:FindFirstChild("Sign") :: Part?
	if not (floor and zone and giantAnchor and signPart) then
		return nil
	end
	local front, back
	for _, g in signPart:GetChildren() do
		if g:IsA("SurfaceGui") then
			local label = g:FindFirstChildOfClass("TextLabel")
			if g.Face == Enum.NormalId.Front then
				front = label
			elseif g.Face == Enum.NormalId.Back then
				back = label
			end
		end
	end
	if not front then
		return nil
	end
	local sign = front :: TextLabel
	sign.Text = "BASE LIVRE"
	if back then
		local backLabel = back :: TextLabel
		backLabel.Text = sign.Text
		sign:GetPropertyChangedSignal("Text"):Connect(function()
			backLabel.Text = sign.Text
		end)
	end
	local slots: { Part } = {}
	for i = 1, Config.PlotSlotsVIP do
		local slot = model:FindFirstChild("Slot" .. i) :: Part?
		if not slot then
			return nil
		end
		table.insert(slots, slot)
	end
	return {
		index = index,
		model = model,
		origin = floor.CFrame * CFrame.new(0, -1, 0), -- o piso fica em origin * (0, 1, 0)
		slots = slots,
		giantAnchor = giantAnchor,
		sign = sign,
		zone = zone,
		owner = nil,
	}
end

-- Usa o mapa assado se ele for desta versão e estiver completo.
local function adoptBakedMap(root: Instance): boolean
	local shop = root:FindFirstChild("ShopPad") :: Part?
	if not shop then
		return false
	end
	local bases: { BaseInfo } = {}
	for i = 1, Config.MaxPlayers do
		local model = root:FindFirstChild("Base" .. i)
		if not (model and model:IsA("Model")) then
			return false
		end
		local info = adoptBase(i, model)
		if not info then
			return false
		end
		bases[i] = info
	end
	MapService.Bases = bases
	MapService.ShopPad = shop
	game:GetService("CollectionService"):AddTag(shop, "TutorialShop")
	return true
end

function MapService.init()
	stashLegacyBaseplate()
	local baked = Workspace:FindFirstChild("Map")
	if baked and baked:GetAttribute("Baked") == true then
		if baked:GetAttribute("MapVersion") == MAP_VERSION and adoptBakedMap(baked) then
			print("[MapService] usando o mapa assado do place (versão " .. MAP_VERSION .. ")")
			return
		end
		warn("[MapService] mapa assado desatualizado ou incompleto; gerando de novo (re-asse no Studio)")
		baked:Destroy()
	elseif baked then
		baked:Destroy() -- sobra de outra versão: o mapa é sempre do código
	end
	buildMap()
end

-- Assa o mapa no MODO EDIÇÃO do Studio, para ver e editar o mundo sem dar Play.
-- No Studio (barra de comandos ou MCP):
--   require(game.ServerScriptService.Server.Services.MapService).bake()
-- Depois salve o place (Ctrl+S / Publicar). Ao rodar, o jogo reaproveita este mapa (sem gerar outro).
-- ATENÇÃO: mudanças feitas à mão dentro de Workspace.Map ficam no place, mas são PERDIDAS se o código
-- mudar a versão (MAP_VERSION) e alguém re-assar. Para mudanças permanentes, altere World.lua.
function MapService.bake(): string
	stashLegacyBaseplate()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	-- mesma luz do jogo, para a visão no modo edição bater com o Play
	local LightingRecipes = require(game.ReplicatedStorage.Shared.LightingRecipes)
	LightingRecipes.apply("GoldenAfternoon")
	MapService.Bases = {}
	local root = buildMap()
	root:SetAttribute("Baked", true)
	root:SetAttribute("MapVersion", MAP_VERSION)
	root:SetAttribute("BakedAt", os.date("!%Y-%m-%d %H:%M UTC"))
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("Mapa assado: versão %d, %d peças. Salve o place (Ctrl+S)."):format(MAP_VERSION, parts)
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
