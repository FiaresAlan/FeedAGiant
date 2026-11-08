--!strict
-- World.lua — o cenário do jogo (Fase 1, estilo cartoon pintado / guia "simulator" do make-map).
-- Gerado por código a cada início de servidor, com semente fixa (mesmo mapa sempre).
--
-- Contrato com o resto do jogo (NÃO mudar sem conferir os serviços):
--   * filhos diretos de Workspace.Map: ShopPad (HUD), EventPad (EventService),
--     Leaderboard1..3 com SurfaceGui > List (LeaderboardService);
--   * chão das bases em y 0..2 (MapService), praça interna com topo em y = 2,
--     faixa de drops r 35..94 livre de obstáculos (DropService: r 35..80 + raio 14).
--
-- Kit: MapKit do fwjelaa (FWJ STUDIOS), vendorizado em ServerScriptService.fwjelaa.MapKit.
-- Paleta e métricas: make-map/styles/simulator.md. Notas do vault: Stylized Lighting Recipes,
-- Art Budgets - Triangles Draw Calls Memory (orçamento < 10k peças).

local Config = require(game.ReplicatedStorage.Shared.Config)

local MapKit = game:GetService("ServerScriptService"):WaitForChild("fwjelaa"):WaitForChild("MapKit")
local Build = require(MapKit:WaitForChild("Build")) :: any
local Props = require(MapKit:WaitForChild("Props")) :: any
local Scatter = require(MapKit:WaitForChild("Scatter")) :: any
local CreatureAssets = require(game.ReplicatedStorage.Shared.CreatureAssets)
local InsertService = game:GetService("InsertService")

-- Caldeirão 3D do usuário (assets/optimized/cauldron.glb, enviado na Fase 2). nil se não houver ID
-- ou se o carregamento falhar: aí fica o caldeirão de primitivas.
local function loadCauldronMesh(): Model?
	local id = CreatureAssets["cauldron"]
	local numeric = id and tonumber(string.match(id, "%d+"))
	if not numeric then
		return nil
	end
	local ok, loaded = pcall(function()
		return InsertService:LoadAsset(numeric)
	end)
	if not ok or not loaded then
		warn("[World] caldeirão 3D não carregou:", loaded)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "CauldronMesh"
	for _, child in (loaded :: Instance):GetChildren() do
		child.Parent = model
	end
	(loaded :: Instance):Destroy()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true -- é o corpo do marco: ninguém atravessa
			d.CanTouch = false
		end
	end
	return model
end

local World = {}

local hex = Color3.fromHex

-- Paleta (cores oficiais BrickColor do guia simulator, zona Meadow/spawn)
World.Palette = {
	grass = "#7FA34E", -- fim de tarde: verde-amarelado e menos saturado (era #5B9A4C)
	grassDark = "#6A8F45",
	sand = "#F0D5A0",
	sandDark = "#D7C59A",
	path = "#D7C59A",
	pathEdge = "#B9A07A",
	plaza = "#DCC08A",
	plazaRing = "#C9A46A",
	stone = "#A9A8AB",
	stoneDark = "#635F62",
	wood = "#694028",
	woodLight = "#CC8E69",
	water = "#0D69AC",
	white = "#F8F8F8",
}

-- Uma cor-tema por base (todas saturadas, distintas em tons de cinza duas a duas vizinhas)
World.BaseThemes = {
	{ name = "Azul", color = "#0D69AC", light = "#80BBDB" },
	{ name = "Vermelho", color = "#C4281C", light = "#FF9F9F" },
	{ name = "Amarelo", color = "#F5CD30", light = "#FFF2A6" },
	{ name = "Roxo", color = "#8C5B9F", light = "#C9B3E8" },
	{ name = "Turquesa", color = "#12A8A8", light = "#9FE8E0" },
	{ name = "Rosa", color = "#FF66CC", light = "#FFC9EC" },
	{ name = "Laranja", color = "#DA8541", light = "#FFCF9E" },
	{ name = "Verde", color = "#287F47", light = "#A8DDA0" },
}

-- Medidas (studs). Chão da ilha: topo em y = 0.
local ISLAND_R = 470
local BEACH_W = 26
local PLAZA_INNER_R = 120 -- topo y = 2 (drops, loja, evento)
local PLAZA_OUTER_R = 138 -- degrau com topo y = 1
local PATH_W = 14
local SEED = 2026
-- Marco: escala 1,7 (~130 studs com pedestal e vapor). Raio da fogueira = 17 * escala ≈ 29 studs;
-- a faixa de drops começa em r 50 (DropService) com círculo de raio 14 → livre a partir de r 36.
local CAULDRON_SCALE = 1.7

-- φ = ângulo a partir do norte (-Z), no sentido horário (para o leste, +X)
local function polar(phiDeg: number, r: number, y: number): Vector3
	local phi = math.rad(phiDeg)
	return Vector3.new(math.sin(phi) * r, y, -math.cos(phi) * r)
end

local function facingCenter(pos: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

-- Disco horizontal (cilindro de Part, eixo em X) com topo em `top`.
-- Cilindros grandes ficam facetados (polígono visível na borda): com `copies` > 1, cópias
-- giradas em volta do eixo vertical preenchem os cantos e a borda fica quase redonda.
local function disc(
	name: string,
	radius: number,
	top: number,
	thickness: number,
	color: string,
	parent: Instance,
	copies: number?,
	material: Enum.Material?
): Part
	local n = copies or 1
	local first: Part? = nil
	for i = 0, n - 1 do
		local p = Build.part({
			Name = if i == 0 then name else name .. "_Fill" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(thickness, radius * 2, radius * 2),
			CFrame = CFrame.new(0, top - thickness / 2, 0)
				* CFrame.Angles(0, i * math.rad(360 / 24) / n, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = hex(color),
			Material = material or Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
		p.Parent = parent
		first = first or p
	end
	return first :: Part
end

---------------------------------------------------------------------------
-- Ilha, praia e mar
---------------------------------------------------------------------------
function World.buildGround(root: Instance)
	local P = World.Palette
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	-- Materiais com textura do Roblox (sem upload): pedido do usuário de chão natural, não liso.
	disc("Island", ISLAND_R, 0, 10, P.grass, ground, 4, Enum.Material.Grass)
	disc("Beach", ISLAND_R + BEACH_W, -0.6, 10, P.sand, ground, 4, Enum.Material.Sand)
	-- Mar só de peça (sem água de terreno). Medido na Fase 1: a água de terreno em 1.400 studs
	-- custava ~290 mil triângulos por vista (mais da metade do orçamento de celular).
	-- Faixa clara rasa perto da praia + mar azul até o horizonte (estilo cartoon).
	disc("Shallows", ISLAND_R + BEACH_W + 70, -2.2, 1, "#4FA3E0", ground, 4)
	local sea = Build.decor(Build.part({
		Name = "FarSea",
		Size = Vector3.new(8000, 1, 8000),
		CFrame = CFrame.new(0, -2.8, 0),
		Color = hex(P.water),
		Reflectance = 0.1,
		CastShadow = false,
	}))
	sea.Parent = ground
	ground.Parent = root
end

---------------------------------------------------------------------------
-- Marco: o Caldeirão do Banquete (centro da praça, ~120 studs com o vapor)
---------------------------------------------------------------------------
local function buildCauldron(parent: Instance)
	local P = World.Palette
	local m = Instance.new("Model")
	m.Name = "BanquetCauldron"
	-- Marco sempre carregado no cliente se o StreamingEnabled for ligado (hoje está desligado).
	-- Vault "Instance Streaming": Persistent só para poucos itens essenciais; este é o único.
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local S = CAULDRON_SCALE
	local function cyl(name: string, d: number, h: number, cf: CFrame, color: string, decor: boolean?): Part
		local p = Build.part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, d, d),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
			Color = hex(color),
		})
		if decor then
			Build.decor(p)
		end
		p.Parent = m
		return p
	end
	local function ballp(name: string, d: number, pos: Vector3, color: string): Part
		local p = Build.decor(Build.part({
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			CFrame = CFrame.new(pos),
			Color = hex(color),
		}))
		p.Parent = m
		return p
	end
	-- Pedestal de pedra em degraus (eleva o marco acima das placas e da praça; raio ≤ 29)
	local plinthTop = 2
	local steps: { { r: number, h: number, color: string } } = {
		{ r = 29, h = 3, color = P.stone },
		{ r = 26, h = 3, color = "#BDBCBF" },
		{ r = 23, h = 3, color = P.stone },
	}
	for i, step in steps do
		cyl("Plinth" .. i, step.r * 2, step.h, CFrame.new(0, plinthTop + step.h / 2, 0), step.color).Material =
			Enum.Material.Slate
		plinthTop += step.h
	end
	-- Quatro bandeiras altas nas diagonais, com as cores das bases (leem de longe).
	-- Mastros saem do piso da praça em r 34: fora do caldeirão (raio ~32) e antes da faixa
	-- de drops (círculos a partir de r 36).
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local poleBase = Vector3.new(math.cos(a) * 34, 2, math.sin(a) * 34)
		local pole = Build.part({
			Name = "FlagPole",
			Size = Vector3.new(1.4, 64, 1.4),
			CFrame = CFrame.new(poleBase + Vector3.new(0, 32, 0)),
			Color = hex(P.white),
		})
		pole.Parent = m
		local theme = World.BaseThemes[k * 2 + 1]
		local flag = Build.decor(Build.part({
			Name = "Flag",
			Size = Vector3.new(0.4, 9, 15),
			-- bandeira para fora (lado oposto ao caldeirão)
			CFrame = CFrame.lookAt(poleBase + Vector3.new(0, 58, 0), poleBase * 2 + Vector3.new(0, 58, 0))
				* CFrame.new(0, 0, -7.5),
			Color = hex(theme.color),
		}))
		flag.Parent = m
		ballp("PoleTop", 2.6, poleBase + Vector3.new(0, 64.5, 0), "#F5CD30")
	end
	local floor = plinthTop -- topo do pedestal
	-- Fogueira de pedra (raio máximo = CAULDRON_RADIUS: a faixa de drops começa depois dele)
	cyl("Hearth", 34 * S, 4 * S, CFrame.new(0, floor + 2 * S, 0), P.stone).Material = Enum.Material.Slate
	local hearthTopPart = cyl("HearthTop", 30 * S, 0.6, CFrame.new(0, floor + 4 * S + 0.3, 0), P.stoneDark, true)
	-- Uma única luz quente no fogo (sem sombra: barata no celular)
	local glow = Instance.new("PointLight")
	glow.Color = hex("#FF9A3C")
	glow.Range = 40
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = hearthTopPart
	local hearthTop = floor + 4 * S
	for i = 0, 3 do
		local log = Build.decor(Build.part({
			Name = "Log",
			Size = Vector3.new(26 * S, 2.2 * S, 2.2 * S),
			CFrame = CFrame.new(0, hearthTop + 1.6 * S, 0) * CFrame.Angles(0, i * math.pi / 4, 0),
			Color = hex(P.wood),
		}))
		log.Parent = m
	end
	for i = 0, 5 do
		local pos = Vector3.new(math.cos(i) * 9 * S, hearthTop + 3.5 * S, math.sin(i) * 9 * S)
		local flame = ballp("Flame", 4.5 * S, pos, if i % 2 == 0 then "#FFB000" else "#FF8C1A")
		flame.Material = Enum.Material.Neon -- fogo = "lava" no guia simulator: o Neon passa do limiar do Bloom
	end
	-- Pernas e corpo: cobre quente (claro o bastante para ler de longe e no celular)
	local bodyBottom = hearthTop + 4 * S
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local leg = Build.part({
			Name = "Leg",
			Size = Vector3.new(3 * S, 8 * S, 3 * S),
			CFrame = CFrame.new(math.cos(a) * 13 * S, hearthTop + 2 * S, math.sin(a) * 13 * S),
			Color = hex("#7A4B2A"),
		})
		leg.Parent = m
	end
	local potH = 26 * S
	cyl("Pot", 38 * S, potH, CFrame.new(0, bodyBottom + potH / 2, 0), "#B87333")
	cyl("PotBand", 39 * S, 2.4 * S, CFrame.new(0, bodyBottom + potH * 0.25, 0), "#8A5A2B", true)
	cyl("PotBand2", 39 * S, 2.4 * S, CFrame.new(0, bodyBottom + potH * 0.7, 0), "#8A5A2B", true)
	cyl("Rim", 42 * S, 3 * S, CFrame.new(0, bodyBottom + potH + 0.5 * S, 0), "#E0A060")
	-- Alças
	for _, side in { -1, 1 } do
		local handle = Build.decor(Build.part({
			Name = "Handle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2 * S, 12 * S, 12 * S),
			CFrame = CFrame.new(side * 20 * S, bodyBottom + potH * 0.75, 0),
			Color = hex("#8A5A2B"),
		}))
		handle.Parent = m
	end
	-- Sopa
	local soupTop = bodyBottom + potH + 1.6 * S
	local soupD = 36 * S
	-- Fase 2: com o caldeirão 3D do usuário, ele substitui pernas, corpo, faixas, borda e alças;
	-- a largura fica igual à do caldeirão de primitivas (38 * S) e a base apoia na fogueira.
	local meshPot = loadCauldronMesh()
	if meshPot then
		local _, size0 = meshPot:GetBoundingBox()
		meshPot:ScaleTo(meshPot:GetScale() * (38 * S) / math.max(size0.X, size0.Z))
		local cf, size = meshPot:GetBoundingBox()
		local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
		local offset = meshPot:GetPivot():ToObjectSpace(bottom)
		meshPot:PivotTo(CFrame.new(0, hearthTop, 0) * offset:Inverse())
		meshPot.Parent = m
		for _, name in { "Leg", "Pot", "PotBand", "PotBand2", "Rim", "Handle" } do
			for _, part in m:GetChildren() do
				if part.Name == name and part:IsA("BasePart") then
					part:Destroy()
				end
			end
		end
		soupTop = hearthTop + size.Y - 2.5
		soupD = math.max(size.X, size.Z) * 0.72
	end
	cyl("Soup", soupD, 1, CFrame.new(0, soupTop - 0.5, 0), "#FF8C1A", true)
	local rng = Random.new(SEED)
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, 14) * S
		ballp("Bubble", rng:NextNumber(1.6, 3.2) * S, Vector3.new(math.cos(a) * r, soupTop, math.sin(a) * r), "#FFB347")
	end
	-- Comidas gigantes saindo da sopa
	local function drumstick(cf: CFrame)
		local bone = Build.decor(Build.part({
			Name = "Bone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14 * S, 2.2 * S, 2.2 * S),
			CFrame = cf,
			Color = hex(P.white),
		}))
		bone.Parent = m
		ballp("BoneEnd", 3.6 * S, (cf * CFrame.new(7 * S, 0, 0)).Position, P.white)
		ballp("Meat", 10 * S, (cf * CFrame.new(-5 * S, 0, 0)).Position, "#A0522D")
		ballp("Meat2", 8 * S, (cf * CFrame.new(-8 * S, 0.5 * S, 0)).Position, "#B5652E")
	end
	drumstick(CFrame.new(7 * S, soupTop + 4 * S, -4 * S) * CFrame.Angles(0, math.rad(30), math.rad(40)))
	local carrotBase = CFrame.new(-8 * S, soupTop + 2 * S, 5 * S) * CFrame.Angles(math.rad(-25), 0, math.rad(-20))
	for i = 0, 4 do
		ballp("Carrot", (6.5 - i * 1.1) * S, (carrotBase * CFrame.new(0, i * 2.4 * S, 0)).Position, "#FF8C00")
	end
	for i = -1, 1 do
		local leaf = Build.decor(Build.part({
			Name = "CarrotLeaf",
			Size = Vector3.new(0.8 * S, 6 * S, 2 * S),
			CFrame = carrotBase * CFrame.new(i * 1.2 * S, -3 * S, 0) * CFrame.Angles(0, 0, math.rad(i * 25)),
			Color = hex("#348E40"),
		}))
		leaf.Parent = m
	end
	local ladle = Build.decor(Build.part({
		Name = "LadleHandle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(34 * S, 1.8 * S, 1.8 * S),
		CFrame = CFrame.new(10 * S, soupTop + 9 * S, 10 * S) * CFrame.Angles(0, math.rad(-45), math.rad(60)),
		Color = hex(P.woodLight),
	}))
	ladle.Parent = m
	-- Vapor: nuvens subindo (decorativas, sem sombra)
	for i, h in { 10, 20, 31 } do
		local cloud = Props.cloud(
			CFrame.new((i - 2) * 3 * S, soupTop + h * S, (i % 2) * 4 * S) * CFrame.Angles(0, i * 1.1, 0),
			{ rng = Random.new(SEED + i), scale = (0.9 + i * 0.2) * S }
		)
		for _, p in cloud:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0.1 + i * 0.12
			end
		end
		cloud.Parent = m
	end
	m.Parent = parent
end

---------------------------------------------------------------------------
-- Praça central: loja, evento, placares, spawn, canteiros
---------------------------------------------------------------------------
local function leaderboard(index: number, title: string, phi: number, parent: Instance)
	local pos = polar(phi, 128, 0)
	local cf = facingCenter(pos)
	local board = Build.part({
		Name = "Leaderboard" .. index,
		Size = Vector3.new(18, 22, 1.5),
		CFrame = cf * CFrame.new(0, 15, 0),
		Color = hex("#5A3A22"), -- madeira escura: combina com barraca e mesas; texto claro contrasta
	})
	-- Moldura e pés
	for _, x in { -9.5, 9.5 } do
		local post = Build.part({
			Name = "Post",
			Size = Vector3.new(1.6, 27, 1.6),
			CFrame = cf * CFrame.new(x, 13.5, 0),
			Color = hex("#F5CD30"),
		})
		post.Parent = board
	end
	local top = Build.part({
		Name = "Crown",
		Size = Vector3.new(21, 2, 2),
		CFrame = cf * CFrame.new(0, 27, 0),
		Color = hex("#F5CD30"),
	})
	top.Parent = board
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
	t.TextColor3 = hex("#F5CD30")
	t.Parent = sg
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.04, 0.14)
	list.Size = UDim2.fromScale(0.92, 0.84)
	list.BackgroundTransparency = 1
	list.Text = "Carregando..."
	list.TextScaled = true
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.Font = Enum.Font.GothamBold
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Parent = sg
	board.Parent = parent
end

function World.buildHub(root: Instance): Part
	local P = World.Palette
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	disc("PlazaOuter", PLAZA_OUTER_R, 1, 3, P.sandDark, hub, 3, Enum.Material.Pavement)
	disc("PlazaInner", PLAZA_INNER_R, 2, 3, P.plaza, hub, nil, Enum.Material.Pavement)
	disc("PlazaRing", PLAZA_INNER_R - 22, 2.05, 0.2, P.plazaRing, hub) -- anel de desenho no piso
	disc("PlazaCore", PLAZA_INNER_R - 25, 2.1, 0.2, P.plaza, hub, nil, Enum.Material.Pavement)
	buildCauldron(hub)
	-- Faixas no piso: continuam cada caminho até o caldeirão (linhas-guia; só decoração)
	for k = 0, 7 do
		local phi = k * 45
		local r0, r1 = 36, PLAZA_INNER_R
		local mid = polar(phi, (r0 + r1) / 2, 2.12)
		local stripe = Build.decor(Build.part({
			Name = "FloorStripe",
			Size = Vector3.new(10, 0.25, r1 - r0),
			CFrame = facingCenter(mid),
			Color = hex(P.plazaRing),
			CastShadow = false,
		}))
		stripe.Parent = hub
	end

	-- Loja (norte): barraca virada para o centro + plataforma de entrada (Neon: interação)
	local shopPos = polar(0, 104, 2)
	local shopCf = facingCenter(shopPos)
	local stall = Props.stall(shopCf * CFrame.new(0, 0, 6), { text = "LOJA", width = 22, color = "#FF5959" })
	stall.Parent = hub
	local shopPad = Build.part({
		Name = "ShopPad",
		Size = Vector3.new(18, 1, 12),
		CFrame = shopCf * CFrame.new(0, 0.5, -4),
		Color = hex("#FF8C1A"),
		Material = Enum.Material.Neon,
	})

	-- Evento (sul): pedestal redondo com aro
	local eventPos = polar(180, 104, 2)
	local eventPad = Build.part({
		Name = "EventPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 26, 26),
		CFrame = CFrame.new(eventPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex("#F5CD30"),
		Material = Enum.Material.Neon,
	})
	local eventRim = Build.decor(Build.part({
		Name = "EventRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 30, 30),
		CFrame = CFrame.new(eventPos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex("#DA8541"),
	}))
	eventRim.Parent = hub

	-- Placares entre os caminhos (os caminhos chegam nos múltiplos de 45°)
	leaderboard(1, "MAIORES GIGANTES", -22.5, root)
	leaderboard(2, "MAIS REBIRTHS", 22.5, root)
	leaderboard(3, "REIS DA ARENA", 157.5, root)

	-- Canteiros nos outros vãos entre caminhos
	local rng = Random.new(SEED + 7)
	for _, phi in { 67.5, 112.5, 202.5, 247.5, 292.5 } do
		local c = polar(phi, 129, 1)
		local bed = Build.part({
			Name = "Planter",
			Size = Vector3.new(16, 2, 8),
			CFrame = facingCenter(c) * CFrame.new(0, 1, 0),
			Color = hex(P.woodLight),
		})
		bed.Parent = hub
		local soil = Build.decor(Build.part({
			Name = "Soil",
			Size = Vector3.new(14.6, 0.3, 6.6),
			CFrame = facingCenter(c) * CFrame.new(0, 2.05, 0),
			Color = hex("#7C5C46"),
		}))
		soil.Parent = hub
		for i = -2, 2 do
			local f = Props.flower(facingCenter(c) * CFrame.new(i * 2.6, 2.2, rng:NextNumber(-1.5, 1.5)), { rng = rng })
			f.Parent = hub
		end
		local bush = Props.bush(facingCenter(c) * CFrame.new(0, 2.2, 0), { rng = rng, scale = 0.9 })
		bush.Parent = hub
	end

	-- Spawn neutro (todos são levados à própria base em seguida; MapService/Main)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(polar(0, 70, 2.5))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = hex(P.white)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub

	-- Mesas de banquete (tema do jogo) no anel livre entre a faixa de drops (r ≤ 96) e a borda
	local tableRng = Random.new(SEED + 11)
	local foodColors = { "#FF5959", "#F5CD30", "#DA8541", "#A0522D", "#5B9A4C" }
	for _, phi in { 67.5, 112.5, 247.5, 292.5 } do
		local c = facingCenter(polar(phi, 109, 2))
		local top = Build.part({
			Name = "BanquetTable",
			Size = Vector3.new(18, 1, 6),
			CFrame = c * CFrame.new(0, 3.5, 0),
			Color = hex(P.woodLight),
		})
		top.Parent = hub
		local cloth = Build.decor(Build.part({
			Name = "TableCloth",
			Size = Vector3.new(18.4, 0.2, 3),
			CFrame = c * CFrame.new(0, 4.1, 0),
			Color = hex("#FF5959"),
		}))
		cloth.Parent = hub
		for _, x in { -8, 8 } do
			for _, z in { -2.4, 2.4 } do
				local leg = Build.decor(Build.part({
					Name = "TableLeg",
					Size = Vector3.new(0.8, 3, 0.8),
					CFrame = c * CFrame.new(x, 1.5, z),
					Color = hex(P.wood),
				}))
				leg.Parent = hub
			end
		end
		for _, z in { -5, 5 } do
			local bench = Build.part({
				Name = "Bench",
				Size = Vector3.new(16, 0.8, 2),
				CFrame = c * CFrame.new(0, 1.9, z),
				Color = hex(P.wood),
			})
			bench.Parent = hub
		end
		for i = -3, 3 do
			local food = Build.decor(Build.part({
				Name = "TableFood",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * tableRng:NextNumber(1.4, 2.2),
				CFrame = c * CFrame.new(i * 2.3, 4.9, tableRng:NextNumber(-1.2, 1.2)),
				Color = hex(foodColors[tableRng:NextInteger(1, #foodColors)]),
			}))
			food.Parent = hub
		end
	end
	-- Postes de luz dos dois lados de cada entrada de caminho na praça
	for k = 0, 7 do
		for _, side in { -1, 1 } do
			World.lamp(CFrame.new(polar(k * 45 + side * 6.5, PLAZA_OUTER_R - 4, 1)), hub)
		end
	end
	hub.Parent = root
	shopPad.Parent = root
	eventPad.Parent = root
	return shopPad
end

---------------------------------------------------------------------------
-- Caminhos das bases até a praça
---------------------------------------------------------------------------
function World.buildPath(origin: CFrame, parent: Instance)
	local P = World.Palette
	local dir = (Vector3.zero - origin.Position).Unit
	local startR = Config.BaseSize / 2
	local fromPos = origin.Position + dir * startR
	local endPos = dir * PLAZA_OUTER_R * -1
	local len = (endPos - fromPos).Magnitude + 4 -- encosta no degrau da praça
	local mid = fromPos + (endPos - fromPos).Unit * (len / 2 - 2)
	local path = Build.part({
		Name = "Path",
		Size = Vector3.new(PATH_W, 1, len),
		CFrame = CFrame.lookAt(mid, Vector3.new(0, mid.Y, 0)) * CFrame.new(0, 0.5, 0),
		Color = hex(P.path),
		Material = Enum.Material.Cobblestone,
	})
	-- Bordas mais escuras (o caminho precisa ter brilho diferente do chão: guia simulator)
	for _, side in { -1, 1 } do
		local edge = Build.decor(Build.part({
			Name = "PathEdge",
			Size = Vector3.new(1.2, 1.1, len),
			CFrame = CFrame.lookAt(mid, Vector3.new(0, mid.Y, 0)) * CFrame.new(side * (PATH_W / 2 + 0.6), 0.55, 0),
			Color = hex(P.pathEdge),
			Material = Enum.Material.Slate,
		}))
		edge.Parent = path
	end
	path.Parent = parent
	-- Postes ao longo do caminho, alternando os lados, a cada ~45 studs
	local unit = (endPos - fromPos).Unit
	local right = unit:Cross(Vector3.yAxis).Unit
	local total = (endPos - fromPos).Magnitude
	local i = 0
	local d = 30
	while d < total - 20 do
		local side = if i % 2 == 0 then 1 else -1
		World.lamp(CFrame.new(fromPos + unit * d + right * side * (PATH_W / 2 + 3)), parent)
		local bush = Props.bush(
			CFrame.new(fromPos + unit * (d + 8) - right * side * (PATH_W / 2 + 5)),
			{ rng = Random.new(SEED + i + math.floor(d)), color = "#7C9C6B", scale = 1.1 }
		)
		bush.Parent = parent
		d += 45
		i += 1
	end
end

-- Poste de luz estilizado (sem PointLight: de dia não aparece e custaria desempenho no celular)
function World.lamp(cf: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	local post = Build.part({
		Name = "Post",
		Size = Vector3.new(1, 11, 1),
		CFrame = cf * CFrame.new(0, 5.5, 0),
		Color = hex("#694028"),
	})
	post.Parent = m
	local cap = Build.decor(Build.part({
		Name = "Cap",
		Size = Vector3.new(2.4, 0.6, 2.4),
		CFrame = cf * CFrame.new(0, 11.2, 0),
		Color = hex("#4A2C1A"),
	}))
	cap.Parent = m
	local bulb = Build.decor(Build.part({
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = cf * CFrame.new(0, 12.4, 0),
		Color = hex("#FFD27A"),
		Material = Enum.Material.Neon, -- lâmpada acesa: pequena, passa do limiar do Bloom (1,1)
	}))
	bulb.Parent = m
	m.Parent = parent
end

---------------------------------------------------------------------------
-- Natureza espalhada (sementes fixas)
---------------------------------------------------------------------------
function World.buildNature(root: Instance, baseOrigins: { CFrame })
	local nature = Instance.new("Folder")
	nature.Name = "Nature"
	nature.Parent = root
	local exclude: { any } = {
		{ center = Vector2.zero, radius = PLAZA_OUTER_R + 10 },
	}
	for _, o in baseOrigins do
		local p = Vector2.new(o.Position.X, o.Position.Z)
		table.insert(exclude, { center = p, radius = Config.BaseSize * 0.75 + 8 })
		-- Caminho: segmento base→praça, com 6 studs livres de cada lado
		table.insert(exclude, { a = p, b = Vector2.zero, radius = PATH_W / 2 + 6 })
	end
	-- Fase 3: arena e a estrada até ela
	for _, e in World.arenaExclusions() do
		table.insert(exclude, e)
	end
	-- Lagos (água estilizada de peça: barata e no estilo; a água de terreno fica só no mar)
	for i, pond in { { 67.5, 235, 30 }, { 202.5, 240, 34 }, { 292.5, 230, 26 } } do
		local c = polar(pond[1], pond[2], 0)
		local pr = pond[3]
		local rim = Build.part({
			Name = "PondRim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, (pr + 4) * 2, (pr + 4) * 2),
			CFrame = CFrame.new(c + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = hex(World.Palette.sand),
			Material = Enum.Material.Sand,
			CastShadow = false,
		})
		rim.Parent = nature
		local water = Build.part({
			Name = "PondWater",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, pr * 2, pr * 2),
			CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = hex("#4FA3E0"),
			Reflectance = 0.15,
			CastShadow = false,
		})
		water.Parent = nature
		local rng = Random.new(SEED + 50 + i)
		for _ = 1, 5 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, pr - 5)
			local pad = Build.decor(Build.part({
				Name = "LilyPad",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 4, 4),
				CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, 0.45, math.sin(a) * r))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = hex("#348E40"),
			}))
			pad.Parent = nature
		end
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			local rock = Props.rock(
				CFrame.new(c + Vector3.new(math.cos(a) * (pr + 3), 0, math.sin(a) * (pr + 3))),
				{ rng = rng, scale = rng:NextNumber(0.9, 1.4) }
			)
			rock.Parent = nature
		end
		table.insert(exclude, { center = Vector2.new(c.X, c.Z), radius = pr + 7 })
	end
	local box = ISLAND_R - 12
	local common = {
		min = Vector2.new(-box, -box),
		max = Vector2.new(box, box),
		exclude = exclude,
		height = { -0.2, 0.3 }, -- só na grama (topo 0): nunca na praia, praça, bases ou caminhos
		parent = nature,
	}
	local function run(extra: { [string]: any })
		local o = table.clone(common)
		for k, v in extra do
			o[k] = v
		end
		return Scatter.run(o)
	end
	local P = World.Palette
	run({
		seed = SEED + 9,
		spacing = 75,
		clearance = 14,
		make = function(cf: CFrame, rng: Random)
			local r = rng:NextNumber(12, 26)
			local patch = Build.decor(Build.part({
				Name = "GrassPatch",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, r * 2, r * 2),
				CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = hex(if rng:NextNumber() < 0.5 then "#93B55E" else "#6C9146"),
				Material = Enum.Material.Grass,
				CastShadow = false,
			}))
			return patch
		end,
	})
	run({
		seed = SEED + 1,
		clusters = { spacing = 100, radius = 16, per = { 3, 5 }, minDist = 10 },
		clearance = 7,
		make = function(cf: CFrame, rng: Random)
			return Props.tree(cf, { rng = rng, leaf = P.grass, leafDark = "#348E40" })
		end,
	})
	run({
		seed = SEED + 2,
		spacing = 60,
		clearance = 3,
		make = function(cf: CFrame, rng: Random)
			return Props.bush(cf, { rng = rng, color = "#7C9C6B" })
		end,
	})
	run({
		seed = SEED + 3,
		spacing = 140,
		clearance = 5,
		make = function(cf: CFrame, rng: Random)
			return Props.rock(cf, { rng = rng, scale = rng:NextNumber(1.3, 1.9) })
		end,
	})
	run({
		seed = SEED + 4,
		-- orçamento de celular: cada flor tem 6 esferas (medido: vista da natureza passou de 500k triângulos)
		clusters = { spacing = 130, radius = 6, per = { 2, 4 }, minDist = 2 },
		clearance = 1,
		make = function(cf: CFrame, rng: Random)
			return Props.flower(cf, { rng = rng })
		end,
	})
	-- Colinas largas e baixas para o chão não ser uma tábua (guia simulator: boulder raio 12-15, squash ~0,25)
	run({
		seed = SEED + 5,
		spacing = 150,
		clearance = 16,
		limit = 10,
		make = function(cf: CFrame, rng: Random)
			return Props.boulder(
				cf * CFrame.new(0, -1, 0),
				{ rng = rng, radius = rng:NextNumber(12, 15), squash = 0.25, color = P.grassDark }
			)
		end,
	})
end

---------------------------------------------------------------------------
-- Decoração das bases (cor-tema, borda, cerca, arbustos na entrada)
---------------------------------------------------------------------------
function World.decorateBase(index: number, origin: CFrame, model: Model)
	local theme = World.BaseThemes[(index - 1) % #World.BaseThemes + 1]
	local size = Config.BaseSize
	local half = size / 2
	-- Borda colorida em volta do piso (o piso fica claro com a cor-tema)
	for _, e in
		{
			{ Vector3.new(size + 2, 0.4, 2), Vector3.new(0, 2.2, -half) },
			{ Vector3.new(size + 2, 0.4, 2), Vector3.new(0, 2.2, half) },
			{ Vector3.new(2, 0.4, size), Vector3.new(-half, 2.2, 0) },
			{ Vector3.new(2, 0.4, size), Vector3.new(half, 2.2, 0) },
		}
	do
		local trim = Build.decor(Build.part({
			Name = "Trim",
			Size = e[1],
			CFrame = origin * CFrame.new(e[2]),
			Color = hex(theme.color),
		}))
		trim.Parent = model
	end
	-- Cerca nos fundos e nas laterais (a frente, voltada para a praça, fica aberta)
	local function world(x: number, z: number): Vector3
		return (origin * CFrame.new(x, 2, z)).Position
	end
	for _, seg in
		{
			{ world(-half, half), world(half, half) },
			{ world(-half, -half + 8), world(-half, half) },
			{ world(half, -half + 8), world(half, half) },
		}
	do
		local fence = Props.fence(seg[1], seg[2], { color = "#F8F8F8", spacing = 6 })
		fence.Parent = model
	end
	-- Arbustos e flores ladeando a entrada
	local rng = Random.new(SEED + 100 + index)
	for _, x in { -half - 4, half + 4 } do
		local b = Props.bush(origin * CFrame.new(x, 0, -half - 2), { rng = rng, scale = 1.2 })
		b.Parent = model
		for i = 1, 3 do
			local f =
				Props.flower(origin * CFrame.new(x + rng:NextNumber(-3, 3), 0, -half - 6 - i * 1.5), { rng = rng })
			f.Parent = model
		end
	end
	return theme
end

---------------------------------------------------------------------------
-- Fase 3: ARENA (Giant Clash) — coliseu físico para as lutas de boxe de verdade.
-- Referência do usuário (08/11/2026): coliseu redondo de pedra lilás, arquibancadas de madeira em
-- degraus, 8 braseiros, bandeiras vermelhas/azuis com coroa, portão com arco e coroa, camarote real,
-- chão de areia com anéis e uma coroa pintada no centro. Só peças (estilo do mapa), ~260 peças.
-- Lugar: vão entre as bases a φ 22,5° (bases a cada 45° começando em 90°; lagos em 67,5/202,5/292,5).
---------------------------------------------------------------------------
World.Arena = {
	phi = 22.5,
	r = 235,
	floorR = 24, -- área de luta (sair dela = derrota por ringue)
	floorTop = 0.6,
	outerR = 38,
	gateHalfDeg = 12,
}
World.Arena.center = polar(World.Arena.phi, World.Arena.r, 0)

local ARENA_COLORS = {
	stone = "#A89EB8",
	stoneDark = "#857B99",
	wood = "#A85F2E",
	woodDark = "#7A4320",
	sand = "#E9B577",
	sandRing = "#C97843",
	emblem = "#B85A30",
	gold = "#F5C33B",
	red = "#C93A3A",
	blue = "#2F5BC4",
	bronze = "#B87333",
}

-- Quadro local da arena: -Z aponta para o centro da ilha (portão), +Z para o camarote.
local function arenaFrame(): CFrame
	local c = World.Arena.center
	return CFrame.lookAt(c, Vector3.new(0, 0, 0))
end

-- Ponto no anel (ângulo θ em graus a partir do portão, sentido horário), já orientado para o centro.
local function ringCf(thetaDeg: number, r: number, y: number): CFrame
	local t = math.rad(thetaDeg)
	local p = Vector3.new(math.sin(t) * r, y, -math.cos(t) * r)
	return CFrame.lookAt(p, Vector3.new(0, y, 0))
end

local function arenaPart(parent: Instance, base: CFrame, props: { [string]: any }, class: string?): BasePart
	local local_cf = props.CFrame :: CFrame
	props.CFrame = base * local_cf
	if type(props.Color) == "string" then
		props.Color = hex(props.Color)
	end
	local p = Build.part(props, class)
	p.Parent = parent
	return p
end

-- Coroa 3D de peças (barra + 3 pontas em losango + 3 bolinhas). `cf` = centro da barra, olhando +Z.
local function crown3d(parent: Instance, cf: CFrame, s: number)
	local gold = Enum.Material.Foil
	local function piece(size: Vector3, off: CFrame, shape: Enum.PartType?)
		local p = Build.part({
			Name = "Crown",
			Size = size * s,
			CFrame = cf * off,
			Color = hex(ARENA_COLORS.gold),
			Material = gold,
			CanCollide = false,
		})
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
	end
	piece(Vector3.new(4.4, 1.1, 0.8), CFrame.new())
	for i, x in { -1.6, 0, 1.6 } do
		local h = if i == 2 then 1.5 else 1.2
		piece(Vector3.new(h, h, 0.7), CFrame.new(x * s, (0.55 + h * 0.55) * s, 0) * CFrame.Angles(0, 0, math.rad(45)))
		piece(Vector3.new(0.7, 0.7, 0.7), CFrame.new(x * s, (1.1 + h * 1.15) * s, 0), Enum.PartType.Ball)
	end
end

function World.buildArena(root: Instance): Model
	local A = World.Arena
	local K = ARENA_COLORS
	local model = Instance.new("Model")
	model.Name = "Arena"
	local base = arenaFrame()

	-- Chão de luta: areia com dois anéis e a coroa pintada (vista de cima)
	local function floorDisc(name: string, radius: number, top: number, color: string, material: Enum.Material?)
		for i = 0, 2 do
			arenaPart(model, base, {
				Name = if i == 0 then name else name .. "_Fill" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, radius * 2, radius * 2),
				CFrame = CFrame.new(0, top - 0.3, 0)
					* CFrame.Angles(0, math.rad(i * 5), 0)
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = color,
				Material = material or Enum.Material.SmoothPlastic,
				CastShadow = false,
			})
		end
	end
	floorDisc("ArenaFloor", A.floorR + 1.5, A.floorTop, K.sand, Enum.Material.Sand)
	floorDisc("ArenaRingOuter", 19, A.floorTop + 0.02, K.sandRing)
	floorDisc("ArenaRingInner", 17.6, A.floorTop + 0.04, K.sand, Enum.Material.Sand)
	floorDisc("ArenaCenter", 8, A.floorTop + 0.06, K.sandRing)
	floorDisc("ArenaCenterIn", 7.2, A.floorTop + 0.08, K.sand, Enum.Material.Sand)
	-- coroa pintada (peças finas no chão)
	local emblem = A.floorTop + 0.1
	arenaPart(model, base, {
		Name = "Emblem",
		Size = Vector3.new(7, 0.06, 1.4),
		CFrame = CFrame.new(0, emblem, 1.4),
		Color = K.emblem,
		CanCollide = false,
	})
	for _, x in { -2.6, 0, 2.6 } do
		arenaPart(model, base, {
			Name = "Emblem",
			Size = Vector3.new(1.9, 0.06, 1.9),
			CFrame = CFrame.new(x, emblem, if x == 0 then -0.6 else -0.1) * CFrame.Angles(0, math.rad(45), 0),
			Color = K.emblem,
			CanCollide = false,
		})
	end

	-- Muro baixo da área de luta (com abertura no portão)
	local inner = 25.5
	local N = 24
	for i = 0, N - 1 do
		local th = (i + 0.5) * 360 / N
		if math.abs(((th + 180) % 360) - 180) > A.gateHalfDeg then
			arenaPart(model, base, {
				Name = "InnerWall",
				Size = Vector3.new(2 * math.pi * inner / N + 0.4, 3, 1.4),
				CFrame = ringCf(th, inner, 1.5),
				Color = K.stoneDark,
				Material = Enum.Material.Slate,
			})
		end
	end

	-- Arquibancadas: 3 degraus (base de pedra + banco de madeira), fora do portão e do camarote
	for tier = 1, 3 do
		local r = 26.5 + tier * 2.8
		local top = 1.6 + tier * 1.8
		local n = 18 + tier * 4
		for i = 0, n - 1 do
			local th = (i + 0.5) * 360 / n
			local fromGate = math.abs(((th + 180) % 360) - 180)
			local fromBox = math.abs(((th % 360) - 180))
			if fromGate > A.gateHalfDeg + 4 and fromBox > 14 then
				local w = 2 * math.pi * r / n + 0.3
				arenaPart(model, base, {
					Name = "StandStone",
					Size = Vector3.new(w, top - 0.6, 2.8),
					CFrame = ringCf(th, r, (top - 0.6) / 2),
					Color = K.stone,
					Material = Enum.Material.Slate,
				})
				arenaPart(model, base, {
					Name = "StandBench",
					Size = Vector3.new(w, 0.6, 2.4),
					CFrame = ringCf(th, r + 0.1, top - 0.3),
					Color = if i % 2 == 0 then K.wood else K.woodDark,
					Material = Enum.Material.WoodPlanks,
				})
			end
		end
	end

	-- Muro externo
	local outer = A.outerR
	local No = 28
	for i = 0, No - 1 do
		local th = (i + 0.5) * 360 / No
		if math.abs(((th + 180) % 360) - 180) > A.gateHalfDeg then
			arenaPart(model, base, {
				Name = "OuterWall",
				Size = Vector3.new(2 * math.pi * outer / No + 0.4, 9, 2),
				CFrame = ringCf(th, outer, 4.5),
				Color = if i % 2 == 0 then K.stone else K.stoneDark,
				Material = Enum.Material.Slate,
			})
		end
	end

	-- 8 pilares com braseiros (fogo + luz quente)
	for i = 0, 7 do
		local th = i * 45 + 22.5
		local pillarCf = ringCf(th, outer + 0.5, 5.5)
		arenaPart(model, base, {
			Name = "Pillar",
			Size = Vector3.new(3.4, 11, 3.4),
			CFrame = pillarCf,
			Color = K.stone,
			Material = Enum.Material.Slate,
		})
		arenaPart(model, base, {
			Name = "PillarCap",
			Size = Vector3.new(4, 0.8, 4),
			CFrame = ringCf(th, outer + 0.5, 11.4),
			Color = K.stoneDark,
			Material = Enum.Material.Slate,
		})
		local bowl = arenaPart(model, base, {
			Name = "Brazier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 3.2, 3.2),
			CFrame = ringCf(th, outer + 0.5, 12.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color = K.bronze,
			Material = Enum.Material.Metal,
		})
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 7
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 70)
		light.Range = 14
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = bowl
	end

	-- Bandeiras vermelhas e azuis com coroa (atrás das arquibancadas)
	for i = 0, 5 do
		local th = 45 + i * 54
		if math.abs(((th % 360) - 180)) > 14 then
			local cf = ringCf(th, outer + 3, 0)
			arenaPart(model, base, {
				Name = "BannerPole",
				Size = Vector3.new(0.5, 18, 0.5),
				CFrame = cf * CFrame.new(0, 9, 0),
				Color = K.woodDark,
				Material = Enum.Material.Wood,
			})
			arenaPart(model, base, {
				Name = "BannerTop",
				Size = Vector3.new(4, 0.5, 0.5),
				CFrame = cf * CFrame.new(0, 17.6, 0),
				Color = K.gold,
				Material = Enum.Material.Foil,
			})
			arenaPart(model, base, {
				Name = "Banner",
				Size = Vector3.new(3.4, 6.5, 0.2),
				CFrame = cf * CFrame.new(0, 14, -0.4),
				Color = if i % 2 == 0 then K.red else K.blue,
				Material = Enum.Material.Fabric,
			})
			crown3d(model, base * cf * CFrame.new(0, 14, -0.6) * CFrame.Angles(0, math.pi, 0), 0.45)
		end
	end

	-- Portão: dois pilares, arco de madeira com coroa dourada e rampa de pedra
	local gateR = outer + 0.5
	for _, sgn in { -1, 1 } do
		arenaPart(model, base, {
			Name = "GatePillar",
			Size = Vector3.new(3.6, 12, 3.6),
			CFrame = ringCf(sgn * (A.gateHalfDeg + 1), gateR, 6),
			Color = K.stone,
			Material = Enum.Material.Slate,
		})
		-- bandeiras azuis penduradas no portão
		arenaPart(model, base, {
			Name = "GateBanner",
			Size = Vector3.new(2.6, 6, 0.2),
			CFrame = ringCf(sgn * (A.gateHalfDeg + 1), gateR + 1.95, 5.5),
			Color = K.blue,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	local gateW = 2 * gateR * math.sin(math.rad(A.gateHalfDeg + 1)) + 3.6
	arenaPart(model, base, {
		Name = "GateArch",
		Size = Vector3.new(gateW, 1.8, 2.8),
		CFrame = CFrame.new(0, 12.4, -gateR),
		Color = K.wood,
		Material = Enum.Material.WoodPlanks,
	})
	crown3d(model, base * CFrame.new(0, 14.2, -gateR - 0.4) * CFrame.Angles(0, math.pi, 0), 1.1)
	arenaPart(model, base, {
		Name = "GateRamp",
		Size = Vector3.new(gateW - 4, 0.6, 12),
		CFrame = CFrame.new(0, 0.3, -gateR - 5),
		Color = K.stone,
		Material = Enum.Material.Cobblestone,
	})

	-- Camarote real (fundo): plataforma, painel azul com moldura dourada e coroa
	arenaPart(model, base, {
		Name = "RoyalBox",
		Size = Vector3.new(12, 8, 6),
		CFrame = CFrame.new(0, 4, outer - 1),
		Color = K.stone,
		Material = Enum.Material.Slate,
	})
	arenaPart(model, base, {
		Name = "RoyalTrim",
		Size = Vector3.new(11, 7.6, 0.5),
		CFrame = CFrame.new(0, 12.6, outer + 1.4),
		Color = K.gold,
		Material = Enum.Material.Foil,
	})
	arenaPart(model, base, {
		Name = "RoyalPanel",
		Size = Vector3.new(10, 6.6, 0.6),
		CFrame = CFrame.new(0, 12.6, outer + 1.1),
		Color = K.blue,
		Material = Enum.Material.Fabric,
	})
	crown3d(model, base * CFrame.new(0, 12.8, outer + 0.7), 1.2)
	crown3d(model, base * CFrame.new(0, 17.4, outer + 1.2), 0.9)

	-- Estrada de pedra da praça até a rampa do portão
	local from = PLAZA_OUTER_R
	local to = A.r - gateR - 10
	local len = to - from
	local dir = polar(A.phi, 1, 0)
	local mid = dir * (from + len / 2)
	local road = Build.part({
		Name = "ArenaRoad",
		Size = Vector3.new(PATH_W, 0.4, len),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.2, 0), Vector3.new(0, 0.2, 0)),
		Color = hex(World.Palette.path),
		Material = Enum.Material.Cobblestone,
		CastShadow = false,
	})
	road.Parent = model

	-- Pontos de largada dos lutadores (frente a frente, perpendicular ao portão)
	local spawns: { [string]: number } = { SpawnA = -10, SpawnB = 10 }
	for name, x in spawns do
		local sp = Build.part({
			Name = name,
			Size = Vector3.new(4, 0.1, 4),
			CFrame = base * CFrame.new(x, A.floorTop + 0.12, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		sp.Parent = model
	end

	model:SetAttribute("FloorRadius", A.floorR)
	model:SetAttribute("FloorTop", A.floorTop)
	model.Parent = root
	return model
end

-- Área que a natureza deve evitar (arena + estrada até a praça).
function World.arenaExclusions(): { any }
	local c = World.Arena.center
	local dir = polar(World.Arena.phi, 1, 0)
	return {
		{ center = Vector2.new(c.X, c.Z), radius = World.Arena.outerR + 12 },
		{
			a = Vector2.new(dir.X, dir.Z) * PLAZA_OUTER_R,
			b = Vector2.new(c.X, c.Z),
			radius = PATH_W / 2 + 6,
		},
	}
end

return World
