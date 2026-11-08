--!strict
-- UI.lua — kit visual próprio do Feed a Giant. Nada de "painel colorido com fonte branca":
-- painéis 9-slice com faixa dourada, gradientes, glow neon, ícones em sprite-sheet, botões com sombra "chunky" 3D,
-- barras com brilho animado e texto com gradiente. Tudo degrada graciosamente se Config.Assets.* = 0.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local UIAssets = require(game.ReplicatedStorage.Shared.UIAssets)

local UI = {}

UI.Font = Enum.Font.FredokaOne
-- Gotham foi aposentada pela Roblox (renderiza como Montserrat): fonte de corpo pesada da Builder.
UI.FontBody = Enum.Font.BuilderSansExtraBold
-- HUD nova (referência do usuário de 08/11, assets/HUD nova referencia): painéis GRAFITE, botões,
-- ícones e destaques coloridos (moeda dourada, laranja de destaque, verde progresso, vermelho combate).
UI.Colors = {
	Bg = Color3.fromRGB(24, 26, 30),
	Panel = Color3.fromRGB(44, 47, 55),
	Panel2 = Color3.fromRGB(64, 68, 80),
	Outline = Color3.fromRGB(14, 15, 18),
	Edge = Color3.fromRGB(88, 94, 108), -- borda clara e fina dos painéis grafite
	Accent = Color3.fromRGB(255, 210, 63), -- dourado
	Accent2 = Color3.fromRGB(255, 150, 30),
	Green = Color3.fromRGB(80, 230, 130),
	Red = Color3.fromRGB(255, 85, 95),
	Blue = Color3.fromRGB(90, 180, 255),
	Purple = Color3.fromRGB(190, 110, 255),
	Text = Color3.fromRGB(255, 250, 235),
	Muted = Color3.fromRGB(175, 180, 192),
	Orange = Color3.fromRGB(255, 140, 30),
}

-- Sprite sheet 4x2 (assets/ui/icons_sheet.png, 1536x1024)
UI.Icons = {
	coin = { 0, 0 },
	glove = { 1, 0 },
	lunchbox = { 2, 0 },
	backpack = { 3, 0 },
	trophy = { 0, 1 },
	shield = { 1, 1 },
	crown = { 2, 1 },
	gear = { 3, 1 },
}
local ICON_FALLBACK = {
	coin = "🪙",
	glove = "🥊",
	lunchbox = "🍱",
	backpack = "🎒",
	trophy = "🏆",
	shield = "🛡️",
	crown = "👑",
	gear = "⚙️",
}

local function assetId(n: number): string
	return "rbxassetid://" .. n
end

---------------------------------------------------------------------------
-- Escala por aparelho (Fase 3, HUD; skill fwjelaa-ui-builder): desenho em 1920x1080,
-- UM UIScale por grupo (cluster), preso entre 0,6 e 1,0 para manter texto >= 12 px e toque >= 44 px.
---------------------------------------------------------------------------
local DESIGN_H = 1080
local MIN_SCALE, MAX_SCALE = 0.6, 1.0
local scalers: { UIScale } = {}
local scaleWatch = false

function UI.deviceScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	local k = math.min(vp.Y / DESIGN_H, vp.X / 1920 * 1.25)
	return math.clamp(k, MIN_SCALE, MAX_SCALE)
end

-- Põe o UIScale do aparelho num grupo e o mantém atualizado quando a janela muda.
function UI.autoScale(frame: GuiObject): GuiObject
	local s = Instance.new("UIScale")
	s.Name = "DeviceScale"
	s.Scale = UI.deviceScale()
	s.Parent = frame
	table.insert(scalers, s)
	local cam = workspace.CurrentCamera
	if not scaleWatch and cam then
		scaleWatch = true
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local k = UI.deviceScale()
			for i = #scalers, 1, -1 do
				local sc = scalers[i]
				if sc.Parent then
					sc.Scale = k
				else
					table.remove(scalers, i)
				end
			end
		end)
	end
	return frame
end

function UI.corner(inst: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = inst
	return c
end

function UI.stroke(inst: GuiObject, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or UI.Colors.Outline
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function UI.gradient(inst: GuiObject, c1: Color3, c2: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	g.Parent = inst
	return g
end

-- Glow externo (ImageLabel com blur radial da própria Roblox)
function UI.glow(inst: GuiObject, color: Color3, spread: number?, transparency: number?)
	local g = Instance.new("ImageLabel")
	g.Name = "Glow"
	g.BackgroundTransparency = 1
	g.Image = "rbxassetid://5028857084"
	g.ImageColor3 = color
	g.ImageTransparency = transparency or 0.45
	g.ScaleType = Enum.ScaleType.Slice
	g.SliceCenter = Rect.new(24, 24, 276, 276)
	local s = spread or 18
	g.Size = UDim2.new(1, s * 2, 1, s * 2)
	g.Position = UDim2.fromOffset(-s, -s)
	g.ZIndex = inst.ZIndex - 1
	g.Parent = inst
	return g
end

-- Painel: 9-slice se houver asset, senão gradiente + faixa dourada no topo + rebites
function UI.panel(parent: Instance, props: { [string]: any }): Frame
	-- Painel grafite liso com degradê suave, borda clara fina e cantos arredondados (HUD nova).
	-- O painel 9-slice azul-marinho/dourado da Fase 3 saiu: a referência nova pede bordas mais leves.
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UI.Colors.Panel
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	UI.corner(f, 18)
	UI.stroke(f, UI.Colors.Edge, 2)
	UI.gradient(f, UI.Colors.Panel2, UI.Colors.Panel, 90)
	return f
end

-- frame simples (compat com código antigo)
function UI.frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UI.Colors.Panel
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	UI.corner(f)
	return f
end

function UI.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UI.Font
	l.TextColor3 = UI.Colors.Text
	l.TextScaled = true
	l.Text = Locale.t(text)
	l.TextStrokeColor3 = UI.Colors.Outline
	l.TextStrokeTransparency = 0.15
	l.Size = UDim2.fromScale(1, 1)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- Título com gradiente dourado + contorno grosso (estilo logo)
function UI.title(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = UI.label(parent, text, props)
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	UI.gradient(l, UI.Colors.Accent, UI.Colors.Accent2, 90)
	local st = Instance.new("UIStroke")
	st.Color = UI.Colors.Outline
	st.Thickness = 2.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Parent = l
	return l
end

function UI.icon(parent: Instance, name: string, props: { [string]: any }?): GuiObject
	-- Fase 3 (HUD): ícone recortado e enviado individualmente (UIAssets). A folha 4x2 só serve de
	-- reserva: o Roblox reduz a folha para 1024x683 e o recorte em pixels apontava para o lugar errado.
	local assets = UIAssets :: { [string]: string }
	local single = assets[name] or assets["extra_" .. name]
	if single then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = single
		img.ScaleType = Enum.ScaleType.Fit
		if props then
			for k, v in props do
				(img :: any)[k] = v
			end
		end
		img.Parent = parent
		return img
	end
	local cell = UI.Icons[name]
	if Config.Assets.IconsSheet ~= 0 and cell then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = assetId(Config.Assets.IconsSheet)
		img.ImageRectSize = Vector2.new(384, 512)
		img.ImageRectOffset = Vector2.new(cell[1] * 384, cell[2] * 512)
		img.ScaleType = Enum.ScaleType.Fit
		if props then
			for k, v in props do
				(img :: any)[k] = v
			end
		end
		img.Parent = parent
		return img
	end
	local l = UI.label(parent, ICON_FALLBACK[name] or "•", props)
	l.TextStrokeTransparency = 1
	return l
end

-- Botão chunky: sombra 3D, gradiente, brilho no topo, hover/press animados, som de clique
function UI.button(parent: Instance, text: string, color: Color3, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = UI.Font
	b.Text = Locale.t(text)
	b.TextColor3 = UI.Colors.Text
	b.TextScaled = true
	b.TextStrokeColor3 = UI.Colors.Outline
	b.TextStrokeTransparency = 0.1
	b.ZIndex = 2
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b.Parent = parent
	UI.corner(b, 14)
	UI.stroke(b, UI.Colors.Outline, 2.5)
	local h, s, v = color:ToHSV()
	local dark = Color3.fromHSV(h, math.min(1, s * 1.1), v * 0.55)
	local light = Color3.fromHSV(h, s * 0.8, math.min(1, v * 1.15))
	UI.gradient(b, light, color, 90)
	-- Borda escura ABAIXO do botão (efeito "pressionável"). Revisão de UI 08/11: antes era um filho
	-- do tamanho do botão; com ZIndexBehavior Sibling os filhos ficam por cima do pai e cobriam o
	-- texto do próprio botão (o "X" de fechar sumia). Agora só aparece embaixo, sem cobrir nada.
	-- Coordenadas descontam o UIPadding do botão (10 nas laterais, 6 em cima e embaixo).
	local DEPTH = 6
	local sh = Instance.new("Frame")
	sh.Name = "Shadow"
	sh.BackgroundColor3 = dark
	sh.BorderSizePixel = 0
	sh.Size = UDim2.new(1, 12, 0, DEPTH + 4)
	sh.Position = UDim2.new(0, -6, 1, 2)
	sh.ZIndex = b.ZIndex
	sh.Parent = b
	UI.corner(sh, 10)
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.75
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -16, 0, 6)
	shine.Position = UDim2.fromOffset(8, 5)
	shine.ZIndex = b.ZIndex + 1
	shine.Parent = b
	UI.corner(shine, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	local basePos = b.Position
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { Position = basePos - UDim2.fromOffset(0, 2) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { Position = basePos }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { Position = basePos + UDim2.fromOffset(0, 5) }):Play()
		sh.Size = UDim2.new(1, 12, 0, 5)
		UI.sfx("Click", 0.5)
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { Position = basePos }):Play()
		sh.Size = UDim2.new(1, 12, 0, DEPTH + 4)
	end)
	return b
end

-- Botão redondo com ícone (menu lateral)
function UI.iconButton(
	parent: Instance,
	iconName: string,
	caption: string,
	color: Color3,
	props: { [string]: any }?
): TextButton
	local b = UI.button(parent, "", color, props)
	UI.icon(b, iconName, { Size = UDim2.new(1, -8, 1, -22), Position = UDim2.fromOffset(4, 0), ZIndex = b.ZIndex + 1 })
	UI.label(b, caption, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -22),
		TextScaled = false,
		TextSize = 20,
		ZIndex = b.ZIndex + 1,
	})
	return b
end

-- Barra de progresso com brilho que percorre a barra
function UI.bar(parent: Instance, color: Color3, props: { [string]: any }?): (Frame, Frame)
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(14, 15, 30)
	bg.BorderSizePixel = 0
	if props then
		for k, v in props do
			(bg :: any)[k] = v
		end
	end
	bg.Parent = parent
	UI.corner(bg, 10)
	UI.stroke(bg, UI.Colors.Outline, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = bg.ZIndex + 1
	fill.Parent = bg
	UI.corner(fill, 10)
	local h, s, v = color:ToHSV()
	UI.gradient(fill, Color3.fromHSV(h, s * 0.7, math.min(1, v * 1.2)), Color3.fromHSV(h, s, v * 0.75), 90)
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(0, 14, 1, -6)
	shine.Position = UDim2.fromOffset(0, 3)
	shine.ZIndex = fill.ZIndex + 1
	shine.ClipsDescendants = true
	shine.Parent = fill
	UI.corner(shine, 6)
	-- Pedido do usuário (08/11): a "sombra branca rolando" por cima das barras parecia bug.
	-- O brilho agora é um reflexo parado no alto da barra (sem movimento).
	shine.Size = UDim2.new(1, -8, 0.35, 0)
	shine.Position = UDim2.fromOffset(4, 2)
	shine.BackgroundTransparency = 0.78
	return bg, fill
end

function UI.setBar(fill: Frame, pct: number, instant: boolean?)
	pct = math.clamp(pct, 0, 1)
	if instant then
		fill.Size = UDim2.fromScale(pct, 1)
	else
		TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(pct, 1) }):Play()
	end
end

-- Tamanho "de verdade" de cada objeto animado (revisão de UI 08/11: pop/pulso repetidos liam o
-- tamanho no meio da animação e o objeto ia crescendo ou encolhendo).
local baseSizes: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
local activeTweens: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function baseSize(inst: GuiObject): UDim2
	local b = baseSizes[inst]
	if not b then
		b = inst.Size
		baseSizes[inst] = b
	end
	return b
end

local function play(inst: GuiObject, info: TweenInfo, goal: { [string]: any }): Tween
	local old = activeTweens[inst]
	if old then
		old:Cancel()
	end
	local t = TweenService:Create(inst, info, goal)
	activeTweens[inst] = t
	t:Play()
	return t
end

-- Com "Movimento reduzido" ligado: aparece direto (sem crescer), só o retorno de cor/visibilidade.
function UI.reducedMotion(): boolean
	return GuiService.ReducedMotionEnabled
end

function UI.pop(inst: GuiObject)
	inst.Visible = true
	local goal = baseSize(inst)
	if UI.reducedMotion() then
		inst.Size = goal
		return
	end
	inst.Size = UI.scaleUDim(goal, 0.8)
	play(inst, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = goal })
end

function UI.pulse(inst: GuiObject, scale: number?, time: number?)
	local goal = baseSize(inst)
	if UI.reducedMotion() then
		return
	end
	local half = (time or 0.18) / 2
	local t = play(inst, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UI.scaleUDim(goal, scale or 1.12),
	})
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			play(inst, TweenInfo.new(half, Enum.EasingStyle.Quad), { Size = goal })
		end
	end)
end

function UI.scaleUDim(u: UDim2, k: number): UDim2
	return UDim2.new(u.X.Scale * k, u.X.Offset * k, u.Y.Scale * k, u.Y.Offset * k)
end

-- Janelas abertas, da mais antiga para a mais nova (ESC / botão B fecham a última).
local openStack: { { win: Frame, hide: () -> () } } = {}
local escBound = false
local function bindEscape()
	if escBound then
		return
	end
	escBound = true
	-- Bug do teste do usuário (08/11): em primeira pessoa o mouse ficava preso no centro com a loja
	-- aberta. Um botão com Modal = true (o "X" de cada janela) libera o cursor enquanto estiver
	-- visível; ESC (teclado) e B (controle) fecham a janela de cima.
	UserInputService.InputBegan:Connect(function(input)
		local key = input.KeyCode
		if key ~= Enum.KeyCode.Escape and key ~= Enum.KeyCode.ButtonB and key ~= Enum.KeyCode.Backspace then
			return
		end
		if key == Enum.KeyCode.Backspace and UserInputService:GetFocusedTextBox() then
			return
		end
		for i = #openStack, 1, -1 do
			local e = openStack[i]
			if e.win.Visible then
				e.hide()
				return
			end
		end
	end)
end

-- Janela modal com cabeçalho dourado, fechamento animado e fundo escurecido
function UI.window(gui: ScreenGui, titleText: string, size: UDim2): (Frame, Frame)
	local dim = Instance.new("Frame")
	dim.Name = "Dim_" .. titleText
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	-- P0 da especificação v3 (08/11/2026): a janela não escurece mais o mundo. Antes era 0,45 de
	-- preto na tela inteira; agora o contraste vem só da sombra/brilho atrás do painel (UI.glow).
	-- O quadro continua existindo (é o pai da janela e acompanha o Visible), mas é invisível.
	dim.BackgroundTransparency = 1
	dim.Active = false
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.ZIndex = 10
	dim.Parent = gui
	local win = UI.panel(dim, {
		Name = "Window",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 11,
		-- BUG do teste do usuário (08/11): a janela nascia "visível" com o fundo escondido, então
		-- `if not win.Visible then UI.pop(win)` nunca rodava e NENHUM botão da HUD abria nada.
		Visible = false,
	})
	-- Sombra suave só atrás do painel (substitui o escurecimento da tela inteira) + brilho laranja.
	UI.glow(win, Color3.new(0, 0, 0), 34, 0.55)
	UI.glow(win, UI.Colors.Orange, 22, 0.82)
	local header = Instance.new("Frame")
	header.BackgroundColor3 = UI.Colors.Accent
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, -40, 0, 46)
	header.Position = UDim2.fromOffset(20, -18)
	header.ZIndex = 13
	header.Parent = win
	UI.corner(header, 14)
	UI.stroke(header, UI.Colors.Outline, 3)
	UI.gradient(header, Color3.fromRGB(255, 176, 40), UI.Colors.Orange, 90)
	-- Título branco com contorno escuro sobre a faixa laranja (referência da HUD nova).
	local ttl = UI.label(header, titleText, {
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 1,
	})
	local tst = Instance.new("UIStroke")
	tst.Color = UI.Colors.Outline
	tst.Thickness = 2.5
	tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	tst.Parent = ttl
	local close = UI.button(
		win,
		"X",
		UI.Colors.Red,
		{ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -30, 0, -16), ZIndex = 14 }
	)
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -40, 1, -70)
	body.Position = UDim2.fromOffset(20, 48)
	body.ZIndex = 12
	body.Parent = win
	baseSizes[win] = size
	local function hide()
		if UI.reducedMotion() then
			win.Visible = false
			return
		end
		local t = play(win, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UI.scaleUDim(size, 0.85),
		})
		-- Só esconde se o fechamento terminou de verdade (reabrir no meio cancela este tween).
		t.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				win.Visible = false
				win.Size = size
			end
		end)
	end
	close.Activated:Connect(hide)
	close.Modal = true -- libera o mouse em primeira pessoa enquanto a janela está aberta
	table.insert(openStack, { win = win, hide = hide })
	bindEscape()
	-- Fase 4 (celular primeiro): a janela é desenhada em pixels de 1080p e encolhe para caber na
	-- área segura (antes, 760x500 passava da tela de 844x390). Um UIScale só, separado do pop.
	local fit = Instance.new("UIScale")
	fit.Name = "FitScale"
	fit.Parent = win
	local function refit()
		local area = gui.AbsoluteSize
		if area.X <= 0 or area.Y <= 0 then
			return
		end
		local w = size.X.Offset + area.X * size.X.Scale
		local h = size.Y.Offset + area.Y * size.Y.Scale + 24 -- cabeçalho acima da janela
		fit.Scale = math.clamp(math.min(1, (area.X - 24) / math.max(w, 1), (area.Y - 24) / math.max(h, 1)), 0.4, 1)
		-- O botão fechar nunca fica abaixo de 44 px desenhados, mesmo com a janela encolhida.
		local c = math.max(44, math.ceil(44 / fit.Scale))
		close.Size = UDim2.fromOffset(c, c)
		close.Position = UDim2.new(1, -c + 14, 0, -c + 28)
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	-- compat: código antigo faz win.Visible = false / UI.pop(win)
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		dim.Visible = win.Visible
		if win.Visible then
			-- a janela aberta por último vai para o topo da pilha do ESC
			for i, e in openStack do
				if e.win == win then
					table.insert(openStack, table.remove(openStack, i) :: any)
					break
				end
			end
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
		-- Controle/teclado: foco no fechar ao abrir e a seleção fica presa dentro da janela.
		if win.Visible and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = close
		elseif not win.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(win) then
			GuiService.SelectedObject = nil
		end
	end)
	win.SelectionGroup = true
	dim.MouseEnter:Connect(function() end)
	return win, body
end

-- Sons compartilhados
local sounds: { [string]: Sound } = {}
local Players = game:GetService("Players")
local function voLocale(): string
	local ok, loc = pcall(function()
		return string.lower(Players.LocalPlayer.LocaleId)
	end)
	loc = if ok and loc then loc else "en"
	if string.sub(loc, 1, 2) == "pt" then
		return "pt-br"
	elseif string.sub(loc, 1, 2) == "es" then
		return "es"
	end
	return "en"
end

function UI.sfx(key: string, volume: number?)
	local id = (Config.Sounds :: any)[key]
	if string.sub(key, 1, 3) == "VO_" then
		local tbl = (Config.Sounds.VO :: any)[voLocale()] or (Config.Sounds.VO :: any)["en"]
		id = tbl and tbl[string.sub(key, 4)]
		key = key .. "_" .. voLocale()
	end
	if not id or id == 0 then
		return
	end
	local s: Sound
	local cached = sounds[key]
	if cached then
		s = cached
	else
		s = Instance.new("Sound")
		s.SoundId = if type(id) == "number" then assetId(id) else id
		-- Canais de volume (Music.lua cria os SoundGroups): narrador em Vozes, o resto em Efeitos.
		local g = SoundService:FindFirstChild(if string.sub(key, 1, 3) == "VO_" then "Vozes" else "Efeitos")
		if g and g:IsA("SoundGroup") then
			s.SoundGroup = g
		end
		s.Parent = SoundService
		sounds[key] = s
	end
	s.Volume = volume or 0.6
	s.PlaybackSpeed = 0.95 + math.random() * 0.1
	s:Play()
end

-- Logo (imagem se existir, senão título com gradiente)
function UI.logo(parent: Instance, props: { [string]: any }): GuiObject
	local hud2 = (UIAssets :: { [string]: string })["extra_hud2_logo"]
	if hud2 then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = hud2
		img.ScaleType = Enum.ScaleType.Fit
		for k, v in props do
			(img :: any)[k] = v
		end
		img.Parent = parent
		return img
	end
	if Config.Assets.Logo ~= 0 then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = assetId(Config.Assets.Logo)
		img.ScaleType = Enum.ScaleType.Fit
		for k, v in props do
			(img :: any)[k] = v
		end
		img.Parent = parent
		return img
	end
	return UI.title(parent, "FEED A GIANT", props)
end

return UI
