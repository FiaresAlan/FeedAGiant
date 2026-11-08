--!strict
-- Shop.lua — janela da Loja: Lunchboxes (moedas), Game Passes e Dev Products (Robux), além de janela de Códigos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)
local LunchboxOdds = require(game.ReplicatedStorage.Shared.LunchboxOdds)
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
local gatedButtons: { [TextButton]: boolean } = {}

local PASS_INFO = {
	{ key = "DoubleCoins", name = "2x Moedas", desc = "Dobra toda a renda do pátio." },
	{ key = "VIP", name = "VIP", desc = "+4 slots no pátio, 1.5x XP e nametag." },
	{ key = "AutoFeed", name = "Auto-Feed", desc = "Alimenta seu Gigante sozinho a cada 5s." },
	{ key = "Guardian", name = "Guardião", desc = "Seu Gigante NUNCA passa fome (sempre Feliz) + aura dourada." },
	{ key = "BoxerPro", name = "Boxer Pro", desc = "+25% dano, +30% stamina nos socos." },
	{ key = "ArenaVIP", name = "Arena VIP", desc = "Cooldown de duelo pela metade e rouba 3 comidas ao vencer." },
	{ key = "DragonGiant", name = "Gigante Dragão", desc = "Espécie SECRETA: 2x XP, +50% moedas, nunca passa fome." },
	{ key = "PhoenixGiant", name = "Gigante Fênix", desc = "Espécie SECRETA: Rebirth dá +50%, nunca passa fome." },
}

local PRODUCT_INFO = {
	{ key = "Coins10k", name = "10.000 Moedas", desc = "Impulso rápido para a próxima Lunchbox." },
	{ key = "Coins100k", name = "100.000 Moedas", desc = "Pule direto para as caixas Lendárias." },
	{ key = "SuperShield", name = "Super Escudo", desc = "10 minutos sem roubos na sua base." },
	{ key = "LuckyBox", name = "Lucky Lunchbox", desc = "Rara ou melhor, garantido." },
	{ key = "StaminaRefill", name = "Stamina Infinita (60s)", desc = "Stamina cheia + 60s sem gastar stamina." },
	{ key = "ArenaRematch", name = "Revanche", desc = "Zera o cooldown de duelo agora." },
	{
		key = "SpeciesReroll",
		name = "Ficha de Espécie",
		desc = "Desbloqueie a espécie comprável que VOCÊ escolher (Loja › Espécies).",
	},
}

---------------------------------------------------------------------------
-- Chances (Fase 0.5): tudo vem de LunchboxOdds, a MESMA tabela do sorteio no servidor.
---------------------------------------------------------------------------
local function currentLuck(): number
	local v = ReplicatedStorage:GetAttribute(LunchboxOdds.LUCK_ATTRIBUTE)
	return if type(v) == "number" then v else 0
end

-- Resumo por raridade para o cartão da caixa ("Rare 22% · Epic 6% ...").
local function oddsSummary(boxId: string, minRarity: string?): string
	local byRarity: { [string]: number } = {}
	-- Caixa paga (tem raridade mínima) sorteia sem bônus de evento no servidor.
	for _, row in LunchboxOdds.rows(boxId, if minRarity then 0 else currentLuck(), minRarity) do
		byRarity[row.rarity] = (byRarity[row.rarity] or 0) + row.percent
	end
	local ordered = {}
	for rarity, pct in byRarity do
		table.insert(ordered, { r = rarity, p = pct, o = Config.Rarities[rarity].order })
	end
	table.sort(ordered, function(a, b)
		return a.o < b.o
	end)
	local Odds = require(ReplicatedStorage:WaitForChild("fwjelaa"):WaitForChild("Odds"))
	local parts = {}
	for _, e in ordered do
		table.insert(parts, string.format("%s %s", Locale.rarity(e.r), Odds.Format(e.p)))
	end
	return table.concat(parts, "  ·  ")
end

local oddsWin: Frame
local oddsHeading: TextLabel
local oddsList: ScrollingFrame
local oddsShown: { boxId: string, minRarity: string?, title: string }? = nil
local summaryLabels: { [string]: TextLabel } = {}

local function renderOdds()
	local shown = oddsShown
	if not shown or not oddsList then
		return
	end
	for _, child in oddsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local luck = if shown.minRarity then 0 else currentLuck()
	oddsHeading.Text = if luck > 0
		then string.format("%s  (Lucky Boxes ativo: +%d%% em Rare ou melhor)", shown.title, math.floor(luck * 100))
		else shown.title
	local rows = LunchboxOdds.rows(shown.boxId, luck, shown.minRarity)
	for i, row in rows do
		local color = Config.Rarities[row.rarity].color
		UI.label(oddsList, string.format("%s  [%s]   %s", row.name, Locale.rarity(row.rarity), row.text), {
			Size = UDim2.new(1, -10, 0, 28),
			LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			TextColor3 = color,
		})
	end
	UI.label(oddsList, LunchboxOdds.Disclaimer, {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #rows + 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextTransparency = 0.3,
	})
end

local function buildOddsWindow(gui: ScreenGui)
	local body: Frame
	oddsWin, body = UI.window(gui, "CHANCES", UDim2.fromOffset(460, 440))
	oddsHeading = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 52),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
	})
	oddsList = Instance.new("ScrollingFrame")
	oddsList.Size = UDim2.new(1, 0, 1, -58)
	oddsList.Position = UDim2.fromOffset(0, 56)
	oddsList.CanvasSize = UDim2.new()
	oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	oddsList.BackgroundTransparency = 1
	oddsList.BorderSizePixel = 0
	oddsList.ScrollBarThickness = 6
	oddsList.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = oddsList
	ReplicatedStorage:GetAttributeChangedSignal(LunchboxOdds.LUCK_ATTRIBUTE):Connect(function()
		renderOdds()
		for boxId, label in summaryLabels do
			label.Text = oddsSummary(boxId, nil)
		end
	end)
end

function Shop.showOdds(boxId: string, minRarity: string?, title: string)
	oddsShown = { boxId = boxId, minRarity = minRarity, title = title }
	renderOdds()
	if not oddsWin.Visible then
		UI.pop(oddsWin)
	end
end

-- Itens aleatórios pagos: o servidor publica o atributo PaidRandomAllowed (PolicyService).
local function paidRandomAllowed(): boolean
	return player:GetAttribute("PaidRandomAllowed") == true
end

local function buildBoxesTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, box in Config.Lunchboxes do
		local card = UI.frame(scroll, {
			Size = UDim2.new(1, -10, 0, 136),
			LayoutOrder = i,
			BackgroundColor3 = UI.Colors.Panel2,
		})
		UI.stroke(card, box.color, 3)
		-- Skin nova da caixa (arte do usuário, assets/HUD nova referencia/lunchbox_*.png); sem ela, o
		-- quadrado colorido com "?" de antes.
		local skin = UI.icon(card, "box_" .. box.id, {
			Size = UDim2.fromOffset(112, 112),
			Position = UDim2.fromOffset(8, 12),
			ZIndex = card.ZIndex + 1,
		})
		if skin:IsA("TextLabel") then
			skin:Destroy()
			local icon = UI.frame(
				card,
				{ Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(20, 28), BackgroundColor3 = box.color }
			)
			UI.label(
				icon,
				"?",
				{ Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.3 }
			)
		end
		UI.label(card, box.name, {
			Size = UDim2.new(1, -290, 0, 34),
			Position = UDim2.fromOffset(128, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = box.color,
		})
		summaryLabels[box.id] = UI.label(card, oddsSummary(box.id, nil), {
			Size = UDim2.new(1, -290, 0, 82),
			Position = UDim2.fromOffset(128, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextTransparency = 0.2,
		})
		local btn = UI.button(card, Util.formatNumber(box.price) .. " $", UI.Colors.Accent, {
			Size = UDim2.fromOffset(140, 50),
			Position = UDim2.new(1, -152, 0.5, -52),
			TextColor3 = Color3.new(1, 1, 1),
		})
		local oddsBtn = UI.button(card, "CHANCES", UI.Colors.Blue, {
			Size = UDim2.fromOffset(140, 48),
			Position = UDim2.new(1, -152, 0.5, 6),
		})
		oddsBtn.Activated:Connect(function()
			Shop.showOdds(box.id, nil, box.name)
		end)
		btn.Activated:Connect(function()
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
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local order = 0
	local function row(name: string, desc: string, color: Color3, buttonText: string, cb: () -> ()): TextButton
		order += 1
		local card = UI.frame(scroll, { Size = UDim2.new(1, -10, 0, 92), LayoutOrder = order })
		UI.stroke(card, color, 2)
		UI.label(card, name, {
			Size = UDim2.new(1, -200, 0, 30),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
		})
		UI.label(card, desc, {
			Size = UDim2.new(1, -200, 0, 48),
			Position = UDim2.fromOffset(12, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextTransparency = 0.2,
		})
		local btn = UI.button(
			card,
			buttonText,
			color,
			{ Size = UDim2.fromOffset(160, 48), Position = UDim2.new(1, -172, 0.5, -24) }
		)
		btn.Activated:Connect(cb)
		return btn
	end

	order += 1
	UI.label(scroll, "GAME PASSES", {
		Size = UDim2.new(1, -10, 0, 24),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
	})
	for _, p in PASS_INFO do
		passButtons[p.key] = row(p.name, p.desc, UI.Colors.Accent, "COMPRAR", function()
			Remotes.RequestGamePass:FireServer(p.key)
		end)
	end
	order += 1
	UI.label(scroll, "PRODUTOS", {
		Size = UDim2.new(1, -10, 0, 24),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Blue,
	})
	for _, p in PRODUCT_INFO do
		local def = (Config.DevProducts :: any)[p.key]
		local gated = def and (def.paidRandom == true or def.fundsRandom == true)
		local btn = row(p.name, p.desc, UI.Colors.Blue, "ROBUX", function()
			if gated and not paidRandomAllowed() then
				return -- o servidor também recusa; aqui só evita o clique inútil
			end
			Remotes.RequestPurchase:FireServer(p.key)
		end)
		if def and def.paidRandom then
			-- Chances SEMPRE visíveis antes da compra (regra de 2026).
			btn.Size = UDim2.fromOffset(160, 30)
			btn.Position = UDim2.new(1, -172, 0.5, -32)
			local card = btn.Parent :: GuiObject
			local oddsBtn = UI.button(card, "CHANCES", UI.Colors.Accent, {
				Size = UDim2.fromOffset(160, 40),
				Position = UDim2.new(1, -172, 0.5, 4),
			})
			oddsBtn.Activated:Connect(function()
				Shop.showOdds("rare", "Rare", p.name .. " (Lunchbox Rara, mínimo Rare)")
			end)
		end
		if gated then
			gatedButtons[btn] = true
		end
	end
	local function refreshGated()
		for btn in gatedButtons do
			if paidRandomAllowed() then
				btn.Text = "ROBUX"
				btn.BackgroundColor3 = UI.Colors.Blue
			else
				btn.Text = "INDISPONÍVEL"
				btn.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
			end
		end
	end
	player:GetAttributeChangedSignal("PaidRandomAllowed"):Connect(refreshGated)
	refreshGated()
end

local speciesCards: { [string]: TextButton } = {}

-- Confirmação antes de qualquer compra de espécie (pedido do usuário: estátuas "ENCONTRAR X" mostram
-- preço e atributos reais e só compram depois de confirmar; nunca ao se aproximar).
local confirmWin: Frame
local confirmTitle: TextLabel
local confirmDesc: TextLabel
local confirmStats: TextLabel
local confirmBuy: TextButton
local confirmSpecies: string? = nil

local function speciesAction(sp: any): (string, Color3, () -> ())
	local s = State.current :: any
	local owned = s.ownedSpecies and s.ownedSpecies[sp.id]
	if s.species == sp.id then
		return "EQUIPADO ✓", UI.Colors.Green, function() end
	elseif owned then
		return "EQUIPAR", UI.Colors.Blue, function()
			Remotes.RequestEquipSpecies:FireServer(sp.id)
		end
	elseif sp.robux and sp.passKey then
		return "COMPRAR (ROBUX)",
			Color3.fromRGB(40, 190, 90),
			function()
				Remotes.RequestGamePass:FireServer(sp.passKey)
			end
	elseif (s.speciesTokens or 0) > 0 then
		return "USAR FICHA", UI.Colors.Accent, function()
			Remotes.RequestBuySpecies:FireServer(sp.id, true)
		end
	end
	local can = (s.coins or 0) >= sp.price
	return "COMPRAR  $ " .. Util.formatNumber(sp.price),
		if can then UI.Colors.Accent else Color3.fromRGB(90, 90, 100),
		function()
			if can then
				Remotes.RequestBuySpecies:FireServer(sp.id, false)
			end
		end
end

local confirmAction: () -> () = function() end

local function renderConfirm()
	local id = confirmSpecies
	local sp: any = if id then Config.SpeciesById[id] else nil
	if not sp then
		return
	end
	confirmTitle.Text = Locale.upper(sp.name) .. "  [" .. sp.rarityTag .. "]"
	confirmTitle.TextColor3 = sp.color
	confirmDesc.Text = sp.desc
	confirmStats.Text = string.format(
		"XP x%.2f  •  Moedas x%.2f  •  Força na arena %d  •  Vida %d HP",
		sp.xpMult,
		sp.coinMult,
		sp.arenaPower,
		sp.arenaHp
	)
	local text, color, action = speciesAction(sp)
	confirmBuy.Text = text
	confirmBuy.BackgroundColor3 = color
	confirmAction = action
end

function Shop.confirmSpecies(id: string)
	confirmSpecies = id
	renderConfirm()
	if not confirmWin.Visible then
		UI.pop(confirmWin)
	end
end

local function buildConfirm(gui: ScreenGui)
	local body: Frame
	confirmWin, body = UI.window(gui, "GIGANTE", UDim2.fromOffset(560, 330))
	confirmTitle = UI.label(body, "", { Size = UDim2.new(1, 0, 0, 40) })
	confirmDesc = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 46),
		TextScaled = false,
		TextSize = 22,
		TextWrapped = true,
	})
	confirmStats = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.fromOffset(0, 106),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = UI.Colors.Accent,
	})
	confirmBuy = UI.button(body, "", UI.Colors.Accent, {
		Size = UDim2.new(0.62, -6, 0, 56),
		Position = UDim2.new(0, 0, 1, -64),
		TextScaled = false,
		TextSize = 24,
	})
	local cancel = UI.button(body, "CANCELAR", Color3.fromRGB(96, 102, 118), {
		Size = UDim2.new(0.38, -6, 0, 56),
		Position = UDim2.new(0.62, 6, 1, -64),
		TextScaled = false,
		TextSize = 24,
	})
	confirmBuy.Activated:Connect(function()
		confirmAction()
		confirmWin.Visible = false
	end)
	cancel.Activated:Connect(function()
		confirmWin.Visible = false
	end)
	State.onChanged(function()
		if confirmWin.Visible then
			renderConfirm()
		end
	end)
	-- Estátuas da praça: ProximityPrompt com o atributo SpeciesId abre esta confirmação.
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		local sid = prompt:GetAttribute("SpeciesId")
		if type(sid) == "string" then
			Shop.confirmSpecies(sid)
		end
	end)
end
local function buildSpeciesTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	UI.label(
		scroll,
		"Cada espécie muda forma, XP, moedas, fome e força na arena. Trocar é grátis depois de comprar.",
		{
			Size = UDim2.new(1, -10, 0, 52),
			LayoutOrder = 0,
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextTransparency = 0.2,
		}
	)
	for i, sp in Config.Species do
		local card = UI.panel(scroll, { Size = UDim2.new(1, -10, 0, 116), LayoutOrder = i })
		UI.stroke(card, sp.color, 2)
		local icon = UI.frame(
			card,
			{ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 30), BackgroundColor3 = sp.skin }
		)
		UI.corner(icon, 28)
		UI.stroke(icon, sp.color, 3)
		UI.label(card, sp.name .. "  [" .. sp.rarityTag .. "]", {
			Size = UDim2.new(1, -260, 0, 26),
			Position = UDim2.fromOffset(76, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = sp.color,
		})
		UI.label(card, sp.desc, {
			Size = UDim2.new(1, -260, 0, 46),
			Position = UDim2.fromOffset(76, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextTransparency = 0.2,
		})
		UI.label(
			card,
			string.format("XP x%.2f • $ x%.2f • Arena %d/%dHP", sp.xpMult, sp.coinMult, sp.arenaPower, sp.arenaHp),
			{
				Size = UDim2.new(1, -260, 0, 24),
				Position = UDim2.fromOffset(76, 84),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 20,
				TextColor3 = UI.Colors.Accent,
			}
		)
		local btn =
			UI.button(card, "", sp.color, { Size = UDim2.fromOffset(160, 48), Position = UDim2.new(1, -172, 0.5, -24) })
		btn.Activated:Connect(function()
			local s = State.current :: any
			if s.ownedSpecies and s.ownedSpecies[sp.id] then
				Remotes.RequestEquipSpecies:FireServer(sp.id)
			else
				Shop.confirmSpecies(sp.id) -- compra só depois de confirmar
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
		elseif (a.speciesTokens or 0) > 0 then
			btn.Text = string.format("USAR FICHA (%d)", a.speciesTokens)
			btn.BackgroundColor3 = UI.Colors.Accent
		else
			btn.Text = "$ " .. Util.formatNumber(sp.price)
			btn.BackgroundColor3 = if s.coins >= sp.price then sp.color else Color3.fromRGB(90, 90, 110)
		end
	end
end

-- Janela do pedestal "RENOVAR ESCUDO" (item 8). Moedas: 2 cliques (o segundo confirma). Robux: o
-- próprio diálogo de compra da Roblox confirma.
local function buildShield(gui: ScreenGui)
	local body: Frame
	local shieldWin: Frame
	shieldWin, body = UI.window(gui, "ESCUDO DA BASE", UDim2.fromOffset(560, 360))
	local status = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 40),
		TextScaled = false,
		TextSize = 26,
		TextColor3 = UI.Colors.Blue,
	})
	UI.label(body, "Com escudo, ninguém rouba comida do seu pátio.", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 42),
		TextScaled = false,
		TextSize = 20,
		TextTransparency = 0.2,
	})
	local coinBtn = UI.button(body, "", UI.Colors.Accent, {
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 84),
		TextScaled = false,
		TextSize = 24,
	})
	local superBtn = UI.button(body, "", UI.Colors.Blue, {
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 162),
		TextScaled = false,
		TextSize = 24,
	})
	local data: any = nil
	local leftAt = 0
	local confirming = false
	local function render()
		if not data then
			return
		end
		local left = math.max(0, leftAt - os.time())
		status.Text = if left > 0
			then string.format("🛡 Escudo ativo: %d:%02d", left // 60, left % 60)
			else "Sem escudo: sua base pode ser roubada!"
		status.TextColor3 = if left > 0 then UI.Colors.Blue else UI.Colors.Red
		local secs = math.floor((data.coinSeconds or 300) / 60)
		if confirming then
			coinBtn.Text = string.format("CONFIRMAR: pagar %s moedas?", Util.formatNumber(data.coinPrice or 0))
			coinBtn.BackgroundColor3 = UI.Colors.Orange
		else
			coinBtn.Text = string.format(
				"%s %d MIN  •  %s $",
				if left > 0 then "RENOVAR +" else "ATIVAR",
				secs,
				Util.formatNumber(data.coinPrice or 0)
			)
			coinBtn.BackgroundColor3 = if (State.current.coins or 0) >= (data.coinPrice or 0)
				then UI.Colors.Accent
				else Color3.fromRGB(90, 90, 100)
		end
		if data.superAvailable then
			superBtn.Text = string.format("SUPER ESCUDO %d MIN (ROBUX)", math.floor((data.superSeconds or 600) / 60))
			superBtn.BackgroundColor3 = UI.Colors.Blue
		else
			superBtn.Text = "SUPER ESCUDO (em breve)"
			superBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
	coinBtn.Activated:Connect(function()
		if not data then
			return
		end
		if not confirming then
			confirming = true
			render()
			task.delay(4, function()
				confirming = false
				render()
			end)
			return
		end
		confirming = false
		Remotes.RequestShieldRenew:FireServer()
		render()
	end)
	superBtn.Activated:Connect(function()
		if data and data.superAvailable then
			Remotes.RequestPurchase:FireServer("SuperShield")
		end
	end)
	Remotes.ShieldMenu.OnClientEvent:Connect(function(d)
		if type(d) ~= "table" then
			return
		end
		data = d
		leftAt = os.time() + (tonumber(d.left) or 0)
		confirming = false
		render()
		if not shieldWin.Visible then
			UI.pop(shieldWin)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if shieldWin.Visible then
				render()
			end
		end
	end)
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
	redeem.Activated:Connect(function()
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

-- Pedido do usuário (item 7): três lojas separadas. LOJA = Lunchboxes (moedas); GIGANTES = espécies;
-- LOJA ROBUX = passes e produtos, aberta de qualquer lugar pelo botão R$ da HUD.
local speciesWin: Frame
local robuxWin: Frame

local function openWin(w: Frame)
	for _, other in { win, speciesWin, robuxWin } do
		if other ~= w and other.Visible then
			other.Visible = false
		end
	end
	if not w.Visible then
		UI.pop(w)
	end
end

function Shop.open()
	openWin(win)
end

function Shop.openSpecies()
	openWin(speciesWin)
end

function Shop.openRobux()
	openWin(robuxWin)
end

function Shop.openCodes()
	if not codesWin.Visible then
		UI.pop(codesWin)
	end
end

function Shop.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "LOJA DE LUNCHBOXES", UDim2.fromOffset(700, 560))
	buildBoxesTab(body)
	local sBody: Frame
	speciesWin, sBody = UI.window(gui, "LOJA DE GIGANTES", UDim2.fromOffset(700, 560))
	buildSpeciesTab(sBody)
	local rBody: Frame
	robuxWin, rBody = UI.window(gui, "LOJA ROBUX", UDim2.fromOffset(700, 560))
	buildRobuxTab(rBody)

	buildConfirm(gui)
	buildShield(gui)
	buildCodes(gui)
	buildOddsWindow(gui)
	State.onChanged(refresh)
	State.onChanged(refreshSpecies)
	print("[Client] Shop pronto para", player.Name)
end

return Shop
