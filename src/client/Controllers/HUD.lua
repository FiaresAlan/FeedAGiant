--!strict
-- HUD.lua — barra superior (moedas, CPS, nível/XP, fome, escudo) e botões de ação (Loja, Inventário, Rebirth, Daily, Códigos).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local State = require(script.Parent.Parent.State)

local HUD = {}

local player = Players.LocalPlayer
local coinsLabel: TextLabel
local cpsLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local hungerFill: Frame
local hungerText: TextLabel
local shieldLabel: TextLabel
local rebirthBtn: TextButton
local dailyBtn: TextButton
local lastCoins = 0

HUD.OnOpenShop = nil :: (() -> ())?
HUD.OnOpenInventory = nil :: (() -> ())?
HUD.OnOpenCodes = nil :: (() -> ())?
HUD.OnOpenArena = nil :: (() -> ())?

local function moodColor(h: number): Color3
	if h < 25 then
		return UI.Colors.Red
	elseif h < 70 then
		return UI.Colors.Accent
	end
	return UI.Colors.Green
end

local function moodName(h: number): string
	if h < 25 then
		return Locale.t("Faminto") .. " (0.8x)"
	elseif h < 70 then
		return Locale.t("Satisfeito") .. " (1.0x)"
	end
	return Locale.t("Feliz") .. " (1.25x)"
end

local function setCaption(b: TextButton, text: string)
	for _, c in b:GetChildren() do
		if c:IsA("TextLabel") and c.TextSize == 13 then
			c.Text = text
		end
	end
end

local function buildTopBar(gui: ScreenGui)
	-- Logo no canto
	UI.logo(gui, { Name = "Logo", Size = UDim2.fromOffset(190, 70), Position = UDim2.fromOffset(10, 4), ZIndex = 3 })

	local bar = UI.panel(gui, {
		Name = "TopBar",
		Size = UDim2.new(0, 600, 0, 78),
		Position = UDim2.fromOffset(206, 10),
		BackgroundTransparency = 0.05,
	})

	-- Moedas (cápsula dourada com ícone)
	local coinBox = UI.frame(
		bar,
		{
			Size = UDim2.fromOffset(200, 56),
			Position = UDim2.fromOffset(12, 12),
			BackgroundColor3 = UI.Colors.Bg,
			ZIndex = 2,
		}
	)
	UI.stroke(coinBox, UI.Colors.Accent, 2)
	UI.glow(coinBox, UI.Colors.Accent, 10, 0.8)
	UI.icon(coinBox, "coin", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 6), ZIndex = 3 })
	coinsLabel = UI.title(
		coinBox,
		"0",
		{
			Size = UDim2.fromOffset(140, 30),
			Position = UDim2.fromOffset(54, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}
	)
	cpsLabel = UI.label(
		coinBox,
		"+0/s",
		{
			Size = UDim2.fromOffset(140, 18),
			Position = UDim2.fromOffset(56, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Green,
			TextScaled = false,
			TextSize = 14,
			Font = UI.FontBody,
			ZIndex = 3,
		}
	)

	-- Nível + XP
	local lvlBox = UI.frame(
		bar,
		{
			Size = UDim2.fromOffset(220, 56),
			Position = UDim2.fromOffset(222, 12),
			BackgroundColor3 = UI.Colors.Bg,
			ZIndex = 2,
		}
	)
	UI.stroke(lvlBox, UI.Colors.Blue, 2)
	levelLabel = UI.label(
		lvlBox,
		"Bebê Nv. 1",
		{
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}
	)
	local xpBg
	xpBg, xpFill = UI.bar(
		lvlBox,
		UI.Colors.Blue,
		{ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 32), ZIndex = 3 }
	)
	xpText = UI.label(
		xpBg,
		"0 / 50 XP",
		{ Size = UDim2.fromScale(1, 1), TextSize = 12, TextScaled = false, Font = UI.FontBody, ZIndex = 6 }
	)

	-- Fome / humor
	local hBox = UI.frame(
		bar,
		{
			Size = UDim2.fromOffset(136, 56),
			Position = UDim2.fromOffset(452, 12),
			BackgroundColor3 = UI.Colors.Bg,
			ZIndex = 2,
		}
	)
	UI.stroke(hBox, UI.Colors.Green, 2)
	hungerText = UI.label(
		hBox,
		"Fome",
		{
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}
	)
	local hBg
	hBg, hungerFill = UI.bar(
		hBox,
		UI.Colors.Green,
		{ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 32), ZIndex = 3 }
	)

	-- Escudo
	shieldLabel = UI.label(gui, "", {
		Size = UDim2.fromOffset(320, 24),
		Position = UDim2.fromOffset(212, 92),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Blue,
		Visible = false,
	})
end

local function buildSideButtons(gui: ScreenGui)
	local col = UI.frame(gui, {
		Name = "SideButtons",
		Size = UDim2.fromOffset(92, 6 * 88),
		Position = UDim2.new(0, 12, 0.5, 20),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = col

	local function side(icon: string, caption: string, color: Color3, order: number, cb: () -> ()): TextButton
		local b = UI.iconButton(col, icon, caption, color, { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = order })
		b.MouseButton1Click:Connect(cb)
		return b
	end

	side("lunchbox", "LOJA", UI.Colors.Accent, 1, function()
		if HUD.OnOpenShop then
			HUD.OnOpenShop()
		end
	end)
	side("backpack", "ITENS", UI.Colors.Blue, 2, function()
		if HUD.OnOpenInventory then
			HUD.OnOpenInventory()
		end
	end)
	rebirthBtn = side("crown", "REBIRTH", UI.Colors.Purple, 3, function()
		Remotes.RequestRebirth:FireServer()
	end)
	dailyBtn = side("trophy", "DIÁRIO", UI.Colors.Green, 4, function()
		Remotes.RequestClaimDaily:FireServer()
	end)
	side("glove", "ARENA", UI.Colors.Red, 5, function()
		if HUD.OnOpenArena then
			HUD.OnOpenArena()
		end
	end)
	side("gear", "CÓDIGOS", Color3.fromRGB(120, 125, 165), 6, function()
		if HUD.OnOpenCodes then
			HUD.OnOpenCodes()
		end
	end)
end

local function buildFeedButton(gui: ScreenGui)
	local feed = UI.button(gui, "ALIMENTAR GIGANTE", UI.Colors.Green, {
		Name = "FeedButton",
		Size = UDim2.fromOffset(300, 64),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
	})
	UI.glow(feed, UI.Colors.Green, 16, 0.6)
	local hint = UI.label(
		gui,
		"Alimenta a comida mais rara do seu pátio (+XP). Comida no pátio gera moedas; comida alimentada vira crescimento.",
		{
			Size = UDim2.fromOffset(520, 20),
			Position = UDim2.new(0.5, 0, 1, -94),
			AnchorPoint = Vector2.new(0.5, 1),
			TextSize = 13,
			TextScaled = false,
			TextTransparency = 0.25,
		}
	)
	hint.Visible = true

	feed.MouseButton1Click:Connect(function()
		local best: number? = nil
		local bestOrder = 0
		for key, food in State.current.plot do
			local def = Config.FoodById[food.id]
			if def and Config.Rarities[def.rarity].order > bestOrder then
				bestOrder = Config.Rarities[def.rarity].order
				best = tonumber(key)
			end
		end
		if best then
			Remotes.RequestFeed:FireServer(best)
		elseif #State.current.inventory > 0 then
			Remotes.RequestFeed:FireServer({ inv = 1 })
		else
			Remotes.RequestFeed:FireServer(0)
		end
	end)

	local pulse =
		TweenService:Create(feed, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.fromOffset(310, 68),
		})
	State.onChanged(function(s)
		local hasFood = next(s.plot) ~= nil or #s.inventory > 0
		feed.BackgroundColor3 = hasFood and UI.Colors.Green or Color3.fromRGB(90, 90, 100)
		if hasFood and s.hunger < 70 then
			pulse:Play()
		else
			pulse:Cancel()
			feed.Size = UDim2.fromOffset(300, 64)
		end
	end)
end

local function refresh(s: State.PlayerState)
	if s.coins ~= lastCoins then
		local delta = s.coins - lastCoins
		if s.coins > lastCoins + 0.5 then
			UI.pulse(coinsLabel, 1.15, 0.2)
		end
		lastCoins = s.coins
		coinsLabel.Text = Util.formatNumber(s.coins)
		if delta > 0 then
			TweenService:Create(
				coinsLabel,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
				{ TextColor3 = UI.Colors.Green }
			):Play()
		end
	end
	cpsLabel.Text = "+" .. Util.formatNumber(s.cps) .. "/s"
	levelLabel.Text = Locale.fmt(
		"level_label",
		nil,
		{
			s = (s :: any).stage or "Gigante",
			n = s.level,
			m = string.format("%.1f", 1 + s.level * Config.Giant.ScalePerLevel),
		}
	)
	local pct = s.xpNeeded > 0 and math.clamp(s.xp / s.xpNeeded, 0, 1) or 0
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(pct, 1) }):Play()
	xpText.Text = Util.formatNumber(s.xp) .. " / " .. Util.formatNumber(s.xpNeeded) .. " XP"
	hungerText.Text = moodName(s.hunger)
	TweenService:Create(
		hungerFill,
		TweenInfo.new(0.25),
		{ Size = UDim2.fromScale(math.clamp(s.hunger / 100, 0, 1), 1), BackgroundColor3 = moodColor(s.hunger) }
	):Play()

	local canRebirth = s.level >= Config.Rebirth.MinLevel
	setCaption(
		rebirthBtn,
		canRebirth and Locale.t("REBIRTH!") or Locale.fmt("rebirth_btn", nil, { n = Config.Rebirth.MinLevel })
	)
	rebirthBtn.BackgroundColor3 = canRebirth and Color3.fromRGB(255, 120, 255) or Color3.fromRGB(110, 70, 140)
	if s.rebirths > 0 then
		levelLabel.Text ..= "  R" .. s.rebirths
	end

	local today = os.date("!*t", os.time()).yday
	local lastDay = s.lastDaily > 0 and os.date("!*t", s.lastDaily).yday or -1
	local claimable = today ~= lastDay
	setCaption(dailyBtn, claimable and Locale.t("DIÁRIO!") or Locale.fmt("daily_btn", nil, { n = s.dailyStreak }))
	dailyBtn.BackgroundColor3 = claimable and UI.Colors.Green or Color3.fromRGB(70, 130, 90)
end

local function shieldLoop()
	while true do
		local left = State.current.shieldUntil - os.time()
		if left > 0 then
			shieldLabel.Visible = true
			shieldLabel.Text = Locale.fmt("shield_active", nil, { t = string.format("%d:%02d", left // 60, left % 60) })
		else
			shieldLabel.Visible = false
		end
		task.wait(1)
	end
end

-- Abre a Loja ao pisar no ShopPad central
local function watchShopPad()
	local map = Workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	local pad = map:WaitForChild("ShopPad", 30) :: BasePart?
	if not pad then
		return
	end
	local debounce = 0
	pad.Touched:Connect(function(hit)
		local char = player.Character
		if char and hit:IsDescendantOf(char) and os.clock() - debounce > 1.5 then
			debounce = os.clock()
			if HUD.OnOpenShop then
				HUD.OnOpenShop()
			end
		end
	end)
end

function HUD.init(gui: ScreenGui)
	buildTopBar(gui)
	buildSideButtons(gui)
	buildFeedButton(gui)
	State.onChanged(refresh)
	task.spawn(shieldLoop)
	task.spawn(watchShopPad)
end

return HUD
