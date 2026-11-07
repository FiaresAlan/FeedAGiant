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
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)

local MapKit = game:GetService("ServerScriptService"):WaitForChild("fwjelaa"):WaitForChild("MapKit")
local Build = require(MapKit:WaitForChild("Build")) :: any
local Props = require(MapKit:WaitForChild("Props")) :: any
local Scatter = require(MapKit:WaitForChild("Scatter")) :: any

local World = {}

local hex = Color3.fromHex

-- Paleta (cores oficiais BrickColor do guia simulator, zona Meadow/spawn)
World.Palette = {
	grass = "#5B9A4C",
	grassDark = "#4B974B",
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
-- Marco: escala 1,7 (~120 studs com o vapor). Raio da fogueira = 17 * escala ≈ 29 studs;
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
	copies: number?
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
	disc("Island", ISLAND_R, 0, 10, P.grass, ground, 4)
	disc("Beach", ISLAND_R + BEACH_W, -0.6, 10, P.sand, ground, 4)
	-- Água de verdade só perto da ilha; uma peça plana leva o mar até o horizonte
	-- (make-map: água de terreno é o que mais custa draw calls; manter ~700 studs em volta).
	local terrain = Workspace.Terrain
	terrain.WaterColor = hex(P.water)
	terrain.WaterTransparency = 0.3
	terrain.WaterReflectance = 0.15
	terrain:FillBlock(CFrame.new(0, -5, 0), Vector3.new(1400, 6, 1400), Enum.Material.Water)
	local sea = Build.decor(Build.part({
		Name = "FarSea",
		Size = Vector3.new(8000, 1, 8000),
		CFrame = CFrame.new(0, -2.8, 0),
		Color = hex(P.water),
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
	local floor = 2 -- topo da praça interna
	-- Fogueira de pedra (raio máximo = CAULDRON_RADIUS: a faixa de drops começa depois dele)
	cyl("Hearth", 34 * S, 4 * S, CFrame.new(0, floor + 2 * S, 0), P.stone)
	cyl("HearthTop", 30 * S, 0.6, CFrame.new(0, floor + 4 * S + 0.3, 0), P.stoneDark, true)
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
		ballp("Flame", 4.5 * S, pos, if i % 2 == 0 then "#FFB000" else "#FF8C1A")
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
	cyl("Soup", 36 * S, 1, CFrame.new(0, soupTop - 0.5, 0), "#FF8C1A", true)
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
		Color = hex("#0D69AC"),
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
	disc("PlazaOuter", PLAZA_OUTER_R, 1, 3, P.sandDark, hub, 3)
	disc("PlazaInner", PLAZA_INNER_R, 2, 3, P.plaza, hub)
	disc("PlazaRing", PLAZA_INNER_R - 22, 2.05, 0.2, P.plazaRing, hub) -- anel de desenho no piso
	disc("PlazaCore", PLAZA_INNER_R - 25, 2.1, 0.2, P.plaza, hub)
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
		Color = hex("#B480FF"),
		Material = Enum.Material.Neon,
	})
	local eventRim = Build.decor(Build.part({
		Name = "EventRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 30, 30),
		CFrame = CFrame.new(eventPos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex("#8C5B9F"),
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
	})
	-- Bordas mais escuras (o caminho precisa ter brilho diferente do chão: guia simulator)
	for _, side in { -1, 1 } do
		local edge = Build.decor(Build.part({
			Name = "PathEdge",
			Size = Vector3.new(1.2, 1.1, len),
			CFrame = CFrame.lookAt(mid, Vector3.new(0, mid.Y, 0)) * CFrame.new(side * (PATH_W / 2 + 0.6), 0.55, 0),
			Color = hex(P.pathEdge),
		}))
		edge.Parent = path
	end
	path.Parent = parent
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
		seed = SEED + 1,
		clusters = { spacing = 95, radius = 16, per = { 3, 5 }, minDist = 10 },
		clearance = 7,
		make = function(cf: CFrame, rng: Random)
			return Props.tree(cf, { rng = rng, leaf = P.grass, leafDark = "#348E40" })
		end,
	})
	run({
		seed = SEED + 2,
		spacing = 44,
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
		clusters = { spacing = 90, radius = 6, per = { 3, 5 }, minDist = 2 },
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
		limit = 14,
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

return World
