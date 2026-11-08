--!strict
-- Admin.lua — tela do PAINEL DO ADMIN (08/11/2026). Só aparece para quem o SERVIDOR marcou com o
-- atributo AdminRole; mesmo assim, cada botão só manda um pedido e o servidor confere a permissão
-- de novo (AdminService). Nada aqui dá poder: esconder o botão não é segurança.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)

local Admin = {}
local player = Players.LocalPlayer

local win: Frame
local playerList: ScrollingFrame
local targetLabel: TextLabel
local statusLabel: TextLabel
local logLabel: TextLabel
local botLabel: TextLabel
local announceBox: TextBox
local confirmBtn: TextButton
local selected: number? = nil
local lastState: { [string]: any }? = nil
local confirmToken: string? = nil

local function send(cmd: string, args: { [string]: any }?)
	Remotes.AdminCommand:FireServer(cmd, args or {})
end

local function needTarget(): number?
	if not selected then
		statusLabel.Text = "Escolha um jogador na lista primeiro."
		statusLabel.TextColor3 = UI.Colors.Red
		return nil
	end
	return selected
end

local function renderPlayers(st: { [string]: any })
	for _, c in playerList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, p in (st.players or {}) :: { any } do
		local isSel = p.userId == selected
		local b = UI.button(
			playerList,
			string.format("%s  ·  Nv.%d  ·  %s", tostring(p.display), p.level or 0, Util.formatNumber(p.coins or 0)),
			if isSel then UI.Colors.Accent else Color3.fromRGB(78, 84, 100),
			{
				Size = UDim2.new(1, -8, 0, 48),
				LayoutOrder = i,
				TextScaled = false,
				TextSize = 20,
			}
		)
		local uid = p.userId
		b.Activated:Connect(function()
			selected = uid
			targetLabel.Text = "Alvo: " .. tostring(p.display) .. " (" .. tostring(p.role) .. ")"
			if lastState then
				renderPlayers(lastState)
			end
		end)
	end
	local bots = st.bots or {}
	local names = {}
	for _, b in bots :: { any } do
		table.insert(names, tostring(b.name))
	end
	botLabel.Text = string.format("Bots: %d  %s", st.botCount or 0, table.concat(names, ", "))
	local lines = {}
	local log = st.log or {}
	for i = #log, math.max(1, #log - 5), -1 do
		local e = log[i]
		table.insert(lines, string.format("%s %s: %s", if e.ok then "✔" else "✘", tostring(e.cmd), tostring(e.msg)))
	end
	logLabel.Text = table.concat(lines, "\n")
end

local function row(parent: Instance, title: string, order: number): Frame
	local r = UI.frame(parent, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	UI.label(r, title, {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
		TextScaled = false,
		TextSize = 22,
	})
	local holder = UI.frame(r, {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 46)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 34)
	pad.Parent = r
	return holder
end

local function action(holder: Frame, text: string, color: Color3, cb: () -> ())
	local b = UI.button(holder, text, color, { TextScaled = false, TextSize = 18 })
	b.Activated:Connect(cb)
	return b
end

function Admin.open()
	send("state")
	if not win.Visible then
		UI.pop(win)
	end
end

function Admin.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "PAINEL DO ADMIN", UDim2.fromOffset(900, 620))
	-- Coluna esquerda: jogadores
	local left = UI.frame(body, { Size = UDim2.new(0, 300, 1, 0), BackgroundTransparency = 1 })
	UI.label(left, "JOGADORES", {
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
	})
	playerList = Instance.new("ScrollingFrame")
	playerList.Size = UDim2.new(1, 0, 1, -150)
	playerList.Position = UDim2.fromOffset(0, 32)
	playerList.BackgroundTransparency = 1
	playerList.BorderSizePixel = 0
	playerList.ScrollBarThickness = 6
	playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerList.CanvasSize = UDim2.new()
	playerList.Parent = left
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 6)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = playerList
	targetLabel = UI.label(left, "Alvo: nenhum", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 1, -112),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
	})
	logLabel = UI.label(left, "", {
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.new(0, 0, 1, -80),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		Font = UI.FontBody,
	})

	-- Coluna direita: ações
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -316, 1, -40)
	scroll.Position = UDim2.fromOffset(316, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local econ = row(scroll, "ECONOMIA (no alvo)", 1)
	for _, n in { 10000, 100000, 1000000 } do
		action(econ, "+" .. Util.formatNumber(n) .. " moedas", UI.Colors.Green, function()
			local t = needTarget()
			if t then
				send("coins", { target = t, amount = n })
			end
		end)
	end
	for _, lv in { 10, 25, 50, 100 } do
		action(econ, "Nível " .. lv, UI.Colors.Blue, function()
			local t = needTarget()
			if t then
				send("level", { target = t, level = lv })
			end
		end)
	end
	for _, f in { { "goldpizza", "Lendária x1" }, { "universelasagna", "Mítica x1" }, { "giantmeat", "Carne x5" } } do
		action(econ, f[2], UI.Colors.Purple, function()
			local t = needTarget()
			if t then
				send("food", { target = t, foodId = f[1], count = if f[1] == "giantmeat" then 5 else 1 })
			end
		end)
	end
	for _, sp in Config.Species do
		if sp.robux then
			continue
		end
		action(econ, sp.name, Color3.fromRGB(96, 102, 118), function()
			local t = needTarget()
			if t then
				send("species", { target = t, species = sp.id })
			end
		end)
	end

	local mod = row(scroll, "MODERAÇÃO (no alvo)", 2)
	action(mod, "Expulsar", UI.Colors.Orange, function()
		local t = needTarget()
		if t then
			send("kick", { target = t, reason = "" })
		end
	end)
	action(mod, "Banir 1 dia", UI.Colors.Red, function()
		local t = needTarget()
		if t then
			send("ban", { target = t, minutes = 1440, reason = "" })
		end
	end)
	action(mod, "Banir 7 dias", UI.Colors.Red, function()
		local t = needTarget()
		if t then
			send("ban", { target = t, minutes = 10080, reason = "" })
		end
	end)
	confirmBtn = action(mod, "CONFIRMAR", Color3.fromRGB(200, 30, 30), function()
		if confirmToken then
			send("ban", { token = confirmToken })
			confirmToken = nil
			confirmBtn.Visible = false
		end
	end)
	confirmBtn.Visible = false

	local ev = row(scroll, "EVENTOS AGORA", 3)
	action(ev, "Golden Hour", UI.Colors.Accent, function()
		send("event", { id = "GoldenHour" })
	end)
	action(ev, "Chuva de Comida", UI.Colors.Blue, function()
		send("event", { id = "FoodRain" })
	end)
	action(ev, "Lucky Boxes", UI.Colors.Green, function()
		send("event", { id = "LuckyBoxes" })
	end)
	action(ev, "Carne Gigante", UI.Colors.Orange, function()
		send("meat")
	end)
	action(ev, "Dragão", UI.Colors.Red, function()
		send("boss")
	end)

	local bots = row(scroll, "BOTS", 4)
	for _, n in { 0, 2, 4, 6 } do
		action(bots, n .. " bots", Color3.fromRGB(78, 84, 100), function()
			send("bots", { count = n })
		end)
	end
	botLabel = UI.label(scroll, "", {
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
	})

	local ann = row(scroll, "AVISO PARA TODOS (passa pelo filtro da Roblox)", 6)
	announceBox = Instance.new("TextBox")
	announceBox.Size = UDim2.fromOffset(150, 46)
	announceBox.PlaceholderText = "mensagem..."
	announceBox.Text = ""
	announceBox.ClearTextOnFocus = false
	announceBox.TextScaled = true
	announceBox.Font = UI.FontBody
	announceBox.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	announceBox.Parent = ann
	action(ann, "Enviar aviso", UI.Colors.Accent, function()
		local text = announceBox.Text
		if #text > 0 then
			send("announce", { text = string.sub(text, 1, 120) })
			announceBox.Text = ""
		end
	end)

	statusLabel = UI.label(body, "", {
		Size = UDim2.new(1, -316, 0, 34),
		Position = UDim2.new(0, 316, 1, -34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
	})

	-- Botão ADM (canto superior direito), só para quem o servidor marcou.
	local adm = UI.button(gui, "ADM", Color3.fromRGB(150, 40, 40), {
		Name = "AdminButton",
		Size = UDim2.fromOffset(70, 40),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		TextScaled = false,
		TextSize = 18,
		Visible = false,
		ZIndex = 30,
	})
	adm.Activated:Connect(Admin.open)
	local function refreshVisible()
		adm.Visible = player:GetAttribute("AdminRole") ~= nil
	end
	player:GetAttributeChangedSignal("AdminRole"):Connect(refreshVisible)
	refreshVisible()

	Remotes.AdminState.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Confirm" and type(e.token) == "string" then
			confirmToken = e.token
			confirmBtn.Visible = true
			statusLabel.Text = tostring(e.text)
			statusLabel.TextColor3 = UI.Colors.Red
			return
		end
		if type(e.msg) == "string" then
			statusLabel.Text = e.msg
			statusLabel.TextColor3 = if e.ok then UI.Colors.Green else UI.Colors.Red
		end
		if type(e.state) == "table" then
			lastState = e.state
			renderPlayers(e.state)
		end
	end)
end

return Admin
