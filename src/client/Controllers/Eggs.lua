--!strict
-- Eggs — cliente do Sistema de Ovos (Features.EggSystem; o servidor só manda dados com a função ligada).
--   * Janela "NINHO DE OVOS": lugares do ninho (tempo, ALIMENTAR, CHOCAR), ovos guardados (COLOCAR),
--     loja de moedas (Pequeno e Médio) e CHANCES por espécie (EggOdds, a mesma tabela do servidor).
--   * Os ovos do PRÓPRIO jogador aparecem no ninho da praça, com cronômetro e efeito por raridade
--     (Features.EggVFX). Cada jogador vê os seus (o ninho é compartilhado).
--   * Eclosão: o servidor já entregou e salvou o gigante; aqui só a animação (3 a 5 s pela raridade).
-- Orçamento de efeito (vault "ParticleEmitter - Engine Reference Card", "Juice on a Budget"): no máximo
-- ~30 partículas vivas por ovo (Rate x Lifetime), sem Bloom, respeita "movimento reduzido".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local EggOdds = require(game.ReplicatedStorage.Shared.EggOdds)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)

local E = GameRules.Eggs

local Eggs = {}

type Slot = { size: string, hatchAt: number, fed: boolean, warmed: boolean }
type State = {
	eggs: { string },
	nest: { [string]: Slot },
	slots: number,
	now: number,
	commonFood: number,
	coins: number,
	open: boolean?,
}

local state: State? = nil
local clockOffset = 0 -- servidor - cliente (os.time)
local win: Frame
local body: Frame
local listFrame: ScrollingFrame
local oddsLabel: TextLabel

local function serverNow(): number
	return os.time() + clockOffset
end

-- Ovos v2: estrelas de cuidado (alimentado, aquecido, laço com o gigante). Mesma regra do servidor
-- (GameLogic.eggStars); aqui só para mostrar.
local starsOf = EggOdds.stars

local function starText(n: number): string
	return string.rep("★", n) .. string.rep("☆", 3 - n)
end

local function clockText(s: number): string
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Texto do lugar do ninho: tempo + o que falta para cada estrela.
local function slotText(slot: { [string]: any }, now: number): string
	local def = E.Sizes[slot.size]
	local left = slot.hatchAt - now
	local stars = starsOf(slot)
	local head = string.format("%s  %s", def.name, starText(stars))
	if left <= 0 then
		return head .. string.format("\nPRONTO PARA CHOCAR!  (+%d nível por estrela)", stars)
	end
	local need = E.BondFeeds[slot.size] or 0
	return string.format(
		"%s\nChoca em %s  ·  %s  ·  %s  ·  %s",
		head,
		clockText(left),
		if slot.fed then "alimentado ★" else "dê 1 comida Comum",
		if slot.warmed then "aquecido ★" else "fique perto 30 s",
		if (slot.bond or 0) >= need
			then "laço ★"
			else string.format("alimente seu gigante %d/%d", slot.bond or 0, need)
	)
end

local function rarityColor(size: string): Color3
	return Config.Rarities[E.Sizes[size].rarity].color
end

---------------------------------------------------------------------------
-- Miniatura 3D do ovo (ViewportFrame)
---------------------------------------------------------------------------
local function eggTemplate(size: string): MeshPart?
	local folder = ReplicatedStorage:FindFirstChild("EggModels")
	local m = folder and folder:FindFirstChild(size)
	return if m and m:IsA("MeshPart") then m else nil
end

local function eggView(parent: GuiObject, size: string, props: { [string]: any }): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.fromRGB(255, 245, 230)
	vf.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in props do
		(vf :: any)[k] = v
	end
	vf.Parent = parent
	local t = eggTemplate(size)
	if t then
		local m = t:Clone()
		m.CFrame = CFrame.new(0, 0, 0)
		m.Parent = vf
		local cam = Instance.new("Camera")
		local h = m.Size.Y
		cam.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.1, h * 1.9), Vector3.new(0, 0, 0))
		cam.FieldOfView = 40
		cam.Parent = vf
		vf.CurrentCamera = cam
	else
		UI.label(vf, "OVO", { Size = UDim2.fromScale(1, 1), TextColor3 = rarityColor(size) })
	end
	return vf
end

---------------------------------------------------------------------------
-- Efeito por raridade (mundo)
---------------------------------------------------------------------------
local VFX = {
	Common = { color = Color3.fromRGB(120, 230, 120), rate = 4, life = 1.5, light = 0.6, beams = 0 },
	Rare = { color = Color3.fromRGB(80, 160, 255), rate = 6, life = 2, light = 1.0, beams = 0 },
	Epic = { color = Color3.fromRGB(180, 90, 255), rate = 8, life = 2, light = 1.4, beams = 1 },
	Legendary = { color = Color3.fromRGB(255, 200, 60), rate = 10, life = 2, light = 1.8, beams = 2 },
	Mythic = { color = Color3.fromRGB(255, 120, 220), rate = 12, life = 2.5, light = 2.2, beams = 3 },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})

local function addVfx(part: BasePart, rarity: string)
	local v = (VFX :: any)[rarity] or VFX.Common
	local att = Instance.new("Attachment")
	att.Name = "EggFx"
	att.Parent = part
	local seq = if rarity == "Mythic" then RAINBOW else ColorSequence.new(v.color)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = seq
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new(0.35, 0)
	pe.Lifetime = NumberRange.new(v.life * 0.7, v.life)
	pe.Rate = v.rate -- vivas no máximo: rate x lifetime <= 30
	pe.Speed = NumberRange.new(0.6, 1.6)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = att
	local light = Instance.new("PointLight")
	light.Color = v.color
	light.Brightness = v.light
	light.Range = 8
	light.Shadows = false
	light.Parent = part
	-- feixes verticais (Épico ou melhor)
	for i = 1, v.beams do
		local a0 = Instance.new("Attachment")
		local ang = (i - 1) * (math.pi * 2 / v.beams)
		a0.Position = Vector3.new(math.cos(ang) * 0.6, -part.Size.Y * 0.3, math.sin(ang) * 0.6)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = a0.Position + Vector3.new(0, 7, 0)
		a1.Parent = part
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = seq
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 0.5
		beam.Width1 = 0.05
		beam.Transparency = NumberSequence.new(0.45, 1)
		beam.FaceCamera = true
		beam.Parent = part
	end
end

---------------------------------------------------------------------------
-- Ovos no ninho (só os do jogador local)
---------------------------------------------------------------------------
local worldEggs: { [string]: { part: BasePart, label: TextLabel, size: string, spin: number } } = {}

-- 09/11 (Features.EggSteal): os ovos moram no ninho da SUA base. Sem ele (flag desligada ou base
-- ainda não carregada), usa o ninho da praça como antes.
local function myNest(): Model?
	if Features.on("EggSteal") then
		local folder = Workspace:FindFirstChild("BaseNests")
		if folder then
			for _, m in folder:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
					return m
				end
			end
		end
	end
	local plaza = Workspace:FindFirstChild("EggNest")
	return if plaza and plaza:IsA("Model") then plaza else nil
end

-- O servidor mostra os ovos de cada base para TODOS (para poder roubar); na minha base eu já vejo a
-- versão do cliente (com efeitos), então a do servidor fica invisível só para mim.
local hidden: { [Instance]: boolean } = {}
local function hideServerCopies(nest: Model)
	local eggs = nest:FindFirstChild("Eggs")
	if not eggs or hidden[eggs] then
		return
	end
	hidden[eggs] = true
	local function hide(inst: Instance)
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
	end
	hide(eggs)
	eggs.DescendantAdded:Connect(function(d)
		task.defer(function()
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end)
	end)
end

local function nestOffsets(): { Vector3 }
	local nest = myNest()
	local raw = nest and nest:GetAttribute("SlotOffsets")
	local out = {}
	if type(raw) == "string" then
		for chunk in string.gmatch(raw, "[^;]+") do
			local x, y, z = string.match(chunk, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
			table.insert(out, Vector3.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0))
		end
	end
	return out
end

local renderedAt: Model? = nil
local function renderNest()
	local st = state
	local nest = myNest()
	local center = nest and nest:FindFirstChild("Center")
	if nest and nest.Name ~= "EggNest" then
		hideServerCopies(nest)
	end
	-- mudou de ninho (a base carregou depois): redesenha tudo no lugar novo
	if nest ~= renderedAt then
		for key, w in worldEggs do
			w.part:Destroy()
			worldEggs[key] = nil
		end
		renderedAt = nest
	end
	for key, w in worldEggs do
		local slot = st and st.nest[key]
		if not slot or slot.size ~= w.size then
			w.part:Destroy()
			worldEggs[key] = nil
		end
	end
	if not st or not center or not center:IsA("BasePart") then
		return
	end
	local offsets = nestOffsets()
	for key, slot in st.nest do
		if not worldEggs[key] then
			local t = eggTemplate(slot.size)
			local part: BasePart
			if t then
				part = t:Clone()
				local big = nest and nest:GetAttribute("EggScale")
				local k = E.Sizes[slot.size].scale
					* (if type(big) == "number" then big else 1)
					/ math.max(t.Size.Y, 0.01)
				part.Size = t.Size * k
			else
				part = Util.makePart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 3, 2.4) })
				part.Color = rarityColor(slot.size)
			end
			part.Name = "MyEgg_" .. key
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local off = offsets[tonumber(key) or 1] or Vector3.zero
			part.CFrame = CFrame.new(center.Position + off + Vector3.new(0, part.Size.Y / 2, 0))
			part.Parent = Workspace
			if Features.on("EggVFX") then
				addVfx(part, E.Sizes[slot.size].rarity)
			end
			local label = Util.makeBillboard(
				part,
				"",
				UDim2.fromOffset(180, 40),
				Vector3.new(0, part.Size.Y * 0.5 + 1.5, 0),
				rarityColor(slot.size)
			)
			worldEggs[key] = { part = part, label = label, size = slot.size, spin = 0 }
		end
	end
end

---------------------------------------------------------------------------
-- Janela
---------------------------------------------------------------------------
local function clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function section(text: string, order: number)
	UI.label(listFrame, text, {
		Size = UDim2.new(1, -10, 0, 34),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 13,
	})
end

local function row(order: number, h: number): Frame
	local f = UI.frame(listFrame, {
		Size = UDim2.new(1, -10, 0, h),
		LayoutOrder = order,
		BackgroundColor3 = UI.Colors.Panel2,
		ZIndex = 13,
	})
	return f
end

local function smallButton(parent: GuiObject, text: string, color: Color3, x: number, w: number, cb: () -> ())
	local b = UI.button(parent, text, color, {
		Size = UDim2.fromOffset(w, 48),
		Position = UDim2.new(1, x, 0.5, -24),
		TextScaled = false,
		TextSize = 20,
		ZIndex = 15,
	})
	b.Activated:Connect(cb)
	return b
end

local function showOdds(size: string)
	local parts = {}
	for _, e in EggOdds.odds(size) do
		local sp = Config.SpeciesById[e.id]
		table.insert(parts, string.format("%s %s", sp and sp.name or e.id, EggOdds.format(e.p)))
	end
	oddsLabel.Text = string.format(
		"CHANCES — %s (nasce no nível %d):  %s.  Valores arredondados.",
		E.Sizes[size].name,
		E.Sizes[size].level,
		table.concat(parts, " · ")
	)
	oddsLabel.Visible = true
end

local function render()
	local st = state
	if not st or not listFrame then
		return
	end
	clear(listFrame)
	local now = serverNow()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	section(string.format("NINHO (%d de 3 lugares abertos)", st.slots), nextOrder())
	for i = 1, 3 do
		local key = tostring(i)
		local r = row(nextOrder(), 96)
		if i > st.slots then
			UI.label(r, string.format("Lugar %d: abre no nível %d", i, E.SlotLevels[i]), {
				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = 0.4,
				TextScaled = false,
				TextSize = 22,
				ZIndex = 14,
			})
			continue
		end
		local slot = st.nest[key]
		if not slot then
			UI.label(r, string.format("Lugar %d: vazio — coloque um ovo", i), {
				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 22,
				ZIndex = 14,
			})
			continue
		end
		eggView(r, slot.size, { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(6, 6), ZIndex = 14 })
		local left = slot.hatchAt - now
		UI.label(r, slotText(slot, now), {
			Name = "Status_" .. key,
			Size = UDim2.new(1, -330, 1, -8),
			Position = UDim2.fromOffset(98, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextColor3 = rarityColor(slot.size),
			ZIndex = 14,
		})
		if left <= 0 then
			smallButton(r, "CHOCAR!", UI.Colors.Green, -190, 180, function()
				Remotes.RequestEgg:FireServer("hatch", key)
			end)
		elseif not slot.fed then
			smallButton(
				r,
				string.format("ALIMENTAR (%d)", st.commonFood),
				if st.commonFood > 0 then UI.Colors.Accent else Color3.fromRGB(96, 102, 118),
				-230,
				220,
				function()
					Remotes.RequestEgg:FireServer("feed", key)
				end
			)
		end
	end
	section(string.format("OVOS GUARDADOS (%d)", #st.eggs), nextOrder())
	if #st.eggs == 0 then
		UI.label(row(nextOrder(), 48), "Nenhum ovo guardado. Compre abaixo ou ganhe no Dragão.", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.3,
			TextScaled = false,
			TextSize = 20,
			ZIndex = 14,
		})
	end
	for i, size in st.eggs do
		local r = row(nextOrder(), 84)
		eggView(r, size, { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(6, 6), ZIndex = 14 })
		UI.label(
			r,
			string.format(
				"%s  ·  %s  ·  nível %d",
				E.Sizes[size].name,
				clockText(E.Sizes[size].seconds),
				E.Sizes[size].level
			),
			{
				Size = UDim2.new(1, -300, 1, 0),
				Position = UDim2.fromOffset(86, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 20,
				TextColor3 = rarityColor(size),
				ZIndex = 14,
			}
		)
		smallButton(r, "COLOCAR", UI.Colors.Blue, -190, 180, function()
			Remotes.RequestEgg:FireServer("place", i)
		end)
	end
	section("LOJA DE OVOS (moedas)", nextOrder())
	for _, size in E.Order do
		local def = E.Sizes[size]
		if def.price then
			local r = row(nextOrder(), 84)
			eggView(r, size, { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(6, 6), ZIndex = 14 })
			UI.label(r, string.format("%s  ·  nasce no nível %d", def.name, def.level), {
				Size = UDim2.new(1, -420, 1, 0),
				Position = UDim2.fromOffset(86, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 20,
				TextColor3 = rarityColor(size),
				ZIndex = 14,
			})
			smallButton(r, "CHANCES", UI.Colors.Blue, -330, 140, function()
				showOdds(size)
			end)
			smallButton(
				r,
				Util.formatNumber(def.price) .. " $",
				if st.coins >= def.price then UI.Colors.Accent else Color3.fromRGB(96, 102, 118),
				-180,
				170,
				function()
					Remotes.RequestEgg:FireServer("buy", size)
				end
			)
		end
	end
	UI.label(
		row(nextOrder(), 60),
		"Ovos Grande, Enorme e Colossal: prêmio do Dragão (1 por dia) e dos níveis 100 e 200.",
		{
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 18,
			TextTransparency = 0.3,
			ZIndex = 14,
		}
	)
end

---------------------------------------------------------------------------
-- Eclosão (animação depois que o servidor já entregou)
---------------------------------------------------------------------------
local hatchGui: Frame
local hatchQueue: { { [string]: any } } = {}
local hatchRunning = false

-- Fragmentos visuais 2D: não exige malha rachada adicional, nem uploads externos.
local function hatchShards(parent: Frame, color: Color3, amount: number)
	local uiScale = UI.deviceScale()
	for i = 1, amount do
		local angle = (i / amount) * math.pi * 2
		local shard = Instance.new("Frame")
		shard.Size = UDim2.fromOffset(
			math.max(4, math.floor((if i % 3 == 0 then 13 else 8) * uiScale)),
			math.max(6, math.floor((if i % 3 == 0 then 20 else 12) * uiScale))
		)
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.Position = UDim2.fromScale(0.5, 0.44)
		shard.Rotation = math.deg(angle)
		shard.BorderSizePixel = 0
		shard.BackgroundColor3 = color
		shard.ZIndex = 44
		shard.Parent = parent
		TweenService:Create(shard, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(
				0.5, math.cos(angle) * (130 + (i % 3) * 26) * uiScale,
				0.44, math.sin(angle) * (100 + (i % 4) * 16) * uiScale
			),
			BackgroundTransparency = 1,
			Rotation = shard.Rotation + 100,
		}):Play()
		task.delay(0.75, function()
			shard:Destroy()
		end)
	end
end

local function playHatch(data: { [string]: any })
	local size = data.size
	if type(size) ~= "string" or not E.Sizes[size] then
		return
	end
	local def = E.Sizes[size]
	local order = Config.Rarities[def.rarity].order
	local color = rarityColor(size)
	local reduced = UI.reducedMotion()
	local uiScale = UI.deviceScale()
	-- A animação inteira leva ~4 s; não prende o jogador em ~8 s de tela.
	local crackTime = if reduced then 0.15 else math.clamp(1.1 + order * 0.18, 1.4, 2.2)
	clear(hatchGui)
	hatchGui.Visible = true
	hatchGui.BackgroundTransparency = 1 -- mundo sempre visível, sem overlay escuro
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.44)
	ring.Size = UDim2.fromOffset(320 * uiScale, 320 * uiScale)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 40
	ring.Parent = hatchGui
	UI.corner(ring, 160)
	UI.stroke(ring, color, 4)
	local vf = eggView(hatchGui, size, {
		Size = UDim2.fromOffset(300 * uiScale, 300 * uiScale),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 41,
	})
	local headline = UI.title(hatchGui, "CHOCANDO " .. string.upper(def.name) .. "...", {
		Size = UDim2.new(0.9, 0, 0, 50),
		Position = UDim2.fromScale(0.5, 0.17),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = color,
		ZIndex = 44,
	})
	if not reduced then
		TweenService:Create(vf, TweenInfo.new(crackTime, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(340 * uiScale, 340 * uiScale),
		}):Play()
	end
	local cracks = 0
	local function crack()
		cracks += 1
		local line = Instance.new("Frame")
		line.Size = UDim2.fromOffset((72 - cracks * 10) * uiScale, math.max(2, 5 * uiScale))
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(0.5, (cracks - 2) * 18 * uiScale, 0.44, (cracks - 2) * 25 * uiScale)
		line.Rotation = if cracks == 2 then 24 else -40
		line.BackgroundColor3 = Color3.fromRGB(35, 27, 42)
		line.BorderSizePixel = 0
		line.ZIndex = 43
		line.Parent = hatchGui
		UI.stroke(line, color, 1)
		UI.sfx("Whoosh", 0.35)
	end
	if reduced then
		crack()
		UI.sfx("Bell", 0.45)
		task.wait(crackTime)
	else
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / crackTime, 0, 1)
			vf.Rotation = math.sin(os.clock() * (9 + 32 * k)) * (3 + 14 * k)
			if cracks == 0 and k >= 0.32 then
				crack()
			elseif cracks == 1 and k >= 0.61 then
				crack()
			elseif cracks == 2 and k >= 0.84 then
				crack()
			end
		end)
		task.wait(crackTime)
		conn:Disconnect()
	end
	vf:Destroy()
	ring:Destroy()
	headline:Destroy()
	if not reduced then
		hatchShards(hatchGui, color, if order >= 4 then 18 else 10)
	end
	UI.sfx(if order >= 4 then "Evolve" else "Bell", if order >= 4 then 0.9 else 0.65)
	local sp = if type(data.speciesId) == "string" then Config.SpeciesById[data.speciesId] else nil
	local st = math.clamp(tonumber(data.stars) or 0, 0, 3)
	local title = UI.title(hatchGui, (if data.duplicate then "GIGANTE REPETIDO" else "NOVO GIGANTE!") .. "  " .. starText(st), {
		Size = UDim2.new(0.9, 0, 0, 66),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = color,
		ZIndex = 45,
	})
	local line = if data.duplicate
		then string.format(
			"%s ganhou %s XP · nível %d",
			sp and sp.name or "?",
			Util.formatNumber(tonumber(data.xp) or 0),
			tonumber(data.level) or 1
		)
		else string.format("%s nasceu no nível %d!", sp and sp.name or "?", tonumber(data.level) or 1)
	UI.label(hatchGui, line, {
		Size = UDim2.new(0.9, 0, 0, 50),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 45,
	})
	if not reduced then
		UI.pop(title)
	end
	task.wait(if reduced then 1.4 else 2)
	hatchGui.Visible = false
	clear(hatchGui)
end

---------------------------------------------------------------------------
function Eggs.init(gui: ScreenGui)
	win, body = UI.window(gui, "NINHO DE OVOS", UDim2.fromOffset(820, 600))
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, 0, 1, -64)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.ZIndex = 12
	listFrame.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame
	oddsLabel = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.new(0, 0, 1, -60),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 14,
	})

	hatchGui = Instance.new("Frame")
	hatchGui.Name = "EggHatch"
	hatchGui.Size = UDim2.fromScale(1, 1)
	hatchGui.BackgroundColor3 = Color3.new(0, 0, 0)
	hatchGui.BackgroundTransparency = 0.8
	hatchGui.Visible = false
	hatchGui.ZIndex = 40
	hatchGui.Parent = gui

	Remotes.EggState.OnClientEvent:Connect(function(st: any)
		if type(st) ~= "table" then
			return
		end
		clockOffset = (tonumber(st.now) or os.time()) - os.time()
		state = st
		renderNest()
		if st.open and not win.Visible then
			oddsLabel.Visible = false
			UI.pop(win)
		end
		if win.Visible then
			render()
		end
	end)
	Remotes.EggHatched.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			win.Visible = false
			-- fila: uma eclosão por vez (dois CHOCAR seguidos não sobrepõem as animações)
			table.insert(hatchQueue, data)
			if not hatchRunning then
				hatchRunning = true
				task.spawn(function()
					while #hatchQueue > 0 do
						local nextData = table.remove(hatchQueue, 1)
						if nextData then
							playHatch(nextData)
						end
					end
					hatchRunning = false
				end)
			end
		end
	end)
	-- cronômetros: 1 vez por segundo (janela e etiquetas no mundo); giro leve dos ovos raros
	task.spawn(function()
		while true do
			task.wait(1)
			local st = state
			if st then
				local now = serverNow()
				for key, w in worldEggs do
					local slot = st.nest[key]
					if slot then
						local left = slot.hatchAt - now
						w.label.Text = if left <= 0 then "PRONTO!" else clockText(left)
					end
				end
				if win.Visible then
					for key, slot in st.nest do
						local lbl = listFrame:FindFirstChild("Status_" .. key, true)
						if lbl and lbl:IsA("TextLabel") then
							local left = slot.hatchAt - now
							if left <= 0 and not string.find(lbl.Text, "PRONTO") then
								render()
								break
							end
							lbl.Text = slotText(slot, now)
						end
					end
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if UI.reducedMotion() then
			return
		end
		for _, w in worldEggs do
			local order = Config.Rarities[E.Sizes[w.size].rarity].order
			if order >= 4 then -- Épico ou melhor: rotação lenta (Mítico também pulsa)
				w.spin += dt * (0.4 + 0.1 * order)
				local base = w.part.CFrame.Position
				w.part.CFrame = CFrame.new(base) * CFrame.Angles(0, w.spin, 0)
			end
		end
	end)
end

return Eggs
