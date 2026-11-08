--!strict
-- WorldFx — efeitos vivos do mundo (pedido do usuário em 08/11/2026: "lago geométrico, não é água",
-- "mar é uma base azul", "a panela tem formas geométricas que não são fumaça", "fogo embaixo dela,
-- bem animado, e no evento o fogo e a fumaça aumentam", "estátuas dos outros gigantes pelo mapa").
--
-- Roda no servidor depois do mapa pronto (assado ou gerado), então funciona nos dois casos:
--   * Água de terreno nos 3 lagos e num anel de mar em volta da praia (só o anel: água de terreno no
--     mar inteiro custava ~290 mil triângulos na Fase 1; o anel cobre o que se vê da ilha).
--   * Fogo e fumaça de partículas no caldeirão; as nuvens de peças e as bolas de neon somem.
--   * Estátuas das 12 espécies de gigante em volta da praça, com placa de preço (progressão visível).
-- Partículas usam as texturas que já vêm com o Roblox (rbxasset://textures/particles/...), sem upload.
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Locale = require(game.ReplicatedStorage.Shared.Locale)

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
local function water(map: Instance)
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	-- Mar: anel de água entre a praia e ~150 studs para fora. Topo em -1,6 (abaixo da praia, -0,6).
	local outer = ISLAND_R + BEACH_W + 150
	terrain:FillCylinder(CFrame.new(0, -4.4, 0), 5.6, outer, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(0, -4.4, 0), 6, ISLAND_R - 20, Enum.Material.Air)
	-- Lagos: água com topo 0,4 acima do chão (o aro de areia fica em volta); a peça azul some.
	for _, pond in PONDS do
		local c = polar(pond[1], pond[2], 0)
		terrain:FillCylinder(CFrame.new(c.X, -1.6, c.Z), 4, pond[3], Enum.Material.Water)
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "PondWater" then
			d.Transparency = 1
		end
	end
	-- O mar distante (peça) fica com a mesma cor da água e um pouco de brilho.
	local far = map:FindFirstChild("FarSea", true)
	if far and far:IsA("BasePart") then
		far.Color = Color3.fromRGB(30, 120, 180)
		far.Material = Enum.Material.Glass
		far.Transparency = 0.1
	end
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

local function plaque(pedestal: BasePart, sp: Config.SpeciesDef)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = pedestal
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.5)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 240, 200)
	title.TextStrokeTransparency = 0.3
	title.Text = Locale.upper(sp.name)
	title.Parent = sg
	local price = title:Clone()
	price.Position = UDim2.fromScale(0, 0.5)
	price.TextColor3 = if sp.robux then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 210, 60)
	price.Text = if sp.robux
		then "PASSE (ROBUX)"
		elseif sp.price <= 0 then "INICIAL"
		else Util.formatNumber(sp.price) .. " moedas"
	price.Parent = sg
end

local function statues(map: Instance, template: (string) -> Model?)
	local old = Workspace:FindFirstChild("GiantStatues")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "GiantStatues"
	-- 12 lugares: pares (±8°) no meio entre os caminhos das bases, menos o vão da estrada da arena
	-- (22,5°). Caminhos a cada 45° a partir de 90°.
	local angles = {}
	for k = 0, 7 do
		local mid = 22.5 + k * 45
		if math.abs(mid - 22.5) > 1 and #angles < 12 then
			table.insert(angles, mid - 8)
			table.insert(angles, mid + 8)
		end
	end
	local list = Config.Species
	for i, sp in list do
		local phi = angles[i]
		if not phi then
			break
		end
		local pos = polar(phi, STATUE_R, 0)
		local face = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
		-- Abre espaço: tira árvores/pedras da natureza que caíram no lugar da estátua.
		local nature = map:FindFirstChild("Nature")
		if nature then
			for _, d in nature:GetChildren() do
				local ok, pivot = pcall(function()
					return (d :: any):GetPivot()
				end)
				if ok and (Vector3.new(pivot.Position.X, 0, pivot.Position.Z) - pos).Magnitude < 12 then
					d:Destroy()
				end
			end
		end
		local model = Instance.new("Model")
		model.Name = "Statue_" .. sp.id
		local gold = sp.robux
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Size = Vector3.new(12, 5, 12)
		pedestal.CFrame = face * CFrame.new(0, 2.5, 0)
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.Marble
		pedestal.Color = Color3.fromRGB(225, 220, 210)
		pedestal.Parent = model
		local trim = pedestal:Clone()
		trim.Name = "Trim"
		trim.Size = Vector3.new(13, 1, 13)
		trim.CFrame = face * CFrame.new(0, 5.2, 0)
		trim.Color = if gold then Color3.fromRGB(245, 195, 60) else Color3.fromRGB(150, 145, 160)
		trim.Material = if gold then Enum.Material.Foil else Enum.Material.Slate
		trim.Parent = model
		plaque(pedestal, sp)
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
			s:PivotTo(face * CFrame.new(0, 5.7, 0) * CFrame.Angles(0, math.pi + yaw, 0) * offset:Inverse())
			for _, d in s:GetDescendants() do
				if d:IsA("MeshPart") then
					d.TextureID = "" -- estátua: pedra/ouro, sem a pintura da criatura
				end
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.Material = if gold then Enum.Material.Foil else Enum.Material.Marble
					d.Color = if gold then Color3.fromRGB(245, 195, 60) else Color3.fromRGB(205, 200, 195)
				end
			end
			s.Parent = model
		end
		model.Parent = folder
	end
	folder.Parent = Workspace
end

function WorldFx.init(template: (string) -> Model?)
	local map = Workspace:WaitForChild("Map", 60)
	if not map then
		return
	end
	for name, step in { ["água"] = water, ["caldeirão"] = cauldron } :: { [string]: (Instance) -> () } do
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
