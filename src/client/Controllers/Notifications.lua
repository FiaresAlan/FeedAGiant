--!strict
-- Notifications.lua — toasts empilhados, banner de evento global com contagem e alerta de roubo.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Config = require(game.ReplicatedStorage.Shared.Config)

local Notifications = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local stack: Frame
local banner: Frame
local bannerLabel: TextLabel
local bannerTimer: TextLabel
local activeEventEnd = 0
local activeName = ""
local activeColor = Color3.new(1, 1, 1)
-- Próximo evento anunciado pelo servidor (os.time do início). Pedido do usuário (08/11): ver a
-- contagem "vai começar em X minutos" para criar expectativa.
local nextAt = 0
local nextName = ""
local nextColor = Color3.new(1, 1, 1)
local bannerStroke: UIStroke

local MAX_TOASTS = 5

local function pushToast(text: string, color: Color3?, duration: number?)
	local toast = UI.frame(stack, {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = -os.clock(),
	})
	UI.stroke(toast, color or UI.Colors.Accent, 2)
	UI.label(toast, text, {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or UI.Colors.Text,
	})
	toast.Position = UDim2.fromOffset(300, 0)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play()

	while #stack:GetChildren() > MAX_TOASTS + 1 do
		local oldest: GuiObject? = nil
		for _, c in stack:GetChildren() do
			if c:IsA("Frame") and (oldest == nil or c.LayoutOrder > oldest.LayoutOrder) then
				oldest = c
			end
		end
		if oldest then
			oldest:Destroy()
		else
			break
		end
	end

	task.delay(duration or 4, function()
		if toast.Parent then
			local t = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			toast:Destroy()
		end
	end)
end

function Notifications.toast(text: string, color: Color3?, duration: number?)
	pushToast(text, color, duration)
end

local function mmss(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- Um só laço atualiza o chip: evento ativo (cor do evento) ou contagem do próximo.
local function tickBanner()
	if os.clock() < activeEventEnd then
		banner.Visible = true
		banner.BackgroundColor3 = activeColor:Lerp(Color3.new(0, 0, 0), 0.35)
		bannerStroke.Color = activeColor
		bannerLabel.Text = Locale.fmt("event_now", nil, { e = Locale.upper(Locale.t(activeName)) })
		bannerTimer.Text = mmss(activeEventEnd - os.clock())
		bannerTimer.TextColor3 = Color3.new(1, 1, 1)
	elseif nextAt > 0 then
		local left = nextAt - os.time()
		banner.Visible = true
		banner.BackgroundColor3 = UI.Colors.Panel
		bannerLabel.Text = Locale.fmt("next_event", nil, { e = Locale.t(nextName) })
		bannerTimer.Text = mmss(left)
		-- Último minuto: o chip pisca na cor do evento (expectativa), menos com "Movimento reduzido".
		local urgent = left <= 60
		bannerStroke.Color = if urgent then nextColor else Color3.fromRGB(90, 100, 170)
		bannerTimer.TextColor3 = if urgent then nextColor else UI.Colors.Accent
		if urgent and not UI.reducedMotion() and left % 2 == 0 then
			banner.BackgroundColor3 = nextColor:Lerp(Color3.new(0, 0, 0), 0.55)
		end
	else
		banner.Visible = false
	end
end

local function showBanner(name: string, duration: number, color: Color3)
	activeEventEnd = os.clock() + duration
	activeName = name
	activeColor = color
	tickBanner()
	UI.pop(banner)
end

local function hideBanner()
	activeEventEnd = 0
	tickBanner()
end

local function stealAlert(thiefName: string, food: string)
	pushToast(Locale.fmt("steal_alert", nil, { p = thiefName, f = food }), UI.Colors.Red, 6)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = UI.Colors.Red
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.ZIndex = 0
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(0.9, function()
		flash:Destroy()
	end)
end

function Notifications.init(parentGui: ScreenGui)
	gui = parentGui

	stack = UI.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(320, 300),
		Position = UDim2.new(1, -16, 0, 90),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = stack

	-- Chip do evento no canto superior esquerdo (antes ficava no meio do topo, em cima da HUD).
	banner = UI.frame(gui, {
		Name = "EventBanner",
		Size = UDim2.fromOffset(520, 60),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
	})
	UI.autoScale(banner)
	UI.corner(banner, 16)
	bannerStroke = UI.stroke(banner, Color3.fromRGB(90, 100, 170), 3)
	bannerLabel = UI.label(banner, "", {
		Size = UDim2.new(1, -112, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 24,
		TextWrapped = true,
	})
	bannerTimer = UI.title(banner, "0:00", {
		Size = UDim2.fromOffset(96, 48),
		Position = UDim2.new(1, -104, 0, 6),
	})
	-- HUD nova: a coluna da esquerda é das estatísticas; o chip do evento fica no meio do topo.
	task.spawn(function()
		while true do
			tickBanner()
			task.wait(1)
		end
	end)
	Remotes.EventSchedule.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.at) == "number" then
			nextAt = data.at
			nextName = tostring(data.nextName)
			nextColor = if typeof(data.color) == "Color3" then data.color else UI.Colors.Accent
			tickBanner()
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if type(data.key) == "string" then
			-- Raridade chega como ID interno ("Epic"): mostra no idioma do jogador ("Épico").
			local params: { [string]: any } = if type(data.params) == "table" then table.clone(data.params) else {}
			if type(params.r) == "string" and Config.Rarities[params.r] then
				params.r = Locale.rarity(params.r)
			end
			pushToast(Locale.fmt(data.key, nil, params), data.color)
		elseif type(data.text) == "string" then
			pushToast(Locale.t(data.text), data.color)
		end
	end)
	Remotes.EventStarted.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			showBanner(tostring(data.name), tonumber(data.duration) or 60, data.color or UI.Colors.Accent)
		end
	end)
	Remotes.EventEnded.OnClientEvent:Connect(hideBanner)
	Remotes.StealAlert.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			stealAlert(tostring(data.thiefName), tostring(data.food or "comida"))
		end
	end)

	print("[Client] Notifications pronto para", player.Name)
end

return Notifications
