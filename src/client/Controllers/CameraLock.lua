--!strict
-- CameraLock.lua — TRAVAR A MIRA (pedido do usuário, 09/11/2026): "um botão que trave a tela na direção
-- que você está olhando, principalmente com o mouse... no boxe isso é importante".
-- Tecla C (ou o botão no canto, no celular; R3 no controle) liga/desliga:
--   * o mouse fica preso no centro e a câmera gira com o movimento do mouse (como o shift-lock);
--   * o personagem SEMPRE olha para onde a câmera olha (o soco vai na direção da mira);
--   * a câmera vai um pouco para o lado do ombro, e uma mira aparece no centro.
-- Só do cliente (o próprio personagem é do cliente na física), nada vai para o servidor.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.Parent.UI)

local CameraLock = {}

local player = Players.LocalPlayer
local locked = false
local button: TextButton
local crosshair: Frame
local hostGui: ScreenGui
local SHOULDER = Vector3.new(1.75, 0.4, 0)

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function setLocked(on: boolean)
	locked = on
	local hum = humanoid()
	if hum then
		hum.AutoRotate = not on
		hum.CameraOffset = if on then SHOULDER else Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	crosshair.Visible = on
	button.Text = if on then "MIRA TRAVADA (C)" else "TRAVAR MIRA (C)"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = if on then Color3.fromRGB(40, 170, 90) else Color3.fromRGB(70, 80, 110)
	UI.sfx("Click", 0.5)
end

function CameraLock.isLocked(): boolean
	return locked
end

function CameraLock.init(gui: ScreenGui)
	hostGui = gui
	button = UI.button(gui, "TRAVAR MIRA (C)", Color3.fromRGB(70, 80, 110), {
		Name = "CameraLockButton",
		Size = UDim2.fromOffset(170, 40),
		AnchorPoint = Vector2.new(1, 1),
		-- acima do botão LUTAR/SAIR (canto inferior direito)
		Position = UDim2.new(1, -16, 1, -96),
		TextScaled = false,
		TextSize = 18,
	})
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0.3
	button.Activated:Connect(function()
		setLocked(not locked)
	end)
	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.fromOffset(10, 10)
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Visible = false
	crosshair.Parent = gui
	UI.corner(crosshair, 5)
	UI.stroke(crosshair, Color3.new(0, 0, 0), 2)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonR3 then
			setLocked(not locked)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if locked then
			setLocked(true) -- vale para o personagem novo
		end
	end)
	RunService:BindToRenderStep("FeedCameraLock", Enum.RenderPriority.Camera.Value + 1, function()
		if not locked then
			return
		end
		-- com uma janela aberta o mouse fica solto (para clicar nos botões); fechou, trava de novo.
		-- A Roblox devolve o mouse ao normal em várias situações: por isso reaplica a cada quadro.
		local windowOpen = false
		for _, c in hostGui:GetChildren() do
			if c:IsA("Frame") and c.Visible and string.sub(c.Name, 1, 4) == "Dim_" then
				windowOpen = true
				break
			end
		end
		if UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = if windowOpen
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		local hum = humanoid()
		if root and root:IsA("BasePart") and cam and hum and not hum.PlatformStand and not hum.Sit then
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
			end
		end
	end)
end

return CameraLock
