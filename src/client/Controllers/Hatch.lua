--!strict
-- Hatch.lua — animação de abertura de Lunchbox: caixa balança, explode em partículas e revela a comida com cor da raridade.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)

local Hatch = {}

local overlay: Frame
local box: Frame
local reveal: Frame
local revealName: TextLabel
local revealRarity: TextLabel
local busy = false
local queue: { any } = {}

local SOUND_IDS = {
	shake = "rbxassetid://9114653986",
	pop = "rbxassetid://9114611543",
	rare = "rbxassetid://9114646405",
}

local function playSound(id: string, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function burst(parent: Frame, color: Color3, count: number)
	for _ = 1, count do
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(math.random(8, 18), math.random(8, 18))
		p.Position = UDim2.fromScale(0.5, 0.5)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.Rotation = math.random(0, 360)
		p.Parent = parent
		UI.corner(p, 4)
		local angle = math.random() * math.pi * 2
		local dist = math.random(160, 320)
		TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist),
			BackgroundTransparency = 1,
			Rotation = p.Rotation + math.random(-180, 180),
		}):Play()
		task.delay(1, function()
			p:Destroy()
		end)
	end
end

local function play(data: { foodId: string, rarity: string, name: string?, color: Color3? })
	busy = true
	local def = Config.FoodById[data.foodId]
	local rar = Config.Rarities[data.rarity] or Config.Rarities.Common
	local isBig = rar.order >= 4

	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()

	reveal.Visible = false
	box.Visible = true
	box.Rotation = 0
	box.Size = UDim2.fromOffset(0, 0)
	box.BackgroundColor3 = rar.color
	TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(160, 160) }):Play()
	task.wait(0.35)

	local shakes = isBig and 10 or 6
	for i = 1, shakes do
		local amp = 8 + i * (isBig and 3 or 2)
		TweenService:Create(box, TweenInfo.new(0.06), { Rotation = amp }):Play()
		task.wait(0.06)
		TweenService:Create(box, TweenInfo.new(0.06), { Rotation = -amp }):Play()
		task.wait(0.06)
		if i % 2 == 0 then
			playSound(SOUND_IDS.shake, 0.3)
		end
	end
	TweenService:Create(box, TweenInfo.new(0.1), { Rotation = 0, Size = UDim2.fromOffset(200, 200) }):Play()
	task.wait(0.12)

	box.Visible = false
	burst(overlay, rar.color, isBig and 60 or 28)
	playSound(isBig and SOUND_IDS.rare or SOUND_IDS.pop, isBig and 0.9 or 0.6)

	reveal.BackgroundColor3 = (def and def.color) or (data.color or rar.color)
	revealName.Text = (def and def.name) or (data.name or data.foodId)
	revealRarity.Text = string.upper(Locale.t(data.rarity))
	revealRarity.TextColor3 = rar.color
	reveal.Size = UDim2.fromOffset(0, 0)
	reveal.Visible = true
	TweenService:Create(
		reveal,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic),
		{ Size = UDim2.fromOffset(isBig and 300 or 240, isBig and 300 or 240) }
	):Play()

	task.wait(isBig and 2.2 or 1.4)
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(reveal, TweenInfo.new(0.25), { Size = UDim2.fromOffset(0, 0) }):Play()
	task.wait(0.28)
	overlay.Visible = false
	busy = false
end

local function pump()
	while #queue > 0 do
		local data = table.remove(queue, 1)
		if data then
			play(data)
		end
	end
end

function Hatch.init(gui: ScreenGui)
	overlay = Instance.new("Frame")
	overlay.Name = "HatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 50
	overlay.Parent = gui

	box = UI.frame(overlay, {
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 51,
	})
	UI.corner(box, 20)
	UI.stroke(box, Color3.new(0, 0, 0), 4)
	local lid = UI.frame(box, {
		Size = UDim2.new(1, 16, 0, 36),
		Position = UDim2.fromOffset(-8, -10),
		BackgroundColor3 = Color3.fromRGB(40, 40, 60),
		ZIndex = 52,
	})
	UI.corner(lid, 10)
	UI.label(
		box,
		"?",
		{ Size = UDim2.fromScale(1, 1), ZIndex = 53, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.4 }
	)

	reveal = UI.frame(overlay, {
		Size = UDim2.fromOffset(240, 240),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 51,
	})
	UI.corner(reveal, 28)
	UI.stroke(reveal, Color3.new(1, 1, 1), 4)
	revealName =
		UI.label(reveal, "", { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -96), ZIndex = 52 })
	revealRarity =
		UI.label(reveal, "", { Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -50), ZIndex = 52 })

	Remotes.HatchResult.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.foodId) == "string" then
			table.insert(queue, data)
			if not busy then
				task.spawn(pump)
			end
		end
	end)
end

return Hatch
