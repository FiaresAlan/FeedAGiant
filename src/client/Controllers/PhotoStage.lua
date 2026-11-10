--!strict
-- PhotoStage — câmera voluntária no Mirante dos Colossos.
-- Não altera o avatar nem abre tela escura. Abandona automaticamente após 12s.
-- A captura de tela usa o botão nativo do dispositivo/Roblox, sem upload remoto.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local PhotoStage = {}

local EXIT_ACTION = "FeedAGiant_ExitPhotoSpot"
local active = false
local serial = 0
local currentCamera: Camera? = nil
local oldSubject: Instance? = nil
local panel: Frame? = nil
local bound: { [Instance]: boolean } = {}
local exitButton: TextButton? = nil

local function hide()
	serial += 1
	if not active then
		return
	end
	active = false
	ContextActionService:UnbindAction(EXIT_ACTION)
	if panel then
		panel.Visible = false
	end
	local cam = currentCamera
	if cam and cam.Parent then
		cam.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		cam.CameraSubject = if hum then hum else oldSubject
	end
	currentCamera, oldSubject = nil, nil
end

local function show(spot: BasePart)
	if active or not spot:IsDescendantOf(Workspace) then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	if (root.Position - spot.Position).Magnitude > 19 then
		return
	end
	local look = spot:FindFirstAncestor("ColossusLookout")
	local marker = look and look:FindFirstChild("PhotoCamera")
	local cam = Workspace.CurrentCamera
	if not marker or not marker:IsA("BasePart") or not cam then
		return
	end
	active = true
	serial += 1
	local this = serial
	currentCamera = cam
	oldSubject = cam.CameraSubject
	cam.CameraType = Enum.CameraType.Scriptable
	if panel then
		panel.Visible = true
	end
	local target = CFrame.lookAt(marker.Position, spot.Position + Vector3.new(0, 3.3, 0))
	TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	ContextActionService:BindAction(EXIT_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	task.delay(12, function()
		if active and serial == this then
			hide()
		end
	end)
end

local function bind(spot: Instance)
	if bound[spot] or not spot:IsA("BasePart") then
		return
	end
	local prompt = spot:FindFirstChild("PhotoPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	bound[spot] = true
	prompt.Triggered:Connect(function(who)
		if who == nil or who == player then
			show(spot)
		end
	end)
	spot.Destroying:Connect(function()
		bound[spot] = nil
		if active then
			hide()
		end
	end)
end

function PhotoStage.init(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "PhotoStageGuide"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 76)
	frame.Size = UDim2.fromOffset(340, 82)
	frame.BackgroundTransparency = 0.12
	frame.BackgroundColor3 = Color3.fromRGB(30, 42, 52)
	frame.Visible = false
	frame.ZIndex = 85
	frame.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 10)
	round.Parent = frame
	local title = Instance.new("TextLabel")
	title.Name = "Guide"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 42)
	title.Position = UDim2.fromOffset(6, 2)
	title.Font = Enum.Font.FredokaOne
	title.Text = "MIRANTE DOS COLOSSOS\nUse a captura de tela do seu dispositivo"
	title.TextColor3 = Color3.fromRGB(255, 225, 151)
	title.TextScaled = true
	title.ZIndex = 86
	title.Parent = frame
	local exit = Instance.new("TextButton")
	exit.Name = "ExitPhoto"
	exit.Size = UDim2.fromOffset(138, 27)
	exit.Position = UDim2.new(0.5, -69, 1, -30)
	exit.BackgroundColor3 = Color3.fromRGB(221, 97, 69)
	exit.Text = "SAIR DA FOTO"
	exit.Font = Enum.Font.FredokaOne
	exit.TextColor3 = Color3.new(1, 1, 1)
	exit.TextScaled = true
	exit.ZIndex = 87
	exit.Parent = frame
	local exitRound = Instance.new("UICorner")
	exitRound.CornerRadius = UDim.new(0, 7)
	exitRound.Parent = exit
	exit.Activated:Connect(hide)
	exitButton = exit
	panel = frame
	for _, spot in CollectionService:GetTagged("ColossusPhotoSpot") do
		bind(spot)
	end
	CollectionService:GetInstanceAddedSignal("ColossusPhotoSpot"):Connect(bind)
	player.CharacterAdded:Connect(hide)
end

return PhotoStage
