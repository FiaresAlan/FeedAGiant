--!strict
-- Inventory.lua — janela de Inventário (comidas na mochila) e Pátio (slots ocupados), com ações Colocar / Alimentar / Recolher.
local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local State = require(script.Parent.Parent.State)
local FoodView = require(script.Parent.Parent.FoodView)

local Inventory = {}

local win: Frame
local invList: ScrollingFrame
local plotList: ScrollingFrame
local invTitle: TextLabel
local plotTitle: TextLabel

local function clear(container: Instance)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function makeList(parent: Frame, pos: UDim2): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.5, -6, 1, -36)
	scroll.Position = pos
	scroll.BackgroundColor3 = UI.Colors.Panel
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	UI.corner(scroll)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = scroll
	return scroll
end

local function foodRow(
	parent: Instance,
	def: Config.FoodDef,
	order: number,
	actions: { { text: string, color: Color3, cb: () -> () } },
	mut: string?,
	big: boolean?
): Frame
	local rar = Config.Rarities[def.rarity]
	local row =
		UI.frame(parent, { Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order, BackgroundColor3 = UI.Colors.Bg })
	UI.stroke(row, rar.color, 2)
	-- Miniatura 3D (FoodView); quadrado colorido se o modelo ainda não chegou.
	local thumb = UI.frame(row, {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.fromOffset(6, 5),
		BackgroundColor3 = UI.Colors.Panel,
	})
	UI.corner(thumb, 10)
	if not FoodView.create(thumb, def.id, { yaw = 30 }) then
		local swatch = UI.frame(thumb, {
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = def.color,
		})
		UI.corner(swatch, def.shape == "Ball" and 18 or 8)
	end
	-- Mutação (noite 09/11): nome na frente, na cor dela, e contorno da cor
	local m = mut and GameRules.Mutations[mut]
	UI.label(row, (if big then "XL " else "") .. def.name, {
		Size = UDim2.new(1, -60 - #actions * 92, 0, 26),
		Position = UDim2.fromOffset(56, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if m then m.color else nil,
	})
	if m then
		UI.stroke(row, m.color, 3)
	end
	-- 4.3: a característica muda o XP (ao comer) e a renda (exposta): mostra os valores JÁ ajustados
	-- e o selo colorido da característica no nome.
	local trait = GameRules.traitOf(def.id)
	-- Mutação e Fusão (noite 09/11) entram nos valores mostrados e como etiqueta na 2ª linha
	local extra = (if big then GameRules.Fusion.Mult else 1)
	local xpShown = math.floor(rar.xp * (if trait then trait.xpMult else 1) * GameRules.mutationXp(mut) * extra)
	local cpsShown = math.floor(
		rar.cps * (if trait then trait.incomeMult else 1) * GameRules.mutationIncome(mut) * extra * 10 + 0.5
	) / 10
	local tags = (if m then "  ·  " .. m.name else "") .. (if big then "  ·  Gigantesca" else "")
	if trait and #actions < 3 then -- com 3 botões (FUNDIR) não sobra espaço: o nome tem prioridade
		UI.label(row, trait.icon .. " " .. Locale.t(trait.name), {
			Size = UDim2.fromOffset(150, 22),
			Position = UDim2.new(1, -(150 + #actions * 92), 0, 6),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 18,
			TextColor3 = trait.color,
		})
	end
	UI.label(row, Locale.fmt("food_row", nil, { r = Locale.rarity(def.rarity), x = xpShown, c = cpsShown }) .. tags, {
		Size = UDim2.new(1, -60 - #actions * 92, 0, 20),
		Position = UDim2.fromOffset(56, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextColor3 = rar.color,
	})
	for i, a in actions do
		local b = UI.button(
			row,
			a.text,
			a.color,
			{ Size = UDim2.fromOffset(84, 40), Position = UDim2.new(1, -(92 * i), 0.5, -20) }
		)
		b.Activated:Connect(a.cb)
	end
	return row
end

local function refresh(s: State.PlayerState)
	if not win.Visible then
		return
	end
	clear(invList)
	clear(plotList)

	invTitle.Text = Locale.fmt("backpack_n", nil, { n = #s.inventory })
	plotTitle.Text = Locale.fmt("yard_n", nil, { n = State.plotCount(), m = s.maxSlots })

	-- Fusão (noite 09/11): quantas iguais (sem fusão) há de cada comida; FUNDIR aparece com 3+
	local sameCount: { [string]: number } = {}
	for _, food in s.inventory do
		if not (food :: any).big then
			sameCount[food.id] = (sameCount[food.id] or 0) + 1
		end
	end
	local fuseShown: { [string]: boolean } = {}
	for i, food in s.inventory do
		local def = Config.FoodById[food.id]
		if def then
			local idx = i
			local actions = {}
			if
				Features.on("Fusion")
				and not (food :: any).big
				and (sameCount[food.id] or 0) >= GameRules.Fusion.Count
				and not fuseShown[food.id]
			then
				fuseShown[food.id] = true -- 1 botão por tipo de comida
				local fid = food.id
				table.insert(actions, {
					text = "FUNDIR",
					color = UI.Colors.Orange,
					cb = function()
						Remotes.RequestFuse:FireServer(fid)
					end,
				})
			end
			local rowActions = {
				{
					text = "COLOCAR",
					color = UI.Colors.Blue,
					cb = function()
						Remotes.RequestPlace:FireServer(idx)
					end,
				},
				{
					text = "COMER",
					color = UI.Colors.Green,
					cb = function()
						Remotes.RequestFeed:FireServer({ inv = idx })
					end,
				},
			}
			for _, a in actions do
				table.insert(rowActions, a)
			end
			foodRow(invList, def, i, rowActions, (food :: any).mut, (food :: any).big)
		end
	end
	if #s.inventory == 0 then
		UI.label(
			invList,
			"Vazio. Compre uma Lunchbox na Loja!",
			{ Size = UDim2.new(1, 0, 0, 40), TextTransparency = 0.3 }
		)
	end

	local keys = {}
	for key in s.plot do
		table.insert(keys, tonumber(key) or 0)
	end
	table.sort(keys)
	for order, slot in keys do
		local food = s.plot[tostring(slot)]
		local def = food and Config.FoodById[food.id]
		if def then
			local slotIdx = slot
			foodRow(plotList, def, order, {
				{
					text = "RECOLHER",
					color = Color3.fromRGB(120, 120, 150),
					cb = function()
						Remotes.RequestPickup:FireServer(slotIdx)
					end,
				},
				{
					text = "COMER",
					color = UI.Colors.Green,
					cb = function()
						Remotes.RequestFeed:FireServer(slotIdx)
					end,
				},
			}, (food :: any).mut, (food :: any).big)
		end
	end
	if #keys == 0 then
		UI.label(
			plotList,
			"Nenhuma comida no pátio. Coloque para gerar moedas.",
			{ Size = UDim2.new(1, 0, 0, 40), TextTransparency = 0.3 }
		)
	end
end

function Inventory.open()
	if not win.Visible then
		UI.pop(win)
		refresh(State.current)
	end
end

function Inventory.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "INVENTÁRIO & PÁTIO", UDim2.fromOffset(760, 500))
	invTitle = UI.label(body, "MOCHILA", { Size = UDim2.new(0.5, -6, 0, 28), TextColor3 = UI.Colors.Blue })
	plotTitle = UI.label(
		body,
		"PÁTIO",
		{ Size = UDim2.new(0.5, -6, 0, 28), Position = UDim2.new(0.5, 6, 0, 0), TextColor3 = UI.Colors.Accent }
	)
	invList = makeList(body, UDim2.fromOffset(0, 32))
	plotList = makeList(body, UDim2.new(0.5, 6, 0, 32))
	State.onChanged(refresh)
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		if win.Visible then
			refresh(State.current)
		end
	end)
end

return Inventory
