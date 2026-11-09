--!strict
-- Hatch.lua — animação de abertura de Lunchbox: caixa balança, explode em partículas e revela a comida com cor da raridade.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local UIAssets = require(game.ReplicatedStorage.Shared.UIAssets)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local FoodView = require(script.Parent.Parent.FoodView)

local Hatch = {}

local overlay: Frame
local box: Frame
local reveal: Frame
local revealName: TextLabel
local revealRarity: TextLabel
local revealView: Frame
local revealStroke: UIStroke
local busy = false
local queue: { any } = {}

-- Os IDs da v4 (9114653986/9114611543/9114646405) não são sons ("Asset type does not
-- match"); usa a biblioteca de sons do Config, verificada no Studio. SFX finais: Fase 3.
local SOUND_IDS = {
	shake = Config.Sounds.Whoosh,
	pop = Config.Sounds.Coin,
	rare = Config.Sounds.Win,
}

local function playSound(id: string, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	local g = SoundService:FindFirstChild("Efeitos")
	if g and g:IsA("SoundGroup") then
		s.SoundGroup = g
	end
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function burst(parent: Frame, color: Color3, count: number)
	for _ = 1, count do
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(math.random(8, 18), math.random(8, 18))
		p.Position = UDim2.fromScale(0.5, 0.5)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.Rotation = math.random(0, 360)
		p.Parent = parent
		UI.corner(p, 4)
		local angle = math.random() * math.pi * 2
		local dist = math.random(160, 320)
		TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist),
			BackgroundTransparency = 1,
			Rotation = p.Rotation + math.random(-180, 180),
		}):Play()
		task.delay(1, function()
			p:Destroy()
		end)
	end
end

local boxSkin: ImageLabel
local boxPlain: { GuiObject } = {}
local boxStroke: UIStroke
local lootRow: Frame
local lootTitle: TextLabel
local lootChips: Frame

-- v5 (09/11): a caixa traz várias comidas. Abaixo da melhor (a grande), aparece a fila com TODAS,
-- cada uma com a cor da raridade, para o jogador ver claramente o que ganhou.
local function showLoot(items: { any }?)
	for _, c in lootChips:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	lootRow.Visible = false
	if type(items) ~= "table" or #items <= 1 then
		return
	end
	lootTitle.Text = string.format("A CAIXA TROUXE %d COMIDAS", #items)
	for i, it in items do
		local rar = Config.Rarities[it.rarity] or Config.Rarities.Common
		local def = Config.FoodById[it.foodId]
		local chip = UI.frame(lootChips, {
			Size = UDim2.fromOffset(112, 30),
			LayoutOrder = i,
			BackgroundColor3 = UI.Colors.Panel,
			ZIndex = 52,
		})
		UI.corner(chip, 10)
		UI.stroke(chip, rar.color, 2)
		UI.label(chip, (def and def.name) or tostring(it.name), {
			Size = UDim2.new(1, -8, 1, -4),
			Position = UDim2.fromOffset(4, 2),
			TextColor3 = rar.color,
			ZIndex = 53,
		})
	end
	lootRow.Visible = true
end

local function play(data: {
	foodId: string,
	rarity: string,
	name: string?,
	color: Color3?,
	boxId: string?,
	items: { any }?,
})
	busy = true
	local def = Config.FoodById[data.foodId]
	local rar = Config.Rarities[data.rarity] or Config.Rarities.Common
	local isBig = rar.order >= 4

	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	-- Não escurecer nem bloquear a visão do gameplay quando abrir uma Lunchbox.
	-- A caixa e a revelação continuam animadas no primeiro plano.
	overlay.BackgroundTransparency = 1

	reveal.Visible = false
	box.Visible = true
	box.Rotation = 0
	box.Size = UDim2.fromOffset(0, 0)
	box.BackgroundColor3 = rar.color
	-- Skin nova da caixa (arte do usuário) quando houver; senão o quadrado colorido de antes.
	local skinId = data.boxId and (UIAssets :: { [string]: string })["extra_box_" .. data.boxId]
	boxSkin.Image = skinId or ""
	boxSkin.Visible = skinId ~= nil
	box.BackgroundTransparency = if skinId then 1 else 0
	boxStroke.Enabled = skinId == nil
	for _, g in boxPlain do
		g.Visible = skinId == nil
	end
	TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(160, 160) }):Play()
	task.wait(0.35)

	local shakes = isBig and 10 or 6
	for i = 1, shakes do
		local amp = 8 + i * (isBig and 3 or 2)
		TweenService:Create(box, TweenInfo.new(0.06), { Rotation = amp }):Play()
		task.wait(0.06)
		TweenService:Create(box, TweenInfo.new(0.06), { Rotation = -amp }):Play()
		task.wait(0.06)
		if i % 2 == 0 then
			playSound(SOUND_IDS.shake, 0.3)
		end
	end
	TweenService:Create(box, TweenInfo.new(0.1), { Rotation = 0, Size = UDim2.fromOffset(200, 200) }):Play()
	task.wait(0.12)

	box.Visible = false
	burst(overlay, rar.color, isBig and 60 or 28)
	playSound(isBig and SOUND_IDS.rare or SOUND_IDS.pop, isBig and 0.9 or 0.6)

	reveal.BackgroundColor3 = (def and def.color) or (data.color or rar.color)
	revealName.Text = (def and def.name) or (data.name or data.foodId)
	revealRarity.Text = Locale.upper(Locale.rarity(data.rarity))
	revealRarity.TextColor3 = rar.color
	-- Fase 3: a comida aparece em 3D girando (mesmo modelo do mundo); sem modelo, fica só a cor.
	for _, child in revealView:GetChildren() do
		child:Destroy()
	end
	if FoodView.create(revealView, data.foodId, { spin = true, zIndex = 53 }) then
		-- fundo escuro com borda da raridade: a comida 3D não some na própria cor (sorvete roxo)
		reveal.BackgroundColor3 = UI.Colors.Panel
		revealStroke.Color = rar.color
	else
		revealStroke.Color = Color3.new(1, 1, 1)
	end
	reveal.Size = UDim2.fromOffset(0, 0)
	reveal.Visible = true
	showLoot(data.items)
	TweenService:Create(
		reveal,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic),
		{ Size = UDim2.fromOffset(isBig and 300 or 240, isBig and 300 or 240) }
	):Play()

	local many = type(data.items) == "table" and #data.items > 1
	task.wait((isBig and 2.2 or 1.4) + (if many then 1.2 else 0))
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(reveal, TweenInfo.new(0.25), { Size = UDim2.fromOffset(0, 0) }):Play()
	task.wait(0.28)
	lootRow.Visible = false
	overlay.Visible = false
	busy = false
end

local function pump()
	while #queue > 0 do
		local data = table.remove(queue, 1)
		if data then
			play(data)
		end
	end
end

function Hatch.init(gui: ScreenGui)
	overlay = Instance.new("Frame")
	overlay.Name = "HatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 50
	overlay.Parent = gui

	box = UI.frame(overlay, {
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 51,
	})
	UI.corner(box, 20)
	boxStroke = UI.stroke(box, Color3.new(0, 0, 0), 4)
	boxSkin = Instance.new("ImageLabel")
	boxSkin.Name = "Skin"
	boxSkin.BackgroundTransparency = 1
	boxSkin.Size = UDim2.fromScale(1.25, 1.25)
	boxSkin.Position = UDim2.fromScale(0.5, 0.5)
	boxSkin.AnchorPoint = Vector2.new(0.5, 0.5)
	boxSkin.ScaleType = Enum.ScaleType.Fit
	boxSkin.ZIndex = 54
	boxSkin.Visible = false
	boxSkin.Parent = box
	local lid = UI.frame(box, {
		Size = UDim2.new(1, 16, 0, 36),
		Position = UDim2.fromOffset(-8, -10),
		BackgroundColor3 = Color3.fromRGB(40, 40, 60),
		ZIndex = 52,
	})
	UI.corner(lid, 10)
	local q = UI.label(
		box,
		"?",
		{ Size = UDim2.fromScale(1, 1), ZIndex = 53, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.4 }
	)
	boxPlain = { lid, q }

	reveal = UI.frame(overlay, {
		Size = UDim2.fromOffset(240, 240),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 51,
	})
	UI.corner(reveal, 28)
	revealStroke = UI.stroke(reveal, Color3.new(1, 1, 1), 4)
	revealName =
		UI.label(reveal, "", { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -96), ZIndex = 52 })
	revealView = Instance.new("Frame")
	revealView.Name = "View"
	revealView.BackgroundTransparency = 1
	revealView.Size = UDim2.new(1, -24, 1, -108)
	revealView.Position = UDim2.fromOffset(12, 10)
	revealView.ZIndex = 52
	revealView.Parent = reveal
	revealRarity =
		UI.label(reveal, "", { Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -50), ZIndex = 52 })
	lootRow = Instance.new("Frame")
	lootRow.Name = "Loot"
	lootRow.BackgroundTransparency = 1
	lootRow.AnchorPoint = Vector2.new(0.5, 0)
	lootRow.Position = UDim2.new(0.5, 0, 0.5, 160)
	lootRow.Size = UDim2.fromScale(0.92, 0)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(600, math.huge)
	cap.Parent = lootRow
	lootRow.AutomaticSize = Enum.AutomaticSize.Y
	lootRow.Visible = false
	lootRow.ZIndex = 52
	lootRow.Parent = overlay
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = lootRow
	lootTitle = UI.label(lootRow, "", {
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 0,
		TextScaled = false,
		TextSize = 20,
		ZIndex = 52,
	})
	lootTitle.TextStrokeTransparency = 0.3
	lootChips = Instance.new("Frame")
	lootChips.Name = "Chips"
	lootChips.BackgroundTransparency = 1
	lootChips.Size = UDim2.fromScale(1, 0)
	lootChips.AutomaticSize = Enum.AutomaticSize.Y
	lootChips.LayoutOrder = 1
	lootChips.ZIndex = 52
	lootChips.Parent = lootRow
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(112, 30)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = lootChips

	Remotes.HatchResult.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.foodId) == "string" then
			table.insert(queue, data)
			if not busy then
				task.spawn(pump)
			end
		end
	end)
end

return Hatch
