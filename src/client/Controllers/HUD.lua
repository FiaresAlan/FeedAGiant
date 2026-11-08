--!strict
-- HUD.lua — Fase 3 (reforma pedida pelo usuário: "mega importante").
-- Referências do usuário: assets/ui/panel_9slice.png (painel azul-marinho com faixa dourada e rebites),
-- assets/ui/icons_sheet.png (ícones cartoon recortados em UIAssets), logo, thumbnail.
-- Regras (skill fwjelaa-ui-builder; vault "Safe Areas and Insets", "Responsive UI", "Accessibility"):
--   * desenho em 1920x1080 com UM UIScale por grupo, preso entre 0,6 e 1,0 (texto >= 12 px e toque
--     >= 44 px no menor celular);
--   * o ScreenGui usa ScreenInsets = CoreUISafeInsets: tudo fica dentro da área segura e abaixo da
--     barra do Roblox (sem somar a altura da barra à mão);
--   * botões usam Activated (mouse, toque e controle); estado nunca só por cor (texto junto).
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
local shieldChip: Frame
local shieldLabel: TextLabel
local rebirthCaption: TextLabel
local rebirthTile: TextButton
local dailyCaption: TextLabel
local dailyTile: TextButton
local dailyBadge: Frame
local lastCoins = 0

HUD.OnOpenShop = nil :: (() -> ())?
HUD.OnOpenInventory = nil :: (() -> ())?
HUD.OnOpenCodes = nil :: (() -> ())?
HUD.OnOpenArena = nil :: (() -> ())?

-- Escala por aparelho: no kit UI (UI.deviceScale / UI.autoScale), igual para todos os painéis.
local scaled = UI.autoScale

local function moodColor(h: number): Color3
	if h < 30 then
		return UI.Colors.Red
	elseif h < 75 then
		return UI.Colors.Accent
	end
	return UI.Colors.Green
end

local function moodName(h: number): string
	if h < 30 then
		return Locale.t("Faminto") .. "  x0.8"
	elseif h < 75 then
		return Locale.t("Satisfeito") .. "  x1.0"
	end
	return Locale.t("Feliz") .. "  x1.25"
end

-- Cápsula escura dentro do painel (fundo das estatísticas).
local function pill(parent: Instance, x: number, w: number, accent: Color3): Frame
	local f = UI.frame(parent, {
		Size = UDim2.fromOffset(w, 76),
		Position = UDim2.fromOffset(x, 26),
		BackgroundColor3 = Color3.fromRGB(16, 20, 54),
		ZIndex = 3,
	})
	UI.corner(f, 18)
	UI.stroke(f, accent, 2.5)
	return f
end

local function buildTopBar(gui: ScreenGui)
	-- O ScreenGui usa ScreenInsets = CoreUISafeInsets: a área já começa abaixo da barra do Roblox
	-- (medido no teste de 08/11: somar TopbarInset de novo deixava o painel ~60 px baixo demais).
	local top = Instance.new("Frame")
	top.Name = "TopCluster"
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 6)
	top.Size = UDim2.fromOffset(900, 150)
	top.Parent = gui
	scaled(top)

	local panel = UI.panel(top, { Name = "Panel", Size = UDim2.fromOffset(900, 116), ZIndex = 2 })
	UI.glow(panel, UI.Colors.Accent, 14, 0.82)

	-- Moedas
	local coin = pill(panel, 18, 300, UI.Colors.Accent)
	UI.icon(coin, "coin", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(6, 6), ZIndex = 4 })
	coinsLabel = UI.title(coin, "0", {
		Size = UDim2.fromOffset(212, 44),
		Position = UDim2.fromOffset(78, 2),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	cpsLabel = UI.label(coin, "+0/s", {
		Size = UDim2.fromOffset(212, 24),
		Position = UDim2.fromOffset(80, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Green,
		TextScaled = false,
		TextSize = 22,
		ZIndex = 4,
	})

	-- Nível + XP
	local lvl = pill(panel, 330, 330, UI.Colors.Blue)
	UI.icon(lvl, "crown", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 10), ZIndex = 4 })
	levelLabel = UI.label(lvl, "Bebê • Nv. 1", {
		Size = UDim2.fromOffset(250, 30),
		Position = UDim2.fromOffset(70, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 24,
		ZIndex = 4,
	})
	local xpBg
	xpBg, xpFill = UI.bar(lvl, UI.Colors.Blue, {
		Size = UDim2.fromOffset(246, 26),
		Position = UDim2.fromOffset(70, 40),
		ZIndex = 4,
	})
	xpText = UI.label(xpBg, "0 / 50 XP", {
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 18,
		Font = UI.FontBody,
		ZIndex = 7,
	})

	-- Humor / fome
	local mood = pill(panel, 672, 210, UI.Colors.Green)
	hungerText = UI.label(mood, "Satisfeito", {
		Size = UDim2.fromOffset(190, 30),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		ZIndex = 4,
	})
	local _hBg
	_hBg, hungerFill = UI.bar(mood, UI.Colors.Green, {
		Size = UDim2.fromOffset(190, 26),
		Position = UDim2.fromOffset(10, 40),
		ZIndex = 4,
	})

	-- Escudo (chip abaixo do painel)
	shieldChip = UI.frame(top, {
		Name = "Shield",
		Size = UDim2.fromOffset(260, 36),
		Position = UDim2.new(0.5, 0, 0, 122),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(16, 20, 54),
		Visible = false,
		ZIndex = 2,
	})
	UI.stroke(shieldChip, UI.Colors.Blue, 2)
	UI.icon(shieldChip, "shield", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(6, 3), ZIndex = 3 })
	shieldLabel = UI.label(shieldChip, "", {
		Size = UDim2.new(1, -46, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextColor3 = UI.Colors.Blue,
		ZIndex = 3,
	})

	-- Logo no canto (só em telas largas: no celular a área é das estatísticas)
	local logo = UI.logo(gui, {
		Name = "Logo",
		Size = UDim2.fromOffset(170, 64),
		Position = UDim2.fromOffset(12, 4),
		ZIndex = 3,
	})
	local function updateLogo()
		local cam = Workspace.CurrentCamera
		logo.Visible = cam ~= nil and cam.ViewportSize.X >= 1280
	end
	updateLogo()
	if Workspace.CurrentCamera then
		(Workspace.CurrentCamera :: Camera):GetPropertyChangedSignal("ViewportSize"):Connect(updateLogo)
	end
end

-- Azulejo do menu lateral: ícone grande + legenda, botão "pressionável" com sombra.
local function tile(
	parent: Instance,
	icon: string,
	caption: string,
	color: Color3,
	order: number
): (TextButton, TextLabel)
	local b = UI.button(parent, "", color, { Size = UDim2.fromOffset(104, 112), LayoutOrder = order })
	UI.icon(b, icon, { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(6, -2), ZIndex = b.ZIndex + 1 })
	local cap = UI.label(b, caption, {
		Size = UDim2.new(1, 8, 0, 24),
		Position = UDim2.new(0, -4, 1, -22),
		TextScaled = false,
		TextSize = 19,
		ZIndex = b.ZIndex + 1,
	})
	return b, cap
end

local function buildSideButtons(gui: ScreenGui)
	local col = Instance.new("Frame")
	col.Name = "SideCluster"
	col.BackgroundTransparency = 1
	col.AnchorPoint = Vector2.new(0, 0.5)
	col.Position = UDim2.new(0, 14, 0.5, 30)
	col.Size = UDim2.fromOffset(104, 6 * 112 + 5 * 12)
	col.Parent = gui
	scaled(col)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = col

	local function open(cb: (() -> ())?)
		return function()
			if cb then
				cb()
			end
		end
	end

	local shop = tile(col, "lunchbox", "LOJA", UI.Colors.Accent, 1)
	shop.Activated:Connect(function()
		open(HUD.OnOpenShop)()
	end)
	local inv = tile(col, "backpack", "ITENS", UI.Colors.Blue, 2)
	inv.Activated:Connect(function()
		open(HUD.OnOpenInventory)()
	end)
	rebirthTile, rebirthCaption = tile(col, "crown", "REBIRTH", UI.Colors.Purple, 3)
	rebirthTile.Activated:Connect(function()
		Remotes.RequestRebirth:FireServer()
	end)
	dailyTile, dailyCaption = tile(col, "trophy", "DIÁRIO", UI.Colors.Green, 4)
	dailyTile.Activated:Connect(function()
		Remotes.RequestClaimDaily:FireServer()
	end)
	-- Bolinha de "pronto para resgatar" (forma + cor, não só cor)
	dailyBadge = UI.frame(dailyTile, {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -18, 0, -10),
		BackgroundColor3 = UI.Colors.Red,
		ZIndex = dailyTile.ZIndex + 3,
		Visible = false,
	})
	UI.corner(dailyBadge, 14)
	UI.stroke(dailyBadge, UI.Colors.Outline, 2)
	UI.label(dailyBadge, "!", { ZIndex = dailyTile.ZIndex + 4 })
	local arena = tile(col, "glove", "ARENA", UI.Colors.Red, 5)
	arena.Activated:Connect(function()
		open(HUD.OnOpenArena)()
	end)
	local codes = tile(col, "gear", "CÓDIGOS", Color3.fromRGB(120, 125, 165), 6)
	codes.Activated:Connect(function()
		open(HUD.OnOpenCodes)()
	end)
end

local function buildFeedButton(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "FeedCluster"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -18)
	holder.Size = UDim2.fromOffset(420, 104)
	holder.Parent = gui
	scaled(holder)

	local feed = UI.button(holder, "", UI.Colors.Green, {
		Name = "FeedButton",
		Size = UDim2.fromOffset(420, 96),
	})
	UI.glow(feed, UI.Colors.Green, 16, 0.6)
	UI.icon(
		feed,
		"lunchbox",
		{ Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(4, 2), ZIndex = feed.ZIndex + 1 }
	)
	UI.title(feed, "ALIMENTAR!", {
		Size = UDim2.fromOffset(300, 48),
		Position = UDim2.fromOffset(84, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = feed.ZIndex + 1,
	})
	local sub = UI.label(feed, "Dá a comida mais rara do pátio", {
		Size = UDim2.fromOffset(310, 24),
		Position = UDim2.fromOffset(86, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 19,
		Font = UI.FontBody,
		ZIndex = feed.ZIndex + 1,
	})

	feed.Activated:Connect(function()
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
		end
	end)

	-- Pulso de atenção só quando há comida e o gigante não está feliz (via UIScale, não Size)
	local press = Instance.new("UIScale")
	press.Name = "Pulse"
	press.Parent = feed
	local pulse = TweenService:Create(
		press,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 }
	)
	State.onChanged(function(s)
		local hasFood = next(s.plot) ~= nil or #s.inventory > 0
		feed.BackgroundColor3 = if hasFood then UI.Colors.Green else Color3.fromRGB(90, 90, 100)
		sub.Text = if hasFood then Locale.t("Dá a comida mais rara do pátio") else Locale.t("Compre comida na LOJA")
		if hasFood and s.hunger < 75 then
			pulse:Play()
		else
			pulse:Cancel()
			press.Scale = 1
		end
	end)
end

local function refresh(s: State.PlayerState)
	if s.coins ~= lastCoins then
		local delta = s.coins - lastCoins
		lastCoins = s.coins
		coinsLabel.Text = Util.formatNumber(s.coins)
		if delta > 0 then
			UI.pulse(coinsLabel, 1.1, 0.2)
		end
	end
	cpsLabel.Text = "+" .. Util.formatNumber(s.cps) .. "/s"
	local stage = (s :: any).stage or "Gigante"
	levelLabel.Text = string.format("%s • Nv. %d", Locale.t(stage), s.level)
		.. (if s.rebirths > 0 then "  R" .. s.rebirths else "")
	local pct = if s.xpNeeded > 0 then math.clamp(s.xp / s.xpNeeded, 0, 1) else 0
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(pct, 1) }):Play()
	xpText.Text = Util.formatNumber(s.xp) .. " / " .. Util.formatNumber(s.xpNeeded) .. " XP"
	hungerText.Text = moodName(s.hunger)
	TweenService:Create(
		hungerFill,
		TweenInfo.new(0.25),
		{ Size = UDim2.fromScale(math.clamp(s.hunger / 100, 0, 1), 1), BackgroundColor3 = moodColor(s.hunger) }
	):Play()

	local canRebirth = s.level >= Config.Rebirth.MinLevel
	rebirthCaption.Text = if canRebirth
		then Locale.t("REBIRTH!")
		else Locale.fmt("rebirth_btn", nil, { n = Config.Rebirth.MinLevel })
	rebirthTile.BackgroundColor3 = if canRebirth then Color3.fromRGB(255, 120, 255) else Color3.fromRGB(110, 70, 140)

	local claimable = os.time() - s.lastDaily >= 20 * 3600
	dailyCaption.Text = if claimable then Locale.t("DIÁRIO!") else Locale.fmt("daily_btn", nil, { n = s.dailyStreak })
	dailyTile.BackgroundColor3 = if claimable then UI.Colors.Green else Color3.fromRGB(70, 130, 90)
	dailyBadge.Visible = claimable
end

local function shieldLoop()
	while true do
		local left = State.current.shieldUntil - os.time()
		if left > 0 then
			shieldChip.Visible = true
			shieldLabel.Text = Locale.fmt("shield_active", nil, { t = string.format("%d:%02d", left // 60, left % 60) })
		else
			shieldChip.Visible = false
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
	local pad = map:WaitForChild("ShopPad", 30)
	if not pad or not pad:IsA("BasePart") then
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
