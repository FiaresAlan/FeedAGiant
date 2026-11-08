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

local function showBanner(name: string, duration: number, color: Color3)
	activeEventEnd = os.clock() + duration
	banner.BackgroundColor3 = color
	bannerLabel.Text = Locale.fmt("event_banner", nil, { s = string.upper(Locale.t(name)) })
	banner.Visible = true
	UI.pop(banner)
	task.spawn(function()
		while banner.Visible and os.clock() < activeEventEnd do
			local left = math.max(0, math.ceil(activeEventEnd - os.clock()))
			bannerTimer.Text = string.format("%d:%02d", left // 60, left % 60)
			task.wait(0.25)
		end
	end)
end

local function hideBanner()
	activeEventEnd = 0
	banner.Visible = false
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

	banner = UI.frame(gui, {
		Name = "EventBanner",
		Size = UDim2.fromOffset(420, 52),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
	})
	UI.stroke(banner, Color3.new(0, 0, 0), 3)
	bannerLabel = UI.label(banner, "", {
		Size = UDim2.new(1, -110, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	bannerTimer = UI.label(banner, "0:00", {
		Size = UDim2.fromOffset(90, 40),
		Position = UDim2.new(1, -100, 0, 6),
	})

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
