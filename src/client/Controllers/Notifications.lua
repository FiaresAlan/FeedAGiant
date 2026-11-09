--!strict
-- Notifications.lua — toasts empilhados, banner de evento global com contagem e alerta de roubo.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Config = require(game.ReplicatedStorage.Shared.Config)

local Notifications = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local stack: Frame
local banner: Frame
local bannerLabel: TextLabel
local bannerTimer: TextLabel
local activeEventEnd = 0
local activeName = ""
local activeColor = Color3.new(1, 1, 1)
-- Próximo evento anunciado pelo servidor (os.time do início). Pedido do usuário (08/11): ver a
-- contagem "vai começar em X minutos" para criar expectativa.
local nextAt = 0
local nextName = ""
local nextColor = Color3.new(1, 1, 1)
local bannerStroke: UIStroke

local MAX_TOASTS = 5

local function pushToast(text: string, color: Color3?, duration: number?)
	local toast = UI.frame(stack, {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.Panel,
		-- pedido do usuário (09/11): os avisos são semitransparentes (dá para ver o jogo atrás)
		BackgroundTransparency = 0.4,
		LayoutOrder = -os.clock(),
	})
	local tstroke = UI.stroke(toast, color or UI.Colors.Accent, 2)
	tstroke.Transparency = 0.3
	local toastText = UI.label(toast, text, {
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or UI.Colors.Text,
	})
	toastText.TextStrokeTransparency = 0.4 -- contorno: o texto continua legível sobre o fundo transparente
	toast.Position = UDim2.fromOffset(300, 0)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play()

	while #stack:GetChildren() > MAX_TOASTS + 1 do
		local oldest: GuiObject? = nil
		for _, c in stack:GetChildren() do
			if c:IsA("Frame") and (oldest == nil or c.LayoutOrder > oldest.LayoutOrder) then
				oldest = c
			end
		end
		if oldest then
			oldest:Destroy()
		else
			break
		end
	end

	task.delay(duration or 4, function()
		if toast.Parent then
			local t = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			toast:Destroy()
		end
	end)
end

function Notifications.toast(text: string, color: Color3?, duration: number?)
	pushToast(text, color, duration)
end

local function mmss(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- Pedido do usuário (09/11, item 12): a faixa NÃO fica no meio do topo tampando a tela. Ela mora pequena
-- no canto superior direito; ao anunciar algo importante (evento começando ou a 10 s de começar), aparece
-- grande e animada no centro por 2,5 s e desliza de volta para o canto.
local DOCK_POS = UDim2.new(1, -16, 0, 56)
local DOCK_SIZE = UDim2.fromOffset(330, 46)
local BIG_POS = UDim2.fromScale(0.5, 0.16)
local BIG_SIZE = UDim2.fromOffset(560, 72)
local announcing = false
local function dock(instant: boolean?)
	banner.AnchorPoint = Vector2.new(1, 0)
	if instant or UI.reducedMotion() then
		banner.Position = DOCK_POS
		banner.Size = DOCK_SIZE
		return
	end
	TweenService:Create(banner, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = DOCK_POS,
		Size = DOCK_SIZE,
	}):Play()
end
local function announce()
	if announcing then
		return
	end
	announcing = true
	banner.Visible = true
	-- vai para o centro (âncora no meio), cresce, espera e volta para o canto
	banner.AnchorPoint = Vector2.new(0.5, 0)
	if UI.reducedMotion() then
		banner.Position = BIG_POS
		banner.Size = BIG_SIZE
	else
		banner.Position = BIG_POS
		banner.Size = UDim2.fromOffset(330, 46)
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = BIG_SIZE,
		}):Play()
	end
	task.delay(2.5, function()
		dock(false)
		task.delay(0.6, function()
			announcing = false
		end)
	end)
end

-- Um só laço atualiza o chip: evento ativo (cor do evento) ou contagem do próximo.
local function tickBanner()
	if os.clock() < activeEventEnd then
		banner.Visible = true
		banner.BackgroundColor3 = activeColor:Lerp(Color3.new(0, 0, 0), 0.35)
		bannerStroke.Color = activeColor
		bannerLabel.Text = Locale.fmt("event_now", nil, { e = Locale.upper(Locale.t(activeName)) })
		bannerTimer.Text = mmss(activeEventEnd - os.clock())
		bannerTimer.TextColor3 = Color3.new(1, 1, 1)
	elseif nextAt > 0 then
		local left = nextAt - os.time()
		banner.Visible = true
		banner.BackgroundColor3 = UI.Colors.Panel
		bannerLabel.Text = Locale.fmt("next_event", nil, { e = Locale.t(nextName) })
		bannerTimer.Text = mmss(left)
		-- Último minuto: o chip pisca na cor do evento (expectativa), menos com "Movimento reduzido".
		local urgent = left <= 60
		if left == 10 then
			announce() -- "falta pouco": a faixa cresce no topo e volta para o canto
		end
		bannerStroke.Color = if urgent then nextColor else Color3.fromRGB(90, 100, 170)
		bannerTimer.TextColor3 = if urgent then nextColor else UI.Colors.Accent
		if urgent and not UI.reducedMotion() and left % 2 == 0 then
			banner.BackgroundColor3 = nextColor:Lerp(Color3.new(0, 0, 0), 0.55)
		end
	else
		banner.Visible = false
	end
end

-- ANÚNCIO GRANDE (pedido do usuário, 09/11): evento, Dragão ou chefe começando aparece GRANDE no meio
-- da tela, com pulo e brilho, fica ~2,6 s e então VOA para o canto superior direito (onde mora a faixa)
-- encolhendo e sumindo. Não bloqueia cliques (Active = false). Um por vez: o seguinte espera.
local calloutFrame: Frame
local calloutTitle: TextLabel
local calloutSub: TextLabel
local calloutStroke: UIStroke
local calloutQueue: { { title: string, sub: string, color: Color3 } } = {}
local calloutBusy = false
local CALLOUT_SIZE = UDim2.new(0.7, 0, 0, 150)

local function playCallout(c: { title: string, sub: string, color: Color3 })
	calloutBusy = true
	calloutTitle.Text = c.title
	calloutSub.Text = c.sub
	calloutTitle.TextColor3 = Color3.new(1, 1, 1)
	calloutStroke.Color = c.color
	calloutFrame.BackgroundColor3 = c.color:Lerp(Color3.new(0, 0, 0), 0.35)
	calloutFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	calloutFrame.Position = UDim2.fromScale(0.5, 0.36)
	calloutFrame.BackgroundTransparency = 0.25
	calloutTitle.TextTransparency = 0
	calloutSub.TextTransparency = 0
	calloutFrame.Visible = true
	UI.sfx("Bell", 0.8)
	if UI.reducedMotion() then
		calloutFrame.Size = CALLOUT_SIZE
		task.wait(3)
	else
		calloutFrame.Size = UDim2.new(0.2, 0, 0, 40)
		TweenService:Create(calloutFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = CALLOUT_SIZE,
		}):Play()
		-- "respira" 2 vezes para chamar atenção
		task.wait(0.5)
		for _ = 1, 2 do
			TweenService:Create(calloutFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
				Size = UDim2.new(0.73, 0, 0, 158),
			}):Play()
			task.wait(0.5)
			TweenService:Create(calloutFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = CALLOUT_SIZE }):Play()
			task.wait(0.55)
		end
		-- voa para o canto da faixa
		calloutFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		local fly = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(calloutFrame, fly, {
			Position = UDim2.new(1, -180, 0, 80),
			Size = UDim2.fromOffset(330, 46),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(calloutTitle, fly, { TextTransparency = 1 }):Play()
		TweenService:Create(calloutSub, fly, { TextTransparency = 1 }):Play()
		task.wait(0.72)
	end
	calloutFrame.Visible = false
	if banner.Visible then
		UI.pop(banner)
	end
	calloutBusy = false
	local nextOne = table.remove(calloutQueue, 1)
	if nextOne then
		task.spawn(playCallout, nextOne)
	end
end

function Notifications.callout(title: string, sub: string?, color: Color3?)
	local c = { title = title, sub = sub or "", color = color or UI.Colors.Accent }
	if calloutBusy then
		if #calloutQueue < 3 then
			table.insert(calloutQueue, c)
		end
		return
	end
	task.spawn(playCallout, c)
end

local function buildCallout()
	calloutFrame = UI.frame(gui, {
		Name = "Callout",
		Size = CALLOUT_SIZE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 60,
	})
	calloutFrame.Active = false
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(900, 170)
	cap.Parent = calloutFrame
	UI.corner(calloutFrame, 22)
	calloutStroke = UI.stroke(calloutFrame, UI.Colors.Accent, 4)
	calloutTitle = UI.label(calloutFrame, "", {
		Size = UDim2.new(1, -24, 0.62, 0),
		Position = UDim2.fromOffset(12, 6),
		ZIndex = 61,
	})
	calloutTitle.TextStrokeTransparency = 0
	calloutSub = UI.label(calloutFrame, "", {
		Size = UDim2.new(1, -24, 0.3, 0),
		Position = UDim2.new(0, 12, 0.64, 0),
		ZIndex = 61,
		TextColor3 = Color3.fromRGB(255, 240, 200),
	})
	calloutSub.TextStrokeTransparency = 0.2
end

local function showBanner(name: string, duration: number, color: Color3)
	activeEventEnd = os.clock() + duration
	activeName = name
	activeColor = color
	tickBanner()
	Notifications.callout(Locale.upper(Locale.t(name)) .. "!", "EVENTO COMEÇOU — vamos lá!", color)
end

local function hideBanner()
	activeEventEnd = 0
	tickBanner()
end

local function stealAlert(thiefName: string, food: string)
	pushToast(Locale.fmt("steal_alert", nil, { p = thiefName, f = food }), UI.Colors.Red, 6)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = UI.Colors.Red
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.ZIndex = 0
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(0.9, function()
		flash:Destroy()
	end)
end

function Notifications.init(parentGui: ScreenGui)
	gui = parentGui

	stack = UI.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(320, 300),
		Position = UDim2.new(1, -16, 0, 112),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = stack

	-- Chip do evento no canto superior esquerdo (antes ficava no meio do topo, em cima da HUD).
	banner = UI.frame(gui, {
		Name = "EventBanner",
		Size = UDim2.fromOffset(330, 46),
		Position = UDim2.new(1, -16, 0, 56),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.35,
		Visible = false,
	})
	UI.autoScale(banner)
	UI.corner(banner, 16)
	bannerStroke = UI.stroke(banner, Color3.fromRGB(90, 100, 170), 3)
	bannerLabel = UI.label(banner, "", {
		Size = UDim2.new(1, -112, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true, -- cabe no tamanho pequeno (canto) e no grande (anúncio)
		TextWrapped = true,
	})
	bannerTimer = UI.title(banner, "0:00", {
		Size = UDim2.new(0, 90, 1, -8),
		Position = UDim2.new(1, -96, 0, 4),
	})
	-- HUD nova: a coluna da esquerda é das estatísticas; o chip do evento fica no meio do topo.
	task.spawn(function()
		while true do
			tickBanner()
			task.wait(1)
		end
	end)
	Remotes.EventSchedule.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.at) == "number" then
			nextAt = data.at
			nextName = tostring(data.nextName)
			nextColor = if typeof(data.color) == "Color3" then data.color else UI.Colors.Accent
			tickBanner()
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if type(data.key) == "string" then
			-- Raridade chega como ID interno ("Epic"): mostra no idioma do jogador ("Épico").
			local params: { [string]: any } = if type(data.params) == "table" then table.clone(data.params) else {}
			if type(params.r) == "string" and Config.Rarities[params.r] then
				params.r = Locale.rarity(params.r)
			end
			pushToast(Locale.fmt(data.key, nil, params), data.color)
		elseif type(data.text) == "string" then
			pushToast(Locale.t(data.text), data.color)
		end
	end)
	Remotes.EventStarted.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			showBanner(tostring(data.name), tonumber(data.duration) or 60, data.color or UI.Colors.Accent)
		end
	end)
	Remotes.EventEnded.OnClientEvent:Connect(hideBanner)
	buildCallout()
	Remotes.Callout.OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.title) == "string" then
			Notifications.callout(
				data.title,
				if type(data.sub) == "string" then data.sub else nil,
				if typeof(data.color) == "Color3" then data.color else nil
			)
		end
	end)
	Remotes.StealAlert.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			stealAlert(tostring(data.thiefName), tostring(data.food or "comida"))
		end
	end)

	print("[Client] Notifications pronto para", player.Name)
end

return Notifications
