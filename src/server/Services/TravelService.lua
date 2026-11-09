--!strict
-- TravelService — VIAGEM RÁPIDA e TURBO DA PONTE (pedido do usuário, 09/11/2026, itens 1, 5, 6 e 10).
--
-- "O jogador anda demais": em cada ponto importante do mapa há um BLIP, um círculo brilhante no chão
-- com o nome do lugar. Pisou (ou apertou E/X), abre o menu VIAGEM RÁPIDA com os outros lugares; o
-- jogador escolhe e vai na hora. Lugares: praça, a própria base, arena, ninho, Ilha do Dragão (pé da
-- ponte e topo) e Gigante Ancestral (quando ligado).
--
-- Regras (todas no servidor):
--   * só viaja quem está em cima/perto de um blip (Touched e prompt não são confiáveis: Guard);
--   * não viaja carregando comida roubada ou drop (senão a viagem viraria fuga de disputa);
--   * não viaja nocauteado, nem de dentro do ringue da arena;
--   * espera de 4 s entre viagens.
--
-- Turbo da ponte do Dragão (item 10): em cima da ponte o jogador anda 2,4x mais rápido (setas
-- brilhantes no piso avisam). Fora da ponte volta ao normal. Carregando drop: sem turbo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(game.ReplicatedStorage.Shared.Features)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Guard = require(script.Parent.Parent.Guard)
local World = require(script.Parent.Parent.World)
local MapService = require(script.Parent.MapService)
local CombatService = require(script.Parent.CombatService)
local DropService = require(script.Parent.DropService)
local StealService = require(script.Parent.StealService)
local BossService = require(script.Parent.BossService)

local TravelService = {}

local PAD_REACH = 14 -- distância máxima de um blip para poder viajar (servidor)
local COOLDOWN = 4
local BRIDGE_MULT = 2.4

type Spot = { id: string, name: string, color: Color3, pad: CFrame?, arrive: CFrame?, order: number }

local spots: { [string]: Spot } = {}
local pads: { { pos: Vector3, id: string } } = {}
local lastTravel: { [Player]: number } = {}
local lastMenu: { [Player]: number } = {}
local boosted: { [Player]: number } = {} -- jogador -> WalkSpeed original

local function polar(phiDeg: number, r: number, y: number): Vector3
	local phi = math.rad(phiDeg)
	return Vector3.new(math.sin(phi) * r, y, -math.cos(phi) * r)
end

-- Chão sob um ponto (ignora jogadores e o próprio blip).
local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local folder = Workspace:FindFirstChild("TravelPads")
	if folder then
		table.insert(ignore, folder)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else pos
end

local function facing(pos: Vector3, toward: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
end

local function defineSpots()
	-- Praça: ao lado do ponto de nascimento (r 70, φ 0), sem ficar em cima dele.
	local plaza = groundAt(polar(330, 78, 2))
	spots.plaza = {
		id = "plaza",
		name = "PRAÇA",
		color = Color3.fromRGB(255, 200, 80),
		pad = facing(plaza, Vector3.zero),
		arrive = facing(plaza + Vector3.new(0, 4, 0), Vector3.zero) * CFrame.new(0, 0, -8),
		order = 1,
	}
	-- Arena: na frente do portão (o portão olha para a praça).
	local A = World.Arena
	local gate = CFrame.lookAt(A.center, Vector3.zero) * CFrame.new(10, 0, -(A.outerR + 9))
	local gatePos = groundAt(gate.Position)
	spots.arena = {
		id = "arena",
		name = "ARENA",
		color = Color3.fromRGB(230, 70, 70),
		pad = facing(gatePos, A.center),
		arrive = facing(gatePos + Vector3.new(-10, 4, 0), A.center),
		order = 3,
	}
	-- Ninho (centro da praça, φ 270°): o blip fica entre o ninho e o caldeirão.
	local nest = groundAt(polar(270, 42, 2))
	spots.nest = {
		id = "nest",
		name = "NINHO",
		color = Color3.fromRGB(255, 150, 210),
		pad = facing(nest, Vector3.zero),
		arrive = facing(nest + Vector3.new(0, 4, 0), polar(270, 64, 2)) * CFrame.new(0, 0, 6),
		order = 4,
	}
	-- Ilha do Dragão: pé da ponte e o topo da ilha (chegada na beira, olhando o centro).
	local I = World.BossIsland
	local foot = groundAt(polar(I.phi, I.bridgeFrom - 14, 0))
	local topPos = polar(I.phi, I.r - I.radius + 10, I.top + 4)
	spots.dragon = {
		id = "dragon",
		name = "ILHA DO DRAGÃO",
		color = Color3.fromRGB(255, 110, 40),
		pad = facing(foot, Vector3.zero),
		arrive = facing(topPos, I.center),
		order = 5,
	}
	-- Gigante Ancestral (só se ligado): na frente do golem, a 70 studs dele.
	if Features.on("Ancestral") then
		local An = GameRules.Ancestral
		local rad = math.rad(An.Angle)
		local golem = Vector3.new(math.cos(rad) * An.Radius, 0, math.sin(rad) * An.Radius)
		local front = groundAt(golem * ((An.Radius - 70) / An.Radius))
		spots.ancestral = {
			id = "ancestral",
			name = "GIGANTE ANCESTRAL",
			color = Color3.fromRGB(150, 220, 120),
			pad = facing(front, golem),
			arrive = facing(front + Vector3.new(0, 4, 0), golem) * CFrame.new(6, 0, 0),
			order = 6,
		}
	end
end

-- Chegada na própria base (é por jogador; o blip de cada base leva para os lugares comuns).
local function baseArrive(player: Player): CFrame?
	local base = MapService.getBaseOf(player)
	return if base then base.origin * CFrame.new(0, 6, 20) else nil
end

---------------------------------------------------------------------------
-- Blip: círculo brilhante no chão + anel girando + nome flutuante + prompt
---------------------------------------------------------------------------
local function buildPad(folder: Instance, cf: CFrame, title: string, color: Color3, id: string)
	local model = Instance.new("Model")
	model.Name = "Blip_" .. id
	local disc = Util.makePart({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 11, 11),
		CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CastShadow = false,
	})
	disc.CanTouch = true
	disc.Parent = model
	local ring = Util.makePart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 14, 14),
		CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
	ring.Parent = model
	-- coluna de luz bem fraca: dá para ver o blip de longe
	local beam = Util.makePart({
		Name = "Glow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 3, 3),
		CFrame = CFrame.new(cf.Position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
	beam.Parent = model
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = disc
	local label =
		Util.makeBillboard(disc, "✦ " .. title .. " ✦", UDim2.fromOffset(220, 44), Vector3.new(0, 7, 0), color)
	label.TextScaled = true
	local bb = label.Parent
	if bb and bb:IsA("BillboardGui") then
		bb.MaxDistance = 220
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Travel"
	prompt.ActionText = "VIAGEM RÁPIDA"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = disc
	local function open(player: Player)
		local now = os.clock()
		if now - (lastMenu[player] or 0) < 2 then
			return
		end
		lastMenu[player] = now
		TravelService.openMenu(player, id)
	end
	prompt.Triggered:Connect(open)
	disc.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player then
			open(player)
		end
	end)
	model:SetAttribute("SpotId", id)
	model.Parent = folder
	table.insert(pads, { pos = cf.Position, id = id })
	return model
end

-- Setas brilhantes no piso da ponte do Dragão (avisam o turbo).
local function buildBridgeArrows(folder: Instance)
	local I = World.BossIsland
	local dir = polar(I.phi, 1, 0)
	local steps = 7
	for i = 1, steps do
		local r = I.bridgeFrom + (I.bridgeTo - I.bridgeFrom) * (i - 0.5) / steps
		local t = (r - I.bridgeFrom) / (I.bridgeTo - I.bridgeFrom)
		local pos = dir * r + Vector3.new(0, I.top * t, 0)
		local g = groundAt(pos + Vector3.new(0, 6, 0))
		local cf = CFrame.lookAt(g + Vector3.new(0, 0.15, 0), g + dir * 10 + Vector3.new(0, 0.15, 0))
		for _, side in { -1, 1 } do
			local bar = Util.makePart({
				Name = "TurboArrow",
				Size = Vector3.new(0.6, 0.2, 5),
				CFrame = cf * CFrame.new(side * 1.6, 0, 0) * CFrame.Angles(0, math.rad(side * 35), 0),
				Color = Color3.fromRGB(80, 200, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
			})
			bar.Parent = folder
		end
	end
end

---------------------------------------------------------------------------
-- Menu e viagem
---------------------------------------------------------------------------
local function nearPad(player: Player): boolean
	local char = player.Character
	-- fwjelaa-ignore: findfirstchild-chain (conferido logo abaixo)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, p in pads do
		local d = root.Position - p.pos
		if Vector3.new(d.X, 0, d.Z).Magnitude <= PAD_REACH and math.abs(d.Y) < 14 then
			return true
		end
	end
	return false
end

function TravelService.openMenu(player: Player, fromId: string)
	local list = {}
	if MapService.getBaseOf(player) and fromId ~= "base" then
		table.insert(list, { id = "base", name = "MINHA BASE", color = Color3.fromRGB(110, 200, 255), order = 2 })
	end
	for id, s in spots do
		if id ~= fromId then
			table.insert(list, { id = id, name = s.name, color = s.color, order = s.order })
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	Remotes.TravelMenu:FireClient(player, { from = fromId, spots = list })
end

local function inArenaRing(root: BasePart): boolean
	local c = World.Arena.center
	local flat = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude
	return flat < World.Arena.floorR + 2 and root.Position.Y < World.Arena.floorTop + 12
end

local function travel(player: Player, id: string, invite: boolean?)
	local char = player.Character
	-- fwjelaa-ignore: findfirstchild-chain (conferido logo abaixo)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root then
		return
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < COOLDOWN then
		return
	end
	-- Convite do Dragão (botão JOGAR): vale de qualquer lugar, mas só enquanto o Dragão está vivo.
	if invite then
		if id ~= "dragon" or not BossService.center() then
			return
		end
	elseif not nearPad(player) then
		return -- longe de qualquer blip: pedido falso
	end
	if StealService.isCarrying(player) or DropService.isCarrying(player) then
		Remotes.Notify:FireClient(player, {
			text = "Entregue o que está carregando antes de viajar!",
			color = Color3.fromRGB(255, 150, 80),
		})
		return
	end
	if CombatService.isKO(player) or inArenaRing(root) then
		return
	end
	local dest: CFrame? = nil
	if id == "base" then
		dest = baseArrive(player)
	else
		local s = spots[id]
		dest = s and s.arrive
	end
	if not dest then
		return
	end
	lastTravel[player] = now
	Remotes.TravelDone:FireClient(player, { id = id })
	task.wait(0.25) -- o cliente escurece a tela; a troca acontece no escuro
	if char.Parent then
		char:PivotTo(dest)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

---------------------------------------------------------------------------
-- Turbo na ponte do Dragão
---------------------------------------------------------------------------
local function onBridge(pos: Vector3): boolean
	local I = World.BossIsland
	local dir = polar(I.phi, 1, 0)
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local along = flat:Dot(dir)
	if along < I.bridgeFrom - 6 or along > I.bridgeTo + 4 then
		return false
	end
	local side = (flat - dir * along).Magnitude
	return side <= I.bridgeW / 2 + 3
end

local function bridgeTick()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- fwjelaa-ignore: findfirstchild-chain (conferido logo abaixo)
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root then
			boosted[player] = nil
			continue
		end
		local want = onBridge(root.Position)
			and not DropService.isCarrying(player)
			and not StealService.isCarrying(player)
		local saved = boosted[player]
		if want and not saved and hum.WalkSpeed > 0 then
			boosted[player] = hum.WalkSpeed
			hum.WalkSpeed = hum.WalkSpeed * BRIDGE_MULT
			Remotes.TravelDone:FireClient(player, { turbo = true })
		elseif not want and saved then
			boosted[player] = nil
			-- só devolve se ninguém mexeu na velocidade enquanto isso (arena congelou, carregou drop...)
			if math.abs(hum.WalkSpeed - saved * BRIDGE_MULT) < 0.01 then
				hum.WalkSpeed = saved
			end
		end
	end
end

function TravelService.init()
	Remotes.RequestTravel.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" and #id <= 20 and Guard.allow(player, "Travel") then
			travel(player, id)
		end
	end)
	Remotes.RequestBossJoin.OnServerEvent:Connect(function(player)
		if Guard.allow(player, "Travel") then
			travel(player, "dragon", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
		lastMenu[player] = nil
		boosted[player] = nil
	end)
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 60)
		if not map then
			return
		end
		task.wait(2) -- o mapa e o ninho já estão no lugar (o raio do chão acerta o piso certo)
		defineSpots()
		local folder = Instance.new("Folder")
		folder.Name = "TravelPads"
		folder.Parent = Workspace
		for id, s in spots do
			if s.pad then
				buildPad(folder, s.pad, s.name, s.color, id)
			end
		end
		-- um blip em cada base (leva aos lugares comuns; "MINHA BASE" aparece nos outros blips)
		for _, base in MapService.Bases do
			local g = groundAt((base.origin * CFrame.new(12, 0, 22)).Position)
			buildPad(folder, CFrame.new(g), "VIAGEM", Color3.fromRGB(110, 200, 255), "base")
		end
		buildBridgeArrows(folder)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			bridgeTick()
		end
	end)
end

return TravelService
