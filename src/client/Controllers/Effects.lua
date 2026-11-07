--!strict
-- Effects.lua — sons/visual de level-up e evolução de estágio (anel de luz no Gigante + banner).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)

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
	local colors = { UI.Colors.Accent, UI.Colors.Green, UI.Colors.Blue, UI.Colors.Purple, UI.Colors.Red, Color3.new(1, 1, 1) }
	for i = 1, n do
		local p = Instance.new("Frame")
		p.BackgroundColor3 = colors[(i % #colors) + 1]
		p.BorderSizePixel = 0
		p.Size = UDim2.fromOffset(10 + math.random(0, 8), 14 + math.random(0, 10))
		p.Position = UDim2.new(math.random(), 0, -0.1, 0)
		p.Rotation = math.random(0, 360)
		p.ZIndex = 45
		p.Parent = confettiHolder
		UI.corner(p, 3)
		local dur = 2.2 + math.random() * 1.6
		TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = UDim2.new(p.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0), Rotation = p.Rotation + math.random(-540, 540) }):Play()
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
			TweenService:Create(r, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.new(1, 1, 1) * (40 * s), Transparency = 1 }):Play()
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
	TweenService:Create(beam, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 400, 0.2), Transparency = 1 }):Play()
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
	TweenService:Create(r, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(0.5, 30 * s, 30 * s), Transparency = 1 }):Play()
	task.delay(1.3, function()
		r:Destroy()
	end)
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
	banner = UI.title(gui, "", { Size = UDim2.fromOffset(700, 60), Position = UDim2.new(0.5, 0, 0.18, 0), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = UI.Colors.Accent, Visible = false })
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
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) == "table" and e.leveled and e.userId == player.UserId then
			UI.sfx("LevelUp", 0.7)
			screenFlash(UI.Colors.Accent, 0.25)
			confetti(25)
		end
	end)
end

return Effects
