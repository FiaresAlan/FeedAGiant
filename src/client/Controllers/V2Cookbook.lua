--!strict
-- V2: Livro e duas panelas, painel sem overlay. O servidor sempre decide posses, tempos e resultados.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Features = require(ReplicatedStorage.Shared.Features)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local Cookbook = {}

local PANEL_BG = Color3.fromRGB(31, 41, 53)
local CARD = Color3.fromRGB(46, 58, 70)
local GOLD = Color3.fromRGB(255, 197, 91)
local TEXT = Color3.fromRGB(246, 243, 237)
local SUBTEXT = Color3.fromRGB(187, 201, 213)

local snapshot: any = { slots = {}, recipes = {}, now = os.time() }
local chosenPot = 1
local firstId: string? = nil
local secondId: string? = nil
local chosenRecipe: string? = nil
local panel: Frame?
local bookButton: TextButton?
local potA: TextButton?
local potB: TextButton?
local firstBtn: TextButton?
local secondBtn: TextButton?
local status: TextLabel?
local list: ScrollingFrame?
local chosenLabel: TextLabel?

local function decorate(gui: GuiObject, r: number, strokeColor: Color3?)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, r)
	round.Parent = gui
	if strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = 1.5
		stroke.Transparency = 0.25
		stroke.Parent = gui
	end
end

local function label(parent: Instance, text: string, size: number, bold: boolean): TextLabel
	local node = Instance.new("TextLabel")
	node.Text = text
	node.TextColor3 = TEXT
	node.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	node.TextSize = size
	node.TextXAlignment = Enum.TextXAlignment.Left
	node.BackgroundTransparency = 1
	node.TextWrapped = true
	node.Parent = parent
	return node
end

local function button(parent: Instance, text: string, size: UDim2, bg: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = "V2Button"
	b.Size = size
	b.BackgroundColor3 = bg
	b.Text = text
	b.TextColor3 = TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextWrapped = true
	b.AutoButtonColor = true
	b.Parent = parent
	decorate(b, 10)
	return b
end

local function ownedIngredientIds(): { string }
	local found: { [string]: boolean } = {}
	for _, item in State.current.inventory do
		if Config.FoodById[item.id] then
			found[item.id] = true
		end
	end
	local ids = {}
	for id in found do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

local function nextIngredient(current: string?): string?
	local choices = ownedIngredientIds()
	if #choices == 0 then
		return nil
	end
	if not current then
		return choices[1]
	end
	for i, id in choices do
		if id == current then
			return choices[(i % #choices) + 1]
		end
	end
	return choices[1]
end

local function displayFood(id: string?): string
	if not id then
		return "Escolher ingrediente"
	end
	local def = Config.FoodById[id]
	return if def then def.name else id
end

local function clock(seconds: number): string
	if seconds <= 0 then
		return "PRONTO"
	end
	return string.format("%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function draw()
	if not panel or not panel.Parent then
		return
	end
	local now = os.time()
	for i, widget in { potA, potB } do
		if widget then
			local slot = snapshot.slots[i] or { state = "empty" }
			local name = if i == 1 then "A" else "B"
			local line = if slot.state == "empty" then "Vazia"
				elseif slot.state == "ready" or (slot.endsAtUtc or math.huge) <= now then "PRONTO!"
				else clock(math.max(0, (slot.endsAtUtc or now) - now))
			widget.Text = "PANELA " .. name .. "\n" .. line
			widget.BackgroundColor3 = if chosenPot == i then Color3.fromRGB(72, 112, 117) else CARD
		end
	end
	if firstBtn then firstBtn.Text = "1 · " .. displayFood(firstId) end
	if secondBtn then secondBtn.Text = "2 · " .. displayFood(secondId) end
	if chosenLabel then chosenLabel.Text = "Selecionada: " .. (chosenRecipe or "experimente 2 ingredientes") end
	if status then
		local slot = snapshot.slots[chosenPot] or { state = "empty" }
		status.Text = if slot.state == "empty" then "Panela livre. Escolha uma receita ou experimente ingredientes."
			elseif slot.state == "ready" or (slot.endsAtUtc or math.huge) <= now then "Prato pronto! Toque em COLETAR."
			else (slot.recipeName or "Cozinhando") .. " · " .. clock(math.max(0, (slot.endsAtUtc or now) - now))
	end
end

local function drawRecipes()
	if not list then return end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, rec in snapshot.recipes or {} do
		local name = if rec.discovered then rec.name else "??? — Receita desconhecida"
		local r = button(list, name .. "\n" .. (if rec.discovered
			then ("Pronto em " .. clock(rec.seconds or 0) .. " · " .. rec.rarity)
			else (rec.hint or "Encontre ingredientes")), UDim2.new(1, -10, 0, 60),
			if rec.discovered then CARD else Color3.fromRGB(42, 48, 58))
		r.TextXAlignment = Enum.TextXAlignment.Left
		r.TextSize = 13
		r.TextColor3 = if rec.discovered then TEXT else SUBTEXT
		r.MouseButton1Click:Connect(function()
			if rec.discovered then
				chosenRecipe = rec.id
				draw()
			end
		end)
	end
end

function Cookbook.init(gui: ScreenGui)
	if not Features.on("RebuildV2") then
		return
	end
	bookButton = button(gui, "LIVRO\n& PANELAS", UDim2.fromOffset(106, 54), GOLD)
	bookButton.Name = "V2OpenCookbook"
	bookButton.TextColor3 = Color3.fromRGB(37, 40, 45)
	bookButton.AnchorPoint = Vector2.new(1, 0)
	bookButton.Position = UDim2.new(1, -14, 0, 90)
	bookButton.ZIndex = 11

	panel = Instance.new("Frame")
	panel.Name = "V2CookbookPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 12)
	panel.Size = UDim2.new(0.88, 0, 0.90, 0)
	panel.BackgroundColor3 = PANEL_BG
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = gui
	decorate(panel, 16, GOLD)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(510, 630)
	limit.Parent = panel

	local head = label(panel, "LIVRO DE RECEITAS", 21, true)
	head.Position = UDim2.fromOffset(18, 12)
	head.Size = UDim2.new(1, -75, 0, 34)
	head.ZIndex = 31
	local close = button(panel, "×", UDim2.fromOffset(38, 36), CARD)
	close.Position = UDim2.new(1, -51, 0, 10)
	close.TextSize = 24
	close.ZIndex = 31
	close.MouseButton1Click:Connect(function() if panel then panel.Visible = false end end)

	local pots = Instance.new("Frame")
	pots.BackgroundTransparency = 1
	pots.Position = UDim2.fromOffset(12, 51)
	pots.Size = UDim2.new(1, -24, 0, 69)
	pots.ZIndex = 31
	pots.Parent = panel
	potA = button(pots, "PANELA A", UDim2.new(0.49, 0, 1, 0), CARD)
	potB = button(pots, "PANELA B", UDim2.new(0.49, 0, 1, 0), CARD)
	potB.Position = UDim2.new(0.51, 0, 0, 0)
	potA.MouseButton1Click:Connect(function() chosenPot = 1; draw() end)
	potB.MouseButton1Click:Connect(function() chosenPot = 2; draw() end)

	status = label(panel, "Buscando panelas...", 12, false)
	status.Position = UDim2.fromOffset(18, 124)
	status.Size = UDim2.new(1, -36, 0, 38)
	status.TextColor3 = SUBTEXT
	status.ZIndex = 31

	firstBtn = button(panel, "Ingrediente 1", UDim2.new(0.45, 0, 0, 42), CARD)
	secondBtn = button(panel, "Ingrediente 2", UDim2.new(0.45, 0, 0, 42), CARD)
	firstBtn.Position = UDim2.new(0.04, 0, 0, 164)
	secondBtn.Position = UDim2.new(0.51, 0, 0, 164)
	firstBtn.ZIndex = 31
	secondBtn.ZIndex = 31
	firstBtn.MouseButton1Click:Connect(function() firstId = nextIngredient(firstId); chosenRecipe = nil; draw() end)
	secondBtn.MouseButton1Click:Connect(function() secondId = nextIngredient(secondId); chosenRecipe = nil; draw() end)

	local combine = button(panel, "EXPERIMENTAR", UDim2.new(0.45, 0, 0, 42), Color3.fromRGB(75, 111, 94))
	local start = button(panel, "COZINHAR SELECIONADA", UDim2.new(0.49, 0, 0, 42), Color3.fromRGB(75, 111, 94))
	combine.Position = UDim2.new(0.04, 0, 0, 210)
	start.Position = UDim2.new(0.51, 0, 0, 210)
	combine.ZIndex = 31
	start.ZIndex = 31
	combine.MouseButton1Click:Connect(function()
		if firstId and secondId then
			Remotes.V2CookRequest:FireServer("combine", chosenPot, firstId, secondId)
		end
	end)
	start.MouseButton1Click:Connect(function()
		if chosenRecipe then Remotes.V2CookRequest:FireServer("start", chosenPot, chosenRecipe) end
	end)

	local claim = button(panel, "COLETAR PRATO PRONTO", UDim2.new(0.92, 0, 0, 38), GOLD)
	claim.Position = UDim2.new(0.04, 0, 0, 257)
	claim.TextColor3 = Color3.fromRGB(34, 40, 46)
	claim.ZIndex = 31
	claim.MouseButton1Click:Connect(function()
		local slot = snapshot.slots[chosenPot]
		if slot and slot.jobId then
			Remotes.V2CookRequest:FireServer("claim", chosenPot, slot.jobId)
		end
	end)

	chosenLabel = label(panel, "Selecionada: nenhuma", 11, false)
	chosenLabel.Position = UDim2.fromOffset(18, 303)
	chosenLabel.Size = UDim2.new(1, -36, 0, 20)
	chosenLabel.TextColor3 = SUBTEXT
	chosenLabel.ZIndex = 31

	list = Instance.new("ScrollingFrame")
	list.Name = "V2Recipes"
	list.Size = UDim2.new(1, -24, 1, -338)
	list.Position = UDim2.fromOffset(12, 326)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 31
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	bookButton.MouseButton1Click:Connect(function()
		if panel then panel.Visible = not panel.Visible end
		Remotes.V2CookRequest:FireServer("snapshot")
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, consumed: boolean)
		if not consumed and input.KeyCode == Enum.KeyCode.B and panel then
			panel.Visible = not panel.Visible
			Remotes.V2CookRequest:FireServer("snapshot")
		end
	end)
	Remotes.V2CookState.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			snapshot = data
			draw()
			drawRecipes()
		end
	end)
	State.onChanged(function()
		if firstId and not table.find(ownedIngredientIds(), firstId) then firstId = nil end
		if secondId and not table.find(ownedIngredientIds(), secondId) then secondId = nil end
		draw()
	end)
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(1)
			if panel and panel.Visible then draw() end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "V2OpenCookbook" and panel then
			chosenPot = if prompt.ObjectText == "PANELA B" then 2 else 1
			panel.Visible = true
			draw()
			Remotes.V2CookRequest:FireServer("snapshot")
		end
	end)
	Remotes.V2CookRequest:FireServer("snapshot")
end

return Cookbook
