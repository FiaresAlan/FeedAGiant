--!strict
-- V3 — parte do cliente da especificação v3 (08/11/2026), atrás de Features no servidor: o
-- servidor só manda estes avisos com a função ligada, então aqui não há checagem de flag.
--   * ObjectiveHint: a dica do servidor ocupa a linha de META da HUD por 12 s (uma por vez);
--   * OnboardingV2 Arrival: câmera de 2,5 s diante do próprio gigante, de baixo para cima;
--   * OnboardingV2 FirstFeed: tremida, FOV e zoom dobrados na primeira alimentação.
-- Tudo respeita "movimento reduzido" (GuiService.ReducedMotionEnabled).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local V3 = {}

local HINT_SECONDS = 12
local COLORS: { [string]: Color3 } = {
	now = Color3.fromRGB(120, 230, 120),
	soon = Color3.fromRGB(255, 150, 70),
	short = Color3.fromRGB(255, 215, 80),
	long = Color3.fromRGB(190, 150, 255),
}

local function myGiant(): Model?
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId and m.Name:match("^Giant_") then
			return m
		end
	end
	return nil
end

local hintToken = 0
local function showHint(data: { [string]: any })
	hintToken += 1
	local token = hintToken
	local text = if type(data.text) == "string" then data.text else ""
	if text == "" then
		HUD.setGoalOverride(nil, nil)
		return
	end
	HUD.setGoalOverride(text, COLORS[data.category] or UI.Colors.Accent)
	task.delay(HINT_SECONDS, function()
		if hintToken == token then
			HUD.setGoalOverride(nil, nil)
		end
	end)
end

local function shake(strength: number, duration: number)
	if UI.reducedMotion() then
		return
	end
	local t0 = os.clock()
	local name = "V3Shake"
	RunService:UnbindFromRenderStep(name)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local a = os.clock() - t0
		local cam = Workspace.CurrentCamera
		if a >= duration or not cam then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = strength * (1 - a / duration)
		cam.CFrame = cam.CFrame
			* CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end

local function fovPulse(delta: number, duration: number)
	local cam = Workspace.CurrentCamera
	if not cam or UI.reducedMotion() then
		return
	end
	local base = cam.FieldOfView
	local up =
		TweenService:Create(cam, TweenInfo.new(duration / 2, Enum.EasingStyle.Sine), { FieldOfView = base + delta })
	up:Play()
	up.Completed:Once(function()
		TweenService:Create(cam, TweenInfo.new(duration / 2, Enum.EasingStyle.Sine), { FieldOfView = base }):Play()
	end)
end

local busyCam = false
local function arrival(seconds: number)
	local cam = Workspace.CurrentCamera
	local giant = myGiant()
	if not cam or not giant or busyCam then
		return
	end
	busyCam = true
	local _, size = giant:GetBoundingBox()
	local center = giant:GetPivot().Position + Vector3.new(0, size.Y * 0.5, 0)
	local look = giant:GetPivot().LookVector
	local dist = math.max(size.Y, size.X, size.Z) * 1.4 + 10
	local startCf =
		CFrame.lookAt(center + look * dist + Vector3.new(0, -size.Y * 0.4, 0), center + Vector3.new(0, size.Y * 0.3, 0))
	local endCf = CFrame.lookAt(center + look * dist * 0.9 + Vector3.new(0, size.Y * 0.35, 0), center)
	local prevType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = startCf
	if UI.reducedMotion() then
		cam.CFrame = endCf
		task.wait(seconds)
	else
		local tw = TweenService:Create(
			cam,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = endCf }
		)
		tw:Play()
		task.wait(seconds * 0.6)
		shake(1.2, 0.4) -- "passo" do gigante
		task.wait(seconds * 0.4)
	end
	cam.CameraType = if prevType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else prevType
	busyCam = false
end

local function firstFeed()
	-- O FeedFx já faz o efeito normal; aqui vem o "dobro": tremida forte, FOV +5 e um pulo de zoom.
	task.delay(0.55, function() -- mesma hora da mordida (GameRules.Feed.FlightSeconds ~0,6 s)
		shake(3, 0.45)
		fovPulse(5, 0.3)
	end)
end

-- Escolha da espécie inicial (StarterSpecies): 3 cartões, 1 toque. O servidor valida (só os 3 ids,
-- 1 vez por conta). Sem "pode trocar depois" (pedido do usuário).
local starterWin: Frame? = nil
local starterBody: Frame? = nil
local pendingStarter: { any }? = nil -- opções enquanto a escolha não foi confirmada pelo servidor

local function showStarterChoice(options: { any })
	pendingStarter = options
	local w, body = starterWin, starterBody
	if not w or not body then
		return
	end
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	UI.label(body, "Escolha o seu primeiro Gigante", {
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 14,
	})
	for i, opt in options do
		if type(opt) ~= "table" or type(opt.id) ~= "string" then
			continue
		end
		local color = if typeof(opt.color) == "Color3" then opt.color else UI.Colors.Accent
		local card = UI.frame(body, {
			Size = UDim2.new(1 / 3, -12, 1, -60),
			Position = UDim2.new((i - 1) / 3, 6, 0, 52),
			BackgroundColor3 = UI.Colors.Panel2,
			ZIndex = 13,
		})
		UI.corner(card, 14)
		UI.stroke(card, color, 4)
		local orb = UI.frame(card, {
			Size = UDim2.fromOffset(90, 90),
			Position = UDim2.new(0.5, -45, 0, 14),
			BackgroundColor3 = color,
			ZIndex = 14,
		})
		UI.corner(orb, 45)
		UI.label(card, tostring(opt.name), {
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.fromOffset(8, 112),
			TextColor3 = color,
			ZIndex = 14,
		})
		UI.label(card, tostring(opt.desc or ""), {
			Size = UDim2.new(1, -16, 0, 60),
			Position = UDim2.fromOffset(8, 154),
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			ZIndex = 14,
		})
		local b = UI.button(card, "ESCOLHER", color, {
			Size = UDim2.new(1, -24, 0, 56),
			Position = UDim2.new(0, 12, 1, -68),
			TextScaled = false,
			TextSize = 22,
			ZIndex = 15,
		})
		local id = opt.id
		b.Activated:Connect(function()
			Remotes.RequestStarter:FireServer(id)
		end)
	end
	if not w.Visible then
		UI.pop(w)
	end
end

function V3.init(gui: ScreenGui?)
	if gui then
		local w, body = UI.window(gui, "SEU GIGANTE", UDim2.fromOffset(820, 440))
		starterWin, starterBody = w, body
		-- A escolha é obrigatória (revisão cega): sem o X, e se o ESC fechar a janela com a escolha
		-- pendente, ela volta em seguida.
		for _, c in w:GetChildren() do
			if c:IsA("TextButton") and c.Text == "X" then
				c.Visible = false
			end
		end
		w:GetPropertyChangedSignal("Visible"):Connect(function()
			local opts = pendingStarter
			if not w.Visible and opts then
				task.delay(0.6, function()
					if pendingStarter == opts and not w.Visible then
						showStarterChoice(opts)
					end
				end)
			end
		end)
	end
	Remotes.ObjectiveHint.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			showHint(data)
		end
	end)
	Remotes.OnboardingV2.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then
			return
		end
		if data.kind == "Arrival" then
			local s = tonumber(data.seconds) or 2.5
			task.spawn(arrival, math.clamp(s, 1, 4))
		elseif data.kind == "FirstFeed" then
			firstFeed()
		elseif data.kind == "StarterChoice" and type(data.options) == "table" then
			showStarterChoice(data.options)
		elseif data.kind == "StarterChosen" then
			pendingStarter = nil
			local w = starterWin
			if w then
				w.Visible = false
			end
			-- frase pedida pelo usuário, na linha de META por alguns segundos
			HUD.setGoalOverride("Este é o seu Gigante. Ele é seu.", Color3.fromRGB(255, 220, 120))
			task.delay(8, function()
				HUD.setGoalOverride(nil, nil)
			end)
			shake(1.5, 0.4)
		end
	end)
end

return V3
