--!strict
-- Travel.lua — menu VIAGEM RÁPIDA (pedido do usuário, 09/11/2026, itens 1, 5 e 6).
-- Abre quando o jogador pisa num blip (círculo brilhante). Um botão grande por lugar, com a cor do
-- blip de lá. O servidor confere tudo; aqui só o menu, o escurecer da tela e o aviso do turbo.
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)

local Travel = {}

local win: Frame
local list: Frame
local fade: Frame
local turboChip: TextLabel
local lastTurbo = 0

local function rebuild(spots: { any })
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, s in spots do
		if type(s) ~= "table" or type(s.id) ~= "string" then
			continue
		end
		local color = if typeof(s.color) == "Color3" then s.color else UI.Colors.Accent
		local b = UI.button(list, tostring(s.name), color, {
			Size = UDim2.new(1, -8, 0, 56),
			LayoutOrder = i,
			TextScaled = false,
			TextSize = 24,
		})
		-- pedido do usuário (09/11): texto BRANCO com contorno escuro (antes era preto)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		b.TextStrokeTransparency = 0.2
		b.Activated:Connect(function()
			win.Visible = false
			Remotes.RequestTravel:FireServer(s.id)
		end)
	end
end

local function doFade()
	fade.Visible = true
	fade.BackgroundTransparency = 1
	TweenService:Create(fade, TweenInfo.new(0.22), { BackgroundTransparency = 0 }):Play()
	UI.sfx("Whoosh", 0.6)
	task.delay(0.45, function()
		local t = TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		fade.Visible = false
	end)
end

local function showTurbo()
	local now = os.clock()
	if now - lastTurbo < 6 then
		return
	end
	lastTurbo = now
	turboChip.Visible = true
	UI.pop(turboChip)
	task.delay(2.2, function()
		turboChip.Visible = false
	end)
end

function Travel.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "VIAGEM RÁPIDA", UDim2.fromOffset(420, 470))
	UI.label(body, "Para onde você quer ir?", {
		Size = UDim2.new(1, 0, 0, 30),
		TextScaled = false,
		TextSize = 22,
		TextColor3 = UI.Colors.Accent,
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -38)
	scroll.Position = UDim2.fromOffset(0, 36)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	list = UI.frame(scroll, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list

	fade = Instance.new("Frame")
	fade.Name = "TravelFade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 90
	fade.Visible = false
	fade.Parent = gui

	turboChip = UI.label(gui, "TURBO DA PONTE!  >>>", {
		Size = UDim2.fromOffset(320, 48),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.fromRGB(120, 220, 255),
		Visible = false,
		ZIndex = 40,
	})
	turboChip.TextStrokeTransparency = 0.2

	Remotes.TravelMenu.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.spots) == "table" then
			rebuild(data.spots)
			if not win.Visible then
				UI.pop(win)
			end
		end
	end)
	Remotes.TravelDone.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.turbo then
			showTurbo()
		else
			doFade()
		end
	end)
end

return Travel
