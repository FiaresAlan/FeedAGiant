--!strict
-- WorldFx — efeitos vivos do mundo (pedido do usuário em 08/11/2026: "lago geométrico, não é água",
-- "mar é uma base azul", "a panela tem formas geométricas que não são fumaça", "fogo embaixo dela,
-- bem animado, e no evento o fogo e a fumaça aumentam", "estátuas dos outros gigantes pelo mapa").
--
-- Roda no servidor depois do mapa pronto (assado ou gerado), então funciona nos dois casos:
--   * Mundo (item 16): chão de grama de terreno com ondulações, montanhas em volta, sem mar, água de
--     terreno só nos 3 lagos, paredes invisíveis no limite.
--   * Fogo e fumaça de partículas no caldeirão; as nuvens de peças e as bolas de neon somem.
--   * Estátuas das 12 espécies de gigante em volta da praça, com placa de preço (progressão visível).
-- Partículas usam as texturas que já vêm com o Roblox (rbxasset://textures/particles/...), sem upload.
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local World = require(script.Parent.World)

local WorldFx = {}

local ISLAND_R = 470 -- igual a World.lua
local BEACH_W = 26
local PONDS = { { 67.5, 235, 30 }, { 202.5, 240, 34 }, { 292.5, 230, 26 } } -- igual a World.lua

local fires: { ParticleEmitter } = {}
local smokes: { ParticleEmitter } = {}
local sparks: { ParticleEmitter } = {}
local glow: PointLight? = nil

local function polar(phiDeg: number, r: number, y: number): Vector3
	local a = math.rad(phiDeg) -- igual a World.lua (0° = -Z, sentido horário)
	return Vector3.new(math.sin(a) * r, y, -math.cos(a) * r)
end

---------------------------------------------------------------------------
-- Água
---------------------------------------------------------------------------
-- Reforma do mapa (pedido do usuário, item 16, 08/11/2026):
--   * SEM MAR em volta: some a água de terreno e a peça azul do horizonte (custo e limite do mapa);
--   * chão de GRAMA DE TERRENO (textura do Roblox) com pequenas ondulações só fora das rotas de jogo
--     (praça, caminhos das bases, bases, arena, lagos e estátuas ficam planos);
--   * cadeia de MONTANHAS cartoon (rocha quente, encostas verdes, picos com neve) em volta de tudo,
--     fechando o horizonte; um anel de paredes invisíveis impede sair da área jogável;
--   * os 3 lagos continuam com água de terreno.
-- Cores pintadas (Terrain:SetMaterialColor) para combinar com o estilo cartoon das criaturas.
local MOUNTAIN_INNER = ISLAND_R + BEACH_W + 40

local function nearPathOrBase(p: Vector3): boolean
	local r = Vector3.new(p.X, 0, p.Z).Magnitude
	-- ângulo até a direção de base/caminho mais próxima (múltiplos de 45°)
	local ang = math.deg(math.atan2(p.Z, p.X)) % 45
	local off = math.min(ang, 45 - ang)
	if r < 360 and off < 13 then
		return true
	end
	-- bases (quadrado de 60 a r 320)
	if r > 270 and r < 380 then
		return true
	end
	return false
end

local function nearPondOrArena(p: Vector3): boolean
	for _, pond in PONDS do
		local c = polar(pond[1], pond[2], 0)
		if (Vector3.new(p.X - c.X, 0, p.Z - c.Z)).Magnitude < pond[3] + 22 then
			return true
		end
	end
	local a = World.Arena.center
	if Vector3.new(p.X - a.X, 0, p.Z - a.Z).Magnitude < World.Arena.outerR + 30 then
		return true
	end
	-- Ilha do Dragão e a ponte (chão plano por baixo)
	local isle = World.BossIsland
	local ic = isle.center
	if Vector3.new(p.X - ic.X, 0, p.Z - ic.Z).Magnitude < isle.radius + 30 then
		return true
	end
	local idir = Vector3.new(ic.X, 0, ic.Z).Unit
	local ialong = Vector3.new(p.X, 0, p.Z):Dot(idir)
	if ialong > isle.bridgeFrom - 20 and ialong < isle.bridgeTo + 10 then
		if (Vector3.new(p.X, 0, p.Z) - idir * ialong).Magnitude < isle.bridgeW / 2 + 14 then
			return true
		end
	end
	-- estrada da praça até a arena
	local dir = Vector3.new(a.X, 0, a.Z).Unit
	local along = Vector3.new(p.X, 0, p.Z):Dot(dir)
	if along > 0 and along < Vector3.new(a.X, 0, a.Z).Magnitude then
		local perp = (Vector3.new(p.X, 0, p.Z) - dir * along).Magnitude
		if perp < 20 then
			return true
		end
	end
	return false
end

local function world(map: Instance)
	local T = Workspace.Terrain
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 178, 62))
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(88, 160, 58))
	T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(168, 128, 112))
	T:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(236, 204, 146))
	T:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(246, 248, 255))
	T.WaterColor = Color3.fromRGB(40, 150, 200)
	T.WaterTransparency = 0.35
	T.WaterReflectance = 0.6
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 8
	-- Chão: areia na borda, grama no resto (topo em y = 0, igual às peças antigas)
	-- O terreno arredonda em blocos de 4 studs (medido: preencher até y = 0 deixava a superfície em
	-- y = 2 e cobria os caminhos, que têm topo em y = 1). Solução medida: blocos cheios até y = -4 e a
	-- camada -4..0 escrita com ocupação 0,5 → superfície em y = 0. Lagos: água na mesma camada.
	T:FillCylinder(CFrame.new(0, -8, 0), 8, ISLAND_R + BEACH_W + 30, Enum.Material.Sand)
	T:FillCylinder(CFrame.new(0, -8, 0), 8, ISLAND_R, Enum.Material.Grass)
	local pondCenters = {}
	for _, pond in PONDS do
		table.insert(pondCenters, { c = polar(pond[1], pond[2], 0), r = pond[3] })
		local c = polar(pond[1], pond[2], 0)
		T:FillCylinder(CFrame.new(c.X, -8, c.Z), 8, pond[3], Enum.Material.Water)
	end
	local R = ISLAND_R + BEACH_W + 30
	local region = Region3.new(Vector3.new(-R, -4, -R), Vector3.new(R, 0, R)):ExpandToGrid(4)
	local count = region.Size / 4
	local minp = region.CFrame.Position - region.Size / 2
	local mats, occs = {}, {}
	for x = 1, count.X do
		mats[x], occs[x] = { {} }, { {} }
		for z = 1, count.Z do
			local px, pz = minp.X + (x - 0.5) * 4, minp.Z + (z - 0.5) * 4
			local r = math.sqrt(px * px + pz * pz)
			local m, o = Enum.Material.Air, 0
			if r <= ISLAND_R then
				m, o = Enum.Material.Grass, 0.5
			elseif r <= ISLAND_R + BEACH_W + 30 then
				m, o = Enum.Material.Sand, 0.5
			end
			for _, pc in pondCenters do
				local d = Vector3.new(px - pc.c.X, 0, pz - pc.c.Z).Magnitude
				if d <= pc.r then
					m, o = Enum.Material.Water, 1
				elseif d <= pc.r + 5 then
					m, o = Enum.Material.Sand, 0.5 -- margem de areia (no lugar do disco de peça)
				end
			end
			mats[x][1][z] = m
			occs[x][1][z] = o
		end
	end
	T:WriteVoxels(region, 4, mats, occs)
	task.wait()
	-- As peças antigas do chão e do mar somem (o terreno fica no lugar delas).
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local n = d.Name
			if
				string.sub(n, 1, 6) == "Island"
				or string.sub(n, 1, 5) == "Beach"
				or string.sub(n, 1, 9) == "Shallows"
				or n == "FarSea"
				or n == "PondWater"
				or n == "PondRim"
				or n == "GrassPatch" -- revisão do mundo: os discos escuros pareciam buracos na grama de terreno
			then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	-- Ondulações suaves (só onde ninguém precisa andar reto)
	local rng = Random.new(4242)
	local placed = 0
	for _ = 1, 400 do
		if placed >= 70 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(185, ISLAND_R - 12)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if nearPathOrBase(p) or nearPondOrArena(p) then
			continue
		end
		local radius = rng:NextNumber(14, 26)
		local h = rng:NextNumber(1, 3.5)
		T:FillBall(Vector3.new(p.X, h - radius - 1, p.Z), radius, Enum.Material.Grass)
		placed += 1
		if placed % 10 == 0 then
			task.wait()
		end
	end
	task.wait()
	-- Montanhas
	local n = 72
	for i = 0, n - 1 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / n * math.pi * 2
		local r = MOUNTAIN_INNER + rng:NextNumber(40, 110)
		local radius = rng:NextNumber(55, 90)
		local cx, cz = math.cos(a) * r, math.sin(a) * r
		local cy = radius * rng:NextNumber(0.05, 0.35)
		T:FillBall(Vector3.new(cx, cy, cz), radius, Enum.Material.Rock)
		-- encosta verde por baixo
		T:FillBall(Vector3.new(cx, cy - radius * 0.55, cz), radius * 0.95, Enum.Material.LeafyGrass)
		if cy + radius > 95 then
			T:FillBall(Vector3.new(cx, cy + radius * 0.82, cz), radius * 0.3, Enum.Material.Snow)
		end
		if i % 4 == 0 then
			task.wait()
		end
	end
	-- Paredes invisíveis no pé das montanhas (ninguém sai da área de jogo)
	local walls = Instance.new("Folder")
	walls.Name = "Boundary"
	local wr = ISLAND_R + BEACH_W + 24
	local segs = 64
	for i = 0, segs - 1 do
		local a = (i + 0.5) / segs * math.pi * 2
		local w = Instance.new("Part")
		w.Name = "Wall"
		w.Anchored = true
		w.Transparency = 1
		w.CanQuery = false
		w.Size = Vector3.new(2 * math.pi * wr / segs + 4, 400, 4)
		w.CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * wr, 200, math.sin(a) * wr), Vector3.new(0, 200, 0))
		w.Parent = walls
	end
	walls.Parent = map
end

---------------------------------------------------------------------------
-- Caldeirão: fogo, fumaça e faíscas
---------------------------------------------------------------------------
local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = parent
	return pe
end

local function cauldron(map: Instance)
	local m = map:FindFirstChild("BanquetCauldron", true)
	if not m then
		return
	end
	local hearth = m:FindFirstChild("HearthTop")
	local soup = m:FindFirstChild("Soup")
	if not hearth or not hearth:IsA("BasePart") or not soup or not soup:IsA("BasePart") then
		return
	end
	-- Fora: bolas de neon ("chamas" de esfera) e nuvens de peças em cima da sopa.
	for _, child in m:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Flame" then
			child.Transparency = 1
		elseif child:IsA("Model") and child.Name ~= "CauldronMesh" then
			for _, p in child:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 1
				end
			end
		end
	end
	local hr = math.max(hearth.Size.Y, hearth.Size.Z) / 2
	-- Fogo: 10 focos na borda da fogueira (a panela 3D é mais larga que a base e escondia o centro),
	-- chamas que sobem lambendo a panela e dançam.
	for i = 0, 9 do
		local a = i * math.pi / 5
		local att = Instance.new("Attachment")
		att.Name = "FireAtt"
		att.Parent = hearth
		-- depois de parentar e sem giro: a peça é um cilindro deitado (o "Top" dela aponta de lado)
		att.WorldCFrame =
			CFrame.new(hearth.Position + Vector3.new(math.cos(a) * hr * 1.05, 0.5, math.sin(a) * hr * 1.05))
		table.insert(
			fires,
			emitter(att, {
				Name = "Fire",
				Texture = "rbxasset://textures/particles/fire_main.dds",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 150, 40)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 20)),
				}),
				LightEmission = 0.9,
				LightInfluence = 0,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 11),
					NumberSequenceKeypoint.new(0.6, 8),
					NumberSequenceKeypoint.new(1, 1.5),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(0.7, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.7, 1.2),
				Speed = NumberRange.new(10, 16),
				Rate = 14,
				RotSpeed = NumberRange.new(-60, 60),
				Rotation = NumberRange.new(0, 360),
				SpreadAngle = Vector2.new(12, 12),
				Acceleration = Vector3.new(0, 6, 0),
				EmissionDirection = Enum.NormalId.Top,
			})
		)
	end
	-- Faíscas subindo do fogo.
	local sparkAtt = Instance.new("Attachment")
	sparkAtt.Name = "SparkAtt"
	sparkAtt.Parent = hearth
	-- depois de parentar e sem giro: a peça é um cilindro deitado (o "Top" dela aponta de lado)
	sparkAtt.WorldCFrame = CFrame.new(hearth.Position + Vector3.new(0, 2, 0))
	table.insert(
		sparks,
		emitter(sparkAtt, {
			Name = "Sparks",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 80)),
			LightEmission = 1,
			Size = NumberSequence.new(0.8, 0),
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(14, 24),
			SpreadAngle = Vector2.new(40, 40),
			Rate = 6,
			Acceleration = Vector3.new(0, 4, 0),
			EmissionDirection = Enum.NormalId.Top,
		})
	)
	-- Fumaça/vapor saindo da sopa: grande, macia, sobe e se espalha.
	local smokeAtt = Instance.new("Attachment")
	smokeAtt.Name = "SmokeAtt"
	smokeAtt.Parent = soup
	-- depois de parentar e sem giro: a peça é um cilindro deitado (o "Top" dela aponta de lado)
	smokeAtt.WorldCFrame = CFrame.new(soup.Position + Vector3.new(0, 2, 0))
	table.insert(
		smokes,
		emitter(smokeAtt, {
			Name = "Steam",
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 235), Color3.fromRGB(200, 195, 200)),
			LightInfluence = 0.25,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 12),
				NumberSequenceKeypoint.new(1, 36),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.15),
				NumberSequenceKeypoint.new(0.6, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(5, 7),
			Speed = NumberRange.new(7, 11),
			SpreadAngle = Vector2.new(18, 18),
			Rate = 5,
			RotSpeed = NumberRange.new(-20, 20),
			Rotation = NumberRange.new(0, 360),
			Acceleration = Vector3.new(1.5, 1, 0), -- vento leve
			EmissionDirection = Enum.NormalId.Top,
		})
	)
	glow = hearth:FindFirstChildOfClass("PointLight")
end

-- Evento começou/acabou: fogo e fumaça crescem (e a fumaça ganha a cor do evento).
function WorldFx.setEventBoost(on: boolean, color: Color3?)
	for _, f in fires do
		f.Rate = if on then 32 else 14
		f.Speed = if on then NumberRange.new(16, 26) else NumberRange.new(10, 16)
	end
	for _, s in sparks do
		s.Rate = if on then 30 else 6
	end
	for _, s in smokes do
		s.Rate = if on then 14 else 5
		s.Color = if on and color
			then ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), Color3.fromRGB(210, 200, 210))
			else ColorSequence.new(Color3.fromRGB(255, 245, 235), Color3.fromRGB(200, 195, 200))
	end
	local g = glow
	if g then
		g.Brightness = if on then 4 else 2
		g.Range = if on then 60 else 40
	end
end

---------------------------------------------------------------------------
-- Estátuas das espécies (progressão à vista)
---------------------------------------------------------------------------
local STATUE_R = 166
local STATUE_HEIGHT = 18

-- Reforma de 08/11 (pedido do usuário): criaturas com a pintura REAL (não pedra), sólidas (um corpo
-- invisível de colisão; a malha detalhada não colide), pedestal redondo em degraus com faixa na cor da
-- espécie, placa de madeira na frente e um ProximityPrompt "ENCONTRAR <NOME>" que abre a confirmação
-- de compra no cliente (Shop.confirmSpecies). Nada é comprado ao se aproximar.
local function cyl(name: string, radius: number, height: number, cf: CFrame, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function sign(model: Model, face: CFrame, sp: Config.SpeciesDef): Part
	local board = Instance.new("Part")
	board.Name = "Sign"
	board.Size = Vector3.new(9, 3.2, 0.5)
	board.CFrame = face * CFrame.new(0, 2.2, -8.6) * CFrame.Angles(math.rad(-18), 0, 0)
	board.Anchored = true
	board.Color = Color3.fromRGB(122, 74, 40)
	board.Material = Enum.Material.Wood
	board.Parent = model
	for _, x in { -3.6, 3.6 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Size = Vector3.new(0.5, 2.2, 0.5)
		post.CFrame = face * CFrame.new(x, 1.1, -8.4)
		post.Anchored = true
		post.Color = Color3.fromRGB(90, 55, 30)
		post.Material = Enum.Material.Wood
		post.Parent = model
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- a frente (-Z) olha para o centro da praça
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 244, 214)
	title.TextStrokeTransparency = 0.2
	title.Text = Locale.upper(sp.name)
	title.Parent = sg
	local price = title:Clone()
	price.Position = UDim2.fromScale(0, 0.55)
	price.Size = UDim2.fromScale(1, 0.45)
	price.TextColor3 = if sp.robux then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 214, 70)
	price.Text = if sp.robux
		then "PASSE (ROBUX)"
		elseif sp.price <= 0 then "INICIAL"
		else Util.formatNumber(sp.price) .. " moedas"
	price.Parent = sg
	return board
end

local function statues(map: Instance, template: (string) -> Model?)
	local old = Workspace:FindFirstChild("GiantStatues")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "GiantStatues"
	-- 12 lugares: pares (±8°) no meio entre os caminhos das bases, menos o vão da estrada da arena
	-- (22,5°). Caminhos a cada 45°.
	local angles = {}
	for k = 0, 7 do
		local mid = 22.5 + k * 45
		if math.abs(mid - 22.5) > 1 and #angles < 12 then
			table.insert(angles, mid - 8)
			table.insert(angles, mid + 8)
		end
	end
	for i, sp in Config.Species do
		local phi = angles[i]
		if not phi then
			break
		end
		local pos = polar(phi, STATUE_R, 0)
		-- A estátua e a placa olham para o centro, onde os jogadores circulam.
		local face = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		local nature = map:FindFirstChild("Nature")
		if nature then
			for _, d in nature:GetChildren() do
				local ok, pivot = pcall(function()
					return (d :: any):GetPivot()
				end)
				if ok and (Vector3.new(pivot.Position.X, 0, pivot.Position.Z) - pos).Magnitude < 13 then
					d:Destroy()
				end
			end
		end
		local model = Instance.new("Model")
		model.Name = "Statue_" .. sp.id
		local stone = Color3.fromRGB(196, 186, 170)
		local stoneDark = Color3.fromRGB(150, 140, 128)
		local band = if sp.robux then Color3.fromRGB(245, 195, 60) else sp.color
		cyl("Base", 7.2, 1.2, face * CFrame.new(0, 0.6, 0), stoneDark, Enum.Material.Slate).Parent = model
		cyl("Step", 6.4, 1.4, face * CFrame.new(0, 1.9, 0), stone, Enum.Material.Sandstone).Parent = model
		local bandPart = cyl("Band", 6.0, 0.7, face * CFrame.new(0, 2.95, 0), band, Enum.Material.SmoothPlastic)
		bandPart.Parent = model
		local top = cyl("Top", 6.2, 0.8, face * CFrame.new(0, 3.7, 0), stone, Enum.Material.Sandstone)
		top.Parent = model
		local topY = 4.1
		sign(model, face, sp)

		local entry = CreatureModels.BySpecies[sp.id]
		local t = entry and template(entry.file)
		if t then
			local s = t:Clone()
			local _, size0 = s:GetBoundingBox()
			s:ScaleTo(s:GetScale() * STATUE_HEIGHT / math.max(size0.Y, 1))
			local cf, size = s:GetBoundingBox()
			local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
			local offset = s:GetPivot():ToObjectSpace(bottom)
			local yaw = math.rad((entry :: any).yaw or 0)
			s:PivotTo(face * CFrame.new(0, topY, 0) * CFrame.Angles(0, yaw, 0) * offset:Inverse()) -- medido: sem o giro de 180° a criatura olha para a praça
			for _, d in s:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false -- a colisão é o corpo invisível abaixo (barato e sem buracos)
					d.CanQuery = false
					d.CanTouch = false
					if d:IsA("MeshPart") and d.TextureID ~= "" then
						d.Color = Color3.new(1, 1, 1) -- cor original da pintura
					end
				end
			end
			s.Parent = model
			-- Corpo sólido: cilindro do tamanho da pegada da criatura (jogador não atravessa).
			local _, ext = s:GetBoundingBox()
			local r = math.clamp(math.min(ext.X, ext.Z) * 0.42, 2.5, 6)
			local body =
				cyl("Collider", r, ext.Y, face * CFrame.new(0, topY + ext.Y / 2, 0), stone, Enum.Material.Plastic)
			body.Transparency = 1
			body.CanQuery = false
			body.Parent = model
		end
		-- Ponto de interação discreto na frente + prompt (PC: E, controle: X, celular: toque).
		local blip = Instance.new("Part")
		blip.Name = "Blip"
		blip.Shape = Enum.PartType.Cylinder
		blip.Size = Vector3.new(0.15, 3, 3)
		blip.CFrame = face * CFrame.new(0, 0.1, -10.5) * CFrame.Angles(0, 0, math.rad(90))
		blip.Anchored = true
		blip.CanCollide = false
		blip.Material = Enum.Material.Neon
		blip.Color = band
		blip.Transparency = 0.35
		blip.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FindSpecies"
		prompt.ActionText = "ENCONTRAR " .. Locale.upper(sp.name):gsub("^GIGANTE%s+", "")
		prompt.ObjectText = if sp.robux then "Passe (Robux)" else Util.formatNumber(sp.price) .. " moedas"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("SpeciesId", sp.id)
		prompt.Parent = blip
		model.Parent = folder
	end
	folder.Parent = Workspace
end

function WorldFx.init(template: (string) -> Model?)
	local map = Workspace:WaitForChild("Map", 60)
	if not map then
		return
	end
	for name, step in { ["mundo"] = world, ["caldeirão"] = cauldron } :: { [string]: (Instance) -> () } do
		local ok, err = pcall(function()
			step(map)
		end)
		if not ok then
			warn("[WorldFx] " .. name .. ":", err)
		end
	end
	task.spawn(function()
		local ok, err = pcall(function()
			statues(map, template)
		end)
		if not ok then
			warn("[WorldFx] estátuas:", err)
		end
	end)
end

return WorldFx
