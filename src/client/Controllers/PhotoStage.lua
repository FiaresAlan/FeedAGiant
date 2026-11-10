--!strict
-- PhotoStage — câmera voluntária no Mirante dos Colossos.
-- Não altera o avatar nem abre tela escura. Abandona automaticamente após 12s.
-- A captura de tela usa o botão nativo do dispositivo/Roblox, sem upload remoto.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local CaptureService = game:GetService("CaptureService")

local player = Players.LocalPlayer
local PhotoStage = {}

local EXIT_ACTION = "FeedAGiant_ExitPhotoSpot"
local active = false
local serial = 0
local currentCamera: Camera? = nil
local oldSubject: Instance? = nil
local photoPreview: Model? = nil
local panel: Frame? = nil
local bound: { [Instance]: boolean } = {}

local function hide()
	serial += 1
	if not active then
		return
	end
	active = false
	ContextActionService:UnbindAction(EXIT_ACTION)
	if photoPreview then
		photoPreview:Destroy()
		photoPreview = nil
	end
	if panel then
		panel.Visible = false
	end
	local cam = currentCamera
	if cam and cam.Parent then
		cam.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		elseif oldSubject then
			cam.CameraSubject = oldSubject
		end
	end
	currentCamera, oldSubject = nil, nil
end

-- Fotografa o jogador JUNTO do gigante verdadeiro em miniatura.
-- A cópia é local ao aparelho, sem alterar o gigante que produz renda na base.
local function previewOwnGiant(spot: BasePart, cam: Camera)
	local original: Model? = nil
	for _, item in Workspace:GetChildren() do
		if item:IsA("Model") and item:GetAttribute("OwnerUserId") == player.UserId then
			original = item
			break
		end
	end
	if not original then
		return
	end
	local ok, result = pcall(function()
		return (original :: Model):Clone()
	end)
	if not ok or not result or not result:IsA("Model") then
		return
	end
	local clone = result :: Model
	clone.Name = "PhotoPreviewOnly"
	clone:SetAttribute("OwnerUserId", nil)
	local count = 0
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
			or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter")
			or d:IsA("Sound") or d:IsA("PointLight") or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			count += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	-- Limite evita clonar corpos extras enormes em dispositivos móveis.
	if count == 0 or count > 80 then
		clone:Destroy()
		return
	end
	local boundingOk, _, ext = pcall(function()
		return clone:GetBoundingBox()
	end)
	if not boundingOk or not ext then
		clone:Destroy()
		return
	end
	local height = math.max(1, ext.Y)
	local scaled = math.clamp(10 / height, 0.06, 2)
	local done = pcall(function()
		clone:ScaleTo(clone:GetScale() * scaled)
		local box, size = clone:GetBoundingBox()
		local bottom = box * CFrame.new(0, -size.Y / 2, 0)
		local offset = clone:GetPivot():ToObjectSpace(bottom)
		clone:PivotTo(spot.CFrame * CFrame.new(7, 0.6, -3) * offset:Inverse())
	end)
	if not done then
		clone:Destroy()
		return
	end
	clone.Parent = cam -- não entra no Workspace como gigante jogável nem replica a ninguém
	photoPreview = clone
end

local function show(spot: BasePart)
	if active or not spot:IsDescendantOf(Workspace) then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
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
	previewOwnGiant(spot, cam)
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
		-- Streaming/replicação pode entregar a tag antes do filho ProximityPrompt.
		task.defer(function()
			local loaded = spot:WaitForChild("PhotoPrompt", 5)
			if loaded then
				bind(spot)
			end
		end)
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

local function savePhoto()
	if not active then
		return
	end
	-- Capta somente quando o usuário toca no botão. Nada é enviado para fora do
	-- dispositivo; a Roblox abre confirmação nativa antes de salvar na galeria.
	local ok, err = pcall(function()
		CaptureService:TakeScreenshotCaptureAsync(function(result, capture)
			if result == Enum.ScreenshotCaptureResult.Success and capture then
				CaptureService:PromptSaveCapturesToGallery({ capture }, function(_results)
					-- Somente a interface nativa confirma o salvamento.
				end)
			else
				warn("[PhotoStage] captura indisponível neste dispositivo:", result)
			end
		end, { UICaptureMode = Enum.UICaptureMode.None })
	end)
	if not ok then
		warn("[PhotoStage] erro de captura (use a captura nativa do aparelho):", err)
	end
end

function PhotoStage.init(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "PhotoStageGuide"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 76)
	frame.Size = UDim2.fromOffset(380, 100)
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
	title.Size = UDim2.new(1, -12, 0, 48)
	title.Position = UDim2.fromOffset(6, 2)
	title.Font = Enum.Font.FredokaOne
	title.Text = "MIRANTE DOS COLOSSOS\nEnquadre seu gigante e compartilhe"
	title.TextColor3 = Color3.fromRGB(255, 225, 151)
	title.TextScaled = true
	title.ZIndex = 86
	title.Parent = frame
	local exit = Instance.new("TextButton")
	exit.Name = "ExitPhoto"
	exit.Size = UDim2.fromOffset(150, 34)
	exit.Position = UDim2.new(0.5, 16, 1, -40)
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
	local save = Instance.new("TextButton")
	save.Name = "SavePhoto"
	save.Size = UDim2.fromOffset(150, 34)
	save.Position = UDim2.new(0.5, -166, 1, -40)
	save.BackgroundColor3 = Color3.fromRGB(58, 160, 144)
	save.Text = "SALVAR FOTO"
	save.Font = Enum.Font.FredokaOne
	save.TextColor3 = Color3.new(1, 1, 1)
	save.TextScaled = true
	save.ZIndex = 87
	save.Parent = frame
	local roundSave = Instance.new("UICorner")
	roundSave.CornerRadius = UDim.new(0, 7)
	roundSave.Parent = save
	save.Activated:Connect(savePhoto)
	panel = frame
	for _, spot in CollectionService:GetTagged("ColossusPhotoSpot") do
		bind(spot)
	end
	CollectionService:GetInstanceAddedSignal("ColossusPhotoSpot"):Connect(bind)
	player.CharacterAdded:Connect(hide)
end

return PhotoStage
