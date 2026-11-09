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
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local FoodChoice = require(game.ReplicatedStorage.Shared.FoodChoice)
local FoodPreference = require(game.ReplicatedStorage.Shared.FoodPreference)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
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
local collBadge: Frame? = nil
local lastCoins = 0
local coinsReady = false -- o primeiro estado só preenche o número (sem moedas voando)
local hudGui: ScreenGui? = nil
local coinIcon: GuiObject? = nil
local miniLevel: TextLabel? = nil
local goalLabel: TextLabel

HUD.OnOpenShop = nil :: (() -> ())?
HUD.OnOpenInventory = nil :: (() -> ())?
HUD.OnOpenCodes = nil :: (() -> ())?
HUD.OnOpenArena = nil :: (() -> ())?
HUD.OnOpenCollection = nil :: (() -> ())?
HUD.OnOpenDiary = nil :: (() -> ())?
local diaryClaimable = false
-- Diário avisa quando há tarefa para resgatar (selo "!" no botão).
function HUD.setDiaryClaimable(on: boolean)
	diaryClaimable = on
	if dailyBadge then
		dailyBadge.Visible = on or os.time() - State.current.lastDaily >= 20 * 3600
	end
end

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

-- HUD nova (referência do usuário de 08/11, assets/HUD nova referencia/feedagiant_hud_transparente.png):
-- coluna à esquerda com logo, cartão de moedas, cartão de nível/XP/fome, grade de botões coloridos e,
-- embaixo, o cartão de META + objetivo do tutorial + "Pular tutorial". Painéis grafite, cores nos botões.
-- Tudo dentro de UM contêiner com o UIScale do aparelho; as posições são em pixels do desenho 1080p e
-- `layout()` recalcula a grade quando a tela muda (celular deitado ganha mais colunas, nada se sobrepõe).
local TILE, TILE_GAP = 104, 10
local CARD_W = 300

local leftRoot: Frame
local logoImg: GuiObject
local coinCard: Frame
local levelCard: Frame
local tileGrid: Frame
local goalCard: Frame
local collapsed = false
local layout: () -> () = function() end
-- MODO COMPACTO (pedido do usuário, 08/11/2026: "a HUD no celular tampa boa parte da experiência").
-- Vault "UI Scale HUD Hide and Compact Mode" §3: em telas baixas (< 500 px lógicos de altura) a HUD
-- vira uma VARIAÇÃO de layout, não só menor: a grade de 8 botões vira 2 botões (LOJA e MENU); o MENU
-- abre/fecha a grade como gaveta; o cartão de nível fica recolhido; o cartão de META sai do canto
-- inferior esquerdo (onde fica o joystick no celular) e vai para o alto, só com a linha da meta.
local COMPACT_H = 500
HUD.compact = false
local compactBar: Frame
local menuOpen = false
local menuBadge: Frame
local wasCompact: boolean? = nil
local gridShop: GuiObject? = nil -- LOJA da grade (no compacto ela já está na barra)
local battleMode = false
-- Batalha por turnos no celular (revisão cega de UI): o placar e os golpes ocupam a tela; a META,
-- o escudo, a gaveta e o botão LUTAR saem do caminho até a luta acabar.
function HUD.setBattleMode(on: boolean)
	battleMode = on
	if on then
		menuOpen = false
	end
	local gui = hudGui
	local fight = gui and gui:FindFirstChild("FightToggle")
	if fight and fight:IsA("GuiObject") then
		fight.Visible = not on
	end
	if shieldChip and on then
		shieldChip.Visible = false
	end
	layout()
end

HUD.goalCard = nil :: Frame?
HUD.goalObjective = nil :: TextLabel?
HUD.goalHint = nil :: TextLabel?

-- v3 (ObjectiveHint): uma dica do servidor ocupa a linha de META por alguns segundos.
local stageGoalText = ""
local goalOverride: { text: string, color: Color3 }? = nil
local function paintGoal()
	if not goalLabel then
		return
	end
	local o = goalOverride
	if o then
		goalLabel.Text = o.text
		goalLabel.TextColor3 = o.color
	else
		goalLabel.Text = stageGoalText
		goalLabel.TextColor3 = UI.Colors.Accent
	end
end
function HUD.setGoalOverride(text: string?, color: Color3?)
	goalOverride = if text and text ~= "" then { text = text, color = color or UI.Colors.Accent } else nil
	paintGoal()
end
HUD.OnOpenRobux = nil :: (() -> ())?

local function card(parent: Instance, name: string, w: number, h: number): Frame
	return UI.panel(parent, { Name = name, Size = UDim2.fromOffset(w, h), BackgroundTransparency = 0.08 })
end

local function buildTopBar(gui: ScreenGui)
	leftRoot = Instance.new("Frame")
	leftRoot.Name = "LeftColumn"
	leftRoot.BackgroundTransparency = 1
	leftRoot.Size = UDim2.fromOffset(640, 1080)
	leftRoot.Parent = gui
	scaled(leftRoot)

	logoImg = UI.logo(leftRoot, { Name = "Logo", Size = UDim2.fromOffset(230, 74), Position = UDim2.fromOffset(18, 2) })

	-- Moedas
	coinCard = card(leftRoot, "CoinCard", CARD_W, 84)
	coinIcon = UI.icon(
		coinCard,
		"hud2_coins",
		{ Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(10, 9), ZIndex = 3 }
	)
	coinsLabel = UI.title(coinCard, "0", {
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.fromOffset(86, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	cpsLabel = UI.label(coinCard, "+0/s", {
		Size = UDim2.fromOffset(110, 26),
		Position = UDim2.fromOffset(88, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Green,
		TextScaled = false,
		TextSize = 22,
		ZIndex = 3,
	})
	local mini = UI.label(coinCard, "", {
		Name = "MiniLevel",
		Size = UDim2.fromOffset(80, 26),
		Position = UDim2.new(1, -132, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = 20,
		TextColor3 = UI.Colors.Blue,
		Visible = false,
		ZIndex = 3,
	})
	miniLevel = mini
	-- Encolher/expandir o cartão de nível (pedido do usuário: a HUD não pode tampar a tela).
	local toggle = UI.button(coinCard, "▲", Color3.fromRGB(78, 84, 100), {
		Name = "Collapse",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -50, 0, 6),
		TextScaled = false,
		TextSize = 22,
		ZIndex = 4,
	})

	-- Nível, XP e fome
	levelCard = card(leftRoot, "LevelCard", CARD_W, 124)
	UI.icon(
		levelCard,
		"hud2_crown",
		{ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(10, 8), ZIndex = 3 }
	)
	levelLabel = UI.label(levelCard, "Bebê • Nv. 1", {
		Size = UDim2.fromOffset(222, 26),
		Position = UDim2.fromOffset(64, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		TextColor3 = UI.Colors.Blue,
		ZIndex = 3,
	})
	local xpBg
	xpBg, xpFill = UI.bar(levelCard, UI.Colors.Green, {
		Size = UDim2.fromOffset(222, 26),
		Position = UDim2.fromOffset(64, 36),
		ZIndex = 3,
	})
	xpText = UI.label(xpBg, "0 / 50 XP", {
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 20,
		Font = UI.FontBody,
		ZIndex = 7,
	})
	local div = Instance.new("Frame")
	div.BackgroundColor3 = UI.Colors.Edge
	div.BackgroundTransparency = 0.5
	div.BorderSizePixel = 0
	div.Size = UDim2.new(1, -24, 0, 2)
	div.Position = UDim2.fromOffset(12, 72)
	div.ZIndex = 3
	div.Parent = levelCard
	UI.icon(
		levelCard,
		"hud2_mood",
		{ Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(14, 80), ZIndex = 3 }
	)
	hungerText = UI.label(levelCard, "Satisfeito", {
		Size = UDim2.fromOffset(128, 30),
		Position = UDim2.fromOffset(58, 82),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 21,
		ZIndex = 3,
	})
	local _hBg
	_hBg, hungerFill = UI.bar(levelCard, UI.Colors.Green, {
		Size = UDim2.fromOffset(96, 20),
		Position = UDim2.fromOffset(190, 88),
		ZIndex = 3,
	})

	-- Escudo: chip ao lado das moedas (só enquanto dura)
	shieldChip = UI.frame(leftRoot, {
		Name = "Shield",
		Size = UDim2.fromOffset(230, 40),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 2,
	})
	UI.stroke(shieldChip, UI.Colors.Blue, 2)
	UI.icon(shieldChip, "shield", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(6, 4), ZIndex = 3 })
	shieldLabel = UI.label(shieldChip, "", {
		Size = UDim2.new(1, -46, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextColor3 = UI.Colors.Blue,
		ZIndex = 3,
	})

	-- Cartão de META + tutorial (embaixo à esquerda)
	goalCard = card(leftRoot, "GoalCard", 450, 40)
	goalCard.AutomaticSize = Enum.AutomaticSize.Y
	goalCard.AnchorPoint = Vector2.new(0, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = goalCard
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = goalCard
	goalLabel = UI.label(goalCard, "", {
		Name = "Goal",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 24,
		TextWrapped = true,
		TextColor3 = UI.Colors.Accent,
		LayoutOrder = 1,
		ZIndex = 3,
	})
	local obj = UI.label(goalCard, "", {
		Name = "Objective",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 22,
		TextWrapped = true,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = UI.Colors.Bg,
		LayoutOrder = 2,
		Visible = false,
		ZIndex = 3,
	})
	UI.corner(obj, 10)
	local objPad = Instance.new("UIPadding")
	objPad.PaddingTop = UDim.new(0, 4)
	objPad.PaddingBottom = UDim.new(0, 4)
	objPad.Parent = obj
	local hint = UI.label(goalCard, "", {
		Name = "Hint",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Accent,
		LayoutOrder = 3,
		Visible = false,
		ZIndex = 3,
	})
	HUD.goalCard = goalCard
	HUD.goalObjective = obj
	HUD.goalHint = hint
	goalCard:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout()
	end)

	toggle.Activated:Connect(function()
		collapsed = not collapsed
		toggle.Text = if collapsed then "▼" else "▲"
		layout()
	end)
	local cam0 = Workspace.CurrentCamera
	collapsed = cam0 ~= nil and cam0.ViewportSize.Y < 430 -- revisão: XP e fome visíveis sempre que couber
	toggle.Text = if collapsed then "▼" else "▲"
end

-- Botão colorido da grade: ícone recortado da referência + legenda desenhada pelo Roblox (traduzível).
local function tile(
	parent: Instance,
	icon: string,
	caption: string,
	color: Color3,
	order: number
): (TextButton, TextLabel)
	local b = UI.button(parent, "", color, { Size = UDim2.fromOffset(TILE, TILE), LayoutOrder = order })
	UI.icon(b, icon, { Size = UDim2.fromOffset(72, 62), Position = UDim2.fromOffset(6, -2), ZIndex = b.ZIndex + 1 })
	local cap = UI.label(b, caption, {
		Size = UDim2.new(1, 12, 0, 24),
		Position = UDim2.new(0, -6, 1, -22),
		TextScaled = false,
		TextSize = 20,
		ZIndex = b.ZIndex + 1,
	})
	return b, cap
end

local TILE_COUNT = 8

local function buildSideButtons(gui: ScreenGui)
	tileGrid = Instance.new("Frame")
	tileGrid.Name = "SideCluster"
	tileGrid.BackgroundTransparency = 1
	tileGrid.Parent = leftRoot
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP + 4)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tileGrid

	local function call(cb: (() -> ())?)
		if cb then
			cb()
		end
	end
	local shop = tile(tileGrid, "hud2_shop", "LOJA", UI.Colors.Accent, 1)
	gridShop = shop
	shop.Activated:Connect(function()
		call(HUD.OnOpenShop)
	end)
	local arena = tile(tileGrid, "hud2_arena", "ARENA", UI.Colors.Red, 2)
	arena.Activated:Connect(function()
		call(HUD.OnOpenArena)
	end)
	local inv = tile(tileGrid, "hud2_items", "ITENS", UI.Colors.Blue, 3)
	inv.Activated:Connect(function()
		call(HUD.OnOpenInventory)
	end)
	local codes = tile(tileGrid, "hud2_codes", "CÓDIGOS", Color3.fromRGB(96, 102, 118), 4)
	codes.Activated:Connect(function()
		call(HUD.OnOpenCodes)
	end)
	rebirthTile, rebirthCaption = tile(tileGrid, "hud2_rebirth", "REBIRTH", UI.Colors.Purple, 5)
	rebirthTile.Activated:Connect(function()
		Remotes.RequestRebirth:FireServer()
	end)
	local coll = tile(tileGrid, "hud2_collection", "COLEÇÃO", UI.Colors.Orange, 6)
	local badge = UI.frame(coll, {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -18, 0, -10),
		BackgroundColor3 = UI.Colors.Red,
		ZIndex = coll.ZIndex + 3,
		Visible = false,
	})
	UI.corner(badge, 14)
	UI.stroke(badge, UI.Colors.Outline, 2)
	UI.label(badge, "!", { ZIndex = coll.ZIndex + 4 })
	collBadge = badge
	coll.Activated:Connect(function()
		badge.Visible = false
		call(HUD.OnOpenCollection)
	end)
	dailyTile, dailyCaption = tile(tileGrid, "hud2_daily", "DIÁRIO", UI.Colors.Green, 7)
	-- 08/11/2026 (noite): o DIÁRIO virou um painel (recompensa diária + tarefas + recordes).
	dailyTile.Activated:Connect(function()
		call(HUD.OnOpenDiary)
	end)
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
	-- Loja de Robux aberta de qualquer lugar (pedido do usuário, item 7).
	local robux = UI.button(tileGrid, "", Color3.fromRGB(40, 190, 90), { LayoutOrder = 8 })
	UI.label(robux, "R$", {
		Size = UDim2.fromOffset(TILE - 20, 56),
		Position = UDim2.fromOffset(0, 2),
		ZIndex = robux.ZIndex + 1,
	})
	UI.label(robux, "ROBUX", {
		Size = UDim2.new(1, 12, 0, 24),
		Position = UDim2.new(0, -6, 1, -22),
		TextScaled = false,
		TextSize = 20,
		ZIndex = robux.ZIndex + 1,
	})
	robux.Activated:Connect(function()
		call(HUD.OnOpenRobux)
	end)

	-- Barra compacta: LOJA (o botão mais usado) + MENU (abre a gaveta com todos os botões).
	compactBar = Instance.new("Frame")
	compactBar.Name = "CompactBar"
	compactBar.BackgroundTransparency = 1
	compactBar.Size = UDim2.fromOffset(TILE * 2 + TILE_GAP, TILE)
	compactBar.Visible = false
	compactBar.Parent = leftRoot
	local barList = Instance.new("UIListLayout")
	barList.FillDirection = Enum.FillDirection.Horizontal
	barList.Padding = UDim.new(0, TILE_GAP)
	barList.SortOrder = Enum.SortOrder.LayoutOrder
	barList.Parent = compactBar
	local cShop = tile(compactBar, "hud2_shop", "LOJA", UI.Colors.Accent, 1)
	cShop.Size = UDim2.fromOffset(TILE, TILE)
	cShop.Activated:Connect(function()
		call(HUD.OnOpenShop)
	end)
	local menuBtn = UI.button(compactBar, "", Color3.fromRGB(78, 84, 100), {
		Name = "MenuButton",
		Size = UDim2.fromOffset(TILE, TILE),
		LayoutOrder = 2,
	})
	-- Ícone desenhado (a fonte não tem "☰"): 3 barras; aberto, vira um X (2 barras giradas).
	local bars: { Frame } = {}
	for i = 1, 3 do
		local bar = UI.frame(menuBtn, {
			Name = "Bar" .. i,
			Size = UDim2.fromOffset(52, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(TILE / 2, 16 + i * 12),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = menuBtn.ZIndex + 1,
		})
		UI.corner(bar, 4)
		bars[i] = bar
	end
	local menuIcon = {
		set = function(open: boolean)
			bars[2].Visible = not open
			bars[1].Rotation = if open then 45 else 0
			bars[3].Rotation = if open then -45 else 0
			bars[1].Position = UDim2.fromOffset(TILE / 2, if open then 40 else 28)
			bars[3].Position = UDim2.fromOffset(TILE / 2, if open then 40 else 52)
		end,
	}
	UI.label(menuBtn, "MENU", {
		Size = UDim2.new(1, 12, 0, 24),
		Position = UDim2.new(0, -6, 1, -22),
		TextScaled = false,
		TextSize = 20,
		ZIndex = menuBtn.ZIndex + 1,
	})
	menuBadge = UI.frame(menuBtn, {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -18, 0, -10),
		BackgroundColor3 = UI.Colors.Red,
		ZIndex = menuBtn.ZIndex + 3,
		Visible = false,
	})
	UI.corner(menuBadge, 14)
	UI.stroke(menuBadge, UI.Colors.Outline, 2)
	UI.label(menuBadge, "!", { ZIndex = menuBtn.ZIndex + 4 })
	local function syncMenuBadge()
		menuBadge.Visible = not menuOpen and ((collBadge ~= nil and collBadge.Visible) or dailyBadge.Visible)
	end
	if collBadge then
		collBadge:GetPropertyChangedSignal("Visible"):Connect(syncMenuBadge)
	end
	dailyBadge:GetPropertyChangedSignal("Visible"):Connect(syncMenuBadge)
	menuBtn.Activated:Connect(function()
		menuOpen = not menuOpen
		menuIcon.set(menuOpen)
		syncMenuBadge()
		layout()
	end)
	-- Tocar num botão da gaveta fecha a gaveta (a janela aberta toma a tela).
	for _, b in tileGrid:GetChildren() do
		if b:IsA("GuiButton") then
			b.Activated:Connect(function()
				if HUD.compact and menuOpen then
					menuOpen = false
					menuIcon.set(false)
					syncMenuBadge()
					layout()
				end
			end)
		end
	end

	layout = function()
		local area = gui.AbsoluteSize
		if area.Y <= 0 then
			return
		end
		local k = UI.deviceScale()
		local H = area.Y / k
		leftRoot.Size = UDim2.fromOffset(640, H)
		local compact = area.Y < COMPACT_H
		HUD.compact = compact
		if compact ~= wasCompact then
			-- entrando no compacto: começa com o cartão de nível recolhido e a gaveta fechada
			if compact then
				collapsed = true
				menuOpen = false
			end
			wasCompact = compact
		end
		local y = 6
		local showLogo = H >= 760 and not compact
		logoImg.Visible = showLogo
		if showLogo then
			y = 78
		end
		coinCard.Position = UDim2.fromOffset(12, y)
		shieldChip.Position = UDim2.fromOffset(12 + CARD_W + 10, y + 22)
		y += 84 + 8
		levelCard.Visible = not collapsed
		local ml = miniLevel
		if ml then
			ml.Visible = collapsed
		end
		if not collapsed then
			levelCard.Position = UDim2.fromOffset(12, y)
			y += 124 + 12
		end
		if compact then
			-- LOJA + MENU; a grade aparece como gaveta AO LADO deles, no alto da tela (embaixo ficam o
			-- joystick e o cartão de disputa — medido no iPhone emulado)
			compactBar.Visible = true
			compactBar.Position = UDim2.fromOffset(12, y)
			local gx = 12 + TILE * 2 + TILE_GAP * 2
			local cols = 4
			local rows = math.ceil((TILE_COUNT - 1) / cols)
			tileGrid.Size = UDim2.fromOffset(cols * TILE + (cols - 1) * TILE_GAP, rows * (TILE + TILE_GAP + 4))
			tileGrid.Position = UDim2.fromOffset(gx, y)
			leftRoot.ZIndex = if menuOpen then 20 else 1
			tileGrid.Visible = menuOpen
			if gridShop then
				gridShop.Visible = false
			end
			-- META no alto, ao lado da barra (fora do joystick); some com a gaveta aberta
			goalCard.AnchorPoint = Vector2.new(0, 0)
			goalCard.Size = UDim2.fromOffset(330, 40)
			goalCard.Position = UDim2.fromOffset(12 + TILE * 2 + TILE_GAP * 2, y)
			goalCard.Visible = not menuOpen and not battleMode
			-- escudo embaixo de LOJA/MENU (ao lado das moedas ele encostava no aviso de evento)
			shieldChip.Position = UDim2.fromOffset(12, y + TILE + 10)
			if menuOpen then
				shieldChip.Visible = false
			end
			return
		end
		compactBar.Visible = false
		leftRoot.ZIndex = 1
		if gridShop then
			gridShop.Visible = true
		end
		tileGrid.Visible = true
		goalCard.Visible = true
		goalCard.AnchorPoint = Vector2.new(0, 1)
		goalCard.Size = UDim2.fromOffset(450, 40)
		goalCard.Position = UDim2.new(0, 12, 1, -12)
		local goalH = goalCard.AbsoluteSize.Y / k
		local avail = H - y - goalH - 24
		local rows = math.clamp(math.floor((avail + TILE_GAP) / (TILE + TILE_GAP + 4)), 1, TILE_COUNT)
		local cols = math.ceil(TILE_COUNT / rows)
		rows = math.ceil(TILE_COUNT / cols)
		tileGrid.Size = UDim2.fromOffset(cols * TILE + (cols - 1) * TILE_GAP, rows * (TILE + TILE_GAP + 4))
		tileGrid.Position = UDim2.fromOffset(12, y)
	end
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	task.defer(layout)
end

-- Selo "!" na Coleção quando aparece comida nova (some ao abrir).
function HUD.markNewDiscovery()
	local badge = collBadge
	if badge then
		badge.Visible = true
	end
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
	local sub = UI.label(feed, "Usa comida comum e preserva seus itens raros", {
		Size = UDim2.fromOffset(310, 24),
		Position = UDim2.fromOffset(86, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		Font = UI.FontBody,
		ZIndex = feed.ZIndex + 1,
	})

	feed.Activated:Connect(function()
		-- Alimentação rápida NUNCA escolhe automaticamente rara, mutada ou gigante.
		-- O jogador ainda pode oferecer qualquer uma manualmente em ITENS.
		local favorite = (State.current :: any).favoriteFoodId
		local slot, index = FoodChoice.choose(State.current.plot, State.current.inventory, favorite)
		if index then
			Remotes.RequestFeed:FireServer({ inv = index })
		elseif slot then
			Remotes.RequestFeed:FireServer(slot)
		end
	end)

	-- Pedido do usuário (08/11): o botão só aparece perto do próprio gigante (mesma distância que o
	-- servidor aceita: borda do gigante + 28 studs). Longe, some e libera a tela para jogar.
	local REACH = 28
	local myGiant: Model? = nil
	task.spawn(function()
		while holder.Parent do
			local g = myGiant
			if not g or not g.Parent then
				g = nil
				for _, m in Workspace:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
						g = m
						break
					end
				end
				myGiant = g
			end
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local near = false
			if g and root then
				local cf, ext = g:GetBoundingBox()
				local d = Vector3.new(root.Position.X - cf.Position.X, 0, root.Position.Z - cf.Position.Z).Magnitude
				near = d - math.max(ext.X, ext.Z) / 2 <= REACH
			end
			if near ~= holder.Visible then
				holder.Visible = near
				if near then
					UI.pop(feed)
				end
			end
			task.wait(0.25)
		end
	end)

	-- 4.1 Sequência de alimentação: selo acima do botão com o multiplicador e uma barra que
	-- esvazia até a sequência acabar (o servidor decide; aqui só mostra o que veio no GiantFed).
	local chip = UI.frame(holder, {
		Name = "StreakChip",
		Size = UDim2.fromOffset(300, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
	})
	UI.corner(chip, 12)
	local chipStroke = UI.stroke(chip, UI.Colors.Accent, 3)
	local chipText = UI.label(chip, "", {
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 2),
		TextScaled = false,
		TextSize = 22,
		ZIndex = chip.ZIndex + 1,
	})
	local chipBar = UI.frame(chip, {
		Size = UDim2.new(1, -16, 0, 5),
		Position = UDim2.new(0, 8, 1, -9),
		BackgroundColor3 = UI.Colors.Accent,
		ZIndex = chip.ZIndex + 1,
	})
	UI.corner(chipBar, 3)
	local streakSerial = 0
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or e.userId ~= player.UserId or type(e.streak) ~= "number" then
			return
		end
		streakSerial += 1
		local serial = streakSerial
		local n = e.streak
		local mult = if type(e.streakMult) == "number" then e.streakMult else 1
		local maxed = n - 1 >= GameRules.Feed.StreakMaxSteps
		chipText.Text = string.format(
			"%s %d  ·  x%.1f%s",
			Locale.t("SEQUÊNCIA"),
			n,
			mult,
			if maxed then "  " .. Locale.t("MÁX!") else ""
		)
		chipStroke.Color = if maxed then Color3.fromRGB(255, 120, 60) else UI.Colors.Accent
		chip.Visible = n >= 2
		if n >= 2 then
			UI.pop(chip)
		end
		chipBar.Size = UDim2.new(1, -16, 0, 5)
		local window = GameRules.Feed.StreakWindow
		local tw = TweenService:Create(chipBar, TweenInfo.new(window, Enum.EasingStyle.Linear), {
			Size = UDim2.fromOffset(0, 5),
		})
		tw:Play()
		task.delay(window, function()
			if streakSerial == serial then
				chip.Visible = false
			end
		end)
	end)

	-- Selo discreto do Banquete em Dupla. Só é visível perto do próprio gigante;
	-- convida o jogador a voltar a alimentar, sem bloquear a câmera ou a interface.
	local coopChip = UI.frame(holder, {
		Name = "CoopFeastChip",
		Size = UDim2.fromOffset(310, 35),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -52),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.25,
		Visible = false,
	})
	UI.corner(coopChip, 12)
	local coopText = UI.label(coopChip, "", {
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		TextScaled = false,
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 220, 110),
	})
	task.spawn(function()
		while coopChip.Parent do
			local untilTime = player:GetAttribute("CoopFeastUntil")
			local remaining = if type(untilTime) == "number" then math.max(0, untilTime - os.time()) else 0
			coopChip.Visible = remaining > 0
			if remaining > 0 then
				coopText.Text = string.format("%s +15%% XP  %d:%02d", Locale.t("BANQUETE"), remaining // 60, remaining % 60)
			end
			task.wait(1)
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
		local favoriteId = (s :: any).favoriteFoodId
		local plotSlot, inventoryIndex = FoodChoice.choose(s.plot, s.inventory, favoriteId)
		local hasFood = plotSlot ~= nil or inventoryIndex ~= nil
		local hasSpecial = next(s.plot) ~= nil or #s.inventory > 0
		feed.BackgroundColor3 = if hasFood then UI.Colors.Green else Color3.fromRGB(90, 90, 100)
		feed.Active = hasFood
		local fav = if type(favoriteId) == "string" then Config.FoodById[favoriteId] else nil
		sub.Text = if hasFood and fav
			then string.format("%s: %s (+%d%% XP)", Locale.t("PREFERE"), Locale.t(fav.name), math.floor((FoodPreference.BonusMult - 1) * 100 + 0.5))
			elseif hasFood then Locale.t("Alimenta sem consumir comida rara")
			elseif hasSpecial then Locale.t("Comida especial: selecione em ITENS")
			else Locale.t("Compre comida na LOJA")
		if hasFood and s.hunger < 75 then
			pulse:Play()
		else
			pulse:Cancel()
			press.Scale = 1
		end
	end)
end

-- Fase 3 (juice): moedas saem do meio da tela e voam até o contador quando o ganho é "de verdade"
-- (venda, prêmio, diário), não a renda passiva de cada segundo. No máximo 8 moedas; nada com
-- "Movimento reduzido" (só o pulso do número).
local function flyCoins(amount: number)
	local gui, target = hudGui, coinIcon
	if not gui or not target or GuiService.ReducedMotionEnabled then
		return
	end
	local origin = gui.AbsolutePosition
	local to = target.AbsolutePosition + target.AbsoluteSize / 2 - origin
	local from = gui.AbsoluteSize / 2 + Vector2.new(0, gui.AbsoluteSize.Y * 0.12)
	local n = math.clamp(math.floor(math.log10(math.max(amount, 1))) * 2 + 2, 3, 8)
	local size = math.floor(44 * UI.deviceScale())
	for i = 1, n do
		task.delay((i - 1) * 0.05, function()
			local c = UI.icon(gui, "coin", {
				Size = UDim2.fromOffset(size, size),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(from.X + math.random(-60, 60), from.Y + math.random(-30, 30)),
				ZIndex = 40,
			})
			local mid = UDim2.fromOffset(
				(from.X + to.X) / 2 + math.random(-120, 120),
				math.min(from.Y, to.Y) - math.random(20, 80)
			)
			local t1 = TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = mid,
			})
			t1:Play()
			t1.Completed:Once(function()
				local t2 = TweenService:Create(c, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromOffset(to.X, to.Y),
					Size = UDim2.fromOffset(size * 0.6, size * 0.6),
				})
				t2:Play()
				t2.Completed:Once(function()
					c:Destroy()
				end)
			end)
		end)
	end
	task.delay(0.5, function()
		UI.sfx("Coin", 0.35)
	end)
end

local function refresh(s: State.PlayerState)
	if s.coins ~= lastCoins then
		local delta = s.coins - lastCoins
		lastCoins = s.coins
		coinsLabel.Text = Util.formatNumber(s.coins)
		if delta > 0 then
			UI.pulse(coinsLabel, 1.1, 0.2)
			if coinsReady and delta > math.max(s.cps * 3, 20) then
				flyCoins(delta)
			end
		end
		coinsReady = true
	end
	cpsLabel.Text = "+" .. Util.formatNumber(s.cps) .. "/s"
	local stage = (s :: any).stage or "Gigante"
	levelLabel.Text = string.format("%s • Nv. %d", Locale.t(stage), s.level)
		.. (if s.rebirths > 0 then "  R" .. s.rebirths else "")
	local pct = if s.xpNeeded > 0 then math.clamp(s.xp / s.xpNeeded, 0, 1) else 0
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(pct, 1) }):Play()
	-- Meta: próximo estágio (ou rebirth quando já é o último)
	local nextStage: any = nil
	for _, st in Config.GiantStages do
		if st.minLevel > s.level then
			nextStage = st
			break
		end
	end
	if nextStage then
		stageGoalText = Locale.fmt("goal_stage", nil, {
			s = Locale.upper(Locale.t(nextStage.name)),
			n = nextStage.minLevel,
			k = nextStage.minLevel - s.level,
		})
	else
		stageGoalText = Locale.fmt("goal_rebirth", nil, { n = Config.Rebirth.MinLevel })
	end
	paintGoal()
	local ml = miniLevel
	if ml then
		ml.Text = "Nv. " .. s.level
	end
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
	dailyBadge.Visible = claimable or diaryClaimable
end

local function shieldLoop()
	while true do
		local left = State.current.shieldUntil - os.time()
		if left > 0 then
			shieldChip.Visible = not (HUD.compact and (menuOpen or battleMode)) -- gaveta aberta ou luta ocupam esse lugar
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
	hudGui = gui
	buildTopBar(gui)
	buildSideButtons(gui)
	buildFeedButton(gui)
	State.onChanged(refresh)
	task.spawn(shieldLoop)
	task.spawn(watchShopPad)
end

return HUD
