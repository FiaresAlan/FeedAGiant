--!strict
-- PlazaDistrict — ilha viva SEM aumentar terreno nem alterar o MapVersion.
-- Atracoes procedurais finais, leves, posicionadas nos vãos da praça (r=90..110),
-- fora das 8 estradas radiais e das 12 estátuas (r=166).
-- Os modelos não possuem Scripts de terceiros e não exigem upload de assets.
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local AssetDecorator = require(script.Parent.AssetDecorator)

local PlazaDistrict = {}

-- Cada ponto ocupa um vão entre as estradas da praça, a 22,5° de uma estrada radial.
-- Usado pelo layout procedural e por testes de não colisão.
PlazaDistrict.Layout = {
	Kitchen = { angle = 112.5, radius = 98 },
	TrailStart = { angle = 202.5, radius = 98 },
	TrailSteps = { 247.5, 292.5, 337.5 },
	Lookout = { angle = 67.5, radius = 98 },
}
local L = PlazaDistrict.Layout

local WOOD = Color3.fromRGB(136, 86, 54)
local WOOD_DARK = Color3.fromRGB(82, 54, 46)
local WARM = Color3.fromRGB(252, 201, 102)
local TEAL = Color3.fromRGB(48, 157, 150)
local TEAL_LIGHT = Color3.fromRGB(105, 222, 198)
local CREAM = Color3.fromRGB(255, 232, 179)
local STONE = Color3.fromRGB(127, 128, 135)

local function polar(angle: number, radius: number, y: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
end

local function make(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false -- a praça original continua sendo o piso físico
	p.CanTouch = false
	p.CanQuery = false -- não interferir com raycasts de comida, bots ou mira
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function disk(parent: Instance, name: string, cf: CFrame, diameter: number, color: Color3, height: number?): Part
	local h = height or 0.3
	return make(
		parent,
		name,
		Vector3.new(h, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.Slate,
		Enum.PartType.Cylinder
	)
end

local function sign(anchor: BasePart, title: string, color: Color3, range: number, rise: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DistrictSign"
	gui.Size = UDim2.fromOffset(280, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, rise or 6, 0)
	gui.MaxDistance = range
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(45, 31, 36)
	label.TextStrokeTransparency = 0.1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
end

local function banner(parent: Instance, cf: CFrame, color: Color3)
	make(parent, "Mastro", Vector3.new(0.6, 11, 0.6), cf * CFrame.new(0, 5.5, 0), WOOD_DARK)
	make(parent, "Bandeirola", Vector3.new(0.2, 4, 3), cf * CFrame.new(0, 8.5, -1.4), color, Enum.Material.Fabric)
	make(
		parent,
		"Ponta",
		Vector3.new(1.1, 1.1, 1.1),
		cf * CFrame.new(0, 11.3, 0),
		WARM,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
end

local function barrel(parent: Instance, name: string, cf: CFrame, scale: number)
	local base = cf * CFrame.new(0, 2 * scale, 0)
	local body = make(
		parent,
		name,
		Vector3.new(4 * scale, 3.4 * scale, 3.4 * scale),
		base * CFrame.Angles(0, 0, math.rad(90)),
		WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	for y = -1, 1, 2 do
		make(
			body,
			"Aro",
			Vector3.new(0.3 * scale, 3.6 * scale, 3.6 * scale),
			base * CFrame.new(0, y * scale, 0) * CFrame.Angles(0, 0, math.rad(90)),
			STONE,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
end

local function tableTop(parent: Instance, cf: CFrame, name: string, color: Color3): Part
	local top = make(parent, name, Vector3.new(8, 0.7, 5), cf * CFrame.new(0, 3.2, 0), color, Enum.Material.WoodPlanks)
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -1.7, 1.7 } do
			make(top, "Pé", Vector3.new(0.7, 3, 0.7), cf * CFrame.new(dx, 1.6, dz), WOOD_DARK, Enum.Material.Wood)
		end
	end
	return top
end

local function createKitchen(root: Instance)
	local center = polar(L.Kitchen.angle, L.Kitchen.radius, 2.35)
	local cf = CFrame.lookAt(center, Vector3.new(0, center.Y, 0))
	local kitchen = Instance.new("Model")
	kitchen.Name = "ColossalKitchen"
	kitchen.Parent = root
	disk(kitchen, "PraçaDaCozinha", cf * CFrame.new(0, 0.25, 0), 36, STONE, 0.5)
	disk(kitchen, "AroDaCozinha", cf * CFrame.new(0, 0.55, 0), 34, TEAL, 0.08)
	disk(kitchen, "PisoInterno", cf * CFrame.new(0, 0.62, 0), 31, WOOD_DARK, 0.1)
	banner(kitchen, cf * CFrame.new(-15, 0, -4), TEAL_LIGHT)
	banner(kitchen, cf * CFrame.new(15, 0, -4), TEAL_LIGHT)
	local serve =
		make(kitchen, "ServeSpot", Vector3.new(6, 2, 6), cf * CFrame.new(0, 1.55, 7), WOOD, Enum.Material.WoodPlanks)
	local tray = make(
		kitchen,
		"BandejaDaEquipe",
		Vector3.new(5, 0.4, 5),
		serve.CFrame * CFrame.new(0, 1.15, 0),
		WARM,
		Enum.Material.Wood
	)
	serve:SetAttribute("Role", "Serve")
	local signAnchor =
		make(kitchen, "TotemCozinha", Vector3.new(2, 7, 1), cf * CFrame.new(0, 3.5, -12), WOOD_DARK, Enum.Material.Wood)
	sign(signAnchor, "COZINHA COLOSSAL", CREAM, 90, 8.5)
	-- Estação A: cortar. Estação B: mexer na panela. A atividade real fica no SocialFeastService.
	local prepA = tableTop(kitchen, cf * CFrame.new(-10, 0, -2), "PrepA", WOOD)
	local prepB = tableTop(kitchen, cf * CFrame.new(10, 0, -2), "PrepB", WOOD)
	make(kitchen, "Tábua", Vector3.new(5, 0.3, 3), prepA.CFrame * CFrame.new(0, 0.52, 0), CREAM, Enum.Material.Wood)
	make(
		kitchen,
		"Cenoura",
		Vector3.new(1.8, 1.8, 1.8),
		prepA.CFrame * CFrame.new(-1.2, 1.5, 0),
		Color3.fromRGB(239, 99, 61),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	make(
		kitchen,
		"Legume",
		Vector3.new(1.2, 1.2, 1.2),
		prepA.CFrame * CFrame.new(1.2, 1.1, 0),
		Color3.fromRGB(109, 178, 67),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	local pot = make(
		kitchen,
		"Panela",
		Vector3.new(2.2, 4.1, 4.1),
		prepB.CFrame * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		STONE,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	make(
		pot,
		"Sopa",
		Vector3.new(0.2, 3.6, 3.6),
		prepB.CFrame * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(245, 132, 54),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	make(
		kitchen,
		"ColherGigante",
		Vector3.new(0.5, 5, 0.5),
		prepB.CFrame * CFrame.new(0.5, 4.2, 0) * CFrame.Angles(math.rad(18), 0, 0),
		CREAM,
		Enum.Material.Wood
	)
	barrel(kitchen, "BarrilComMaçãs", cf * CFrame.new(-14, 0, 7), 0.7)
	barrel(kitchen, "Barril", cf * CFrame.new(14, 0, 7), 0.7)
	serve:SetAttribute("UseBySocialFeast", true)
	tray:SetAttribute("UseBySocialFeast", false)
	-- Os templates opcionais devem ser importados pelo dono em ServerStorage;
	-- sem eles, todas as primitivas acima permanecem visíveis e funcionais.
	local imported = AssetDecorator.apply(kitchen)
	if imported > 0 then
		print("[PlazaDistrict] modelos auditados aplicados à Cozinha:", imported)
	end
	return kitchen
end

local function trailSpot(parent: Instance, name: string, cf: CFrame, color: Color3, label: string): Part
	disk(parent, name .. "Circle", cf * CFrame.new(0, 0.3, 0), 13, color, 0.4)
	disk(parent, "Tampa", cf * CFrame.new(0, 0.53, 0), 10, WOOD_DARK, 0.08)
	local pillar =
		make(parent, name, Vector3.new(3.4, 5, 3.4), cf * CFrame.new(0, 2.55, 0), WOOD, Enum.Material.WoodPlanks)
	make(
		parent,
		"Cristal",
		Vector3.new(2.8, 2.8, 2.8),
		cf * CFrame.new(0, 5.7, 0),
		color,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	sign(pillar, label, CREAM, 85)
	return pillar
end

local function createTrail(root: Instance)
	local trail = Instance.new("Model")
	trail.Name = "IngredientTrail"
	trail.Parent = root
	-- Marcas pequenas e descontínuas seguem o anel sem levantar barreiras no caminho.
	-- Contrastam com o chão alaranjado dos prints e ligam os quatro postos visualmente.
	for angle = 206, 334, 11 do
		local mark = make(
			trail,
			"MigalhaDeRota",
			Vector3.new(2.6, 0.08, 4.5),
			CFrame.new(polar(angle, L.TrailStart.radius, 2.92)) * CFrame.Angles(0, math.rad(angle), 0),
			TEAL_LIGHT,
			Enum.Material.Neon
		)
		mark.Transparency = 0.24
	end
	local start = trailSpot(
		trail,
		"TrailStart",
		CFrame.new(polar(L.TrailStart.angle, L.TrailStart.radius, 2.2)),
		TEAL,
		"TRILHA DA COMIDA"
	)
	start:SetAttribute("TrailStage", 0)
	for i, angle in L.TrailSteps do
		local colors = { Color3.fromRGB(115, 180, 95), Color3.fromRGB(237, 164, 71), TEAL_LIGHT }
		local names = { "PISTA 1 · HORTA", "PISTA 2 · DESPENSA", "PISTA 3 · RECEITA" }
		local p =
			trailSpot(trail, "TrailStep" .. i, CFrame.new(polar(angle, L.TrailStart.radius, 2.2)), colors[i], names[i])
		p:SetAttribute("TrailStage", i)
	end
	return trail
end

local function createLookout(root: Instance)
	local center = polar(L.Lookout.angle, L.Lookout.radius, 2.2)
	local cf = CFrame.lookAt(center, Vector3.new(0, center.Y, 0))
	local lookout = Instance.new("Model")
	lookout.Name = "ColossusLookout"
	lookout.Parent = root
	disk(lookout, "Mirante", cf * CFrame.new(0, 0.35, 0), 27, STONE, 0.7)
	disk(lookout, "Borda", cf * CFrame.new(0, 0.73, 0), 25, TEAL, 0.08)
	disk(lookout, "Centro", cf * CFrame.new(0, 0.79, 0), 22, WOOD_DARK, 0.08)
	banner(lookout, cf * CFrame.new(-10, 0, 1), WARM)
	banner(lookout, cf * CFrame.new(10, 0, 1), WARM)
	local podium =
		make(lookout, "PhotoSpot", Vector3.new(5, 1.1, 5), cf * CFrame.new(0, 1.1, 0), CREAM, Enum.Material.Sandstone)
	make(
		lookout,
		"MarcaDeFoto",
		Vector3.new(3.1, 0.12, 3.1),
		podium.CFrame * CFrame.new(0, 0.61, 0),
		WARM,
		Enum.Material.Neon
	)
	local marker = make(lookout, "PhotoCamera", Vector3.new(1, 1, 1), cf * CFrame.new(0, 10, 21), CREAM)
	marker.Transparency = 1
	marker.CanQuery = false
	local labelPart =
		make(lookout, "PlacaMirante", Vector3.new(1, 5, 1), cf * CFrame.new(0, 3, -9), WOOD, Enum.Material.Wood)
	sign(labelPart, "MIRANTE DOS COLOSSOS", CREAM, 110)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PhotoPrompt"
	prompt.ActionText = "ENQUADRAR FOTO"
	prompt.ObjectText = "Mirante dos Colossos"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0.2
	prompt.RequiresLineOfSight = false
	prompt.Parent = podium
	CollectionService:AddTag(podium, "ColossusPhotoSpot")
	return lookout
end

function PlazaDistrict.build()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local old = map:FindFirstChild("LivingPlazaDistrict")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "LivingPlazaDistrict"
	root.Parent = map
	createKitchen(root)
	createTrail(root)
	createLookout(root)
	-- Todos os objetos são intencionalmente não colidíveis para não interferir
	-- com as estradas, drops, bots, bases ou movimento dos jogadores.
end

return PlazaDistrict
