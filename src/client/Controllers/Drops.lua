--!strict
-- Drops.lua — HUD dos itens que caem no mapa (reforma de 08/11/2026, DropService):
--   * cartão "DISPUTA DE COMIDA" embaixo no meio (referência da HUD nova): item mais próximo, raridade
--     e estado ("libera em 0:12" / "LIVRE — pegue com E" / "carregado por Fulano");
--   * seta com distância até o item (ou até a SUA base quando você carrega algo);
--   * caixas trazidas para a base: aviso "ABRIR AGORA / DEPOIS" e chip "CAIXAS (N)" (nunca abre sozinha).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local State = require(script.Parent.Parent.State)

local Drops = {}
local player = Players.LocalPlayer
local drops: { [number]: any } = {}
local card: Frame
local cardTitle: TextLabel
local cardState: TextLabel
local arrow: TextLabel
local boxChip: TextButton
local boxWin: Frame
local boxTitle: TextLabel
local boxBody: Frame

local function myBasePos(): Vector3?
	-- A base do jogador é onde está o gigante dele (o servidor marca OwnerUserId no modelo).
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m:GetPivot().Position
		end
	end
	return nil
end

local function mmss(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function stateText(d: any): (string, Color3)
	if d.carrierId == player.UserId then
		return "VOCÊ CARREGA! Leve até a sua base (soco derruba)", UI.Colors.Green
	elseif d.carrierId then
		return string.format("Carregado por %s — dê um soco para derrubar!", tostring(d.carrierName)), UI.Colors.Red
	elseif not d.landed then
		return "Caindo na praça...", UI.Colors.Muted
	end
	local left = (tonumber(d.unlockAt) or 0) - Workspace:GetServerTimeNow()
	if left > 0 then
		return "🔒 Libera em " .. mmss(left), UI.Colors.Accent
	end
	return "LIVRE! Chegue perto e pegue (E / toque)", UI.Colors.Green
end

local function nearest(): (any?, number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bd = nil, math.huge
	for _, d in drops do
		if d.carrierId == player.UserId then
			return d, 0 -- o que eu carrego tem prioridade
		end
	end
	for _, d in drops do
		local pos = d.pos
		if typeof(pos) == "Vector3" and root then
			local dist = (pos - root.Position).Magnitude
			if dist < bd then
				bd, best = dist, d
			end
		elseif best == nil and d.carrierId then
			best = d
		end
	end
	return best, bd
end

local function refresh()
	local d, _ = nearest()
	-- Pedido do usuário (09/11, item 13): o cartão "DISPUTA DE COMIDA" embaixo no meio saiu de vez.
	-- Cada item já mostra o nome e o tempo em cima dele no mundo.
	card.Visible = false
	if not d then
		arrow.Visible = false
		return
	end
	local rar = Config.Rarities[d.rarity] or Config.Rarities.Common
	cardTitle.Text = string.format("%s (%s)", tostring(d.name), Locale.rarity(d.rarity))
	cardTitle.TextColor3 = rar.color
	local text, color = stateText(d)
	cardState.Text = text
	cardState.TextColor3 = color
end

local function placeAll(gui: ScreenGui)
	local k = UI.deviceScale()
	-- Embaixo no meio, acima do botão ALIMENTAR (que só aparece perto do gigante).
	card.Position = UDim2.new(0.5, 0, 1, -math.floor(140 * k))
	arrow.Position = UDim2.new(0.5, 0, 1, -math.floor(252 * k))
	local _ = gui
end

local function openBoxWindow()
	local list = (State.current :: any).pendingBoxes :: { string }?
	if not list or #list == 0 then
		boxWin.Visible = false
		return
	end
	for _, c in boxBody:GetChildren() do
		if c:IsA("GuiObject") and c.Name == "Row" then
			c:Destroy()
		end
	end
	boxTitle.Text = string.format("Você tem %d caixa(s) guardada(s) na base.", #list)
	for i, boxId in list do
		if i > 6 then
			break
		end
		local box = Config.LunchboxById[boxId]
		local row = UI.frame(boxBody, {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 64),
			LayoutOrder = i,
			BackgroundColor3 = UI.Colors.Panel2,
		})
		UI.stroke(row, if box then box.color else UI.Colors.Edge, 2)
		UI.icon(
			row,
			"box_" .. boxId,
			{ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(6, 4), ZIndex = row.ZIndex + 1 }
		)
		UI.label(row, if box then box.name else boxId, {
			Size = UDim2.new(1, -230, 1, 0),
			Position = UDim2.fromOffset(70, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 22,
			TextColor3 = if box then box.color else UI.Colors.Text,
		})
		local open = UI.button(row, "ABRIR", UI.Colors.Green, {
			Size = UDim2.fromOffset(140, 48),
			Position = UDim2.new(1, -150, 0.5, -24),
			TextScaled = false,
			TextSize = 22,
		})
		open.Activated:Connect(function()
			Remotes.RequestOpenPending:FireServer(i)
			boxWin.Visible = false
		end)
	end
	if not boxWin.Visible then
		UI.pop(boxWin)
	end
end

function Drops.init(gui: ScreenGui)
	card = UI.panel(gui, {
		Name = "DropsPanel",
		Size = UDim2.fromOffset(520, 96),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UI.autoScale(card)
	UI.title(card, "DISPUTA DE COMIDA", {
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(14, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	cardTitle = UI.label(card, "", {
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(14, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 24,
	})
	cardState = UI.label(card, "", {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(14, 62),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 22,
		Font = UI.FontBody,
	})
	arrow = UI.title(gui, "", {
		Size = UDim2.fromOffset(420, 34),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
	})
	UI.autoScale(arrow)

	-- Caixas guardadas: chip + janela com "ABRIR" (o jogador escolhe quando).
	boxChip = UI.button(gui, "CAIXAS (0)", UI.Colors.Purple, {
		Name = "PendingBoxes",
		Size = UDim2.fromOffset(230, 60),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 190),
		TextScaled = false,
		TextSize = 26,
		Visible = false,
	})
	UI.autoScale(boxChip)
	local wb: Frame
	boxWin, wb = UI.window(gui, "CAIXAS GUARDADAS", UDim2.fromOffset(560, 340))
	boxBody = wb
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = boxBody
	boxTitle = UI.label(boxBody, "", {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 0,
		TextScaled = false,
		TextSize = 22,
	})
	boxChip.Activated:Connect(openBoxWindow)
	State.onChanged(function(s)
		local list = (s :: any).pendingBoxes :: { string }?
		local n = if list then #list else 0
		boxChip.Visible = n > 0
		boxChip.Text = string.format("CAIXAS (%d)", n)
		if boxWin.Visible then
			openBoxWindow()
		end
	end)
	Remotes.PendingBox.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		UI.sfx("Bell", 0.6)
		task.delay(0.3, openBoxWindow) -- mostra a opção de abrir (não abre sozinha)
	end)

	placeAll(gui)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		placeAll(gui)
	end)

	Remotes.DropState.OnClientEvent:Connect(function(d)
		if type(d) ~= "table" or type(d.id) ~= "number" then
			return
		end
		if d.removed then
			drops[d.id] = nil
		else
			if not drops[d.id] then
				-- Pedido do usuário (09/11, item 14): a VOZ não fala mais a cada drop (só quando começa a
				-- Chuva de Comida, abaixo). Aqui, só um sino, e só se o item é importante (Épico+) ou cai perto.
				local rar = Config.Rarities[d.rarity]
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = root ~= nil and typeof(d.pos) == "Vector3" and (d.pos - root.Position).Magnitude < 120
				if (rar and rar.order >= 4) or near then
					UI.sfx("Bell", 0.35)
				end
			end
			drops[d.id] = d
		end
		refresh()
	end)

	-- A voz "comida caindo do céu" só no começo da Chuva de Comida (evento de verdade).
	Remotes.EventStarted.OnClientEvent:Connect(function(data)
		if type(data) == "table" and data.id == "FoodRain" then
			UI.sfx("VO_Drop", 0.9)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			refresh()
		end
	end)

	-- Seta: até o item mais próximo, ou até a sua base quando você carrega algo.
	RunService.Heartbeat:Connect(function()
		local d, dist = nearest()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not d or not root then
			arrow.Visible = false
			return
		end
		-- Seta só quando você CARREGA algo (aponta a sua base). Antes ela aparecia sempre, para o item
		-- mais próximo do mapa inteiro, e virava ruído na tela (pedido do usuário, 09/11).
		local target: Vector3? = nil
		local label = tostring(d.name)
		if d.carrierId == player.UserId then
			target = myBasePos()
			label = "SUA BASE"
		end
		if not target then
			arrow.Visible = false
			return
		end
		dist = (target - root.Position).Magnitude
		local cam = Workspace.CurrentCamera
		local rel = cam.CFrame:PointToObjectSpace(target)
		local ang = math.deg(math.atan2(rel.X, -rel.Z))
		arrow.Visible = true
		arrow.Text = string.format(
			"%s  %dm  %s",
			if ang < -20 then "◄" else (if ang > 20 then "►" else "▲"),
			math.floor(dist),
			label
		)
	end)
end

return Drops
