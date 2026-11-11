--!strict
-- HUD focada da V2. Sem tela escura, monetizacao ou menu legado sobre o ciclo principal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = require(ReplicatedStorage.Shared.Features)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Cookbook = require(script.Parent.V2Cookbook)

local Hub = {}
local rootGui: ScreenGui?
local inventoryPanel: Frame?
local scroll: ScrollingFrame?
local title: TextLabel?
local xpFill: Frame?
local levelLabel: TextLabel?
local pageLabel: TextLabel?
local page = 1
local starterButton: TextButton?
local PAGE_SIZE = 35

local COLOR = {
	dark = Color3.fromRGB(30, 45, 53),
	card = Color3.fromRGB(49, 65, 73),
	cream = Color3.fromRGB(250, 242, 213),
	gold = Color3.fromRGB(244, 195, 103),
	mint = Color3.fromRGB(108, 206, 179),
	sub = Color3.fromRGB(188, 204, 204),
}

local function rounded(inst: GuiObject, radius: number, border: boolean?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	if border then
		local s = Instance.new("UIStroke")
		s.Thickness = 1.5
		s.Color = COLOR.gold
		s.Transparency = 0.18
		s.Parent = inst
	end
end

local function text(parent: Instance, value: string, size: number, strong: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = value
	l.Font = if strong then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = COLOR.cream
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, caption: string, bg: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = caption
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = bg
	b.TextColor3 = COLOR.cream
	b.AutoButtonColor = true
	b.Parent = parent
	rounded(b, 10)
	return b
end

local function redrawInventory()
	if not scroll or not inventoryPanel or not inventoryPanel.Visible then return end
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local inv = State.current.inventory
	local pages = math.max(1, math.ceil(#inv / PAGE_SIZE))
	page = math.clamp(page, 1, pages)
	if pageLabel then pageLabel.Text = ("MOCHILA  •  %d COMIDAS  •  %d/%d"):format(#inv, page, pages) end
	local start = (page - 1) * PAGE_SIZE + 1
	for i = start, math.min(#inv, start + PAGE_SIZE - 1) do
		local item = inv[i]
		local def = Config.FoodById[item.id]
		local row = Instance.new("Frame")
		row.Name = "Food_" .. i
		row.BackgroundColor3 = COLOR.card
		row.Size = UDim2.new(1, -7, 0, 49)
		row.Parent = scroll
		rounded(row, 9)
		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.fromOffset(8, 10)
		swatch.Size = UDim2.fromOffset(28, 28)
		swatch.BackgroundColor3 = if def then def.color else COLOR.gold
		swatch.Parent = row
		rounded(swatch, 8)
		local name = text(row, if def then def.name else item.id, 12, true)
		name.Position = UDim2.fromOffset(43, 6)
		name.Size = UDim2.new(1, -158, 0, 34)
		local rarity = text(row, if def then def.rarity else "Comum", 10, false)
		rarity.TextColor3 = COLOR.sub
		rarity.Position = UDim2.fromOffset(44, 31)
		rarity.Size = UDim2.new(1, -152, 0, 16)
		local feed = button(row, "ALIMENTAR", COLOR.mint)
		feed.TextColor3 = COLOR.dark
		feed.Size = UDim2.fromOffset(105, 35)
		feed.Position = UDim2.new(1, -114, 0, 7)
		feed.MouseButton1Click:Connect(function()
			-- O servidor valida indice do inventario e distancia ate o proprio gigante.
			Remotes.RequestFeed:FireServer({ inv = i })
		end)
	end
end

local function refreshStats()
	if not title or not xpFill or not levelLabel then return end
	local s = State.current
	local species = if s.species then Config.SpeciesById[s.species] else nil
	title.Text = if species then species.name else "Meu gigante"
	if starterButton then starterButton.Visible = s.species == "human" end
	levelLabel.Text = ("NIVEL %d  •  FOME %d%%  •  %d MOEDAS"):format(
		math.floor(s.level), math.floor(s.hunger), math.floor(s.coins))
	xpFill.Size = UDim2.new(math.clamp(s.xp / math.max(1, s.xpNeeded), 0, 1), 0, 1, 0)
	redrawInventory()
end

function Hub.init(gui: ScreenGui)
	if not Features.on("RebuildV2") then return end
	rootGui = gui
	local top = Instance.new("Frame")
	top.Name = "V2CreatureHUD"
	top.Position = UDim2.fromOffset(14, 14)
	top.Size = UDim2.fromOffset(292, 102)
	top.BackgroundColor3 = COLOR.dark
	top.BackgroundTransparency = 0.06
	top.Parent = gui
	top.ZIndex = 17
	rounded(top, 14, true)
	local subtitle = text(top, "FEED A GIANT  /  NOVA JORNADA", 11, true)
	subtitle.Position = UDim2.fromOffset(13, 8)
	subtitle.Size = UDim2.new(1, -20, 0, 18)
	subtitle.TextColor3 = COLOR.gold
	title = text(top, "Meu gigante", 17, true)
	title.Position = UDim2.fromOffset(13, 27)
	title.Size = UDim2.new(1, -26, 0, 24)
	levelLabel = text(top, "NIVEL 1", 11, false)
	levelLabel.Position = UDim2.fromOffset(13, 54)
	levelLabel.Size = UDim2.new(1, -26, 0, 17)
	levelLabel.TextColor3 = COLOR.sub
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -26, 0, 10)
	bar.Position = UDim2.fromOffset(13, 78)
	bar.BackgroundColor3 = COLOR.card
	bar.Parent = top
	rounded(bar, 6)
	xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = COLOR.mint
	xpFill.Parent = bar
	rounded(xpFill, 6)

	starterButton = button(gui, "ESCOLHER GOLEM DE PEDRA · PRIMEIRA ESCOLHA", COLOR.mint)
	starterButton.Name = "V2ChooseStone"
	starterButton.TextColor3 = COLOR.dark
	starterButton.TextSize = 11
	starterButton.Size = UDim2.fromOffset(292, 45)
	starterButton.Position = UDim2.fromOffset(14, 124)
	starterButton.MouseButton1Click:Connect(function()
		-- Concessao validada pelo OnboardingService/GiantService; nao criar dado no cliente.
		Remotes.RequestStarter:FireServer("stone_starter")
	end)

	local actions = Instance.new("Frame")
	actions.Name = "V2PrimaryActions"
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Position = UDim2.new(0, 14, 1, -15)
	actions.Size = UDim2.fromOffset(268, 52)
	actions.BackgroundTransparency = 1
	actions.Parent = gui
	local feedOpen = button(actions, "ALIMENTAR", COLOR.gold)
	feedOpen.TextColor3 = COLOR.dark
	feedOpen.Size = UDim2.fromOffset(130, 50)
	local bookOpen = button(actions, "RECEITAS", COLOR.card)
	bookOpen.Size = UDim2.fromOffset(130, 50)
	bookOpen.Position = UDim2.fromOffset(138, 0)
	bookOpen.MouseButton1Click:Connect(function() Cookbook.open() end)

	inventoryPanel = Instance.new("Frame")
	inventoryPanel.Name = "V2Inventory"
	inventoryPanel.AnchorPoint = Vector2.new(0, 1)
	inventoryPanel.Position = UDim2.new(0, 14, 1, -80)
	inventoryPanel.Size = UDim2.new(0.85, 0, 0.67, 0)
	inventoryPanel.BackgroundColor3 = COLOR.dark
	inventoryPanel.Visible = false
	inventoryPanel.ZIndex = 33
	inventoryPanel.Parent = gui
	rounded(inventoryPanel, 14, true)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(400, 500)
	maxSize.Parent = inventoryPanel
	pageLabel = text(inventoryPanel, "MOCHILA", 15, true)
	pageLabel.Position = UDim2.fromOffset(12, 10)
	pageLabel.Size = UDim2.new(1, -62, 0, 30)
	local close = button(inventoryPanel, "×", COLOR.card)
	close.Size = UDim2.fromOffset(35, 33)
	close.Position = UDim2.new(1, -47, 0, 8)
	close.TextSize = 22
	close.MouseButton1Click:Connect(function() if inventoryPanel then inventoryPanel.Visible = false end end)
	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Foods"
	scroll.Position = UDim2.fromOffset(12, 49)
	scroll.Size = UDim2.new(1, -24, 1, -103)
	scroll.BackgroundTransparency = 1
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 4
	scroll.Parent = inventoryPanel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scroll
	local prev = button(inventoryPanel, "ANTERIOR", COLOR.card)
	prev.Size = UDim2.new(0.43, 0, 0, 38)
	prev.Position = UDim2.new(0.04, 0, 1, -46)
	local nextPage = button(inventoryPanel, "PRÓXIMA", COLOR.card)
	nextPage.Size = UDim2.new(0.43, 0, 0, 38)
	nextPage.Position = UDim2.new(0.53, 0, 1, -46)
	prev.MouseButton1Click:Connect(function() page = math.max(1, page - 1); redrawInventory() end)
	nextPage.MouseButton1Click:Connect(function() page += 1; redrawInventory() end)
	feedOpen.MouseButton1Click:Connect(function()
		if inventoryPanel then inventoryPanel.Visible = not inventoryPanel.Visible end
		redrawInventory()
	end)
	State.onChanged(function()
		refreshStats()
	end)
	refreshStats()
end

return Hub
