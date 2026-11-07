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

local function sound(key: string, volume: number?)
	local s = sounds[key]
	if not s then
		local id = (Config.Sounds :: any)[key]
		if not id or id == 0 then
			return
		end
		s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume or 0.6
		s.Parent = SoundService
		sounds[key] = s
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
	TweenService:Create(koColor, TweenInfo.new(0.25), { Brightness = -0.45, Contrast = -0.2, Saturation = -0.8, TintColor = Color3.fromRGB(180, 120, 140) }):Play()
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
		camera.CFrame = camera.CFrame * CFrame.Angles(math.sin(t * 2.3) * 0.004, math.cos(t * 1.7) * 0.004, math.sin(t * 3.1) * 0.006)
		koBlur.Size = 22 + math.sin(t * 2.5) * 6
		koLabel.TextTransparency = 0.2 + 0.2 * math.sin(t * 4)
	end)
	task.delay(math.max(0.5, seconds - 0.6), function()
		TweenService:Create(koBlur, TweenInfo.new(0.6), { Size = 0 }):Play()
		TweenService:Create(koColor, TweenInfo.new(0.6), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
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
	UI.gradient(koVignette, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 0).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0) })
	lowHpVignette = Instance.new("Frame")
	lowHpVignette.Name = "DamageVignette"
	lowHpVignette.BackgroundColor3 = UI.Colors.Red
	lowHpVignette.BackgroundTransparency = 1
	lowHpVignette.BorderSizePixel = 0
	lowHpVignette.Size = UDim2.fromScale(1, 1)
	lowHpVignette.Visible = false
	lowHpVignette.ZIndex = 49
	lowHpVignette.Parent = gui
	UI.gradient(lowHpVignette, UI.Colors.Red, UI.Colors.Red, 0).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0) })

	-- Painel do lutador
	local box = UI.panel(gui, {
		Name = "CombatBars",
		Size = UDim2.fromOffset(290, 96),
		Position = UDim2.new(1, -12, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 0.05,
	})
	UI.icon(box, "glove", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 14), ZIndex = 3 })
	strengthLabel = UI.label(box, "FORÇA x1.00", { Size = UDim2.fromOffset(80, 16), Position = UDim2.fromOffset(-6, 62), TextScaled = false, TextSize = 12, Font = UI.FontBody, TextColor3 = UI.Colors.Accent, ZIndex = 3 })
	UI.label(box, "HP", { Size = UDim2.fromOffset(34, 20), Position = UDim2.fromOffset(60, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Red, ZIndex = 3 })
	local hpBg
	hpBg, hpFill = UI.bar(box, UI.Colors.Red, { Size = UDim2.fromOffset(184, 20), Position = UDim2.fromOffset(94, 14), ZIndex = 3 })
	local hpText = UI.label(hpBg, "100 / 100", { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 12, Font = UI.FontBody, ZIndex = 7 })
	hpText.Name = "HpText"
	UI.label(box, "STA", { Size = UDim2.fromOffset(34, 20), Position = UDim2.fromOffset(60, 46), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Accent, ZIndex = 3 })
	local stBg
	stBg, staminaFill = UI.bar(box, UI.Colors.Accent, { Size = UDim2.fromOffset(184, 20), Position = UDim2.fromOffset(94, 46), ZIndex = 3 })
	blockBadge = UI.label(box, "🛡 BLOQUEANDO", { Size = UDim2.fromOffset(180, 20), Position = UDim2.fromOffset(94, 70), TextColor3 = UI.Colors.Blue, TextScaled = false, TextSize = 13, Font = UI.FontBody, Visible = false, ZIndex = 3 })
	comboLabel = UI.title(gui, "", { Size = UDim2.fromOffset(300, 60), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 20 })
	koLabel = UI.title(gui, "K.O.!", { Size = UDim2.fromOffset(520, 110), Position = UDim2.new(0.5, 0, 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 60 })
	local hint = UI.label(gui, "Clique/J: soco  •  Dir./K: pesado  •  F: bloquear  •  zona segura no seu pátio", { Size = UDim2.fromOffset(460, 18), Position = UDim2.new(1, -12, 1, -126), AnchorPoint = Vector2.new(1, 1), TextScaled = false, TextSize = 12, Font = UI.FontBody, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Right })
	hint.Visible = not UserInputService.TouchEnabled
end

local function buildMobile(gui: ScreenGui)
	if not UserInputService.TouchEnabled then
		return
	end
	local pad = UI.frame(gui, { Name = "MobileCombat", Size = UDim2.fromOffset(190, 190), Position = UDim2.new(1, -16, 1, -134), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1 })
	local punch = UI.button(pad, "👊", UI.Colors.Accent, { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(100, 100) })
	UI.corner(punch, 42)
	local heavy = UI.button(pad, "💥", UI.Colors.Red, { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 110) })
	UI.corner(heavy, 35)
	local block = UI.button(pad, "🛡", UI.Colors.Blue, { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(110, 10) })
	UI.corner(block, 35)
	punch.MouseButton1Click:Connect(function()
		Remotes.RequestPunch:FireServer(false)
	end)
	heavy.MouseButton1Click:Connect(function()
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
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.J then
			Remotes.RequestPunch:FireServer(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.K then
			Remotes.RequestPunch:FireServer(true)
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL1 then
			setBlock(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			Remotes.RequestPunch:FireServer(false)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			Remotes.RequestPunch:FireServer(true)
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
		elseif e.kind == "Hit" then
			local vroot = rootOfUser(e.victim)
			if vroot then
				hitMarker(vroot.Position, if e.blocked then "BLOQUEADO" else (if e.heavy then "PESADO!" else "HIT"), if e.blocked then UI.Colors.Blue else (if e.heavy then UI.Colors.Red else UI.Colors.Accent))
			end
			sound(if e.blocked then "Block" elseif e.heavy then "Heavy" else "Punch")
			if e.victim == player.UserId then
				shake(if e.heavy then 1.2 else 0.5, 0.25)
			elseif e.attacker == player.UserId then
				shake(0.25, 0.12)
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
