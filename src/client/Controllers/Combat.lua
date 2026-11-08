--!strict
-- Combat.lua — socos (clique/J), pesado (botão direito/K), bloqueio (F segurado). Mobile: botões na tela.
-- Barra de stamina/HP, hit-marker, screen shake e sons.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)

local Combat = {}
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local staminaFill: Frame
local hpFill: Frame
local comboLabel: TextLabel
local koLabel: TextLabel
local blockBadge: TextLabel
local blocking = false
local sounds: { [string]: Sound } = {}
local koBlur: BlurEffect
local koColor: ColorCorrectionEffect
local koVignette: Frame
local koActive = false
local lastHp = -1
local lowHpVignette: Frame
local strengthLabel: TextLabel
-- Modo de luta (pedido do usuário 08/11): fora dele o clique não soca e as luvas somem.
local fightMode = false
local combatBox: Frame
local hintLabel: TextLabel
local mobilePad: Frame? = nil
local fightBtn: TextButton
local fightCaption: TextLabel
local layoutCombat: () -> () = function() end

-- Fase 3: animações de boxe (kit make-anim do fwjelaa; IDs em AnimationIds). Tocadas só no
-- personagem LOCAL: o Animator replica a animação do próprio jogador para os outros.
local AnimationIds = require(game.ReplicatedStorage.Shared.AnimationIds)
local tracks: { [string]: AnimationTrack } = {}
local tracksFor: Model? = nil
local punchSide = false

local function playAnim(name: string, speed: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local id = (AnimationIds :: { [string]: string })[name]
	if not char or not hum or not id or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return -- só R15 (as animações do kit são R15); R6 segue sem animação de soco
	end
	if tracksFor ~= char then
		table.clear(tracks)
		tracksFor = char
	end
	local track = tracks[name]
	if not track then
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, loaded = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if not ok or not loaded then
			return
		end
		local t = loaded :: AnimationTrack
		t.Priority = Enum.AnimationPriority.Action
		tracks[name] = t
		track = t
	end
	local t = track :: AnimationTrack
	t:Play(0.05, 1, speed)
end

local function sound(key: string, volume: number?)
	local s = sounds[key]
	if not s then
		local id = (Config.Sounds :: any)[key]
		if not id or id == 0 then
			return
		end
		local created = Instance.new("Sound")
		created.SoundId = id
		created.Volume = volume or 0.6
		created.Parent = SoundService
		sounds[key] = created
		created:Play()
		return
	end
	s:Play()
end
Combat.sound = sound
local function vo(key: string)
	UI.sfx(key, 1)
end

local function shake(intensity: number, duration: number)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) / duration
		if a >= 1 then
			conn:Disconnect()
			return
		end
		local k = intensity * (1 - a)
		camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end
Combat.shake = shake

local function hitMarker(worldPos: Vector3, text: string, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(worldPos + Vector3.new(math.random(-1, 1), 2, 0))
	part.Parent = Workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.Parent = part
	local l = UI.label(bb, text, { Size = UDim2.fromScale(1, 1), TextColor3 = color })
	TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.65, function()
		part:Destroy()
	end)
end

local function rootOfUser(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Desacordado: visão embaçada + escura + oscilando por poucos segundos; recupera com fade.
local function startKO(seconds: number)
	if koActive then
		return
	end
	koActive = true
	koBlur.Enabled = true
	koColor.Enabled = true
	koVignette.Visible = true
	TweenService:Create(koBlur, TweenInfo.new(0.25), { Size = 28 }):Play()
	TweenService:Create(
		koColor,
		TweenInfo.new(0.25),
		{ Brightness = -0.45, Contrast = -0.2, Saturation = -0.8, TintColor = Color3.fromRGB(180, 120, 140) }
	):Play()
	TweenService:Create(koVignette, TweenInfo.new(0.25), { BackgroundTransparency = 0.35 }):Play()
	koLabel.Visible = true
	koLabel.Text = "DESACORDADO"
	UI.pop(koLabel)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > seconds - 0.6 or not koActive then
			conn:Disconnect()
			return
		end
		-- câmera balança como se estivesse tonto
		camera.CFrame = camera.CFrame
			* CFrame.Angles(math.sin(t * 2.3) * 0.004, math.cos(t * 1.7) * 0.004, math.sin(t * 3.1) * 0.006)
		koBlur.Size = 22 + math.sin(t * 2.5) * 6
		koLabel.TextTransparency = 0.2 + 0.2 * math.sin(t * 4)
	end)
	task.delay(math.max(0.5, seconds - 0.6), function()
		TweenService:Create(koBlur, TweenInfo.new(0.6), { Size = 0 }):Play()
		TweenService:Create(
			koColor,
			TweenInfo.new(0.6),
			{ Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
		):Play()
		TweenService:Create(koVignette, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(koLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.65, function()
			koBlur.Enabled = false
			koColor.Enabled = false
			koVignette.Visible = false
			koLabel.Visible = false
			koLabel.TextTransparency = 0
			koActive = false
		end)
	end)
end

local function flashDamage(heavy: boolean)
	lowHpVignette.BackgroundColor3 = UI.Colors.Red
	lowHpVignette.Visible = true
	lowHpVignette.BackgroundTransparency = if heavy then 0.45 else 0.65
	TweenService:Create(lowHpVignette, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function setBlock(on: boolean)
	if blocking == on then
		return
	end
	blocking = on
	Remotes.RequestBlock:FireServer(on)
end

local function buildBars(gui: ScreenGui)
	-- Efeitos de câmera do KO
	koBlur = Instance.new("BlurEffect")
	koBlur.Name = "KOBlur"
	koBlur.Size = 0
	koBlur.Enabled = false
	koBlur.Parent = Lighting
	koColor = Instance.new("ColorCorrectionEffect")
	koColor.Name = "KOColor"
	koColor.Enabled = false
	koColor.Parent = Lighting
	koVignette = Instance.new("Frame")
	koVignette.Name = "KOVignette"
	koVignette.BackgroundColor3 = Color3.new(0, 0, 0)
	koVignette.BackgroundTransparency = 1
	koVignette.BorderSizePixel = 0
	koVignette.Size = UDim2.fromScale(1, 1)
	koVignette.Visible = false
	koVignette.ZIndex = 50
	koVignette.Parent = gui
	UI.gradient(koVignette, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	lowHpVignette = Instance.new("Frame")
	lowHpVignette.Name = "DamageVignette"
	lowHpVignette.BackgroundColor3 = UI.Colors.Red
	lowHpVignette.BackgroundTransparency = 1
	lowHpVignette.BorderSizePixel = 0
	lowHpVignette.Size = UDim2.fromScale(1, 1)
	lowHpVignette.Visible = false
	lowHpVignette.ZIndex = 49
	lowHpVignette.Parent = gui
	UI.gradient(lowHpVignette, UI.Colors.Red, UI.Colors.Red, 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})

	-- Painel do lutador
	-- Fase 3 (HUD): mesmo painel azul-marinho/dourado da HUD, escala por aparelho e texto >= 20 px
	-- no desenho 1080p (>= 12 px na escala mínima 0,6).
	local box = UI.panel(gui, {
		Name = "CombatBars",
		Visible = false,
		Size = UDim2.fromOffset(400, 128),
		Position = UDim2.new(1, -12, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 0.05,
	})
	UI.autoScale(box)
	UI.icon(box, "glove", { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(12, 14), ZIndex = 3 })
	strengthLabel = UI.label(box, "FORÇA x1.00", {
		Size = UDim2.fromOffset(124, 24),
		Position = UDim2.fromOffset(8, 92),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 3,
	})
	-- Rótulos com coluna própria (90..146) e barras a partir de 154: nada encosta (revisão 08/11).
	UI.label(box, "HP", {
		TextScaled = false,
		TextSize = 22,
		Size = UDim2.fromOffset(56, 28),
		Position = UDim2.fromOffset(90, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Red,
		ZIndex = 3,
	})
	local hpBg
	hpBg, hpFill = UI.bar(
		box,
		UI.Colors.Red,
		{ Size = UDim2.fromOffset(232, 28), Position = UDim2.fromOffset(156, 20), ZIndex = 3 }
	)
	local hpText = UI.label(
		hpBg,
		"100 / 100",
		{ Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 20, Font = UI.FontBody, ZIndex = 7 }
	)
	hpText.Name = "HpText"
	UI.label(box, "STA", {
		TextScaled = false,
		TextSize = 22,
		Size = UDim2.fromOffset(56, 28),
		Position = UDim2.fromOffset(90, 60),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 3,
	})
	local _stBg
	_stBg, staminaFill = UI.bar(
		box,
		UI.Colors.Accent,
		{ Size = UDim2.fromOffset(232, 28), Position = UDim2.fromOffset(156, 60), ZIndex = 3 }
	)
	blockBadge = UI.label(box, "🛡 BLOQUEANDO", {
		Size = UDim2.fromOffset(232, 24),
		Position = UDim2.fromOffset(156, 96),
		TextColor3 = UI.Colors.Blue,
		TextScaled = false,
		TextSize = 20,
		Font = UI.FontBody,
		Visible = false,
		ZIndex = 3,
	})
	comboLabel = UI.title(gui, "", {
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 20,
	})
	koLabel = UI.title(gui, "K.O.!", {
		Size = UDim2.fromOffset(520, 110),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 60,
	})
	local hint =
		UI.label(gui, "Clique/J: soco  •  Dir./K: pesado  •  F: bloquear  •  zona segura no seu pátio", {
			Size = UDim2.fromOffset(700, 30),
			Position = UDim2.new(1, -12, 1, -150),
			AnchorPoint = Vector2.new(1, 1),
			TextScaled = false,
			TextSize = 20,
			Font = UI.FontBody,
			BackgroundTransparency = 0.45,
			BackgroundColor3 = Color3.fromRGB(16, 20, 54),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	hint.Visible = false
	combatBox = box
	hintLabel = hint
	hint.Text = "Clique/J: soco  •  Dir./K: pesado  •  F: bloquear  •  Q: sair da luta"

	-- Botão LUTAR / SAIR (canto inferior direito). Teclado: Q. Controle: Y.
	local holder = Instance.new("Frame")
	holder.Name = "FightToggle"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Size = UDim2.fromOffset(300, 100)
	holder.Position = UDim2.new(1, -12, 1, -16)
	holder.Parent = gui
	UI.autoScale(holder)
	-- Botão grande da referência (luva + LUTAR); continua com Q no teclado e Y no controle.
	fightBtn = UI.button(holder, "", UI.Colors.Red, { Name = "FightButton", Size = UDim2.fromOffset(300, 92) })
	UI.icon(fightBtn, "hud2_fistglove", {
		Size = UDim2.fromOffset(80, 84),
		Position = UDim2.fromOffset(2, -6),
		ZIndex = fightBtn.ZIndex + 1,
	})
	fightCaption = UI.label(fightBtn, "LUTAR", {
		Size = UDim2.fromOffset(180, 70),
		Position = UDim2.fromOffset(92, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = fightBtn.ZIndex + 1,
	})
	fightBtn.Activated:Connect(function()
		Combat.setFightMode(not fightMode)
	end)

	layoutCombat = function()
		local k = UI.deviceScale()
		box.Position = UDim2.new(1, -12, 1, -math.floor(16 + 112 * k))
		hint.Position = UDim2.new(1, -12, 1, -math.floor(16 + 112 * k + 128 * k + 8))
	end
	layoutCombat()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCombat)
	end
end

-- Liga/desliga o modo de luta (o servidor confirma pelo CombatState).
function Combat.setFightMode(on: boolean)
	if on == fightMode then
		return
	end
	fightMode = on
	Remotes.RequestFightMode:FireServer(on)
	Combat.applyFightMode()
	UI.sfx(if on then "Bell" else "Click", 0.5)
end

function Combat.applyFightMode()
	combatBox.Visible = fightMode
	hintLabel.Visible = fightMode and not UserInputService.TouchEnabled
	local pad = mobilePad
	if pad then
		pad.Visible = fightMode
	end
	fightCaption.Text = if fightMode then "SAIR" else "LUTAR"
	fightBtn.BackgroundColor3 = if fightMode then Color3.fromRGB(110, 110, 130) else UI.Colors.Red
	if not fightMode and blocking then
		blocking = false
	end
end

local function buildMobile(gui: ScreenGui)
	if not UserInputService.TouchEnabled then
		return
	end
	local pad = UI.frame(gui, {
		Name = "MobileCombat",
		Visible = false,
		Size = UDim2.fromOffset(190, 190),
		Position = UDim2.new(1, -16, 1, -230),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	})
	UI.autoScale(pad)
	mobilePad = pad
	local punch = UI.button(
		pad,
		"👊",
		UI.Colors.Accent,
		{ Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(100, 100) }
	)
	UI.corner(punch, 42)
	local heavy =
		UI.button(pad, "💥", UI.Colors.Red, { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 110) })
	UI.corner(heavy, 35)
	local block = UI.button(
		pad,
		"🛡",
		UI.Colors.Blue,
		{ Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(110, 10) }
	)
	UI.corner(block, 35)
	punch.Activated:Connect(function()
		Remotes.RequestPunch:FireServer(false)
	end)
	heavy.Activated:Connect(function()
		Remotes.RequestPunch:FireServer(true)
	end)
	block.MouseButton1Down:Connect(function()
		setBlock(true)
	end)
	block.MouseButton1Up:Connect(function()
		setBlock(false)
	end)
	block.MouseLeave:Connect(function()
		setBlock(false)
	end)
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonY then
			Combat.setFightMode(not fightMode)
			return
		end
		if not fightMode then
			return -- fora do modo de luta: clique é só clique (câmera, mundo)
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or key == Enum.KeyCode.J
			or key == Enum.KeyCode.ButtonR1
		then
			Remotes.RequestPunch:FireServer(false)
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton2
			or key == Enum.KeyCode.K
			or key == Enum.KeyCode.ButtonR2
		then
			Remotes.RequestPunch:FireServer(true)
		elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonL1 then
			setBlock(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL1 then
			setBlock(false)
		end
	end)
end

function Combat.init(gui: ScreenGui)
	buildBars(gui)
	buildMobile(gui)
	bindInput()

	Remotes.CombatState.OnClientEvent:Connect(function(s)
		if type(s) ~= "table" then
			return
		end
		UI.setBar(staminaFill, s.stamina / math.max(1, s.maxStamina))
		UI.setBar(hpFill, s.hp / math.max(1, s.maxHp))
		local hpText = hpFill.Parent and hpFill.Parent:FindFirstChild("HpText") :: TextLabel?
		if hpText then
			hpText.Text = string.format("%d / %d", math.floor(s.hp), math.floor(s.maxHp))
		end
		if s.strength then
			strengthLabel.Text = string.format("FORÇA x%.2f", s.strength)
		end
		if lastHp >= 0 and s.hp < lastHp then
			flashDamage(lastHp - s.hp > 20)
		end
		lastHp = s.hp
		if type(s.fightMode) == "boolean" and s.fightMode ~= fightMode then
			fightMode = s.fightMode -- a arena e o chefe ligam o modo de luta pelo servidor
			Combat.applyFightMode()
		end
		blockBadge.Visible = s.blocking == true
		blocking = s.blocking == true
		if s.combo and s.combo >= 2 then
			comboLabel.Text = Locale.fmt("combo", nil, { n = s.combo })
			comboLabel.Visible = true
			UI.pop(comboLabel)
		else
			comboLabel.Visible = false
		end
		if s.ko and not koActive then
			startKO(Config.Combat.KOBlurSeconds)
		end
	end)

	Remotes.CombatEvent.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Swing" then
			sound("Whoosh", 0.35)
			if e.attacker == player.UserId then
				-- Fase 3: animação de soco (jab/direto alternados; pesado = golpe final do combo)
				punchSide = not punchSide
				playAnim(if e.heavy then "R15_M1_4" elseif punchSide then "R15_M1_1" else "R15_M1_2", 1.25)
			end
		elseif e.kind == "Hit" then
			if e.victim == player.UserId and not e.blocked then
				playAnim("R15_HitReact", 1)
			end
			local vroot = rootOfUser(e.victim)
			if vroot then
				hitMarker(
					vroot.Position,
					if e.blocked then "BLOQUEADO" else (if e.heavy then "PESADO!" else "HIT"),
					if e.blocked then UI.Colors.Blue else (if e.heavy then UI.Colors.Red else UI.Colors.Accent)
				)
			end
			sound(if e.blocked then "Block" elseif e.heavy then "Heavy" else "Punch")
			if e.victim == player.UserId then
				shake(if e.heavy then 1.2 else 0.5, 0.25)
			elseif e.attacker == player.UserId then
				shake(0.25, 0.12)
			end
		elseif e.kind == "NpcHit" then
			-- soco no Dragão Faminto
			sound(if e.heavy then "Heavy" else "Punch")
			if e.attacker == player.UserId then
				shake(0.3, 0.12)
			end
		elseif e.kind == "KO" then
			sound("KO", 0.9)
			vo("VO_KO")
			local vroot = rootOfUser(e.victim)
			if vroot then
				hitMarker(vroot.Position, "K.O.!", UI.Colors.Red)
			end
			if e.victim == player.UserId then
				shake(2.5, 0.6)
			end
		elseif e.kind == "Impact" then
			sound("Impact", 0.8)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and typeof(e.pos) == "Vector3" then
				local d = (root.Position - e.pos).Magnitude
				shake(math.clamp(3 - d / 40, 0.2, 3), 0.5)
			end
		end
	end)
end

return Combat
