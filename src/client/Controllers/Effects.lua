--!strict
-- Effects.lua — sons/visual de level-up e evolução de estágio (anel de luz no Gigante + banner).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Config = require(game.ReplicatedStorage.Shared.Config)
local FoodView = require(script.Parent.Parent.FoodView)

local Effects = {}
local flash: Frame
local confettiHolder: Frame

local function screenFlash(color: Color3, strength: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	flash.Visible = true
	local t = TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	t:Play()
	t.Completed:Once(function()
		flash.Visible = false
	end)
end

local function confetti(n: number)
	local colors =
		{ UI.Colors.Accent, UI.Colors.Green, UI.Colors.Blue, UI.Colors.Purple, UI.Colors.Red, Color3.new(1, 1, 1) }
	for i = 1, n do
		local p = Instance.new("Frame")
		p.BackgroundColor3 = colors[(i % #colors) + 1]
		p.BorderSizePixel = 0
		p.Size = UDim2.fromOffset(10 + math.random(0, 8), 14 + math.random(0, 10))
		p.Position = UDim2.fromScale(math.random(), -0.1)
		p.Rotation = math.random(0, 360)
		p.ZIndex = 45
		p.Parent = confettiHolder
		UI.corner(p, 3)
		local dur = 2.2 + math.random() * 1.6
		TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(p.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1),
			Rotation = p.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(dur, function()
			p:Destroy()
		end)
	end
end
Effects.confetti = confetti
Effects.flash = screenFlash
local player = Players.LocalPlayer
local banner: TextLabel
Effects.playSound = nil :: ((string, number?) -> ())?
Effects.toast = nil :: ((string, Color3?) -> ())?

local function giantOf(userId: number): Model?
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == userId then
			return m
		end
	end
	return nil
end

local function shockwave(model: Model, color: Color3)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local s = model:GetScale()
	for k = 1, 3 do
		task.delay((k - 1) * 0.15, function()
			local r = Instance.new("Part")
			r.Shape = Enum.PartType.Ball
			r.Anchored = true
			r.CanCollide = false
			r.CanQuery = false
			r.Material = Enum.Material.ForceField
			r.Color = color
			r.Transparency = 0.1
			r.Size = Vector3.new(2, 2, 2)
			r.CFrame = CFrame.new(root.Position)
			r.Parent = Workspace
			TweenService:Create(
				r,
				TweenInfo.new(0.9, Enum.EasingStyle.Quad),
				{ Size = Vector3.new(1, 1, 1) * (40 * s), Transparency = 1 }
			):Play()
			task.delay(1, function()
				r:Destroy()
			end)
		end)
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.3
	beam.Size = Vector3.new(3 * s, 400, 3 * s)
	beam.CFrame = CFrame.new(root.Position + Vector3.new(0, 200, 0))
	beam.Parent = Workspace
	TweenService
		:Create(
			beam,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad),
			{ Size = Vector3.new(0.2, 400, 0.2), Transparency = 1 }
		)
		:Play()
	task.delay(1.7, function()
		beam:Destroy()
	end)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.Lifetime = NumberRange.new(1, 2)
	pe.Speed = NumberRange.new(20 * s, 40 * s)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(1.5 * s, 0)
	pe.Rate = 0
	pe.Parent = root
	pe:Emit(120)
	task.delay(3, function()
		pe:Destroy()
	end)
end

local function ring(model: Model, color: Color3)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.2
	local base = Vector3.new(root.Position.X, 1, root.Position.Z)
	r.Size = Vector3.new(0.5, 4, 4)
	r.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = Workspace
	local s = model:GetScale()
	TweenService
		:Create(
			r,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad),
			{ Size = Vector3.new(0.5, 30 * s, 30 * s), Transparency = 1 }
		)
		:Play()
	task.delay(1.3, function()
		r:Destroy()
	end)
end

-- Fogos de artifício (pedido do usuário): comida Épica ou melhor (ou o dragão derrotado) solta fogos
-- que TODO o servidor vê: em volta de quem achou e também perto da câmera de cada jogador.
-- Tudo local (peças só no cliente), poucas partículas, sem nada com "Movimento reduzido" além do brilho.
local FIREWORK_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(90, 255, 140),
	Color3.fromRGB(255, 120, 220),
}

local function rocket(from: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = "Firework"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Shape = Enum.PartType.Ball
	p.CFrame = CFrame.new(from)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), color)
	trail.LightEmission = 1
	trail.Lifetime = 0.5
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = p
	p.Parent = Workspace
	local height = 55 + math.random() * 35
	local top = from + Vector3.new(math.random(-12, 12), height, math.random(-12, 12))
	local up = TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(top),
	})
	up:Play()
	up.Completed:Once(function()
		p.Transparency = 1
		trail.Enabled = false
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		burst.LightEmission = 1
		burst.LightInfluence = 0
		burst.Size = NumberSequence.new(4, 0)
		burst.Lifetime = NumberRange.new(1.2, 1.8)
		burst.Speed = NumberRange.new(30, 45)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2.5
		burst.Acceleration = Vector3.new(0, -12, 0)
		burst.Rate = 0
		burst.Parent = p
		burst:Emit(110)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 60
		light.Brightness = 6
		light.Parent = p
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		UI.sfx("Whoosh", 0.25)
		task.delay(2.2, function()
			p:Destroy()
		end)
	end)
end

function Effects.fireworks(at: Vector3?, big: boolean)
	local spots: { Vector3 } = {}
	if at then
		table.insert(spots, at)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		-- à frente da câmera de quem está olhando, no chão
		local f = cam.CFrame.LookVector
		local ahead = cam.CFrame.Position + Vector3.new(f.X, 0, f.Z).Unit * 70
		table.insert(spots, Vector3.new(ahead.X, 2, ahead.Z))
	end
	local n = if big then 6 else 4
	for _, base in spots do
		for i = 1, n do
			task.delay((i - 1) * 0.35 + math.random() * 0.2, function()
				local c = FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]
				rocket(base + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20)), c)
			end)
		end
	end
end

function Effects.init(gui: ScreenGui)
	flash = Instance.new("Frame")
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.Visible = false
	flash.ZIndex = 48
	flash.Parent = gui
	confettiHolder = Instance.new("Frame")
	confettiHolder.BackgroundTransparency = 1
	confettiHolder.Size = UDim2.fromScale(1, 1)
	confettiHolder.ClipsDescendants = true
	confettiHolder.ZIndex = 45
	confettiHolder.Parent = gui
	banner = UI.title(gui, "", {
		Size = UDim2.fromOffset(700, 60),
		Position = UDim2.fromScale(0.5, 0.18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = UI.Colors.Accent,
		Visible = false,
	})
	Remotes.GiantEvolved.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		local m = giantOf(e.userId)
		if m then
			ring(m, Color3.fromRGB(255, 220, 80))
			ring(m, Color3.fromRGB(255, 255, 255))
			shockwave(m, Color3.fromRGB(255, 220, 80))
		end
		if e.userId == player.UserId then
			banner.Text = Locale.fmt("evolved_banner", nil, { s = string.upper(Locale.t(e.stageName)) })
			banner.Visible = true
			UI.pop(banner)
			screenFlash(Color3.new(1, 1, 1), 0.85)
			confetti(90)
			UI.sfx("Evolve", 1)
			UI.sfx("VO_Evolved", 1)
			task.delay(4, function()
				banner.Visible = false
			end)
		end
	end)
	-- Fase 3: faixa "comida rara" com a comida 3D (o servidor limita a 1 a cada 6 s). Quem achou já
	-- vê a abertura da caixa; os outros veem a faixa por 3,5 s, no alto, abaixo da faixa do tutorial.
	-- Fundo liso escuro (o painel 9-slice tem faixa dourada que escondia comidas douradas).
	local rare = UI.frame(gui, {
		Name = "RareBanner",
		BackgroundColor3 = Color3.fromRGB(22, 26, 64),
		Size = UDim2.fromOffset(640, 132),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 280),
		Visible = false,
		ZIndex = 30,
	})
	UI.autoScale(rare)
	UI.corner(rare, 22)
	local rareStroke = UI.stroke(rare, UI.Colors.Accent, 3)
	local rareView = Instance.new("Frame")
	rareView.BackgroundTransparency = 1
	rareView.Size = UDim2.fromOffset(116, 116)
	rareView.Position = UDim2.fromOffset(12, 8)
	rareView.ZIndex = 31
	rareView.Parent = rare
	local rareText = UI.label(rare, "", {
		Size = UDim2.new(1, -152, 0, 52),
		Position = UDim2.fromOffset(136, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	local rareSub = UI.label(rare, "", {
		Size = UDim2.new(1, -152, 0, 34),
		Position = UDim2.fromOffset(136, 76),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 24,
		ZIndex = 31,
	})
	local rareSerial = 0
	Remotes.RareFound.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or e.userId == player.UserId or type(e.foodId) ~= "string" then
			return
		end
		local def = Config.FoodById[e.foodId]
		local rar = def and Config.Rarities[def.rarity]
		if not def or not rar then
			return
		end
		rareSerial += 1
		local serial = rareSerial
		for _, c in rareView:GetChildren() do
			c:Destroy()
		end
		FoodView.create(rareView, def.id, { spin = true, zIndex = 32 })
		rareText.Text = Locale.fmt("rare_banner", nil, { p = tostring(e.name) })
		rareSub.Text = def.name .. "  ·  " .. Locale.upper(Locale.rarity(def.rarity))
		rareSub.TextColor3 = rar.color
		rareStroke.Color = rar.color
		-- logo abaixo das faixas do tutorial (objetivo + dica, ~100 px sem escala)
		rare.Position = UDim2.new(0.5, 0, 0, math.floor(8 + 168 * UI.deviceScale() + 100))
		rare.Visible = true
		UI.pop(rare)
		UI.sfx("Win", 0.5)
		task.delay(3.5, function()
			if rareSerial == serial then
				rare.Visible = false
				for _, c in rareView:GetChildren() do
					c:Destroy()
				end
			end
		end)
	end)
	Remotes.Fireworks.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		local pos = if typeof(e.pos) == "Vector3" then e.pos else nil
		Effects.fireworks(pos, e.big == true)
		local def = if type(e.foodId) == "string" then Config.FoodById[e.foodId] else nil
		if def and type(e.name) == "string" and Effects.toast then
			Effects.toast(
				Locale.fmt("fireworks_msg", nil, { p = e.name, f = def.name, r = Locale.rarity(def.rarity) }),
				Config.Rarities[def.rarity].color
			)
		end
	end)
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) == "table" and e.leveled and e.userId == player.UserId then
			UI.sfx("LevelUp", 0.7)
			screenFlash(UI.Colors.Accent, 0.25)
			confetti(25)
		end
	end)
end

return Effects
