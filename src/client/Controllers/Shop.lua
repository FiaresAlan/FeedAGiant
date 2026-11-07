--!strict
-- Shop.lua — janela da Loja: Lunchboxes (moedas), Game Passes e Dev Products (Robux), além de janela de Códigos.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local State = require(script.Parent.Parent.State)

local Shop = {}

local player = Players.LocalPlayer
local win: Frame
local codesWin: Frame
local boxButtons: { [string]: TextButton } = {}
local passButtons: { [string]: TextButton } = {}

local PASS_INFO = {
	{ key = "DoubleCoins", name = "2x Moedas", desc = "Dobra toda a renda do pátio." },
	{ key = "VIP", name = "VIP", desc = "+4 slots no pátio, 1.5x XP e nametag." },
	{ key = "AutoFeed", name = "Auto-Feed", desc = "Alimenta seu Gigante sozinho a cada 5s." },
	{ key = "Guardian", name = "Guardião", desc = "Seu Gigante NUNCA encolhe por ausência + aura dourada." },
	{ key = "BoxerPro", name = "Boxer Pro", desc = "+25% dano, +30% stamina nos socos." },
	{ key = "ArenaVIP", name = "Arena VIP", desc = "Cooldown de duelo pela metade e rouba 3 comidas ao vencer." },
	{ key = "DragonGiant", name = "Gigante Dragão", desc = "Espécie SECRETA: 2x XP, +50% moedas, nunca encolhe." },
	{ key = "PhoenixGiant", name = "Gigante Fênix", desc = "Espécie SECRETA: Rebirth dá +50%, nunca encolhe." },
}

local PRODUCT_INFO = {
	{ key = "Coins10k", name = "10.000 Moedas", desc = "Impulso rápido para a próxima Lunchbox." },
	{ key = "Coins100k", name = "100.000 Moedas", desc = "Pule direto para as caixas Lendárias." },
	{ key = "SuperShield", name = "Super Escudo", desc = "10 minutos sem roubos na sua base." },
	{ key = "LuckyBox", name = "Lucky Lunchbox", desc = "Rara ou melhor, garantido." },
	{ key = "FreezeDecay7d", name = "Congelar Encolhimento (7d)", desc = "Seu Gigante não perde níveis por 7 dias." },
	{ key = "RestoreLevels", name = "Restaurar Níveis", desc = "Recupera TODOS os níveis perdidos por ausência." },
	{ key = "StaminaRefill", name = "Stamina Infinita (60s)", desc = "Stamina cheia + 60s sem gastar stamina." },
	{ key = "ArenaRematch", name = "Revanche", desc = "Zera o cooldown de duelo agora." },
	{
		key = "SpeciesReroll",
		name = "Espécie Surpresa",
		desc = "Desbloqueia uma espécie aleatória que você não tem.",
	},
}

local function oddsText(box: Config.LunchboxDef): string
	local parts = {}
	local ordered = {}
	for rarity, w in box.weights do
		table.insert(ordered, { r = rarity, w = w, o = Config.Rarities[rarity].order })
	end
	table.sort(ordered, function(a, b)
		return a.o < b.o
	end)
	for _, e in ordered do
		table.insert(parts, string.format("%s %s%%", e.r, tostring(e.w)))
	end
	return table.concat(parts, "  ·  ")
end

local function buildBoxesTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, #Config.Lunchboxes * 118)
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, box in Config.Lunchboxes do
		local card = UI.frame(scroll, { Size = UDim2.new(1, -10, 0, 110), LayoutOrder = i })
		UI.stroke(card, box.color, 3)
		local icon = UI.frame(
			card,
			{ Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(12, 15), BackgroundColor3 = box.color }
		)
		UI.label(icon, "?", { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.3 })
		UI.label(
			card,
			box.name,
			{
				Size = UDim2.new(1, -260, 0, 32),
				Position = UDim2.fromOffset(104, 10),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = box.color,
			}
		)
		UI.label(card, oddsText(box), {
			Size = UDim2.new(1, -260, 0, 50),
			Position = UDim2.fromOffset(104, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			TextTransparency = 0.2,
		})
		local btn = UI.button(card, Util.formatNumber(box.price) .. " $", UI.Colors.Green, {
			Size = UDim2.fromOffset(140, 52),
			Position = UDim2.new(1, -152, 0.5, -26),
		})
		btn.MouseButton1Click:Connect(function()
			Remotes.RequestBuyBox:FireServer(box.id)
		end)
		boxButtons[box.id] = btn
	end
end

local function buildRobuxTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, (#PASS_INFO + #PRODUCT_INFO) * 84 + 60)
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local order = 0
	local function row(name: string, desc: string, color: Color3, buttonText: string, cb: () -> ()): TextButton
		order += 1
		local card = UI.frame(scroll, { Size = UDim2.new(1, -10, 0, 76), LayoutOrder = order })
		UI.stroke(card, color, 2)
		UI.label(
			card,
			name,
			{
				Size = UDim2.new(1, -200, 0, 30),
				Position = UDim2.fromOffset(12, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = color,
			}
		)
		UI.label(
			card,
			desc,
			{
				Size = UDim2.new(1, -200, 0, 32),
				Position = UDim2.fromOffset(12, 38),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 14,
				TextWrapped = true,
				TextTransparency = 0.2,
			}
		)
		local btn = UI.button(
			card,
			buttonText,
			color,
			{ Size = UDim2.fromOffset(160, 48), Position = UDim2.new(1, -172, 0.5, -24) }
		)
		btn.MouseButton1Click:Connect(cb)
		return btn
	end

	order += 1
	UI.label(
		scroll,
		"GAME PASSES",
		{
			Size = UDim2.new(1, -10, 0, 24),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Accent,
		}
	)
	for _, p in PASS_INFO do
		passButtons[p.key] = row(p.name, p.desc, UI.Colors.Accent, "COMPRAR", function()
			Remotes.RequestGamePass:FireServer(p.key)
		end)
	end
	order += 1
	UI.label(
		scroll,
		"PRODUTOS",
		{
			Size = UDim2.new(1, -10, 0, 24),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Blue,
		}
	)
	for _, p in PRODUCT_INFO do
		row(p.name, p.desc, UI.Colors.Blue, "ROBUX", function()
			Remotes.RequestPurchase:FireServer(p.key)
		end)
	end
end

local speciesCards: { [string]: TextButton } = {}
local function buildSpeciesTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, #Config.Species * 92 + 40)
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	UI.label(
		scroll,
		"Cada espécie muda forma, XP, moedas, fome e força na arena. Trocar é grátis depois de comprar.",
		{
			Size = UDim2.new(1, -10, 0, 30),
			LayoutOrder = 0,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			TextTransparency = 0.2,
		}
	)
	for i, sp in Config.Species do
		local card = UI.panel(scroll, { Size = UDim2.new(1, -10, 0, 84), LayoutOrder = i })
		UI.stroke(card, sp.color, 2)
		local icon = UI.frame(
			card,
			{ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 14), BackgroundColor3 = sp.skin }
		)
		UI.corner(icon, 28)
		UI.stroke(icon, sp.color, 3)
		UI.label(
			card,
			sp.name .. "  [" .. sp.rarityTag .. "]",
			{
				Size = UDim2.new(1, -260, 0, 26),
				Position = UDim2.fromOffset(76, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = sp.color,
			}
		)
		UI.label(
			card,
			sp.desc,
			{
				Size = UDim2.new(1, -260, 0, 30),
				Position = UDim2.fromOffset(76, 32),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 13,
				TextWrapped = true,
				TextTransparency = 0.2,
			}
		)
		UI.label(
			card,
			string.format("XP x%.2f • $ x%.2f • Arena %d/%dHP", sp.xpMult, sp.coinMult, sp.arenaPower, sp.arenaHp),
			{
				Size = UDim2.new(1, -260, 0, 16),
				Position = UDim2.fromOffset(76, 62),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 11,
				TextColor3 = UI.Colors.Accent,
			}
		)
		local btn =
			UI.button(card, "", sp.color, { Size = UDim2.fromOffset(160, 48), Position = UDim2.new(1, -172, 0.5, -24) })
		btn.MouseButton1Click:Connect(function()
			local s = State.current :: any
			local owned = s.ownedSpecies and s.ownedSpecies[sp.id]
			if owned then
				Remotes.RequestEquipSpecies:FireServer(sp.id)
			elseif sp.robux and sp.passKey then
				Remotes.RequestGamePass:FireServer(sp.passKey)
			else
				Remotes.RequestBuySpecies:FireServer(sp.id)
			end
		end)
		speciesCards[sp.id] = btn
	end
end

local function refreshSpecies(s: State.PlayerState)
	local a = s :: any
	for _, sp in Config.Species do
		local btn = speciesCards[sp.id]
		if not btn then
			continue
		end
		local owned = a.ownedSpecies and a.ownedSpecies[sp.id]
		if a.species == sp.id then
			btn.Text = "EQUIPADO ✓"
			btn.BackgroundColor3 = UI.Colors.Green
		elseif owned then
			btn.Text = "EQUIPAR"
			btn.BackgroundColor3 = UI.Colors.Blue
		elseif sp.robux then
			btn.Text = "ROBUX"
			btn.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
		else
			btn.Text = "$ " .. Util.formatNumber(sp.price)
			btn.BackgroundColor3 = if s.coins >= sp.price then sp.color else Color3.fromRGB(90, 90, 110)
		end
	end
end

local function buildCodes(gui: ScreenGui)
	local body: Frame
	codesWin, body = UI.window(gui, "CÓDIGOS", UDim2.fromOffset(380, 220))
	UI.label(
		body,
		"Digite um código promocional:",
		{ Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left }
	)
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, 0, 0, 48)
	input.Position = UDim2.fromOffset(0, 36)
	input.BackgroundColor3 = UI.Colors.Panel
	input.BorderSizePixel = 0
	input.Font = UI.Font
	input.TextColor3 = UI.Colors.Text
	input.TextScaled = true
	input.PlaceholderText = Locale.t("EX: GIGANTE")
	input.Text = ""
	input.ClearTextOnFocus = false
	input.Parent = body
	UI.corner(input)
	UI.stroke(input, UI.Colors.Accent, 2)
	local redeem = UI.button(
		body,
		"RESGATAR",
		UI.Colors.Green,
		{ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 96) }
	)
	redeem.MouseButton1Click:Connect(function()
		local code = string.upper((string.gsub(input.Text, "%s", "")))
		if #code > 0 then
			Remotes.RequestRedeemCode:FireServer(code)
			input.Text = ""
		end
	end)
end

local function refresh(s: State.PlayerState)
	for id, btn in boxButtons do
		local box = Config.LunchboxById[id]
		local can = s.coins >= box.price
		btn.BackgroundColor3 = can and UI.Colors.Green or Color3.fromRGB(90, 90, 100)
		btn.Text = Util.formatNumber(box.price) .. " $"
	end
	for key, btn in passButtons do
		if s.passes[key] then
			btn.Text = "ATIVO"
			btn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
		end
	end
end

function Shop.open()
	if not win.Visible then
		UI.pop(win)
	end
end

function Shop.openCodes()
	if not codesWin.Visible then
		UI.pop(codesWin)
	end
end

function Shop.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "LUNCHBOX SHOP", UDim2.fromOffset(640, 540))

	local tabs = UI.frame(body, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	local pages = UI.frame(
		body,
		{ Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1 }
	)
	local boxesPage = UI.frame(pages, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local speciesPage = UI.frame(pages, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	local robuxPage = UI.frame(pages, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	buildBoxesTab(boxesPage)
	buildSpeciesTab(speciesPage)
	buildRobuxTab(robuxPage)

	local inactive = Color3.fromRGB(90, 90, 110)
	local tabBoxes = UI.button(tabs, "LUNCHBOXES", UI.Colors.Accent, { Size = UDim2.new(1 / 3, -4, 1, 0) })
	local tabSpecies = UI.button(
		tabs,
		"ESPÉCIES",
		inactive,
		{ Size = UDim2.new(1 / 3, -4, 1, 0), Position = UDim2.new(1 / 3, 2, 0, 0) }
	)
	local tabRobux =
		UI.button(tabs, "ROBUX", inactive, { Size = UDim2.new(1 / 3, -4, 1, 0), Position = UDim2.new(2 / 3, 4, 0, 0) })
	local function show(page: Frame, btn: TextButton, color: Color3)
		boxesPage.Visible = page == boxesPage
		speciesPage.Visible = page == speciesPage
		robuxPage.Visible = page == robuxPage
		tabBoxes.BackgroundColor3 = inactive
		tabSpecies.BackgroundColor3 = inactive
		tabRobux.BackgroundColor3 = inactive
		btn.BackgroundColor3 = color
	end
	tabBoxes.MouseButton1Click:Connect(function()
		show(boxesPage, tabBoxes, UI.Colors.Accent)
	end)
	tabSpecies.MouseButton1Click:Connect(function()
		show(speciesPage, tabSpecies, UI.Colors.Green)
	end)
	tabRobux.MouseButton1Click:Connect(function()
		show(robuxPage, tabRobux, UI.Colors.Blue)
	end)

	buildCodes(gui)
	State.onChanged(refresh)
	State.onChanged(refreshSpecies)
	print("[Client] Shop pronto para", player.Name)
end

return Shop
