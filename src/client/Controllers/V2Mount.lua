--!strict
-- Cliente da montaria V2: controle local e camera, nunca concede velocidade ou propriedade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Features = require(ReplicatedStorage.Shared.Features)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local localPlayer = Players.LocalPlayer

local Controller = {}
local mounted = false
local currentModel: Model? = nil
local sprintHeld = false
local stamina = 100
local boostRemaining = 0
local label: TextLabel?
local lastCameraSubject: Instance?
local savedView: { subject: Instance?, minZoom: number, maxZoom: number, fieldOfView: number }? = nil
local controls: any = nil

local function setCamera(model: Model?)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if model then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		if not savedView then
			savedView = {
				subject = cam.CameraSubject,
				minZoom = localPlayer.CameraMinZoomDistance,
				maxZoom = localPlayer.CameraMaxZoomDistance,
				fieldOfView = cam.FieldOfView,
			}
		end
		lastCameraSubject = cam.CameraSubject
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
		localPlayer.CameraMaxZoomDistance = math.max(42, localPlayer.CameraMinZoomDistance)
		localPlayer.CameraMinZoomDistance = 18
		cam.FieldOfView = 74
	else
		local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		local previous = savedView
		savedView = nil
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum or (if previous then previous.subject else nil) or lastCameraSubject
		local minZoom = if previous then previous.minZoom else 0.5
		local maxZoom = if previous then previous.maxZoom else 25
		localPlayer.CameraMaxZoomDistance = math.max(maxZoom, localPlayer.CameraMinZoomDistance)
		localPlayer.CameraMinZoomDistance = minZoom
		localPlayer.CameraMaxZoomDistance = maxZoom
		cam.FieldOfView = if previous then previous.fieldOfView else 70
	end
end

local function movement(): Vector3
	local cam = workspace.CurrentCamera
	if not cam then return Vector3.zero end
	local axis = Vector3.zero
	if controls then
		local ok, raw = pcall(function() return controls:GetMoveVector() end)
		if ok and typeof(raw) == "Vector3" then axis = raw end
	end
	if not controls or axis.Magnitude < 0.001 then
		-- Alternativa apenas para teclado. Mobile deve ser validado com PlayerModule no Studio.
		local x = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0)
			- (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
		local z = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0)
			- (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
		axis = Vector3.new(x, 0, z)
	end
	if axis.Magnitude > 1 then axis = axis.Unit end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
	if look.Magnitude < 0.001 or right.Magnitude < 0.001 then return Vector3.zero end
	local vector = right.Unit * axis.X - look.Unit * axis.Z
	return if vector.Magnitude > 1 then vector.Unit else vector
end

local function mountAction(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Remotes.V2MountRequest:FireServer(if mounted then "unmount" else "mount")
	end
	return Enum.ContextActionResult.Sink
end

local function sprintAction(_: string, state: Enum.UserInputState)
	sprintHeld = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function boostAction(_: string, state: Enum.UserInputState)
	if mounted and state == Enum.UserInputState.Begin then Remotes.V2MountRequest:FireServer("boost") end
	return Enum.ContextActionResult.Sink
end

function Controller.isMounted(): boolean
	return mounted
end

function Controller.init(gui: ScreenGui)
	if not Features.on("RebuildV2") then return end
	local status = Instance.new("TextLabel")
	status.Name = "V2MountStatus"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 114)
	status.Size = UDim2.fromOffset(316, 36)
	status.BackgroundColor3 = Color3.fromRGB(29, 45, 53)
	status.BackgroundTransparency = 0.1
	status.TextColor3 = Color3.fromRGB(255, 242, 206)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 14
	status.Text = "F / Y · MONTAR"
	status.ZIndex = 15
	status.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = status
	label = status

	-- Bindings com botoes de toque nativos do Roblox; posicoes aprovadas apenas apos teste mobile.
	ContextActionService:BindAction("V2Mount", mountAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("V2Mount", "MONTAR")
	ContextActionService:SetPosition("V2Mount", UDim2.new(1, -95, 1, -195))
	ContextActionService:BindAction("V2Sprint", sprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("V2Sprint", "CORRER")
	ContextActionService:SetPosition("V2Sprint", UDim2.new(1, -180, 1, -110))
	ContextActionService:BindAction("V2Boost", boostAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
	ContextActionService:SetTitle("V2Boost", "PODER")
	ContextActionService:SetPosition("V2Boost", UDim2.new(1, -95, 1, -110))

	localPlayer.CharacterAdded:Connect(function()
		if mounted then
			mounted = false
			currentModel = nil
			setCamera(nil)
		end
	end)

	local scripts = localPlayer:WaitForChild("PlayerScripts")
	task.spawn(function()
		local pm = scripts:WaitForChild("PlayerModule", 10)
		if pm then
			local ok, ctrl = pcall(function() return require(pm):GetControls() end)
			if ok then controls = ctrl end
		end
	end)
	Remotes.V2MountState.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		local wasMounted = mounted
		mounted = payload.mounted == true
		currentModel = if mounted and typeof(payload.model) == "Instance" and payload.model:IsA("Model")
			then payload.model else nil
		stamina = if type(payload.stamina) == "number" then payload.stamina else stamina
		boostRemaining = if type(payload.boostRemaining) == "number" then payload.boostRemaining else 0
		if mounted and currentModel and (not wasMounted or workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject ~= currentModel:FindFirstChildOfClass("Humanoid")) then
			setCamera(currentModel)
		elseif not mounted and wasMounted then
			setCamera(nil)
			sprintHeld = false
		end
		if label then
			label.Text = if mounted then string.format("MONTADO  |  FOLEGO %d%%  |  Q EM %ds",
				math.floor(stamina), math.ceil(boostRemaining)) else "F / Y · MONTAR"
		end
		ContextActionService:SetTitle("V2Mount", if mounted then "DESCER" else "MONTAR")
		ContextActionService:SetTitle("V2Boost",
			if mounted and boostRemaining > 0 then ("PODER %ds"):format(math.ceil(boostRemaining)) else "PODER")
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(1/14)
			if mounted then
				Remotes.V2MountInput:FireServer(movement(), sprintHeld)
			end
		end
	end)
	Remotes.V2MountRequest:FireServer("snapshot")
end

return Controller
