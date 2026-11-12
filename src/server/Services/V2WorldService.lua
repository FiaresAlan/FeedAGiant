--!strict
-- V2: pista deterministica anexa + decoracao de cozinha em cada base, sem alterar MapService.bake.
-- Apenas construido quando Features.RebuildV2 for ativada em ambiente de QA.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = require(ReplicatedStorage.Shared.Features)
local MapService = require(script.Parent.MapService)
local AudioAssets = require(ReplicatedStorage.Shared.AudioAssets)
local CookRules = require(ReplicatedStorage.Shared.RebuildV2.CookRules)

local World = {}
World.SpawnPoints = {}
World.DeliveryZones = {} :: { [number]: Part }

local C = {
	floor = Color3.fromRGB(70, 111, 116),
	track = Color3.fromRGB(91, 146, 137),
	border = Color3.fromRGB(39, 61, 73),
	gold = Color3.fromRGB(253, 202, 112),
	cream = Color3.fromRGB(253, 237, 198),
	wood = Color3.fromRGB(137, 88, 66),
	rock = Color3.fromRGB(103, 108, 120),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function pillar(parent: Instance, name: string, diameter: number, height: number, cf: CFrame, color: Color3): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function sign(parent: Instance, root: BasePart, title: string, offset: Vector3)
	local bb = Instance.new("BillboardGui")
	bb.Name = "V2Label"
	bb.Size = UDim2.fromOffset(200, 58)
	bb.StudsOffsetWorldSpace = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = 160
	bb.Parent = root
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = C.border
	text.BackgroundTransparency = 0.15
	text.Text = title
	text.TextScaled = true
	text.TextWrapped = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = C.cream
	text.Parent = bb
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 10)
	round.Parent = text
end

local function buildPot(parent: Instance, localCF: CFrame, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local platform = part(m, "StoneCounter", Vector3.new(9, 2, 9), localCF * CFrame.new(0, 3, 0), C.rock, Enum.Material.Slate)
	local stand = pillar(m, "BrassStove", 7.6, 4, localCF * CFrame.new(0, 5.5, 0), C.wood)
	pillar(m, "Pot", 6.5, 3, localCF * CFrame.new(0, 8.4, 0), C.border)
	pillar(m, "Rim", 7.0, 0.5, localCF * CFrame.new(0, 10, 0), C.gold)
	local surface = pillar(m, "Soup", 6.2, 0.15, localCF * CFrame.new(0, 10.25, 0), Color3.fromRGB(229, 149, 75))
	surface.CanCollide = false
	surface.Material = Enum.Material.SmoothPlastic
	surface:SetAttribute("PotState", "empty")
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "CookBubbles"
	bubbles.Rate = 0
	bubbles.Lifetime = NumberRange.new(0.6, 1.1)
	bubbles.Speed = NumberRange.new(0.4, 1.2)
	bubbles.Size = NumberSequence.new(0.3, 0)
	bubbles.Color = ColorSequence.new(C.cream)
	bubbles.LightInfluence = 0
	bubbles.Parent = surface
	local light = Instance.new("PointLight")
	light.Name = "ReadyGlow"
	light.Brightness = 0
	light.Range = 13
	light.Color = C.gold
	light.Parent = surface
	local bell = Instance.new("Sound")
	bell.Name = "ReadyBell"
	bell.SoundId = AudioAssets["sfx_bell"] or ""
	bell.Volume = 0.22
	bell.RollOffMaxDistance = 35
	bell.Parent = surface
	local indicator = Instance.new("BillboardGui")
	indicator.Name = "PotIndicator"
	indicator.Size = UDim2.fromOffset(150, 42)
	indicator.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	indicator.MaxDistance = 55
	indicator.Parent = surface
	local info = Instance.new("TextLabel")
	info.Name = "Text"
	info.Size = UDim2.fromScale(1, 1)
	info.BackgroundColor3 = C.border
	info.BackgroundTransparency = 0.20
	info.TextColor3 = C.cream
	info.TextScaled = true
	info.Text = "VAZIA"
	info.Parent = indicator
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "V2OpenCookbook"
	prompt.ActionText = "Abrir Livro"
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = platform
	sign(m, stand, name, Vector3.new(0, 5.5, 0))
	return m
end

-- Acabamento de ilha/base em blocos pintados, sem tocar no ID do plot,
-- na area navegavel de estoque, nos ovos, nem nos slots das comidas.
local function buildPremiumBase(extras: Folder, base: MapService.BaseInfo)
	local center = base.origin * CFrame.new(0, 0, -16)
	-- Contorno modular arredondado: pecas de brinquedo baixas, sem colisao.
	for n = 1, 16 do
		local theta = ((n - 1) / 16) * math.pi * 2
		local localPos = Vector3.new(math.cos(theta) * 16.5, 2.25, -16 + math.sin(theta) * 16.5)
		local segment = part(extras, "DaisRim" .. n, Vector3.new(4.2, 0.6, 3.1),
			base.origin * CFrame.new(localPos) * CFrame.Angles(0, -theta, 0),
			if n % 4 == 0 then C.gold else C.border, Enum.Material.SmoothPlastic, false)
		segment.TopSurface = Enum.SurfaceType.Studs
	end
	for _, x in { -11, 11 } do
		local torch = part(extras, "GolemStandLight", Vector3.new(1.6, 3, 1.6),
			center * CFrame.new(x, 3.1, 9), C.wood, Enum.Material.SmoothPlastic, false)
		local glow = part(extras, "GolemStandBeacon", Vector3.new(1.2, 0.7, 1.2),
			torch.CFrame * CFrame.new(0, 1.7, 0), C.gold, Enum.Material.Neon, false)
		local lamp = Instance.new("PointLight")
		lamp.Brightness = 0.5
		lamp.Range = 11
		lamp.Parent = glow
	end
	local bookStand = part(extras, "RecipeBookStand", Vector3.new(7, 2.4, 5),
		base.origin * CFrame.new(0, 2.7, 9), C.wood, Enum.Material.Wood, false)
	local book = part(extras, "RecipeBook", Vector3.new(4.1, 0.55, 3),
		bookStand.CFrame * CFrame.new(0, 1.5, 0), C.cream, Enum.Material.SmoothPlastic, false)
	book:SetAttribute("V3Interactive", "cookbook")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "V2OpenCookbook"
	prompt.ObjectText = "LIVRO DE RECEITAS"
	prompt.ActionText = "Consultar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = book
	sign(extras, book, "LIVRO DE RECEITAS", Vector3.new(0, 2, 0))
	local eggStand = part(extras, "EggCollectionPlinth", Vector3.new(6, 1.1, 6),
		base.origin * CFrame.new(23, 2.65, 15), C.rock, Enum.Material.SmoothPlastic, false)
	sign(extras, eggStand, "COLECAO DE OVOS", Vector3.new(0, 3, 0))
end

local function buildBaseProps(base: MapService.BaseInfo)
	local existing = base.model:FindFirstChild("V2BaseExtras")
	if existing then existing:Destroy() end
	local extras = Instance.new("Folder")
	extras.Name = "V2BaseExtras"
	extras.Parent = base.model
	buildPremiumBase(extras, base)
	local left = base.origin * CFrame.new(-24, 0, -9)
	local right = base.origin * CFrame.new(24, 0, -9)
	buildPot(extras, left, "PANELA A")
	buildPot(extras, right, "PANELA B")
	local zone = part(extras, "V2DeliveryZone", Vector3.new(22, 0.7, 9), base.origin * CFrame.new(0, 2.5, 25), C.gold, Enum.Material.Neon, false)
	zone.Transparency = 0.32
	zone:SetAttribute("BaseIndex", base.index)
	sign(extras, zone, "ENTREGA SEGURA", Vector3.new(0, 5, 0))
	World.DeliveryZones[base.index] = zone
end

-- Visual da panela atualizado apenas por estado autorizado no servidor.
function World.updatePot(player: Player, index: number, slot: any, now: number)
	local base = MapService.getBaseOf(player)
	if not base then return end
	local extras = base.model:FindFirstChild("V2BaseExtras")
	local pot = extras and extras:FindFirstChild(if index == 1 then "PANELA A" else "PANELA B")
	local soup = pot and pot:FindFirstChild("Soup")
	if not soup or not soup:IsA("BasePart") then return end
	local oldState = soup:GetAttribute("PotState")
	local ready = CookRules.isReady(slot, now)
	local remaining = CookRules.remainingSeconds(slot, now)
	local invalidTime = slot.state == "cooking" and remaining == nil
	local invalidState = slot.state ~= "cooking" and slot.state ~= "empty" and slot.state ~= "ready"
	local state = if invalidTime or invalidState then "invalid" elseif ready then "ready"
		elseif slot.state == "cooking" then "cooking" else "empty"
	if oldState ~= state then
		soup:SetAttribute("PotState", state)
		soup.Color = if state == "ready" then C.gold elseif state == "cooking"
			then Color3.fromRGB(236, 146, 75) else C.rock
		local bubbles = soup:FindFirstChild("CookBubbles")
		if bubbles and bubbles:IsA("ParticleEmitter") then
			bubbles.Rate = if state == "cooking" then 2 else 0
		end
		local light = soup:FindFirstChild("ReadyGlow")
		if light and light:IsA("PointLight") then
			light.Brightness = if state == "ready" then 0.8 else 0
		end
		if state == "ready" and oldState == "cooking" then
			local bell = soup:FindFirstChild("ReadyBell")
			if bell and bell:IsA("Sound") then bell:Play() end
		end
	end
	local info = soup:FindFirstChild("PotIndicator")
	info = info and info:FindFirstChild("Text")
	if info and info:IsA("TextLabel") then
		if state == "cooking" then
			info.Text = ("COZINHANDO %ds"):format(remaining or 0)
		else
			info.Text = if state == "ready" then "PRONTO!"
				elseif state == "invalid" then "VERIFICAR JOB" else "VAZIA"
		end
	end
end

function World.init()
	if not Features.on("RebuildV2") then return end
	local old = workspace:FindFirstChild("V2BanquetRun")
	if old then old:Destroy() end
	World.SpawnPoints = {}
	local root = Instance.new("Folder")
	root.Name = "V2BanquetRun"
	root.Parent = workspace
	-- A ilha existente tem bases em raio 320; anexar a pista alem da praia sem remover construcoes.
	-- Ponte leste x=390..490; pista x=480..730, z=+-35, top Y=7.5.
	part(root, "ArrivalBridge", Vector3.new(115, 4, 22), CFrame.new(442.5, 5.5, 0), C.rock, Enum.Material.Slate)
	part(root, "TrackFoundation", Vector3.new(260, 6, 74), CFrame.new(610, 4.5, 0), C.border, Enum.Material.Slate)
	part(root, "RaceFloor", Vector3.new(252, 1.5, 62), CFrame.new(610, 8.25, 0), C.track)
	for _, z in { -34, 34 } do
		part(root, "SafetyBarrier", Vector3.new(255, 7, 2.5), CFrame.new(610, 11, z), C.border)
		for x = 490, 730, 24 do
			part(root, "GoldRivet", Vector3.new(2.2, 1.3, 3), CFrame.new(x, 15, z), C.gold, Enum.Material.Metal)
		end
	end
	for x = 496, 720, 28 do
		local stripe = part(root, "RouteStripe", Vector3.new(8, 0.18, 0.7), CFrame.new(x, 9.11, 0), C.cream, Enum.Material.SmoothPlastic, false)
		stripe.Transparency = 0.12
	end
	part(root, "StartingArchLeft", Vector3.new(3.5, 27, 3.5), CFrame.new(496, 22, -28), C.wood)
	part(root, "StartingArchRight", Vector3.new(3.5, 27, 3.5), CFrame.new(496, 22, 28), C.wood)
	part(root, "StartingArchTop", Vector3.new(3.5, 3.5, 60), CFrame.new(496, 35, 0), C.gold)
	local welcome = part(root, "TrackSign", Vector3.new(4, 10, 28), CFrame.new(496, 31, 0), C.border)
	welcome.CanCollide = false
	sign(root, welcome, "PISTA DO BANQUETE", Vector3.new(0, 3.5, 0))
	local spawns = {
		{ x=527, z=-16, itemId="apple", kind="ready_food", weight="light", respawn=9 },
		{ x=529, z=16, itemId="bread", kind="ready_food", weight="light", respawn=9 },
		{ x=556, z=-13, itemId="cheese", kind="ingredient", weight="light", respawn=12 },
		{ x=564, z=15, itemId="potato", kind="ingredient", weight="light", respawn=12 },
		{ x=595, z=-16, itemId="meat", kind="ingredient", weight="medium", respawn=16 },
		{ x=610, z=18, itemId="honey", kind="ingredient", weight="light", respawn=20 },
		{ x=650, z=-16, itemId="pepper_rare", kind="ingredient", weight="medium", respawn=28 },
		{ x=668, z=14, itemId="colossal_fruit", kind="ingredient", weight="heavy", respawn=35 },
		{ x=714, z=0, itemId="spicy_meat", kind="recipe_scroll", recipeId="spicy_meat", weight="heavy", respawn=65 },
	}
	for i, entry in spawns do
		local station = pillar(root, "CargoStation" .. i, 10, 1.4, CFrame.new(entry.x, 10, entry.z), if entry.kind=="recipe_scroll" then C.gold else C.wood)
		station.CanCollide = false
		sign(root, station, if entry.kind == "recipe_scroll" then "PERGAMINHO RARO" else "PEGAR CARGA", Vector3.new(0, 5, 0))
		table.insert(World.SpawnPoints, {
			position = Vector3.new(entry.x, 12, entry.z),
			itemId = entry.itemId,
			kind = entry.kind,
			recipeId = entry.recipeId,
			weight = entry.weight,
			respawn = entry.respawn,
		})
	end
	for _, base in MapService.Bases do
		buildBaseProps(base)
	end
end

return World
