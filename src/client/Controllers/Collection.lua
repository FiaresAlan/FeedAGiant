--!strict
-- Collection — índice de coleção (Fase 4: retenção). Mostra todas as comidas do jogo, por raridade:
-- as já descobertas em 3D com nome; as que faltam como silhueta escura com "???" e a raridade
-- (o jogador sabe o que procurar). Embaixo, as espécies de gigante (tem / falta).
-- O servidor é dono da lista (profile.discovered, marcado em PlotService.pushState); aqui só exibe.
-- Sem recompensa por enquanto (economia: decisão registrada no handoff como sugestão).
local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local FoodView = require(script.Parent.Parent.FoodView)

local Collection = {}

local win: Frame
local foodGrid: ScrollingFrame
local countLabel: TextLabel
local cards: { [string]: { card: Frame, view: Frame, name: TextLabel, shown: string? } } = {}
local speciesCards: { [string]: { card: Frame, state: TextLabel } } = {}
local lastSeenCount = -1

Collection.OnNewDiscovery = nil :: ((count: number) -> ())?

local function sortedFoods(): { Config.FoodDef }
	local list = table.clone(Config.Foods) :: { Config.FoodDef }
	table.sort(list, function(a, b)
		local ra, rb = Config.Rarities[a.rarity].order, Config.Rarities[b.rarity].order
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	return list
end

function Collection.count(s: State.PlayerState): (number, number)
	local found = s.discovered or {}
	local n = 0
	for _, def in Config.Foods do
		if found[def.id] then
			n += 1
		end
	end
	return n, #Config.Foods
end

-- Troca a miniatura quando a comida passa de "faltando" para "descoberta" (ou o modelo chega).
local function paintCard(def: Config.FoodDef, known: boolean)
	local c = cards[def.id]
	if not c then
		return
	end
	local want = (if known then "known" else "hidden") .. (if FoodView.has(def.id) then "3d" else "flat")
	if c.shown == want then
		return
	end
	c.shown = want
	for _, child in c.view:GetChildren() do
		child:Destroy()
	end
	local vf = FoodView.create(c.view, def.id, { silhouette = not known, yaw = 30 })
	if not vf then
		-- Sem modelo 3D: quadrado com a cor da comida (ou escuro, se faltando)
		local sw = UI.frame(c.view, {
			Size = UDim2.fromScale(0.6, 0.6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if known then def.color else Color3.fromRGB(28, 30, 48),
			ZIndex = c.view.ZIndex + 1,
		})
		UI.corner(sw, def.shape == "Ball" and 40 or 12)
	end
	c.name.Text = if known then def.name else "???"
	c.name.TextTransparency = if known then 0 else 0.35
end

local function refresh(s: State.PlayerState)
	local found = s.discovered or {}
	local n, total = Collection.count(s)
	if lastSeenCount >= 0 and n > lastSeenCount and Collection.OnNewDiscovery then
		(Collection.OnNewDiscovery :: (number) -> ())(n)
	end
	if lastSeenCount < 0 or n > lastSeenCount then
		lastSeenCount = n
	end
	if not win.Visible then
		return
	end
	countLabel.Text = Locale.fmt("collection_count", nil, { n = n, m = total })
	for _, def in Config.Foods do
		paintCard(def, found[def.id] == true)
	end
	local owned = s.ownedSpecies or {}
	for id, sc in speciesCards do
		local has = owned[id] == true
		sc.state.Text = if has then Locale.t("✔ TENHO") else Locale.t("🔒 FALTA")
		sc.state.TextColor3 = if has then UI.Colors.Green else Color3.fromRGB(170, 170, 190)
		sc.card.BackgroundTransparency = if has then 0 else 0.35
	end
end

function Collection.open()
	if not win.Visible then
		UI.pop(win)
		refresh(State.current)
	end
end

local function sectionTitle(parent: Instance, text: string, order: number): TextLabel
	return UI.label(parent, text, {
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
	})
end

function Collection.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "COLEÇÃO", UDim2.fromOffset(900, 580))

	countLabel = UI.label(body, "", {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 24,
	})

	foodGrid = Instance.new("ScrollingFrame")
	foodGrid.Name = "List"
	foodGrid.Size = UDim2.new(1, 0, 1, -36)
	foodGrid.Position = UDim2.fromOffset(0, 36)
	foodGrid.BackgroundColor3 = UI.Colors.Panel
	foodGrid.BorderSizePixel = 0
	foodGrid.ScrollBarThickness = 8
	foodGrid.CanvasSize = UDim2.fromOffset(0, 0)
	foodGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	foodGrid.ZIndex = 12
	foodGrid.Parent = body
	UI.corner(foodGrid)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = foodGrid
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = foodGrid

	local function grid(order: number, cell: Vector2): Frame
		local g = Instance.new("Frame")
		g.BackgroundTransparency = 1
		g.Size = UDim2.fromScale(1, 0)
		g.AutomaticSize = Enum.AutomaticSize.Y
		g.LayoutOrder = order
		g.ZIndex = 12
		g.Parent = foodGrid
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		gl.CellPadding = UDim2.fromOffset(10, 10)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = g
		return g
	end

	sectionTitle(foodGrid, Locale.t("COMIDAS"), 1)
	local foods = grid(2, Vector2.new(132, 168))
	for i, def in sortedFoods() do
		local rar = Config.Rarities[def.rarity]
		local card = UI.frame(foods, { LayoutOrder = i, BackgroundColor3 = UI.Colors.Bg, ZIndex = 13 })
		UI.corner(card, 14)
		UI.stroke(card, rar.color, 3)
		local view = UI.frame(card, {
			Size = UDim2.new(1, -12, 0, 100),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(16, 20, 54),
			ZIndex = 14,
		})
		UI.corner(view, 10)
		local name = UI.label(card, "???", {
			Size = UDim2.new(1, -8, 0, 28),
			Position = UDim2.fromOffset(4, 108),
			TextScaled = true,
			ZIndex = 14,
		})
		UI.label(card, string.upper(Locale.t(def.rarity)), {
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 138),
			TextScaled = false,
			TextSize = 18,
			TextColor3 = rar.color,
			ZIndex = 14,
		})
		cards[def.id] = { card = card, view = view, name = name }
	end

	sectionTitle(foodGrid, Locale.t("ESPÉCIES DE GIGANTE"), 3)
	local species = grid(4, Vector2.new(200, 84))
	for i, sp in Config.Species do
		local card = UI.frame(species, { LayoutOrder = i, BackgroundColor3 = UI.Colors.Bg, ZIndex = 13 })
		UI.corner(card, 14)
		UI.stroke(card, sp.color, 3)
		local dot = UI.frame(card, {
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(8, 20),
			BackgroundColor3 = sp.skin or sp.color,
			ZIndex = 14,
		})
		UI.corner(dot, 22)
		UI.label(card, sp.name, {
			Size = UDim2.new(1, -66, 0, 36),
			Position = UDim2.fromOffset(60, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			ZIndex = 14,
		})
		local state = UI.label(card, "", {
			Size = UDim2.new(1, -66, 0, 26),
			Position = UDim2.fromOffset(60, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 18,
			ZIndex = 14,
		})
		speciesCards[sp.id] = { card = card, state = state }
	end

	State.onChanged(refresh)
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		if win.Visible then
			refresh(State.current)
		end
	end)
	-- Os modelos 3D chegam depois do cliente: repinta quando a pasta ganha um modelo.
	task.spawn(function()
		local folder = game.ReplicatedStorage:WaitForChild("FoodTemplates", 60)
		if folder then
			folder.ChildAdded:Connect(function()
				task.defer(function()
					if win.Visible then
						refresh(State.current)
					end
				end)
			end)
		end
	end)
end

return Collection
