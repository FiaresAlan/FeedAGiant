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

function V3.init()
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
		end
	end)
end

return V3
